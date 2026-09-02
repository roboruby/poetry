# frozen_string_literal: true

require "json"
require "time"
require_relative "surface"

module Poetry
  module Agent
    module A2UI
      # The renderer-side consumer of the A2UI envelope: applies
      # `createSurface`, `updateComponents`, `updateDataModel`, and
      # `deleteSurface` to a set of {Surface}s, answers what it cannot
      # honor with renderer-to-agent error messages, and turns a
      # submitted form into the spec's `action` message.
      #
      # @example Fold a stream of messages and read back the surfaces
      #   session = Session.new
      #   session.apply_all(messages)  # => ["login"]
      #   session.surfaces["login"].data
      #   session.errors               # => [] or renderer-to-agent error messages
      class Session
        # Every message carries exactly one of these keys.
        MESSAGE_KEYS = %w[createSurface updateComponents updateDataModel deleteSurface
                          callRendererFunction agentFunctionResponse].freeze

        # A user action, ready for the agent: the spec message plus the
        # AG-UI placement (`forwardedProps.a2uiAction.userAction`).
        Action = Struct.new(:message, :surface, :errors, keyword_init: true) do
          # @return [Boolean] whether every check passed and the message exists
          def valid?
            !message.nil? && (errors.nil? || errors.empty?)
          end

          # @return [Hash, nil] the `{ "version", "action" }` renderer-to-agent
          #   message; nil when a check failed
          def to_h
            message
          end

          # @return [Hash] the AG-UI `forwardedProps` carrying the action (and the
          #   data model when the surface asked for it); empty when invalid
          def forwarded_props
            return {} unless valid?

            props = { "userAction" => message["action"] }
            props["dataModel"] = surface.data if surface.send_data_model
            { "a2uiAction" => props }
          end
        end

        # @return [Hash{String => Surface}] live surfaces by id
        attr_reader :surfaces
        # @return [Array<Hash>] renderer-to-agent error messages, in order
        attr_reader :errors
        # @return [Array<String>] ids of deleted surfaces, in order
        attr_reader :deleted
        # @return [Hash{String => Object}] catalog bindings by catalog id
        attr_reader :catalogs

        # @param catalogs [Hash{String => Object}] catalog bindings by id
        # @param default_catalog [Object, nil] the binding for unknown catalog ids
        #   (Poetry's own when nil)
        def initialize(catalogs: A2UI.catalogs, default_catalog: nil)
          @catalogs = catalogs
          @default_catalog = default_catalog || catalogs[Catalog::DEFAULT_ID] || catalogs.values.first
          @surfaces = {}
          @errors = []
          @deleted = []
        end

        # Applies one envelope message. Returns the ids of the surfaces
        # it changed (a deleted surface counts); problems are recorded in
        # {#errors} and return no ids.
        #
        # @param message [Hash]
        # @return [Array<String>]
        def apply(message)
          key = message_key(message)
          return [] unless key

          body = message[key]
          return reject("INVALID_MESSAGE", "#{key} must be an object") unless body.is_a?(Hash)

          send(:"apply_#{key.gsub(/([A-Z])/) { "_#{::Regexp.last_match(1).downcase}" }}", body)
        end

        # @param messages [Array<Hash>]
        # @return [Array<String>] the changed surface ids, deduplicated
        def apply_all(messages)
          Array(messages).flat_map { |message| apply(message) }.uniq
        end

        # Applies the A2UI messages an AG-UI `a2ui-surface` activity
        # carries (an `a2ui_operations`, `messages`, or `operations` list,
        # or one bare message).
        #
        # @param content [Hash, Array]
        # @return [Array<String>] the changed surface ids
        def apply_activity(content)
          list = case content
                 when Array then content
                 when Hash
                   content["a2ui_operations"] || content["messages"] || content["operations"] || [content]
                 else []
                 end
          apply_all(list.grep(Hash))
        end

        # @param surface_id [String]
        # @return [Surface, nil]
        def surface(surface_id)
          @surfaces[surface_id]
        end

        # Turns a submitted surface form into the agent's `action`
        # message: bound input values are written to the data model first
        # (two-way binding syncs on an action), then the source
        # component's event context resolves against the updated model.
        # Returns nil when the source has no agent event (a local action,
        # or an unknown component), and an invalid action - no message,
        # `errors` by component key - when a `checks` rule fails.
        #
        # @param surface_id [String]
        # @param source [String] the submit button's value (`id` or `id@scope`)
        # @param values [Hash{String => Object}] submitted values by absolute pointer
        # @param timestamp [Time]
        # @return [Action, nil]
        def action(surface_id:, source:, values: {}, timestamp: Time.now.utc)
          surface = @surfaces[surface_id]
          return unless surface

          write_inputs(surface, values)
          component_id, scope = source.to_s.split("@", 2)
          component = surface.component(component_id)
          event = component&.dig("action", "event")
          return unless event.is_a?(Hash) && event["name"].is_a?(String)

          failures = surface.failures
          return Action.new(message: nil, surface: surface, errors: failures) if failures.any?

          context = (event["context"] || {}).to_h { |name, value| [name.to_s, surface.resolve(value, scope)] }
          action = { "name" => event["name"], "surfaceId" => surface_id, "sourceComponentId" => component_id,
                     "timestamp" => timestamp.utc.iso8601(3), "context" => context }
          action["userMessage"] = event["userMessage"] if event["userMessage"].is_a?(String)
          Action.new(message: { "version" => "v#{PROTOCOL_VERSION}", "action" => action }, surface: surface, errors: {})
        end

        # @param catalog_id [String, nil]
        # @return [Object] the catalog binding for an id (the default when unknown)
        def catalog_for(catalog_id)
          @catalogs[catalog_id] || @default_catalog
        end

        private

        def message_key(message)
          return reject("INVALID_MESSAGE", "message must be an object") && nil unless message.is_a?(Hash)

          version = message["version"]
          unless version.nil? || version == "v#{PROTOCOL_VERSION}"
            reject("INVALID_MESSAGE", "unsupported version #{version.inspect}")
            return
          end

          keys = MESSAGE_KEYS & message.keys
          return keys.first if keys.length == 1

          reject("INVALID_MESSAGE", "message must carry exactly one of #{MESSAGE_KEYS.join(", ")}")
          nil
        end

        def apply_create_surface(body)
          surface_id = body["surfaceId"]
          return reject("INVALID_MESSAGE", "createSurface.surfaceId is required") unless surface_id.is_a?(String)
          if @surfaces[surface_id]
            return reject("DUPLICATE_SURFACE", "surface #{surface_id} already exists",
                          surface_id)
          end

          catalog_id = body["catalogId"]
          surface = Surface.new(id: surface_id, catalog: catalog_for(catalog_id), catalog_id: catalog_id,
                                send_data_model: body["sendDataModel"] == true, data: body["dataModel"])
          @surfaces[surface_id] = surface
          record(surface_id, surface.update_components(body["components"])) if body["components"].is_a?(Array)
          [surface_id]
        end

        def apply_update_components(body)
          surface = find(body, "updateComponents") or return []
          components = body["components"]
          unless components.is_a?(Array)
            return reject("INVALID_MESSAGE", "updateComponents.components must be an array", surface.id)
          end

          record(surface.id, surface.update_components(components))
          [surface.id]
        end

        def apply_update_data_model(body)
          surface = find(body, "updateDataModel") or return []
          return reject("INVALID_MESSAGE", "updateDataModel.value is required", surface.id) unless body.key?("value")

          surface.update_data(body["path"], body["value"])
          [surface.id]
        end

        def apply_delete_surface(body)
          surface = find(body, "deleteSurface") or return []
          @surfaces.delete(surface.id)
          @deleted << surface.id
          [surface.id]
        end

        # No renderer functions are registered on this renderer (functions
        # are a later slice), so every agent call is refused as the spec
        # asks.
        def apply_call_renderer_function(body)
          name = body.dig("callFunction", "call")
          error = { "code" => "INVALID_FUNCTION_CALL", "message" => "function #{name.inspect} is not registered" }
          error["functionCallId"] = body["functionCallId"] if body["functionCallId"]
          @errors << { "version" => "v#{PROTOCOL_VERSION}", "error" => error }
          []
        end

        # This renderer never calls agent functions; a response has nothing to match.
        def apply_agent_function_response(_body)
          []
        end

        def find(body, key)
          surface_id = body["surfaceId"]
          surface = surface_id.is_a?(String) && @surfaces[surface_id]
          reject("UNKNOWN_SURFACE", "#{key}: no surface #{surface_id.inspect}", surface_id) unless surface
          surface || nil
        end

        def record(surface_id, validation_errors)
          validation_errors.each do |error|
            @errors << { "version" => "v#{PROTOCOL_VERSION}",
                         "error" => { "code" => error[:code], "surfaceId" => surface_id, "path" => error[:path],
                                      "message" => error[:message] } }
          end
        end

        def reject(code, message, surface_id = nil)
          error = { "code" => code, "message" => message }
          error["surfaceId"] = surface_id if surface_id.is_a?(String)
          @errors << { "version" => "v#{PROTOCOL_VERSION}", "error" => error }
          []
        end

        # Only bound paths are writable, each coerced to its input's kind.
        def write_inputs(surface, values)
          return unless values.respond_to?(:each_pair)

          kinds = surface.inputs.to_h { |input| [input[:path], input[:kind]] }
          values.each_pair do |path, value|
            kind = kinds[path.to_s] or next

            surface.update_data(path.to_s, coerce(value, kind))
          end
        end

        def coerce(value, kind)
          case kind
          when :boolean then %w[true 1 on].include?(value.to_s.downcase)
          when :number then number(value)
          when :string_list then Array(value).map(&:to_s).reject(&:empty?)
          else value.is_a?(Array) ? value.join(", ") : value.to_s
          end
        end

        def number(value)
          text = value.to_s
          return nil if text.strip.empty?

          text.match?(/\A-?\d+\z/) ? text.to_i : Float(text, exception: false)
        end
      end
    end
  end
end
