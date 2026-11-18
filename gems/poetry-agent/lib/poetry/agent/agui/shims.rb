# frozen_string_literal: true

require "json"

module Poetry
  module Agent
    module AGUI
      # The version-gated era shims, installed only when a pipeline's
      # `max_protocol_version:` is at or below the shim's version. nil means a
      # current peer and installs nothing: where a client does not know its
      # peer's version, AG-UI 1.0 has it behave as though the peer were current.
      #
      # The 0.0.45 shim has no class here. It translates the THINKING_* shapes,
      # which the always-on {Compatibility} boundary translates before any
      # gated stage could see one, so its behaviour lives in the boundary once.
      #
      # @api private
      module Shims
        # The ceiling grammar: dot-separated numbers ("0.0.57", "1.0", "1.0.3").
        GRAMMAR = /\A\d+(?:\.\d+)*\z/
        # The version that introduced RunAgentInput's `protocolVersion`.
        PROTOCOL_VERSION_FIELD = "1.0"

        module_function

        # A version's numeric components.
        # @param version [String]
        # @return [Array<Integer>]
        # @raise [ArgumentError] for anything but dot-separated numbers
        def parse(version)
          unless version.is_a?(String) && version.match?(GRAMMAR)
            raise ArgumentError, "max_protocol_version must be a version such as \"0.0.57\" or \"1.0\" (or nil " \
                                 "for a current peer), not #{version.inspect}"
          end

          version.split(".").map(&:to_i)
        end

        # Two versions compared component by component, missing components zero.
        # @param left [String, Array<Integer>]
        # @param right [String, Array<Integer>]
        # @return [Integer] -1, 0 or 1
        def compare(left, right)
          left = parse(left) if left.is_a?(String)
          right = parse(right) if right.is_a?(String)
          width = [left.size, right.size].max
          (left + ([0] * (width - left.size))) <=> (right + ([0] * (width - right.size)))
        end

        # What a content part is called in the dropped-parts warning.
        # @param part [Object]
        # @return [String]
        def part_name(part)
          case part
          when Hash
            type = part["type"]
            return "object" unless part.key?("type")

            type.is_a?(String) ? type : JSON.generate(type)
          when String then "string"
          when Numeric then "number"
          when true, false then "boolean"
          else "object"
          end
        end

        # The shims one peer ceiling installs, and the protocolVersion gate.
        class Era
          # A ceiling's shims, reporting each loss to the callback.
          # @param max_protocol_version [String, nil]
          # @param report [#call] receives each {ProtocolWarning}
          # @raise [ArgumentError] for a ceiling that is not a version
          def initialize(max_protocol_version, report)
            ceiling = max_protocol_version && Shims.parse(max_protocol_version)
            # 0.0.57 sees the outgoing input first, as the reference orders them.
            @shims = [Subagents, Content].select { |shim| ceiling && Shims.compare(ceiling, shim::GATE) <= 0 }
                                         .map { |shim| shim.new(report) }
            @declares = ceiling.nil? || Shims.compare(ceiling, PROTOCOL_VERSION_FIELD) >= 0
          end

          # The installed shims' versions.
          # @return [Array<String>]
          def installed = @shims.map { |shim| shim.class::GATE }

          # The inbound stages, as middleware `(event) -> Array<event>`, run
          # after the application's middleware and immediately before enforcement.
          # @return [Array<#call>]
          def inbound = @shims.select { |shim| shim.respond_to?(:call) }

          # The run input downgraded for the peer.
          # @param input [Hash]
          # @return [Hash]
          def outgoing(input) = @shims.reduce(input) { |acc, shim| shim.outgoing(acc) }

          # Whether the input declares `protocolVersion`: always, except where
          # the peer is known to predate the field.
          # @return [Boolean]
          def declares_protocol_version? = @declares
        end

        # A peer at or below 0.0.39, outgoing only. The run input loses
        # `parentRunId` (a lossless removal) and every message's content is
        # flattened to the text of its text parts, the rest dropped with a
        # warning naming them. A message with a malformed text part is passed
        # on untouched and warned about, so outgoing enforcement reports it: a
        # downgrade never repairs. Absent content becomes "".
        class Content
          # The newest version this shim serves.
          GATE = "0.0.39"

          # A shim reporting each loss to the callback.
          # @param report [#call]
          def initialize(report) = @report = report

          # The run input as a 0.0.39 peer reads it.
          # @param input [Object]
          # @return [Object]
          def outgoing(input)
            return input unless input.is_a?(Hash)

            rest = input.except("parentRunId")
            return rest unless rest["messages"].is_a?(Array)

            rest.merge("messages" => rest["messages"].map { |message| flatten(message) })
          end

          private

          # One message's content as plain text.
          def flatten(message)
            return message unless message.is_a?(Hash)
            return message.merge("content" => "") unless message.key?("content")

            content = message["content"]
            return message unless content.is_a?(Array)

            malformed = content.count { |part| text_part?(part) && !text?(part) }
            return refuse(message, malformed) if malformed.positive?

            dropped = content.reject { |part| text?(part) }.map { |part| Shims.part_name(part) }
            unless dropped.empty?
              say("Flattening message content for a <=0.0.39 peer DROPS non-text parts (#{dropped.join(", ")}). " \
                  "The peer cannot receive them; upgrade it to keep media content. See AG-UI's DEPRECATIONS.md.")
            end
            message.merge("content" => content.select { |part| text?(part) }.map { |part| part["text"] }.join)
          end

          # A message whose text parts are malformed, passed on for enforcement to report.
          def refuse(message, malformed)
            say("Not flattening message content for a <=0.0.39 peer: #{malformed} content part(s) claim type " \
                "\"text\" but carry a malformed 'text' value. That is a defect in the message, not media the " \
                "peer cannot represent, and a downgrade must not repair it - the content is passed on unchanged " \
                "so the outgoing enforcement boundary reports it. See AG-UI's DEPRECATIONS.md.")
            message
          end

          # Reports a loss.
          def say(message) = @report.call(ProtocolWarning.new(kind: :lossy, message: message))

          # Whether a part claims to be text.
          def text_part?(part) = part.is_a?(Hash) && part["type"] == "text"

          # Whether a part is well-formed text.
          def text?(part) = text_part?(part) && part["text"].is_a?(String)
        end

        # A peer at or below 0.0.57, which predates subagents. Outgoing,
        # `subagentRunId` is stripped from every message (lossless). Inbound,
        # where a genuine old peer emits none of this: subagent lifecycle
        # events are dropped with a warning, and `subagentRunId` is stripped
        # from every other event, from MESSAGES_SNAPSHOT and RUN_STARTED input
        # messages, and from an interrupt outcome's entries.
        class Subagents
          # The newest version this shim serves.
          GATE = "0.0.57"
          # The events a pre-subagent peer has no meaning for.
          LIFECYCLE = %w[SUBAGENT_STARTED SUBAGENT_FINISHED SUBAGENT_ERROR].freeze

          # A shim reporting each loss to the callback.
          # @param report [#call]
          def initialize(report) = @report = report

          # The run input as a 0.0.57 peer reads it.
          # @param input [Object]
          # @return [Object]
          def outgoing(input)
            return input unless input.is_a?(Hash) && input["messages"].is_a?(Array)

            input.merge("messages" => input["messages"].map { |message| strip(message) })
          end

          # One inbound event without subagent material.
          # @param event [Object]
          # @return [Array<Object>]
          def call(event)
            return [event] unless event.is_a?(Hash)

            if LIFECYCLE.include?(event["type"])
              @report.call(ProtocolWarning.new(kind: :lossy, message: "AG-UI is dropping #{event["type"]} because " \
                                                                      "the target agent predates subagent support. " \
                                                                      "To remove this warning, upgrade your AG-UI " \
                                                                      "integration package."))
              return []
            end
            [nested(strip(event))]
          end

          private

          # The subagent tags inside an event's messages or interrupts.
          def nested(event)
            case event["type"]
            when "MESSAGES_SNAPSHOT" then strip_list(event, "messages")
            when "RUN_FINISHED"
              outcome = event["outcome"]
              outcome.is_a?(Hash) ? event.merge("outcome" => strip_list(outcome, "interrupts")) : event
            when "RUN_STARTED"
              input = event["input"]
              input.is_a?(Hash) ? event.merge("input" => strip_list(input, "messages")) : event
            else event
            end
          end

          # A value without its subagent tag.
          def strip(value) = value.is_a?(Hash) && value.key?("subagentRunId") ? value.except("subagentRunId") : value

          # A list field's entries without their subagent tags.
          def strip_list(value, field)
            return value unless value[field].is_a?(Array)

            value.merge(field => value[field].map { |entry| strip(entry) })
          end
        end
      end
    end
  end
end
