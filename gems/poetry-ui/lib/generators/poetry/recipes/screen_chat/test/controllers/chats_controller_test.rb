# frozen_string_literal: true

require "test_helper"

# installed by the poetry `screen-chat` recipe. The server half of the
# composer's contract: an accepted message answers with rows for the
# transcript, and a refused one answers with an error, which is what
# keeps the typed text in the field.
class ChatsControllerTest < ActionDispatch::IntegrationTest
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
