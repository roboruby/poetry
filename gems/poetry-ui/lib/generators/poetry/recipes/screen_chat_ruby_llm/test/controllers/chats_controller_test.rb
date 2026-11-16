# frozen_string_literal: true

require "test_helper"

# installed by the poetry `screen-chat-ruby-llm` recipe. The server half
# of a turn, short of the model: what a message stores and starts, what a
# refused one answers, and what Stop records. No request reaches a
# provider, since the job is only enqueued.
class ChatsControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  test "a new conversation opens on the welcome, its composer posting to create" do
    get new_chat_path

    assert_response :success
    assert_select "form#chat-form[action='#{chats_path}']", 1
    assert_select "[data-slot=message-scroller-item]", 0
  end

  test "a first message starts a conversation and its turn" do
    assert_enqueued_with(job: ChatResponseJob) do
      post chats_path, params: { message: "Which orders are late?" }
    end
    chat = Chat.order(:id).last

    assert_redirected_to chat_path(chat)
    assert_equal ["Which orders are late?"], chat.messages.where(role: "user").pluck(:content)
    assert_predicate chat, :responding?
  end

  test "a blank first message is refused" do
    assert_no_difference("Chat.count") { post chats_path, params: { message: "  " } }

    assert_response 422
  end

  test "the conversation renders its messages and draws Stop while a reply runs" do
    chat = chat_with("Which orders are late?")
    chat.begin_turn!
    get chat_path(chat)

    assert_response :success
    assert_select "#chat-thread-messages [data-slot=message-scroller-item]", 1
    assert_select "#chat-action[data-running]", 1
    assert_select "form#chat-stop[action='#{stop_chat_path(chat)}']", 1
  end

  test "a message in a conversation is stored and starts a turn" do
    chat = chat_with("Hello")

    assert_enqueued_with(job: ChatResponseJob) do
      post chat_messages_path(chat), params: { message: "And the refunds?" }
    end

    assert_response :no_content
    assert_equal 2, chat.messages.where(role: "user").count
    assert_predicate chat.reload, :responding?
  end

  test "a message sent while a reply runs is refused, and so is a blank one" do
    chat = chat_with("Hello")
    chat.begin_turn!

    assert_no_enqueued_jobs do
      post chat_messages_path(chat), params: { message: "Too soon" }

      assert_response :conflict

      chat.end_turn!
      post chat_messages_path(chat), params: { message: " " }

      assert_response 422
    end
    assert_equal 1, chat.messages.where(role: "user").count
  end

  test "Stop records the request while a reply runs, and only redraws the slot otherwise" do
    chat = chat_with("Hello")
    chat.begin_turn!
    post stop_chat_path(chat)

    assert_response :no_content
    assert_equal :stopping, chat.reload.composer_status

    chat.end_turn!
    post stop_chat_path(chat)

    assert_response :success
    assert_select "turbo-stream[action=replace][target=chat-action]", 1
  end

  private

  def chat_with(content)
    Chat.create!.tap { |chat| chat.add_message(role: :user, content: content) }
  end
end
