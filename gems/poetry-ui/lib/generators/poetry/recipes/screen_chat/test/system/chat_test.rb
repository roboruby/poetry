# frozen_string_literal: true

require "application_system_test_case"

# installed by the poetry `screen-chat` recipe. Server-render assertions
# only - no JS driver required; the test proves the screen route renders
# the block's furniture and gives the composer its two addresses.
class ChatTest < ApplicationSystemTestCase
  test "the chat screen renders the chat block" do
    visit chat_path

    assert_text "Orders assistant"
    assert_selector "form[action='#{chat_path}'] textarea[name='message']"
    assert_selector "form[action='#{stop_chat_path}']", visible: :all
  end
end
