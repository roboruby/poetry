require "test_helper"

# The screen-chat recipe run as a host would have it. The recipe's files
# are loaded from poetry-ui as they ship (its controller, its views, and
# the chat block as `poetry:block` writes it), behind the routes its
# description names, in the one host of the family that has Turbo. The
# recipe carries a controller test of its own for the app it lands in:
# that file is loaded too, so the suite runs it against the shipped
# controller. The tests here hold the same files to the block's ids.
module ScreenChatRecipe
  SOURCES = Poetry::Ui.root.join(Poetry::Ui::Recipes::SCREEN_SOURCES, "screen_chat")

  # The host's base controller, which the test host has no use for
  # otherwise.
  class ::ApplicationController < ActionController::Base; end unless defined?(::ApplicationController)

  # Loads the recipe's controller and gives it the installed views: the
  # recipe's own, and the block partial under app/views/blocks.
  def self.install
    return if defined?(::ChatsController)

    load SOURCES.join("app/controllers/chats_controller.rb").to_s
    views = Dir.mktmpdir("screen-chat")
    Minitest.after_run { FileUtils.remove_entry(views) if File.directory?(views) }
    FileUtils.mkdir_p(File.join(views, "blocks"))
    File.write(File.join(views, "blocks/_chat.html.erb"),
               Poetry::Ui.root.join(Poetry::Ui::BLOCKS_DIR, "chat.html.erb").read)
    ::ChatsController.prepend_view_path(views)
    ::ChatsController.prepend_view_path(SOURCES.join("app/views").to_s)
  end
end

ScreenChatRecipe.install
# The recipe's own controller test: ChatsControllerTest, as a host runs it.
load ScreenChatRecipe::SOURCES.join("test/controllers/chats_controller_test.rb").to_s

class ScreenChatRecipeTest < ActionDispatch::IntegrationTest
  test "the screen renders the chat block with the recipe's two addresses" do
    get "/chat"

    assert_response :success
    assert_select "form#chat-form[action='/chat']", 1
    assert_select "form#chat-stop[action='/chat/stop']", 1
    assert_select "#chat-thread-messages [data-slot=message-scroller-item]", 4
  end

  test "a new chat opens on the welcome and its prompts" do
    get "/chat?new"

    assert_response :success
    assert_select "#chat-thread-messages", 1
    assert_select "[data-slot=message-scroller-item]", 0
    assert_select "[data-slot=composer-prompt]", 3
  end

  test "a message answers with the person's row and a reply, appended to the transcript" do
    post "/chat", params: { message: "Is <b>ORD-1041</b> late?" }

    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", response.media_type
    assert_equal 2, response.body.scan(%(<turbo-stream action="append" target="chat-thread-messages">)).size
    assert_equal 2, response.body.scan(%(data-slot="message-scroller-item")).size
    assert_includes response.body, "Is &lt;b&gt;ORD-1041&lt;/b&gt; late?", "the person's words are escaped"
    assert_includes response.body, %(data-scroll-anchor="true"), "the person's row anchors the turn"
    assert_includes response.body, "This reply is a stand-in."
  end

  test "a blank message is refused, which keeps the typed text in the field" do
    post "/chat", params: { message: "   " }

    assert_response 422
  end

  test "stop draws the composer's action slot as Send" do
    post "/chat/stop"

    assert_response :success
    assert_includes response.body, %(<turbo-stream action="replace" target="chat-action">)
    assert_includes response.body, %(id="chat-action")
    assert_not_includes response.body, "data-running"
  end

  test "the recipe's tests ask for the same routes" do
    test_source = ScreenChatRecipe::SOURCES.join("test/controllers/chats_controller_test.rb").read

    assert_includes test_source, "post chat_path"
    assert_includes test_source, "post stop_chat_path"
    assert_equal "/chat", Rails.application.routes.url_helpers.chat_path
    assert_equal "/chat/stop", Rails.application.routes.url_helpers.stop_chat_path
  end
end
