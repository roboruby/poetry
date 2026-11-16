# frozen_string_literal: true

# installed by the poetry `screen-chat-ruby-llm` recipe - this file is
# yours. What a chat's open pages are told while a turn runs.
#
# Everything goes down the chat's one Turbo stream, in the order it
# happened: a message's row, the same row again as a reply's text grows,
# and the composer's action slot. The slot is never drawn by a form's
# answer, so an answer and a broadcast cannot cross and leave Stop on
# screen.
class ChatStream
  include ActionView::RecordIdentifier

  def initialize(chat)
    @chat = chat
  end

  # A message's row at the end of the transcript: with the text a reply
  # has so far (text:, streaming: true), or with what is stored. Turbo
  # replaces a row the transcript already holds under the same id, so
  # this both adds a row and redraws it, and a page that began listening
  # after the row first went out gets it with the next frame.
  def show(message, text: nil, streaming: false)
    Turbo::StreamsChannel.broadcast_append_to(@chat, target: "chat-thread-messages", partial: "messages/message",
                                                     locals: { message: message, text: text, streaming: streaming })
  end

  def remove(message)
    Turbo::StreamsChannel.broadcast_remove_to(@chat, target: dom_id(message))
  end

  # A line in the transcript that is not a message: a stop, a failure.
  def note(text)
    Turbo::StreamsChannel.broadcast_append_to(@chat, target: "chat-thread-messages", partial: "messages/note",
                                                     locals: { text: text })
  end

  # The composer's action slot, as the chat's record stands.
  def action
    Turbo::StreamsChannel.broadcast_replace_to(@chat, target: "chat-action", partial: "chats/composer_action",
                                                      locals: { status: @chat.composer_status })
  end
end
