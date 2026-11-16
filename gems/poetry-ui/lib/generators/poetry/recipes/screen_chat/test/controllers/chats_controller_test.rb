# frozen_string_literal: true

require "test_helper"

# installed by the poetry `screen-chat` recipe. The server half of the
# composer's contract: an accepted message answers with rows for the
# transcript, and a refused one answers with an error, which is what
# keeps the typed text in the field.
class ChatsControllerTest < ActionDispatch::IntegrationTest
  test "the chat screen renders the chat block with its two addresses" do
    get chat_path

    assert_response :success
    assert_includes response.body, "Orders assistant"
    assert_select "form[action='#{chat_path}'] textarea[name='message']", 1
    assert_select "form[action='#{stop_chat_path}']", 1
  end

  test "a message answers with the person's row and a reply" do
    post chat_path, params: { message: "Which orders are late?" }

    assert_response :success
    assert_select "turbo-stream[action=append][target=chat-thread-messages]", 2
    assert_includes response.body, "Which orders are late?"
  end

  test "a blank message is refused" do
    post chat_path, params: { message: "  " }

    assert_response 422
  end

  test "stop draws the composer's action slot" do
    post stop_chat_path

    assert_response :success
    assert_select "turbo-stream[action=replace][target=chat-action]"
  end
end
