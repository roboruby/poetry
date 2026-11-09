# frozen_string_literal: true

require "json"
require "securerandom"

module Poetry
  module Agent
    module AGUI
      # The legacy `{ "type" => "binary" }` content part and its upgrade to the
      # media parts AG-UI 1.0 defines, shared by the inbound boundary
      # (MESSAGES_SNAPSHOT and the RUN_STARTED input echo) and the outgoing run
      # input ({Pipeline#outgoing}).
      #
      # - A part is legacy binary when it is an object with type "binary" and
      #   a String mimeType; anything else is left for enforcement to judge.
      # - The media kind follows the MIME prefix: image/, audio/, video/, else
      #   document.
      # - `data` wins over `url` (empty strings and zero do not count); a
      #   `filename` moves to `metadata.filename`.
      # - A part with neither is warned about and kept in its legacy shape,
      #   which enforcement then strips.
      # - A converted part that mirrors one of the message's original modern
      #   parts (same kind, source type, value, mimeType, and filename when the
      #   legacy part had one) is dropped; other repeats are kept.
      # - A malformed payload is carried, not repaired, so enforcement rejects it.
      #
      # @api private
      module LegacyContent
        # The media part types a binary part becomes.
        MEDIA = %w[image audio video document].freeze

        module_function

        # Whether a part is a convertible legacy binary part.
        # @param part [Object]
        # @return [Boolean]
        def binary?(part) = part.is_a?(Hash) && part["type"] == "binary" && part["mimeType"].is_a?(String)

        # Whether a part claims type "binary" at all (the inbound notice's test).
        # @param part [Object]
        # @return [Boolean]
        def claims_binary?(part) = part.is_a?(Hash) && part["type"] == "binary"

        # The media kind a MIME type names.
        # @param mime_type [String]
        # @return [String]
        def kind(mime_type)
          %w[image audio video].find { |prefix| mime_type.start_with?("#{prefix}/") } || "document"
        end

        # The message with its legacy parts upgraded, or the same object when
        # it has none.
        #
        # @param message [Object]
        # @param report [#call] receives a {ProtocolWarning} for a part that cannot be converted
        # @return [Object]
        def upgrade(message, report)
          return message unless message.is_a?(Hash)

          content = message["content"]
          return message unless content.is_a?(Array) && content.any? { |part| binary?(part) }

          upgraded = content.flat_map do |part|
            next [part] unless binary?(part)

            converted = convert(part, report)
            mirrored = !converted.equal?(part) && content.any? { |other| mirror?(other, converted, part["filename"]) }
            mirrored ? [] : [converted]
          end
          message.merge("content" => upgraded)
        end

        # A run input with its messages upgraded; the same object when none changed.
        # @param input [Object]
        # @param report [#call]
        # @return [Object]
        def upgrade_input(input, report)
          return input unless input.is_a?(Hash) && input["messages"].is_a?(Array)

          messages = input["messages"].map { |message| upgrade(message, report) }
          changed?(messages, input["messages"]) ? input.merge("messages" => messages) : input
        end

        # One binary part as a media part, or the part itself when it carries
        # neither data nor a url.
        # @param binary [Hash]
        # @param report [#call]
        # @return [Hash]
        def convert(binary, report)
          metadata = truthy?(binary["filename"]) ? { "metadata" => { "filename" => binary["filename"] } } : {}
          source = if truthy?(binary["data"]) then { "type" => "data", "value" => binary["data"] }
                   elsif truthy?(binary["url"]) then { "type" => "url", "value" => binary["url"] }
                   end
          if source
            return { "type" => kind(binary["mimeType"]),
                     "source" => source.merge("mimeType" => binary["mimeType"]) }.merge(metadata)
          end

          report.call(ProtocolWarning.new(
                        kind: :lossy,
                        message: "A binary content part carries only an id ('#{text(binary["id"])}') and cannot be " \
                                 "converted to a media part; a 1.0 peer will not accept it. Provide data or a url. " \
                                 "See AG-UI's DEPRECATIONS.md."
                      ))
          binary
        end

        # Whether an original modern part is the one a conversion duplicates.
        # A legacy filename is data too, so the mirror goes only when the
        # modern part keeps it.
        # @param other [Object]
        # @param converted [Hash]
        # @param filename [Object]
        # @return [Boolean]
        def mirror?(other, converted, filename)
          return false unless other.is_a?(Hash) && other["type"] == converted["type"]

          source = other["source"]
          wanted = converted["source"]
          return false unless source.is_a?(Hash)
          return false unless %w[type value mimeType].all? { |key| source.key?(key) && same?(source[key], wanted[key]) }
          return true unless truthy?(filename)

          metadata = other["metadata"]
          metadata.is_a?(Hash) && metadata.key?("filename") && same?(metadata["filename"], filename)
        end

        # Whether a value counts as present the way the reference client tests
        # it: nil, false, "", zero and NaN do not.
        # @param value [Object]
        # @return [Boolean]
        def truthy?(value)
          return false if value.nil? || value == false || value == ""

          !(value.is_a?(Numeric) && (value.zero? || (value.is_a?(Float) && value.nan?)))
        end

        # Strict equality: containers equal only themselves.
        # @return [Boolean]
        def same?(left, right)
          return left.equal?(right) if [left, right].any? { |value| value.is_a?(Hash) || value.is_a?(Array) }

          left == right
        end

        # A value as it reads inside a warning.
        # @param value [Object]
        # @return [String]
        def text(value)
          case value
          when nil then ""
          when String then value
          else JSON.generate(value)
          end
        end

        # Whether any entry of a mapped list is a new object.
        # @param after [Array]
        # @param before [Array]
        # @return [Boolean]
        def changed?(after, before) = after.each_with_index.any? { |entry, index| !entry.equal?(before[index]) }
      end

      # The always-on inbound compatibility boundary. It is not version-gated:
      # a legacy-shaped event arriving is itself the proof the peer is old, and
      # on a current stream every branch is a no-op (the same event object
      # comes back). In order:
      #
      # 1. A whole optional field sent as `null` ({OPTIONAL_NULLS}) is read as
      #    absent - on the event, in RUN_FINISHED's outcome and usage entries,
      #    inside RUN_STARTED's input, on media parts in inbound messages -
      #    each warned once per field and location per run.
      # 2. The retired THINKING_* events become their REASONING_* equivalents.
      # 3. Legacy binary content parts in MESSAGES_SNAPSHOT and RUN_STARTED
      #    input messages become media parts ({LegacyContent}), warned per message.
      #
      # RUN_STARTED input's `state: null` is also read as absent, silently: a
      # pre-1.0 request parser accepted it, and the reference keeps that
      # tolerance.
      #
      # @api private
      class Compatibility
        # The retired event types, translated to the reasoning family.
        THINKING = %w[THINKING_START THINKING_END THINKING_TEXT_MESSAGE_START
                      THINKING_TEXT_MESSAGE_CONTENT THINKING_TEXT_MESSAGE_END].freeze

        # Every whole optional field read as absent when a producer sends
        # `null`, by where it sits. A null in any other optional field stays
        # for enforcement to reject, and nulls inside application data (state,
        # metadata values, rawEvent and result contents, tool arguments) are
        # never touched: only the named fields are read.
        OPTIONAL_NULLS = {
          "event" => %w[rawEvent subagentRunId],
          "RUN_STARTED" => %w[parentRunId input],
          "RUN_FINISHED" => %w[result outcome],
          "RUN_ERROR" => %w[usage],
          "SUBAGENT_FINISHED" => %w[result],
          "TOOL_CALL_START" => %w[parentMessageId],
          "TOOL_CALL_CHUNK" => %w[parentMessageId],
          "TOOL_CALL_RESULT" => %w[role],
          "RUN_FINISHED.outcome" => %w[pendingToolCallIds],
          "RUN_FINISHED.usage[]" => %w[provider reasoningTokens cachedInputTokens cacheWriteInputTokens],
          "RunAgentInput" => %w[forwardedProps],
          "Tool" => %w[parameters],
          "ResumeEntry" => %w[payload],
          "input content" => %w[metadata]
        }.transform_values(&:freeze).freeze

        # The rows keyed by event type, for the one lookup each event costs.
        EVENT_ROWS = OPTIONAL_NULLS.select { |location, _| location.match?(/\A[A-Z_]+\z/) }.freeze

        # A boundary reporting each conversion to the callback.
        # @param report [#call] receives each {ProtocolWarning}
        # @param ids [#call] mints an id where a retired shape carried none
        def initialize(report, ids: -> { SecureRandom.uuid })
          @report = report
          @ids = ids
          @reasoning_id = nil # the span THINKING_START opened
          @message_id = nil   # the message THINKING_TEXT_MESSAGE_START opened
          @noticed = Set.new  # optional-null notices given this run
        end

        # One event in, the event in its current shape out (the same object when untouched).
        # @param event [Object]
        # @return [Object]
        def call(event)
          return event unless event.is_a?(Hash)

          # A stream may carry several sequential runs; each one warns afresh.
          @noticed.clear if event["type"] == "RUN_STARTED"
          # Nulls first, so the translations below see the normalized event.
          event = omit_nulls(event, OPTIONAL_NULLS["event"], nil)
          rows = EVENT_ROWS[event["type"]]
          event = omit_nulls(event, rows, event["type"]) if rows

          case event["type"]
          when *THINKING then thinking(event)
          when "RUN_FINISHED" then run_finished(event)
          when "MESSAGES_SNAPSHOT" then map_entries(event, "messages") { |message| inbound_message(message) }
          when "RUN_STARTED" then run_started(event)
          else event
          end
        end

        private

        # Reports a warning of a kind.
        def say(kind, message) = @report.call(ProtocolWarning.new(kind: kind, message: message))

        # The value without those of the fields that are present and null,
        # each announced; the label names the location (nil for any event).
        def omit_nulls(value, fields, label)
          return value unless value.is_a?(Hash)

          rest = nil
          fields.each do |field|
            next unless value.key?(field) && value[field].nil?

            null_notice(label ? "#{label}.#{field}: null" : "#{field}: null")
            (rest ||= value.dup).delete(field)
          end
          rest || value
        end

        # A list field's entries mapped; the same object when no entry changed.
        def map_entries(value, field, &)
          return value unless value.is_a?(Hash) && value[field].is_a?(Array)

          entries = value[field].map(&)
          LegacyContent.changed?(entries, value[field]) ? value.merge(field => entries) : value
        end

        # The optional nulls on a message's media parts.
        def message_nulls(message)
          map_entries(message, "content") do |part|
            next part unless part.is_a?(Hash) && LegacyContent::MEDIA.include?(part["type"])

            omit_nulls(part, OPTIONAL_NULLS["input content"], "#{part["type"]} input content")
          end
        end

        # The optional nulls a pre-1.0 request parser accepted in a run input;
        # nothing else is validated here.
        def input_nulls(input)
          input = omit_nulls(input, OPTIONAL_NULLS["RunAgentInput"], "RunAgentInput")
          input = map_entries(input, "tools") { |tool| omit_nulls(tool, OPTIONAL_NULLS["Tool"], "Tool") }
          input = map_entries(input, "resume") do |entry|
            omit_nulls(entry, OPTIONAL_NULLS["ResumeEntry"], "ResumeEntry")
          end
          map_entries(input, "messages") { |message| message_nulls(message) }
        end

        # One notice per field and location per run, not one per event.
        def null_notice(what)
          notice(what, "an absent field") if @noticed.add?(what)
        end

        # The optional nulls in RUN_FINISHED's outcome and usage entries.
        def run_finished(event)
          outcome = omit_nulls(event["outcome"], OPTIONAL_NULLS["RUN_FINISHED.outcome"], "RUN_FINISHED.outcome")
          event = event.merge("outcome" => outcome) unless outcome.equal?(event["outcome"])
          map_entries(event, "usage") do |entry|
            omit_nulls(entry, OPTIONAL_NULLS["RUN_FINISHED.usage[]"], "RUN_FINISHED.usage[]")
          end
        end

        # The input RUN_STARTED echoes: its nulls, its state tolerance, its legacy parts.
        def run_started(event)
          input = input_nulls(event["input"])
          input = input.except("state") if input.is_a?(Hash) && input.key?("state") && input["state"].nil?
          input = map_entries(input, "messages") { |message| inbound_message(message) }
          input.equal?(event["input"]) ? event : event.merge("input" => input)
        end

        # A message's media-part nulls, then the binary upgrade, warned once
        # per message that carries a legacy part.
        def inbound_message(message)
          message = message_nulls(message)
          return message unless message.is_a?(Hash) && message["content"].is_a?(Array)
          return message unless message["content"].any? { |part| LegacyContent.claims_binary?(part) }

          notice("binary input content", "the media content parts")
          LegacyContent.upgrade(message, @report)
        end

        # A retired THINKING_* event in its REASONING_* shape.
        def thinking(event)
          case event["type"]
          when "THINKING_START"
            @reasoning_id = @ids.call
            notice("THINKING_START", "REASONING_START")
            if event.key?("title")
              # A loss, not a translation, so it gets its own sentence.
              say(:lossy, "Dropping THINKING_START.title #{JSON.generate(event["title"])}: REASONING_START has no " \
                          "title field, so the span's label cannot be carried and nothing downstream can recover it.")
            end
            event.except("title").merge("type" => "REASONING_START", "messageId" => @reasoning_id)
          when "THINKING_TEXT_MESSAGE_START"
            @message_id = @ids.call
            notice("THINKING_TEXT_MESSAGE_START", "REASONING_MESSAGE_START")
            # The schema pins this role to "reasoning".
            event.merge("type" => "REASONING_MESSAGE_START", "messageId" => @message_id, "role" => "reasoning")
          when "THINKING_TEXT_MESSAGE_CONTENT"
            notice("THINKING_TEXT_MESSAGE_CONTENT", "REASONING_MESSAGE_CONTENT")
            id = continuation_id("THINKING_TEXT_MESSAGE_CONTENT", @message_id)
            event.except("delta").merge("type" => "REASONING_MESSAGE_CONTENT", "messageId" => id)
                 .merge(event.slice("delta"))
          when "THINKING_TEXT_MESSAGE_END"
            id = continuation_id("THINKING_TEXT_MESSAGE_END", @message_id)
            @message_id = nil
            notice("THINKING_TEXT_MESSAGE_END", "REASONING_MESSAGE_END")
            event.merge("type" => "REASONING_MESSAGE_END", "messageId" => id)
          when "THINKING_END"
            id = continuation_id("THINKING_END", @reasoning_id)
            @reasoning_id = nil
            notice("THINKING_END", "REASONING_END")
            event.merge("type" => "REASONING_END", "messageId" => id)
          end
        end

        # Announces one conversion.
        def notice(what, replacement)
          say(:translated, "Converting deprecated #{what} to #{replacement}. The old shape leaves the protocol " \
                           "after its shim window - see AG-UI's DEPRECATIONS.md.")
        end

        # A THINKING_* continuation names nothing; the id lives here, put there
        # by its opener. With no opener there is nothing to continue, so one is
        # minted and announced: verification rejects the translated event for
        # naming an id nothing opened, and this line traces that to its cause.
        def continuation_id(from, established)
          return established if established

          minted = @ids.call
          say(:translated, "Minting a messageId ('#{minted}') for #{from}: no THINKING opener preceded it, so there " \
                           "was no id to continue. The id is this client's invention, not the producer's, and " \
                           "verification will reject the translated event for naming something nothing opened.")
          minted
        end
      end
    end
  end
end
