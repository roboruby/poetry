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
      # Each surface speaks the protocol version of the message that created
      # it, v0.9 and v1.0 side by side ({Dialect}): a later message must
      # speak the same one, and whatever the session sends about a surface
      # carries its version (`"v0.9"`, or v1.0's `"1.0"`). Every message
      # names its version; v1.0's earlier spelling `"v1.0"` is accepted.
      #
      # @example Fold a stream of messages and read back the surfaces
      #   session = Session.new
      #   session.apply_all(messages)  # => ["login"]
      #   session.surfaces["login"].data
      #   session.errors               # => [] or renderer-to-agent error messages
      class Session
        # The operations a v0.9 message may carry, exactly one per message.
        MESSAGE_KEYS_V0_9 = %w[createSurface updateComponents updateDataModel deleteSurface].freeze
        # The operations a v1.0 message may carry, exactly one per message.
        MESSAGE_KEYS = (MESSAGE_KEYS_V0_9 + %w[callRendererFunction agentFunctionResponse]).freeze

        # A user action, ready for the agent: the spec message plus the
        # AG-UI placement (`forwardedProps.a2uiAction.userAction`).
        Action = Struct.new(:message, :surface, :errors, keyword_init: true) do
          # Whether the action produced a message and no check failed.
          # @return [Boolean] whether every check passed and the message exists
          def valid?
            !message.nil? && (errors.nil? || errors.empty?)
          end

          # The renderer-to-agent action message, or nil when a check failed.
          # @return [Hash, nil] the `{ "version", "action" }` renderer-to-agent
          #   message; nil when a check failed
          def to_h
            message
          end

          # The forwarded props carrying the action and, when asked for, the data model.
          # @return [Hash] the AG-UI `forwardedProps` carrying the action (and the
          #   data model when the surface asked for it); empty when invalid
          def forwarded_props
            return {} unless valid?

            props = { "userAction" => message["action"] }
            props["dataModel"] = surface.data if surface.send_data_model
            { "a2uiAction" => props }
          end
        end

        # The live surfaces by id.
        # @return [Hash{String => Surface}] live surfaces by id
        attr_reader :surfaces
        # The renderer-to-agent error messages, in order.
        # @return [Array<Hash>] renderer-to-agent error messages, in order
        attr_reader :errors
        # The ids of deleted surfaces, in order.
        # @return [Array<String>] ids of deleted surfaces, in order
        attr_reader :deleted
        # The renderer-to-agent function response messages, in order.
        # @return [Array<Hash>] renderer-to-agent `rendererFunctionResponse` messages, in order
        attr_reader :responses
        # The catalog bindings by catalog id.
        # @return [Hash{String => Object}] catalog bindings by catalog id
        attr_reader :catalogs
        # The last lifecycle status an AG-UI activity carried while no surface
        # was ready yet (`{ "status" => "building", "progressTokens" => 20 }`), or nil.
        # @return [Hash, nil]
        attr_reader :status

        # A session over catalog bindings, with a default for unknown catalog ids.
        # @param catalogs [Hash{String => Object}] catalog bindings by id
        # @param default_catalog [Object, nil] the binding for unknown catalog ids
        #   (Poetry's own when nil)
        def initialize(catalogs: A2UI.catalogs, default_catalog: nil)
          @catalogs = catalogs
          @default_catalog = default_catalog || catalogs[Catalog::DEFAULT_ID] || catalogs.values.first
          @surfaces = {}
          @errors = []
          @deleted = []
          @responses = []
          @creations = {}
        end

        # Applies one envelope message. Returns the ids of the surfaces
        # it changed (a deleted surface counts); problems are recorded in
        # {#errors} and return no ids.
        #
        # @param message [Hash]
        # @param user_activated [Boolean] whether the message answers a user's
        #   gesture, so an agent's `callRendererFunction` may run a function
        #   that needs one (`openUrl`); a server-side renderer cannot see the
        #   gesture, so the host says so
        # @return [Array<String>]
        def apply(message, user_activated: false)
          return reject("INVALID_MESSAGE", "message must be an object") unless message.is_a?(Hash)

          dialect = message_dialect(message) or return []
          key = message_key(message, dialect) or return []
          body = message[key]
          return reject("INVALID_MESSAGE", "#{key} must be an object", dialect: dialect) unless body.is_a?(Hash)

          if key == "callRendererFunction"
            return apply_call_renderer_function(body, dialect,
                                                user_activated: user_activated)
          end

          send(:"apply_#{key.gsub(/([A-Z])/) { "_#{::Regexp.last_match(1).downcase}" }}", body, dialect)
        end

        # Applies a list of messages and returns the ids of the surfaces they changed.
        # @param messages [Array<Hash>]
        # @return [Array<String>] the changed surface ids, deduplicated
        def apply_all(messages)
          Array(messages).flat_map { |message| apply(message) }.uniq
        end

        # Applies the A2UI messages an AG-UI `a2ui-surface` activity
        # carries (an `a2ui_operations`, `messages`, or `operations` list,
        # or one bare message). An activity that carries only a lifecycle
        # status (`{ "status", "progressTokens" }`, while the agent builds the
        # surface) is recorded as {#status}, not an error. A replacing snapshot
        # carries every operation so far, so the `createSurface` that made a
        # surface is skipped when it comes again unchanged.
        #
        # @param content [Hash, Array]
        # @return [Array<String>] the changed surface ids
        def apply_activity(content)
          if lifecycle?(content)
            @status = content.slice("status", "progressTokens")
            return []
          end

          list = case content
                 when Array then content
                 when Hash
                   content["a2ui_operations"] || content["messages"] || content["operations"] || [content]
                 else []
                 end
          @replaying = true
          apply_all(list.grep(Hash))
        ensure
          @replaying = false
        end

        # A surface by id, or nil.
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
          event = component && surface.event_of(component)
          return unless event.is_a?(Hash) && event["name"].is_a?(String)

          failures = surface.failures
          return Action.new(message: nil, surface: surface, errors: failures) if failures.any?

          context = (event["context"] || {}).to_h { |name, value| [name.to_s, surface.resolve(value, scope)] }
          action = { "name" => event["name"], "surfaceId" => surface_id, "sourceComponentId" => component_id,
                     "timestamp" => timestamp.utc.iso8601(3), "context" => context }
          user_message = event.key?("userMessage") ? surface.text(event["userMessage"], scope) : ""
          action["userMessage"] = user_message unless user_message.empty?
          Action.new(message: { "version" => surface.dialect.version, "action" => action }, surface: surface,
                     errors: {})
        end

        # What the renderer tells an agent it supports, by protocol version:
        # the ids of the catalogs it holds for each (A2UI's renderer
        # capabilities; an agent resolves its catalogs against them).
        #
        # @param versions [Array<String>] wire versions to answer for
        # @return [Hash{String => Hash}] `{ "1.0" => { "supportedCatalogIds" => [...] }, "v0.9" => ... }`
        def capabilities(versions: [Dialect::V1_0.version, Dialect::V0_9.version])
          versions.filter_map do |version|
            dialect = Dialect.for(version) or next
            ids = @catalogs.select { |_, catalog| catalog_dialect(catalog).compatible?(dialect) }.keys
            [dialect.version, { "supportedCatalogIds" => ids }]
          end.to_h
        end

        # The data models of the surfaces that send theirs (`sendDataModel`),
        # speaking one version, as A2UI's renderer data model; nil when none does.
        #
        # @param version [String] the wire version asked for
        # @return [Hash, nil] `{ "version", "surfaces" => { id => data } }`
        def renderer_data_model(version:)
          dialect = Dialect.for(version) or return
          surfaces = @surfaces.values.select do |surface|
            surface.send_data_model && surface.dialect.compatible?(dialect)
          end
          return if surfaces.empty?

          { "version" => dialect.version, "surfaces" => surfaces.to_h { |surface| [surface.id, surface.data] } }
        end

        # The binding for a catalog id, or the default.
        # @param catalog_id [String, nil]
        # @return [Object] the catalog binding for an id (the default when unknown)
        def catalog_for(catalog_id)
          @catalogs[catalog_id] || @default_catalog
        end

        private

        # Whether an activity's content is only a lifecycle status, with no message in it.
        def lifecycle?(content)
          content.is_a?(Hash) && content.key?("status") &&
            !content.keys.intersect?(MESSAGE_KEYS + %w[a2ui_operations messages operations version])
        end

        # The dialect of a message's version, or nil after rejecting a missing or unknown one.
        def message_dialect(message)
          version = message["version"]
          return reject("INVALID_MESSAGE", "Missing required version field") && nil if version.nil?

          Dialect.for(version) || (reject("INVALID_MESSAGE", "Unsupported protocol version '#{version}'") && nil)
        end

        # The one operation key of a message for its version, or nil after rejecting a malformed one.
        def message_key(message, dialect)
          allowed = dialect.v1? ? MESSAGE_KEYS : MESSAGE_KEYS_V0_9
          keys = allowed & message.keys
          return keys.first if keys.length == 1

          other = (message.keys - %w[version]).first
          problem = if keys.length > 1 then "Message contains multiple conflicting update actions"
                    elsif other then "action '#{other}' is not supported in protocol version #{dialect.version}"
                    else "Message contains no update action"
                    end
          reject("INVALID_MESSAGE", problem, dialect: dialect)
          nil
        end

        # Creates a surface from a createSurface body, speaking the message's
        # version; a duplicate or missing id is rejected, and so is a v0.9
        # surface without its required catalogId. Inline components and an
        # initial data model are v1.0's; a theme is v0.9's.
        def apply_create_surface(body, dialect)
          surface_id = body["surfaceId"]
          unless surface_id.is_a?(String)
            return reject("INVALID_MESSAGE", "surfaceId must be a string",
                          dialect: dialect)
          end
          return [] if @replaying && @creations[surface_id] == body
          if @surfaces[surface_id]
            return reject("DUPLICATE_SURFACE", "Surface #{surface_id} already exists.",
                          surface_id)
          end

          catalog_id = body["catalogId"]
          unless dialect.v1? || catalog_id.is_a?(String)
            return reject("INVALID_MESSAGE", "createSurface.catalogId is required in #{dialect.version}", surface_id,
                          dialect: dialect)
          end

          surface = Surface.new(id: surface_id, catalog: catalog_for(catalog_id), catalog_id: catalog_id,
                                send_data_model: body["sendDataModel"] == true, dialect: dialect,
                                data: dialect.v1? ? body["dataModel"] : nil, theme: dialect.v1? ? nil : body["theme"])
          @surfaces[surface_id] = surface
          @creations[surface_id] = JSON.parse(JSON.generate(body))
          if dialect.v1? && body["components"].is_a?(Array)
            record(surface_id, surface.update_components(body["components"]))
          end
          [surface_id]
        end

        # Updates a surface's components from an updateComponents body, recording validation errors.
        def apply_update_components(body, dialect)
          surface = find(body, "updateComponents", dialect) or return []
          components = body["components"]
          unless components.is_a?(Array)
            return reject("INVALID_MESSAGE", "updateComponents.components must be an array", surface.id)
          end

          record(surface.id, surface.update_components(components))
          [surface.id]
        end

        # Writes a value into a surface's data model from an updateDataModel
        # body. v1.0 requires the value (null deletes); in v0.9 an omitted one
        # deletes.
        def apply_update_data_model(body, dialect)
          surface = find(body, "updateDataModel", dialect) or return []
          if dialect.v1? && !body.key?("value")
            return reject("INVALID_MESSAGE", "updateDataModel.value is required", surface.id)
          end

          surface.update_data(body["path"], body["value"])
          [surface.id]
        rescue Pointer::Error => e
          reject("DATA_ERROR", "updateDataModel #{body["path"].inspect}: #{e.message}", surface.id)
        end

        # Deletes a surface from a deleteSurface body; an unknown one is already gone.
        def apply_delete_surface(body, dialect)
          return [] unless @surfaces.key?(body["surfaceId"])

          surface = find(body, "deleteSurface", dialect) or return []
          @surfaces.delete(surface.id)
          @deleted << surface.id
          [surface.id]
        end

        # An agent may invoke a function the catalog it names admits
        # (`agentOnly` or `rendererOrAgent`). The answer is always a
        # `rendererFunctionResponse`: the value, or an error inside it
        # (`INVALID_FUNCTION_CALL` for a call the renderer refuses,
        # `EXECUTION_ERROR` for one that raises). A message without a function
        # call or its catalogId is rejected outright.
        def apply_call_renderer_function(body, dialect, user_activated:)
          call = body["callFunction"]
          unless call.is_a?(Hash)
            return reject("INVALID_MESSAGE", "callRendererFunction.callFunction is required",
                          dialect: dialect)
          end
          unless call["catalogId"].is_a?(String)
            return reject("INVALID_MESSAGE", "callRendererFunction.callFunction.catalogId is required",
                          dialect: dialect)
          end

          name = dialect.call_name(call).to_s
          catalog, refusal = rpc_target(call["catalogId"], name, dialect, user_activated)
          return answer(body, dialect, error: refusal) if refusal

          evaluator = Evaluator.new(Surface.new(id: "callRendererFunction", catalog: catalog, dialect: dialect))
          answer(body, dialect, value: catalog.functions.call(name, evaluator.argument(call["args"] || {}), evaluator))
        rescue Functions::Error, Expression::SyntaxError => e
          answer(body, dialect, error: { "code" => "INVALID_FUNCTION_CALL", "message" => e.message })
        rescue StandardError => e
          # A host function's own failure: the agent learns only that it failed.
          answer(body, dialect, error: { "code" => "EXECUTION_ERROR",
                                         "message" => "An error occurred during function execution (#{e.class})." })
        end

        # The catalog an agent's call runs in, or the refusal: no such catalog
        # (there is no fallback), one built for another version, no such
        # function, one the agent may not call, or one that needs a user's
        # gesture the message does not answer.
        def rpc_target(catalog_id, name, dialect, user_activated)
          catalog = @catalogs[catalog_id]
          refusal = if catalog.nil? then "Catalog not found: #{catalog_id}"
                    elsif !catalog_dialect(catalog).compatible?(dialect)
                      "Catalog '#{catalog_id}' specification version (#{catalog_dialect(catalog).version}) " \
                        "does not match message protocol version (#{dialect.version})."
                    elsif !catalog.functions.declared?(name) then "Function not found: #{name}"
                    elsif !catalog.functions.agent_callable?(name)
                      "Function '#{name}' is not invocable by an agent."
                    elsif catalog.functions.activation?(name) && !user_activated
                      "Function '#{name}' requires user activation context to execute."
                    end
          [catalog, refusal && { "code" => "INVALID_FUNCTION_CALL", "message" => refusal }]
        end

        # The protocol version a catalog binding is built for (v1.0 when it does not say).
        def catalog_dialect(catalog)
          catalog.respond_to?(:dialect) ? catalog.dialect : Dialect::V1_0
        end

        # Records the response to an agent's call: its value or its error.
        def answer(body, dialect, value: nil, error: nil)
          response = { "functionCallId" => body["functionCallId"] }
          error ? response["error"] = error : response["value"] = value
          @responses << { "version" => dialect.version, "rendererFunctionResponse" => response }
          []
        end

        # This renderer never calls agent functions; a response has nothing to match.
        def apply_agent_function_response(_body, _dialect)
          []
        end

        # The surface a body names, or nil after rejecting an unknown id or a
        # message in another version than the surface speaks.
        def find(body, key, dialect)
          surface_id = body["surfaceId"]
          surface = surface_id.is_a?(String) && @surfaces[surface_id]
          unless surface
            reject("UNKNOWN_SURFACE", "Surface not found for message: #{surface_id}", surface_id, dialect: dialect)
            return
          end
          return surface if surface.dialect.compatible?(dialect)

          reject("INVALID_MESSAGE", "#{key}: surface #{surface_id} speaks #{surface.dialect.version}, " \
                                    "the message #{dialect.version}", surface_id)
          nil
        end

        # Records a surface's validation errors as error messages.
        def record(surface_id, validation_errors)
          validation_errors.each do |error|
            @errors << { "version" => version_for(surface_id),
                         "error" => { "code" => error[:code], "surfaceId" => surface_id, "path" => error[:path],
                                      "message" => error[:message] } }
          end
        end

        # Records an error message and returns no changed ids. It carries the
        # version of the surface it names, else of the message, else v1.0's.
        def reject(code, message, surface_id = nil, dialect: nil)
          error = { "code" => code, "message" => message }
          error["surfaceId"] = surface_id if surface_id.is_a?(String)
          @errors << { "version" => version_for(surface_id, dialect), "error" => error }
          []
        end

        # The version an outgoing message about a surface carries.
        def version_for(surface_id, dialect = nil)
          surface = surface_id.is_a?(String) && @surfaces[surface_id]
          (surface ? surface.dialect : dialect || Dialect::V1_0).version
        end

        # Only bound paths are writable, each coerced to its input's kind;
        # a path the data model refuses is reported and skipped.
        def write_inputs(surface, values)
          return unless values.respond_to?(:each_pair)

          kinds = surface.inputs.to_h { |input| [input[:path], input[:kind]] }
          values.each_pair do |path, value|
            kind = kinds[path.to_s] or next

            begin
              surface.update_data(path.to_s, coerce(value, kind))
            rescue Pointer::Error => e
              reject("DATA_ERROR", "input #{path.to_s.inspect}: #{e.message}", surface.id)
            end
          end
        end

        # A submitted value coerced to its input's kind.
        def coerce(value, kind)
          case kind
          when :boolean then %w[true 1 on].include?(value.to_s.downcase)
          when :number then number(value)
          when :string_list then Array(value).map(&:to_s).reject(&:empty?)
          else value.is_a?(Array) ? value.join(", ") : value.to_s
          end
        end

        # A submitted value as a number, or nil when blank or unparsable.
        def number(value)
          text = value.to_s
          return nil if text.strip.empty?

          text.match?(/\A-?\d+\z/) ? text.to_i : Float(text, exception: false)
        end
      end
    end
  end
end
