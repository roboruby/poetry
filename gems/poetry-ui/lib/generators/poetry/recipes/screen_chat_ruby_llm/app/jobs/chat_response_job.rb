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
# chunk. RubyLLM removes its empty message on a stop or a failure, so
# what was written is kept as a message of its own, closed where the
# stream left it. A turn that fails says so in the transcript, whatever
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
      next if chunk.content.blank?

      text << chunk.content
      next if reply.nil? || now - shown_at < INTERVAL

      shown_at = now
      stream.show(reply, text: text.dup, streaming: true)
    end
  rescue RubyLLM::CancelledError
    wait_out(started_at)
    keep(chat, stream, reply, text)
    stream&.note("Stopped")
  rescue StandardError => e
    Rails.logger.error("ChatResponseJob #{chat_id}: #{e.class}: #{e.message}")
    wait_out(started_at)
    keep(chat, stream, reply, text)
    stream&.note(Rails.env.local? ? "The reply failed: #{e.message.to_s.truncate(300)}" : "The reply failed.")
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
  # open, so the stored message is whole Markdown.
  def keep(chat, stream, reply, text)
    return if chat.nil? || stream.nil?

    stream.remove(reply) if reply
    written = Poetry::Ui::MarkdownTail.close(text.to_s).strip
    return if written.empty?

    stream.show(chat.messages.create!(role: "assistant", content: written))
  end

  def now
    Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end
end
