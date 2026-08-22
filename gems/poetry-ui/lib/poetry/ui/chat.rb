# frozen_string_literal: true

module Poetry
  module Ui
    # The chat replay DSL ('s designed lead, built 2026-08-22): script
    # a user/assistant conversation in Ruby, get a DETERMINISTIC timeline of
    # streaming frames to replay through the real Turbo Stream pipeline -
    # no model, no network, fixed ids, fixed pacing. The DSL is pure data
    # (transcript + timing); rendering frames into Message rows is the
    # consumer's job (the docs replay demo is the reference consumer).
    #
    #   script = Poetry::Ui::Chat.script do
    #     user "What's the weather in Tokyo?"
    #     assistant do |w|
    #       w.reasoning "Check the weather tool first."
    #       w.tool("getWeather", input: { city: "Tokyo" }, sleep_ms: 800,
    #              output: { temp: 21, condition: "clear" })
    #       w.text "Clear skies and 21°C in Tokyo."
    #     end
    #   end
    #   script.segments  # => enumerable segments; assistant segments carry
    #                    #    frames (accumulated part states + sleeps + versions)
    #
    # A tool with `approval: true` PAUSES its segment after the input frame;
    # the frames that follow (its output - or denial - and later parts)
    # belong to the continuation and are produced by
    # `continuation_frames(approved:)` - the createChat human-in-the-loop
    # model, server-shaped: the pause is a rendered form, the continuation
    # is the stream after the decision.
    module Chat
      def self.script(&)
        Script.new(&)
      end

      # One rendered state of an assistant row mid-stream.
      Frame = Struct.new(:parts, :sleep_ms, :version, keyword_init: true)

      # A step of the conversation: :user (text) or :assistant (frames,
      # possibly pausing for approval).
      class Segment
        attr_reader :kind, :id, :text, :turn

        def initialize(kind:, id:, text: nil, turn: nil)
          @kind = kind
          @id = id
          @text = text
          @turn = turn
        end

        def pause? = kind == :assistant && turn.pause?

        def frames = turn.frames

        def continuation_frames(approved:) = turn.continuation_frames(approved: approved)

        # The final resting parts (approval segments resolve per decision).
        def final_parts(approved: true)
          return [{ kind: :text, text: text }] if kind == :user
          return frames.last.parts unless pause?

          continuation_frames(approved: approved).last.parts
        end
      end

      class Script
        DEFAULT_TEXT_DELAY_MS = 30
        TEXT_CHUNK_WORDS = 3

        def initialize(&)
          @segments = []
          @counter = 0
          instance_eval(&)
        end

        def user(text)
          @segments << Segment.new(kind: :user, id: next_id, text: text)
        end

        def assistant(text = nil, &block)
          turn = AssistantTurn.new
          if block
            yield(turn.writer)
          elsif text
            turn.writer.text(text)
          end
          @segments << Segment.new(kind: :assistant, id: next_id, turn: turn)
        end

        attr_reader :segments

        private

        def next_id
          @counter += 1
          "chat-msg-#{@counter}"
        end
      end

      # Collects writer calls into an ordered part list, then compiles the
      # deterministic frame timeline.
      class AssistantTurn
        def initialize
          @parts = []
        end

        def writer = @writer ||= Writer.new(@parts)

        def pause? = @parts.any? { |part| part[:kind] == :tool && part[:approval] }

        # Frames up to (and including) the pause, or the whole turn.
        def frames
          compile(@parts.take_while.with_index { |_part, i| i.zero? || !pause_before?(i) })
        end

        # Frames AFTER the pause point, resolved by the decision. Versions
        # continue from the paused prefix so the morph guard stays monotonic.
        # Parts scripted AFTER an approval tool are the APPROVED path (the
        # createChat model: denial streams tool-output-denied and stops;
        # the approved branch carries the follow-through). So a denied
        # continuation is exactly the resolution frame.
        def continuation_frames(approved:)
          raise Error, "turn has no approval pause" unless pause?

          resolved = @parts.map do |part|
            next part unless part[:kind] == :tool && part[:approval]

            part.merge(state: approved ? :done : :denied,
                       output: approved ? part[:output] : nil)
          end
          keep = approved ? resolved : resolved.take(pause_index + 1)
          compile(keep).drop(frames.length)
        end

        private

        def pause_index
          @parts.index { |part| part[:kind] == :tool && part[:approval] }
        end

        def pause_before?(index)
          before = @parts.first(index)
          before.any? { |part| part[:kind] == :tool && part[:approval] }
        end

        # The accumulated-state timeline: every frame is the FULL part list
        # as rendered at that instant (streaming morphs the same row).
        def compile(parts)
          frames = []
          acc = []
          version = 0
          push = lambda do |sleep_ms|
            version += 1
            frames << Frame.new(parts: acc.map(&:dup), sleep_ms: sleep_ms, version: version)
          end

          parts.each do |part|
            case part[:kind]
            when :reasoning, :text
              chunks = part[:text].split(/(?<=\S)\s+/).each_slice(Script::TEXT_CHUNK_WORDS).map { |w| w.join(" ") }
              delay = part.fetch(:delay_ms, Script::DEFAULT_TEXT_DELAY_MS) || Script::DEFAULT_TEXT_DELAY_MS
              acc << part.merge(text: "")
              chunks.each do |chunk|
                acc[-1] = acc[-1].merge(text: [acc[-1][:text], chunk].reject(&:empty?).join(" "))
                push.call(delay)
              end
            when :tool
              acc << part.merge(state: :loading, output: nil)
              push.call(0)
              # An approval tool always passes through :awaiting_approval -
              # resolved or not - so the paused prefix and the resolved
              # timeline share frame counts up to the pause and the
              # continuation begins AT the resolution frame (a denial with
              # nothing after it still streams its denial).
              if part[:approval]
                acc[-1] = acc[-1].merge(state: :awaiting_approval)
                push.call(part.fetch(:sleep_ms, 0))
              end
              unless part[:approval] && part[:state].nil?
                acc[-1] = acc[-1].merge(state: part[:state] || :done, output: part[:output])
                push.call(part.fetch(:sleep_ms, 0))
              end
            end
          end
          frames
        end
      end

      class Writer
        def initialize(parts)
          @parts = parts
        end

        def text(text, delay_ms: nil)
          @parts << { kind: :text, text: text, delay_ms: delay_ms }.compact
          self
        end

        def reasoning(text, delay_ms: nil)
          @parts << { kind: :reasoning, text: text, delay_ms: delay_ms }.compact
          self
        end

        # rubocop:disable Metrics/ParameterLists -- the writer vocabulary mirrors createChat's tool options
        def tool(name, input:, output: nil, sleep_ms: 0, approval: false, denied: false)
          @parts << { kind: :tool, name: name, input: input, output: output,
                      sleep_ms: sleep_ms, approval: approval,
                      state: denied ? :denied : nil }
          self
        end
        # rubocop:enable Metrics/ParameterLists
      end
    end
  end
end
