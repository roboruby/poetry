# frozen_string_literal: true

# installed by the poetry `screen-chat-ruby-llm` recipe - this file is
# yours. One turn: the person's message is stored already, so the job
# completes the conversation and writes the reply into the page.
#
# The reply's row is sent again with the text so far a few times a second
# (never a node per token), rendered with streaming: on, so a frame that
# ends inside a bold phrase or a link still reads as prose. When the
# message is whole it is rendered once more from what was stored.
#
# Stop (chat.cancel) raises RubyLLM::CancelledError here at the next
# chunk. The empty message a reply began as is removed on a stop or a
# failure (by RubyLLM, or here when the error is not one it expects), so
# what was written is kept as a message of its own, closed where the
# stream left it. A turn that stops or fails says so in the transcript,
# on the message it ends after, and the line is stored with it, whatever
# failed: the provider, or a model or a key that is not set up yet,
# which is what a first run meets. However the turn ends, the composer
# draws Send again.
class ChatResponseJob < ApplicationJob
  # Seconds between two frames of a reply.
  INTERVAL = 0.15
  # The least a turn lasts, in seconds. A first message starts its turn
  # and then sends the person to the conversation's page, which takes a
  # moment to start listening. A turn that ended inside that moment (a
  # key that is not set fails at once) would end unseen and leave Stop on
  # the page, so its ending waits out the second.
  SHORTEST = 1.0

  def perform(chat_id)
    chat = Chat.find_by(id: chat_id) or return
    stream = ChatStream.new(chat)
    started_at = now
    reply = nil
    text = +""
    shown_at = 0.0

    stream.action
    chat.before_message do
      reply = chat.messages.where(role: "assistant").order(:id).last
      text = +""
      stream.show(reply) if reply
    end
    chat.after_message do
      stream.show(reply.reload) if reply
      reply = nil
    end

    chat.complete do |chunk|
      # A chunk can be a space or a paragraph break on its own: only one
      # with no text at all (a tool call, a thought) is passed over.
      next if chunk.content.to_s.empty?

      text << chunk.content
      next if reply.nil? || now - shown_at < INTERVAL

      shown_at = now
      stream.show(reply, text: text.dup, streaming: true)
    end
  rescue RubyLLM::CancelledError
    wait_out(started_at)
    stream&.note(keep(chat, stream, reply, text) || last_message(chat), "Stopped")
  rescue StandardError => e
    Rails.logger.error("ChatResponseJob #{chat_id}: #{e.class}: #{e.message}")
    wait_out(started_at)
    failed = Rails.env.local? ? "The reply failed: #{e.message.to_s.truncate(300)}" : "The reply failed."
    stream&.note(keep(chat, stream, reply, text) || last_message(chat), failed)
  ensure
    wait_out(started_at)
    chat&.end_turn!
    stream&.action
  end

  private

  # Holds what ends a turn until the turn is SHORTEST old.
  def wait_out(started_at)
    return if started_at.nil? || Rails.env.test?

    sleep([SHORTEST - (now - started_at), 0].max)
  end

  # The text of a reply that did not finish, as a message of its own in
  # the place of the row that showed it. Poetry closes what the text left
  # open, so the stored message is whole Markdown. Returns the message,
  # or nil when nothing had been written.
  def keep(chat, stream, reply, text)
    return if chat.nil? || stream.nil?

    discard(chat, stream, reply)
    written = Poetry::Ui::MarkdownTail.close(text.to_s).strip
    return if written.empty?

    chat.messages.create!(role: "assistant", content: written).tap { |kept| stream.show(kept) }
  end

  # Takes the row a stream was writing out of the page, and its empty
  # message out of the conversation. RubyLLM removes that message itself
  # after a stop or a provider's error; after any other error it is still
  # there, blank, and a blank reply would be sent to the model with the
  # next turn.
  def discard(chat, stream, reply)
    return unless reply

    stream.remove(reply)
    chat.messages.where(id: reply.id, content: [nil, ""]).destroy_all
  end

  # The message a turn's ending is noted on when no text was kept: the
  # person's, which went unanswered.
  def last_message(chat)
    chat.messages.order(:id).last if chat
  end

  def now
    Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end
end
