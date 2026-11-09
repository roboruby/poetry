# frozen_string_literal: true

module Poetry
  module Agent
    module AGUI
      # Chunk expansion, a port of the TypeScript client's chunks/transform.ts.
      # TEXT_MESSAGE_CHUNK, TOOL_CALL_CHUNK and REASONING_MESSAGE_CHUNK become the
      # start/content/end form, so verification and application only ever see the
      # triad. It runs AFTER enforcement, so every chunk it meets is already
      # schema-valid and carries only described properties.
      #
      #   chunks = ChunkExpansion.new
      #   chunks.call(event) # => Array of events (the event itself, or what it expands to)
      #   chunks.finish      # => [] (lanes still open are dropped, never closed)
      #
      # A rejection raises ProtocolError (stage :expansion) BEFORE any state
      # changes, so lenient mode can drop the chunk and carry on.
      class ChunkExpansion
        # An explicit event closes the pending stream in ITS OWN lane only.
        # A subagent's terminal closes that subagent's lane too.
        CLOSES_OWN_LANE = %w[
          TEXT_MESSAGE_START TEXT_MESSAGE_CONTENT TEXT_MESSAGE_END
          TOOL_CALL_START TOOL_CALL_ARGS TOOL_CALL_END TOOL_CALL_RESULT
          STATE_SNAPSHOT STATE_DELTA CUSTOM STEP_STARTED STEP_FINISHED
          REASONING_START REASONING_MESSAGE_START REASONING_MESSAGE_CONTENT REASONING_MESSAGE_END REASONING_END
          SUBAGENT_FINISHED SUBAGENT_ERROR
        ].to_set.freeze
        # Run-level events describe the whole run, so every lane closes.
        CLOSES_ALL_LANES = Set.new(%w[RUN_STARTED RUN_FINISHED RUN_ERROR MESSAGES_SNAPSHOT]).freeze
        # Everything else (RAW, ACTIVITY_*, REASONING_ENCRYPTED_VALUE, SUBAGENT_STARTED)
        # stands aside from assembly and passes through.

        # What each chunk shape expands into.
        Form = Struct.new(:kind, :id_field, :entity, :start, :content, :end, :chunk_type, keyword_init: true)
        # The expansion form for each chunk type.
        FORMS = {
          "TEXT_MESSAGE_CHUNK" => Form.new(kind: :text, id_field: "messageId", entity: "text message",
                                           start: "TEXT_MESSAGE_START", content: "TEXT_MESSAGE_CONTENT",
                                           end: "TEXT_MESSAGE_END", chunk_type: "TEXT_MESSAGE_CHUNK"),
          "TOOL_CALL_CHUNK" => Form.new(kind: :tool, id_field: "toolCallId", entity: "tool call",
                                        start: "TOOL_CALL_START", content: "TOOL_CALL_ARGS",
                                        end: "TOOL_CALL_END", chunk_type: "TOOL_CALL_CHUNK"),
          "REASONING_MESSAGE_CHUNK" => Form.new(kind: :reasoning, id_field: "messageId", entity: "reasoning message",
                                                start: "REASONING_MESSAGE_START", content: "REASONING_MESSAGE_CONTENT",
                                                end: "REASONING_MESSAGE_END", chunk_type: "REASONING_MESSAGE_CHUNK")
        }.freeze
        # The same forms keyed by kind (:text, :tool, :reasoning).
        FORM_BY_KIND = FORMS.values.to_h { |form| [form.kind, form] }.freeze

        # The stream one lane is assembling. `fields` are what the opener
        # established (role, name, toolCallName, parentMessageId, subagentRunId),
        # kept so a repeat can be judged against them.
        Pending = Struct.new(:form, :id, :fields)

        # An expander with no lane open.
        def initialize
          # owner => Pending, where owner is the subagentRunId its chunks are
          # attributed to and nil is the parent agent. One slot per lane, because
          # the shorthand names a continuation only by "the same as before".
          @lanes = {}
        end

        # Whether any lane is mid-assembly.
        def open? = !@lanes.empty?

        # One event in, the events it stands for out: a chunk becomes its stream's START and CONTENT, an
        # event that closes lanes follows the ENDs it forces, and anything else passes through.
        # @param event [Hash] an enforced event
        # @return [Array<Hash>]
        # @raise [ProtocolError] for a chunk that cannot open or continue a stream, before any lane changes
        def call(event)
          type = event["type"]
          if (form = FORMS[type])
            expand(form, event)
          elsif CLOSES_OWN_LANE.include?(type)
            [*close_lane(event["subagentRunId"]), event]
          elsif CLOSES_ALL_LANES.include?(type)
            [*close_all, event]
          else
            [event]
          end
        end

        # End of stream: a lane still open is dropped, never closed. The spec
        # forbids synthesizing a terminal for a truncated run, and TS's finalize
        # discards the END events it builds here for the same reason.
        def finish
          @lanes.clear
          []
        end

        private

        # A chunk's events: the lane's previous END and a START when it opens a stream, then any CONTENT.
        def expand(form, chunk)
          id = chunk[form.id_field]
          tag = chunk["subagentRunId"]
          lane = resolve_lane(form, id, tag)
          open = @lanes[lane]
          continuing = open&.form == form && (id.nil? || id == open.id)

          # Every check before any change, so a rejected chunk leaves no trace.
          if continuing
            agree!(form, open, chunk)
          else
            raise rejection("First #{form.chunk_type} must have a #{form.id_field}") if id.nil?
            if form.kind == :tool && chunk["toolCallName"].nil?
              raise rejection("First TOOL_CALL_CHUNK must have a toolCallName")
            end
          end

          out = []
          unless continuing
            out.concat(close_lane(lane)) # whatever this lane had open ends first
            open = Pending.new(form, id, opener_fields(form, chunk))
            @lanes[lane] = open
            out << with_metadata(start_event(form, open), chunk)
          end
          owner = tag.nil? ? open.fields["subagentRunId"] : tag # the incoming tag first, the opener's as fallback
          if chunk.key?("delta") || chunk.key?("rawEvent")
            content = content_event(form, open, chunk.fetch("delta", ""), owner)
            content = with_metadata(content, chunk)
            content["rawEvent"] = chunk["rawEvent"] if chunk.key?("rawEvent")
            out << content
          elsif out.empty? && chunk.key?("metadata")
            # A metadata-only continuation (usage, a finish reason) adds no
            # content, but its metadata still has to reach the item.
            out << with_metadata(content_event(form, open, "", owner), chunk)
          end
          out
        end

        # Which lane a chunk belongs to. A named id continues wherever it is
        # already open; otherwise a tag names its lane; otherwise the parent's
        # stream of this kind, else the sole open stream of this kind.
        def resolve_lane(form, id, tag)
          return held_lane(form, id, tag) unless id.nil?
          return tag unless tag.nil?
          return nil if @lanes[nil]&.form == form

          candidates = @lanes.select { |_, pending| pending.form == form }
          return candidates.keys.first if candidates.size == 1
          if candidates.size > 1
            raise rejection("Ambiguous #{form.chunk_type}: it carries neither a #{form.id_field} nor a " \
                            "subagentRunId, but #{candidates.size} lanes have an open #{form.entity}. Attribute " \
                            "the chunk to the subagent it belongs to.")
          end
          nil # nothing to continue: the caller opens in the parent lane, or reports the missing id
        end

        # The lane holding an id's open stream, which the chunk's tag must
        # agree with; an id nobody holds opens a new stream in its tag's lane.
        def held_lane(form, id, tag)
          holder = @lanes.find { |_, pending| pending.form == form && pending.id == id }
          return tag unless holder

          owner = holder.first
          if !tag.nil? && tag != owner
            raise rejection("Cannot continue #{form.entity} '#{id}': chunk subagentRunId '#{tag}' does not match " \
                            "the open stream's subagent '#{owner.nil? ? "(the parent agent)" : owner}'.")
          end
          owner
        end

        # A continuation MAY repeat an opener's field, but only with its value
        # (one established by omission included: no role means "assistant").
        def agree!(form, open, chunk)
          fields = case form.kind
                   when :text then %w[role name]
                   when :tool then %w[toolCallName parentMessageId]
                   else []
                   end
          fields.each do |field|
            incoming = chunk[field]
            established = open.fields[field]
            next if incoming.nil? || incoming == established

            raise rejection("Cannot continue #{form.entity} '#{open.id}': chunk #{field} '#{incoming}' does not " \
                            "match the open stream's #{field} #{established.nil? ? "(absent)" : "'#{established}'"}.")
          end
        end

        # The fields an opening chunk establishes for its stream.
        def opener_fields(form, chunk)
          fields = chunk.slice("subagentRunId")
          case form.kind
          when :text
            fields["role"] = chunk.fetch("role", "assistant") # absent means assistant, as on TEXT_MESSAGE_START
            fields.merge!(chunk.slice("name"))
          when :tool then fields.merge!(chunk.slice("toolCallName", "parentMessageId"))
          end
          fields
        end

        # The START that opens a pending stream.
        def start_event(form, open)
          event = { "type" => form.start, form.id_field => open.id }
          case form.kind
          when :text then event.merge!(open.fields.slice("role", "name"))
          when :tool then event.merge!(open.fields.slice("toolCallName", "parentMessageId"))
          when :reasoning then event["role"] = "reasoning"
          end
          event.merge!(open.fields.slice("subagentRunId"))
        end

        # A CONTENT carrying one delta, tagged with its owner.
        def content_event(form, open, delta, owner)
          event = { "type" => form.content, form.id_field => open.id, "delta" => delta }
          event["subagentRunId"] = owner unless owner.nil?
          event
        end

        # A chunk's metadata rides on every event synthesized from it, never on
        # the END that closes the previous item.
        def with_metadata(event, chunk)
          chunk.key?("metadata") ? event.merge("metadata" => chunk["metadata"]) : event
        end

        # The END for a lane's open stream, which empties the lane; none when nothing is open.
        def close_lane(owner)
          pending = @lanes.delete(owner)
          return [] unless pending

          event = { "type" => pending.form.end, pending.form.id_field => pending.id }
          [event.merge!(pending.fields.slice("subagentRunId"))]
        end

        # The ENDs for every open lane.
        def close_all = @lanes.keys.flat_map { |owner| close_lane(owner) }

        # A rejection at the expansion stage.
        def rejection(message) = ProtocolError.new(message, stage: :expansion)
      end
    end
  end
end
