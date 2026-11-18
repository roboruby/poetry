# frozen_string_literal: true

require "test_helper"
require "turbo/broadcastable/test_helper"

# installed by the poetry `screen-chat-ruby-llm` recipe - yours to adapt.
# Whole turns of ChatResponseJob with no network, against a provider that
# answers from a script.
class ChatResponseJobTest < ActiveJob::TestCase
  include Turbo::Broadcastable::TestHelper

  # The provider. Each String is a chunk of the reply, a callable runs
  # between two chunks (the person pressing Stop), and an exception is the
  # provider failing. It overrides the two methods a chat calls on its
  # provider; if a RubyLLM upgrade changes them, this double is what to fix.
  class ScriptedProvider < RubyLLM::Provider
    class << self
      attr_accessor :script, :citations

      def configuration_requirements = []
      def local? = true
      def assume_models_exist? = true
    end

    def api_base = "http://scripted.invalid"
    def preprocess_message(message, **) = message

    def complete(_messages, **, &block)
      written = +""
      self.class.script.each do |step|
        raise step if step.is_a?(Exception)
        next step.call unless step.is_a?(String)

        written << step
        block&.call(RubyLLM::Chunk.new(role: :assistant, content: step))
      end
      RubyLLM::Message.new(role: :assistant, content: written, citations: Array(self.class.citations))
    end
  end
  RubyLLM::Provider.register :scripted, ScriptedProvider

  setup do
    # With no model stored, RubyLLM loads its whole catalog into the table
    # for each test, which takes a second each time.
    RubyLLM::ActiveRecord::Model.find_or_create_by!(model_id: "scripted-1", provider: "scripted") do |model|
      model.name = "Scripted"
    end
    @chat = Chat.create!(model: "scripted-1", provider: "scripted", assume_model_exists: true)
    @chat.add_message(role: :user, content: "Which orders are late?")
    @asked = @chat.messages.order(:id).last
    @chat.begin_turn!
    ScriptedProvider.citations = nil
  end

  # Runs the turn and returns what the chat's pages were sent. RubyLLM
  # looks for a stop at most once a second; a scripted reply is over
  # sooner, so the turn runs with that interval at zero.
  def run_turn(*script)
    ScriptedProvider.script = script
    stub_const(RubyLLM::ActiveRecord::ChatMethods, :CANCELLATION_POLL_INTERVAL, 0) do
      capture_turbo_stream_broadcasts(@chat) { ChatResponseJob.perform_now(@chat.id) }
    end
  end

  def replies
    @chat.messages.where(role: "assistant").order(:id)
  end

  def press_stop
    -> { Chat.find(@chat.id).cancel }
  end

  test "a reply is stored, drawn from what was stored, and the turn ends on Send" do
    streams = run_turn("Two orders ", "are **late**.")
    reply = replies.sole

    assert_equal "Two orders are **late**.", reply.content
    assert_nil reply.note
    refute_predicate @chat.reload, :responding?
    assert_equal %w[replace chat-action], [streams.last["action"], streams.last["target"]]
    assert_includes streams.last.to_s, %(id="chat-action")
    refute_includes streams.last.to_s, "data-running"
    row = streams.reverse.find { |stream| stream["target"] == "chat-thread-messages" }

    assert_equal "append", row["action"]
    assert_includes row.to_s, "<strong>late</strong>"
    assert_includes row.to_s, ActionView::RecordIdentifier.dom_id(reply, :feedback)
  end

  test "Stop keeps what was written, closed where it stopped, and says so on that message" do
    streams = run_turn("Ships **tomorr", press_stop, "ow** from Reno.")
    kept = replies.sole

    assert_equal "Ships **tomorr**", kept.content
    assert_equal "Stopped", kept.note
    assert_nil @asked.reload.note
    refute_predicate @chat.reload, :responding?
    assert_includes streams.to_s, "Stopped"
    assert_includes streams.map { |stream| stream["action"] }, "remove", "the row the stream was writing is taken out"
    assert_equal "chat-action", streams.last["target"]
  end

  test "a chunk that is only a space or a paragraph break is part of the text" do
    streams = run_turn("the", " ", "ship-by date.", "\n\n", "Then the", " ", "next", press_stop, " never shown")

    assert_equal "the ship-by date.\n\nThen the next", replies.sole.content
    assert_includes streams.to_s, "the ship-by date."
  end

  test "Stop before any text notes it on the message that went unanswered" do
    run_turn(press_stop, "never shown")

    assert_empty replies
    assert_equal "Stopped", @asked.reload.note
    refute_predicate @chat.reload, :responding?
  end

  test "a provider that fails ends the turn and says so, whatever it raised" do
    streams = run_turn("Looking", Faraday::ConnectionFailed.new("the provider is down"))

    assert_equal "Looking", replies.sole.content
    assert_match(/\AThe reply failed/, replies.sole.note)
    refute_predicate @chat.reload, :responding?
    assert_equal "chat-action", streams.last["target"]
  end

  test "an error RubyLLM does not expect leaves no blank reply behind" do
    run_turn("Half a ", RuntimeError.new("a bug of our own"))

    assert_equal ["Half a"], replies.pluck(:content), "the empty message the reply began as is gone"
    assert_match(/\AThe reply failed/, replies.sole.note)

    @chat.begin_turn!
    run_turn(RubyLLM::ConfigurationError.new("no key is set"))

    assert_equal 1, replies.count
    refute_predicate @chat.reload, :responding?
  end

  test "a reply that cites its sources stores them, marks them in the text and lists them" do
    text = "Orders ship within two days."
    ScriptedProvider.citations = [{ url: "https://example.com/fulfilment", title: "Fulfilment guide",
                                    cited_text: "Orders ship within two working days of payment.",
                                    start_index: 0, end_index: text.length }]
    streams = run_turn(text)
    reply = replies.sole
    row = streams.reverse.find { |stream| stream["target"] == "chat-thread-messages" }.to_s

    assert_equal "https://example.com/fulfilment", reply.citations.sole.url
    assert_includes row, %(data-component="citation")
    assert_includes row, %(data-component="sources")
    assert_includes row, "Fulfilment guide"
    assert_includes row, %(href="https://example.com/fulfilment")
  end

  test "a row that is still streaming carries neither sources nor thumbs" do
    streams = run_turn("One ", "two ", "three.")
    frames = streams.select { |stream| stream.to_s.include?("data-streaming") }

    frames.each { |frame| refute_includes frame.to_s, "feedback" }
    assert_operator streams.size, :>=, 3
  end
end
