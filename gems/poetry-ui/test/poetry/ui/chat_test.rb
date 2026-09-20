# frozen_string_literal: true

require "test_helper"

module Poetry
  module Ui
    class ChatTest < ActiveSupport::TestCase
      def script
        Chat.script do
          user "What's the weather in Tokyo?"
          assistant do |w|
            w.reasoning "Check the tool.", delay_ms: 10
            w.tool("getWeather", input: { city: "Tokyo" }, sleep_ms: 500,
                                 output: { temp: 21 })
            w.text "Clear and 21 degrees in Tokyo this weekend."
          end
          user "Book the rooftop dinner then."
          assistant do |w|
            w.text "That books under your name - approve?"
            w.tool("bookDinner", input: { venue: "rooftop" }, approval: true,
                                 output: { confirmation: "RT-204" })
            w.text "Booked - confirmation RT-204."
          end
        end
      end

      test "segments carry deterministic ids and kinds" do
        assert_equal %i[user assistant user assistant], script.segments.map(&:kind)
        assert_equal %w[chat-msg-1 chat-msg-2 chat-msg-3 chat-msg-4], script.segments.map(&:id)
      end

      test "an assistant turn compiles an accumulated, versioned frame timeline" do
        frames = script.segments[1].frames

        assert_equal (1..frames.length).to_a, frames.map(&:version), "versions are monotonic from 1"
        assert_equal([:reasoning], frames.first.parts.map { |p| p[:kind] })
        assert_equal(%i[reasoning tool text], frames.last.parts.map { |p| p[:kind] })
        assert_equal :done, frames.last.parts[1][:state]
        assert_equal "Clear and 21 degrees in Tokyo this weekend.", frames.last.parts[2][:text]

        tool_frames = frames.select { |f| f.parts.any? { |p| p[:kind] == :tool } }

        assert_equal :loading, tool_frames.first.parts[1][:state], "the tool streams loading first"
        assert_equal 500, tool_frames[1].sleep_ms
      end

      test "identical scripts compile identical timelines" do
        a = script.segments[1].frames.map { |f| [f.version, f.sleep_ms, f.parts] }
        b = script.segments[1].frames.map { |f| [f.version, f.sleep_ms, f.parts] }

        assert_equal a, b
      end

      test "continuation frames need an approval pause" do
        error = assert_raises(Chat::Error) { script.segments[1].continuation_frames(approved: true) }

        assert_equal "turn has no approval pause", error.message
        assert_kind_of Poetry::Core::Error, error, "rescuable with the family base"
      end

      test "an approval tool pauses the turn at awaiting_approval" do
        seg = script.segments[3]

        assert_predicate seg, :pause?
        last = seg.frames.last.parts.last

        assert_equal :tool, last[:kind]
        assert_equal :awaiting_approval, last[:state]
        refute(seg.frames.last.parts.any? { |p| p[:text].to_s.include?("Booked") },
               "post-pause parts must not leak into the paused prefix")
      end

      test "continuations resolve per decision with monotonic versions" do
        seg = script.segments[3]
        paused_max = seg.frames.last.version

        approved = seg.continuation_frames(approved: true)

        assert_operator approved.first.version, :>, paused_max
        assert_equal :done, approved.first.parts[1][:state]
        assert_equal({ confirmation: "RT-204" }, approved.first.parts[1][:output])
        assert_includes approved.last.parts.last[:text], "Booked - confirmation RT-204."

        denied = seg.continuation_frames(approved: false)

        assert_equal :denied, denied.first.parts[1][:state]
        assert_nil denied.first.parts[1][:output]
        refute(denied.last.parts.any? { |p| p[:text].to_s.include?("Booked") },
               "the approved-path follow-through must not stream on denial")
      end

      test "a denial with nothing after it still streams its resolution" do
        s = Chat.script do
          user "Delete everything."
          assistant do |w|
            w.tool("wipe", input: {}, approval: true, output: { wiped: true })
          end
        end
        denied = s.segments[1].continuation_frames(approved: false)

        refute_empty denied
        assert_equal :denied, denied.first.parts.last[:state]
      end

      test "final_parts resolves user, plain, and approval segments" do
        assert_equal "Book the rooftop dinner then.", script.segments[2].final_parts.first[:text]
        assert_equal :done, script.segments[1].final_parts[1][:state]
        assert_equal :denied, script.segments[3].final_parts(approved: false)[1][:state]
      end
    end
  end
end
