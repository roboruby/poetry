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
        # AG-UI placement (`forwardedProps.a2uiAction.userAction`). A
        # function call as an action runs on the renderer instead and
        # produces no message: `local?`, with the surface's data changed.
        Action = Struct.new(:message, :surface, :errors, :local, keyword_init: true) do
          # Whether the action produced a message and no check failed.
          # @return [Boolean] whether every check passed and the message exists
          def valid?
            !message.nil? && (errors.nil? || errors.empty?)
          end

          # Whether the action ran on the renderer (a `functionCall` action), with nothing for the agent.
          # @return [Boolean]
          def local?
            local == true
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

        # A session over catalog bindings. A surface that names a catalog the
        # session does not hold is refused (`CATALOG_ERROR`), as the spec
        # says; a host that wants such surfaces rendered anyway names a
        # fallback binding.
        # @param catalogs [Hash{String => Object}] catalog bindings by id
        # @param fallback_catalog [Object, nil] the binding a createSurface's unknown catalog id gets (none: refused)
        # @param strict [Boolean] A2UI's strict validation: limits on every
        #   message, the message schemas, (v1.0) identifier ids, and an update
        #   refused whole unless its surface keeps a root, references only
        #   components it holds and reaches every component from the root. By
        #   default a surface tolerates what streaming leaves incomplete. A
        #   catalog's composition constraints (`allowedParents`,
        #   `allowedChildren`) are checked in every mode, as the spec's
        #   processors do.
        # @param allow_orphans [Boolean, nil] whether an update may leave a component unreachable from
        #   the root (the spec's `allowOrphanComponents`): the mode's default when nil (tolerated unless
        #   strict), else as given
        # @param allow_dangling_references [Boolean, nil] whether an update may reference a component the
        #   surface does not hold yet (`allowDanglingReferences`): the mode's default when nil, else as given
        def initialize(catalogs: A2UI.catalogs, fallback_catalog: nil, strict: false, allow_orphans: nil,
                       allow_dangling_references: nil)
          @catalogs = catalogs
          @fallback_catalog = fallback_catalog
          @strict = strict
          @allow_orphans = allow_orphans.nil? ? !strict : allow_orphans
          @allow_dangling_references = allow_dangling_references.nil? ? !strict : allow_dangling_references
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
          if @strict && (limit = Strict.limit_problem(body) || schema_problem(message, key, body, dialect))
            return reject(limit[:code], limit[:message], body["surfaceId"], dialect: dialect, path: limit[:path])
          end

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
          call = component && local_call_of(component)
          return local_action(surface, call, scope) if call

          event = component && surface.event_of(component)
          return unless event.is_a?(Hash) && event["name"].is_a?(String)

          failures = surface.failures
          return Action.new(message: nil, surface: surface, errors: failures) if failures.any?

          if event.key?("userMessage") && !(event["userMessage"].is_a?(String) || event["userMessage"].is_a?(Hash))
            reject("INVALID_ACTION", "action.event.userMessage must be a string", surface_id)
            return Action.new(message: nil, surface: surface, errors: { "userMessage" => "must be a string" })
          end

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
        # capabilities; an agent resolves its catalogs against them), and
        # with `inline:` each catalog's definition too, so an agent that
        # cannot fetch a catalog by its id learns it here: a v1.0 catalog as
        # its document, a v0.9 one in the legacy inline shape
        # ({Catalog.legacy_inline}). A binding without a document is listed
        # by id alone.
        #
        # @param versions [Array<String>] wire versions to answer for
        # @param inline [Boolean] whether to include the catalogs' definitions
        # @return [Hash{String => Hash}] `{ "1.0" => { "supportedCatalogIds" => [...], "inlineCatalogs" => [...] },
        #   "v0.9" => ... }`
        def capabilities(versions: [Dialect::V1_0.version, Dialect::V0_9.version], inline: false)
          versions.filter_map do |version|
            dialect = Dialect.for(version) or next
            bound = catalogs_for(dialect)
            entry = { "supportedCatalogIds" => bound.keys }
            if inline
              entry["inlineCatalogs"] = bound.filter_map do |id, catalog|
                next unless catalog.respond_to?(:document)
                next Catalog.legacy_inline(catalog.document, catalog_id: id) unless dialect.v1?

                inline_document(catalog.document, id)
              end
            end
            [dialect.version, entry]
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

        # The binding for a catalog id, the fallback when it is unknown, or nil.
        # @param catalog_id [String, nil]
        # @return [Object, nil]
        def catalog_for(catalog_id)
          @catalogs[catalog_id] || @fallback_catalog
        end

        # The catalogs a surface of a version may name, by id.
        # @param dialect [Dialect]
        # @return [Hash{String => Object}]
        def catalogs_for(dialect)
          @catalogs.select { |_, catalog| catalog_dialect(catalog).compatible?(dialect) }
        end

        private

        # Why a createSurface's catalog cannot serve the surface, or nil:
        # unknown (without a fallback), or built for another version.
        def surface_catalog_problem(catalog_id, catalog, dialect)
          return if catalog_id.nil?
          return "Catalog not found: #{catalog_id}" unless catalog
          return if catalog_dialect(catalog).compatible?(dialect) || catalog.equal?(@fallback_catalog)

          "Catalog '#{catalog_id}' specification version (#{catalog_dialect(catalog).version}) " \
            "does not match message protocol version (#{dialect.version})."
        end

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

          if dialect.v1? && body.key?("metadata") && (problem = metadata_problem(body["metadata"]))
            return reject("VALIDATION_FAILED", problem, surface_id, dialect: dialect, path: "/metadata")
          end

          catalog = catalog_id.nil? ? nil : catalog_for(catalog_id)
          problem = surface_catalog_problem(catalog_id, catalog, dialect)
          return reject("CATALOG_ERROR", problem, surface_id, dialect: dialect) if problem

          surface = Surface.new(id: surface_id, catalog: catalog, catalog_id: catalog_id,
                                catalogs: catalogs_for(dialect),
                                send_data_model: body["sendDataModel"] == true, dialect: dialect,
                                data: dialect.v1? ? body["dataModel"] : nil, theme: dialect.v1? ? nil : body["theme"])
          @surfaces[surface_id] = surface
          @creations[surface_id] = JSON.parse(JSON.generate(body))
          update(surface, body["components"]) if dialect.v1? && body["components"].is_a?(Array)
          [surface_id]
        end

        # Updates a surface's components from an updateComponents body, recording validation errors.
        def apply_update_components(body, dialect)
          surface = find(body, "updateComponents", dialect) or return []
          components = body["components"]
          unless components.is_a?(Array)
            return reject("INVALID_MESSAGE", "updateComponents.components must be an array", surface.id)
          end

          update(surface, components)
        end

        # Applies components to a surface: refused whole when one id comes
        # twice, or in strict mode when the update breaks the surface;
        # otherwise each well-formed component applies and the rest are reported.
        def update(surface, components)
          ids = components.grep(Hash).map { |component| component["id"] }.grep(String)
          duplicate = ids.detect { |id| ids.count(id) > 1 }
          return reject("INTEGRITY_ERROR", "Duplicate component ID: '#{duplicate}'", surface.id) if duplicate

          problems = @strict ? strict_problems(surface, components) : structure_problems(surface, components)
          if problems.any?
            record(surface.id, problems)
            return []
          end

          record(surface.id, surface.update_components(components))
          [surface.id]
        end

        # What strict validation finds in an update: the components' own
        # problems, identifiers and calls, then their schemas, then the topology
        # and composition of the set it would make.
        def strict_problems(surface, components)
          problems = surface.check(components) + Strict.identifier_problems(components, surface.dialect) +
                     Strict.call_problems(components, surface)
          return problems if problems.any?

          update = { "version" => surface.dialect.version,
                     "updateComponents" => { "surfaceId" => surface.id, "components" => components } }
          schema = validator(surface.dialect, surface.catalog_id).problem(update)
          return [schema] if schema

          structure_problems(surface, components)
        end

        # What every mode refuses an update for: the topology of the set it
        # would make (the root only in strict mode; its references and its
        # reach unless the session allows them dangling or unreached) and
        # its catalogs' composition rules.
        def structure_problems(surface, components)
          candidate = surface.candidate(components)
          topology = Strict.topology_problems(candidate, surface, root: @strict, orphans: !@allow_orphans,
                                                                  dangling: !@allow_dangling_references)
          topology.any? ? topology : Strict.composition_problems(candidate, surface)
        end

        # A strict message's schema problem: the message against its
        # version's schema, with the catalog the createSurface names, or the
        # surface's, as the default (a catalog that cannot be resolved is the
        # code checks' to report). Its components are the update's to judge,
        # after the code checks.
        def schema_problem(message, key, body, dialect)
          default = key == "createSurface" ? body["catalogId"] : @surfaces[body["surfaceId"]]&.catalog_id
          default = nil unless default.is_a?(String)
          outside = "/#{key}/components" if %w[createSurface updateComponents].include?(key)
          validator(dialect, default).problem(message, outside: outside)
        end

        # The schema validator for a version and a default catalog, compiled
        # on first use: every catalog the session holds for the version plugs
        # in, each through its binding's `document` (none admits anything).
        def validator(dialect, default)
          (@validators ||= {})[[dialect.version, default]] ||= begin
            documents = catalogs_for(dialect).transform_values do |binding|
              binding.respond_to?(:document) ? binding.document : nil
            end
            Schemas::Validator.new(dialect, default: default, catalogs: documents)
          end
        end

        # Why a v1.0 createSurface's metadata is malformed: it holds only
        # `extensions`, whose keys are identifiers.
        def metadata_problem(metadata)
          return "createSurface.metadata must be an object" unless metadata.is_a?(Hash)

          other = (metadata.keys - ["extensions"]).first
          return "createSurface.metadata holds only 'extensions', not '#{other}'" if other

          extensions = metadata.fetch("extensions", {})
          return "createSurface.metadata.extensions must be an object" unless extensions.is_a?(Hash)

          key = extensions.keys.find { |name| !name.match?(Strict::IDENTIFIER) }
          "Extension key '#{key}' must be a valid UAX #31 identifier" if key
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

          unless call["args"].nil? || call["args"].is_a?(Hash)
            return reject("INVALID_MESSAGE", "callRendererFunction.callFunction.args must be an object",
                          dialect: dialect)
          end

          name = dialect.call_name(call).to_s
          catalog, refusal = rpc_target(call["catalogId"], name, dialect, user_activated)
          return answer(body, dialect, error: refusal) if refusal

          surface, refusal = rpc_scope(body, catalog, dialect)
          return answer(body, dialect, error: refusal) if refusal

          problems = []
          evaluator = Evaluator.new(surface, on_error: ->(message) { problems << message })
          args, failure = rpc_arguments(call["args"], evaluator, problems)
          return answer(body, dialect, error: failure) if failure

          answer(body, dialect, value: catalog.functions.call(name, args, evaluator))
        rescue Functions::Error, Expression::SyntaxError => e
          answer(body, dialect, error: { "code" => "INVALID_FUNCTION_CALL", "message" => e.message })
        rescue StandardError => e
          # A host function's own failure: the agent learns only that it failed.
          answer(body, dialect, error: { "code" => "EXECUTION_ERROR",
                                         "message" => "An error occurred during function execution (#{e.class})." })
        end

        # The surface an agent's call runs in: the one it names, whose root
        # data context its arguments read, or an isolated empty one when it
        # names none, so nothing of any surface leaks into it.
        def rpc_scope(body, catalog, dialect)
          id = body["surfaceId"]
          return [Surface.new(id: "callRendererFunction", catalog: catalog, dialect: dialect), nil] if id.nil?

          surface = id.is_a?(String) && @surfaces[id]
          return [surface, nil] if surface

          [nil, { "code" => "INVALID_FUNCTION_CALL", "message" => "Surface not found: #{id}" }]
        end

        # The call's arguments resolved in its surface, with the execution
        # error their evaluation met (an `@index` outside a template, say):
        # the evaluator reports a failed call to its listener and resolves it
        # to nothing, and a syntax error raises.
        def rpc_arguments(args, evaluator, problems)
          resolved = evaluator.argument(args || {})
          return [resolved, nil] if problems.empty?

          [nil, { "code" => "EXECUTION_ERROR",
                  "message" => "An error occurred evaluating the call's arguments: #{problems.first}" }]
        rescue Functions::Error, Expression::SyntaxError => e
          [nil,
           { "code" => "EXECUTION_ERROR",
             "message" => "An error occurred evaluating the call's arguments: #{e.message}" }]
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

        # A v1.0 catalog document as capabilities inline it: a copy, named by the id it is bound under.
        def inline_document(document, catalog_id)
          JSON.parse(JSON.generate(document)).merge("catalogId" => catalog_id)
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
            body = { "code" => error[:code], "surfaceId" => surface_id, "path" => error[:path],
                     "message" => error[:message] }
            body.delete("path") unless error[:code] == "VALIDATION_FAILED"
            @errors << { "version" => version_for(surface_id), "error" => body }
          end
        end

        # Records an error message and returns no changed ids. It carries the
        # version of the surface it names, else of the message, else v1.0's.
        def reject(code, message, surface_id = nil, dialect: nil, path: nil)
          error = { "code" => code, "message" => message }
          error["surfaceId"] = surface_id if surface_id.is_a?(String)
          error["path"] = path if path && code == "VALIDATION_FAILED"
          @errors << { "version" => version_for(surface_id, dialect), "error" => error }
          []
        end

        # The version an outgoing message about a surface carries.
        def version_for(surface_id, dialect = nil)
          surface = surface_id.is_a?(String) && @surfaces[surface_id]
          (surface ? surface.dialect : dialect || Dialect::V1_0).version
        end

        # The function call a component's action makes, or nil for an event.
        def local_call_of(component)
          action = component["action"]
          call = action.is_a?(Hash) && action["functionCall"]
          call.is_a?(Hash) ? call : nil
        end

        # Runs a function-call action on the renderer, under the user's
        # gesture, against the surface: its data may change, nothing goes to
        # the agent, and a failure is reported on the surface.
        def local_action(surface, call, scope)
          name = surface.dialect.call_name(call).to_s
          problems = []
          evaluator = Evaluator.new(surface, scope, gesture: true, on_error: ->(message) { problems << message })
          args = evaluator.argument(call["args"] || {})
          raise Functions::Error, problems.first if problems.any?

          surface.catalog.functions.call(name, args, evaluator)
          Action.new(message: nil, surface: surface, errors: {}, local: true)
        rescue StandardError => e
          reject("EXECUTION_ERROR", "An error occurred during function execution (#{e.class}).", surface.id)
          Action.new(message: nil, surface: surface, errors: { "action" => e.message }, local: true)
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
