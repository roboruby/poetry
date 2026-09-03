# frozen_string_literal: true

require_relative "pointer"
require_relative "evaluator"
require_relative "checks"

module Poetry
  module Agent
    module A2UI
      # One A2UI surface on the renderer side: its flat component list
      # (an adjacency list keyed by id, `root` at the top), its data
      # model, and a monotonic version the Turbo Stream delivery compares.
      # A surface belongs to a catalog binding, which knows how each
      # component references its children; the surface itself is
      # catalog-agnostic beyond that.
      #
      # @example
      #   surface = Surface.new(id: "card", catalog: Catalogs::Basic.new)
      #   surface.update_components([{ "id" => "root", "component" => "Text", "text" => { "path" => "/name" } }])
      #   surface.update_data("/name", "Ada")
      #   surface.resolve({ "path" => "/name" }) # => "Ada"
      class Surface
        # Component names are UAX #31 identifiers.
        NAME_PATTERN = /\A[\p{XID_Start}_]\p{XID_Continue}*\z/u
        # The reserved container the renderer instantiates on createSurface.
        RESERVED_COMPONENT = "Surface"

        # @return [String]
        attr_reader :id
        # @return [String, nil] the catalog id the agent named
        attr_reader :catalog_id
        # @return [Object] the catalog binding (see {Catalogs::Basic})
        attr_reader :catalog
        # @return [Boolean] whether actions carry the whole data model
        attr_reader :send_data_model
        # @return [Hash{String => Hash}] components by id
        attr_reader :components
        # @return [Hash] the data model
        attr_reader :data
        # @return [Integer] bumps on every applied change
        attr_reader :version

        # @param id [String]
        # @param catalog [Object] the catalog binding
        # @param catalog_id [String, nil]
        # @param send_data_model [Boolean]
        # @param data [Hash, nil] the initial data model
        # @param components [Array<Hash>] the initial component list
        def initialize(id:, catalog:, catalog_id: nil, send_data_model: false, data: nil, components: [])
          @id = id
          @catalog = catalog
          @catalog_id = catalog_id
          @send_data_model = send_data_model ? true : false
          @data = deep_copy(data.is_a?(Hash) ? data : {})
          @components = {}
          @version = 0
          @errors = []
          update_components(components) if components.any?
        end

        # Upserts components by id and validates the result. Returns the
        # validation errors (each `{ code:, path:, message: }`); a dangling
        # child reference is not one - streaming delivers children later.
        #
        # @param list [Array<Hash>]
        # @return [Array<Hash>]
        def update_components(list)
          errors = []
          Array(list).each_with_index do |component, index|
            error = component_error(component, index)
            errors << error and next if error

            @components[component["id"]] = deep_copy(component)
          end
          errors.concat(cycle_errors)
          bump!
          errors
        end

        # Applies an `updateDataModel` (upsert; nil removes; the root
        # pointer replaces the whole model).
        #
        # @param path [String, nil]
        # @param value [Object, nil]
        # @return [void]
        def update_data(path, value)
          @data = Pointer.upsert(@data, path || "/", deep_copy(value))
          @data = {} unless @data.is_a?(Hash)
          bump!
        end

        # @return [Hash, nil] the top-level component
        def root
          @components["root"]
        end

        # @param component_id [String]
        # @return [Hash, nil]
        def component(component_id)
          @components[component_id]
        end

        # Resolves a dynamic value in a scope: a `{ "path" => ... }` binding
        # reads the data model (relative paths against the scope), a
        # `{ "call" => ... }` function call runs through the catalog's
        # functions (see {Evaluator}), anything else is a literal.
        #
        # @param value [Object]
        # @param scope [String, nil] the collection-item pointer in effect
        # @param on_error [#call, nil] receives each function problem's message
        # @return [Object, nil]
        def resolve(value, scope = nil, on_error: nil)
          Evaluator.new(self, scope, on_error: on_error).resolve(value)
        end

        # The string a resolved value displays as (the spec's conversion
        # rules: nil is empty, containers are JSON).
        #
        # @param value [Object]
        # @param scope [String, nil]
        # @param on_error [#call, nil] receives each function problem's message
        # @return [String]
        def text(value, scope = nil, on_error: nil)
          evaluator = Evaluator.new(self, scope, on_error: on_error)
          evaluator.stringify(evaluator.resolve(value))
        end

        # Evaluates every rendered component's `checks` against the data
        # model, keyed the way an action names its source (`id`, or
        # `id@scope` inside a template).
        #
        # @param on_error [#call, nil] receives each function problem's message
        # @return [Hash{String => Array<Hash>}] failures by component key
        def failures(on_error: nil)
          result = {}
          walk do |component, scope|
            next unless component["checks"].is_a?(Array)

            found = Checks.failures(component, Evaluator.new(self, scope, on_error: on_error))
            result[source_key(component, scope)] = found if found.any?
          end
          result
        end

        # @param component [Hash]
        # @param scope [String, nil]
        # @return [String] `id`, or `id@scope` inside a template
        def source_key(component, scope = nil)
          scope ? "#{component["id"]}@#{scope}" : component["id"].to_s
        end

        # What a client-side evaluator needs to run the checks as the user
        # types: every checked component's rules with its bindings made
        # absolute for its scope, the bound inputs by absolute path with
        # their kinds, and the data model for paths no input carries.
        #
        # @return [Hash] `{ "checks" => { key => { "kind", "rules" } }, "inputs" => { path => kind }, "model" => data }`
        def program
          checks = {}
          walk do |component, scope|
            rules = Array(component["checks"]).grep(Hash).select { |rule| rule["condition"] }
            next if rules.empty?

            checks[source_key(component, scope)] = {
              "kind" => component["action"].is_a?(Hash) ? "button" : "input",
              "rules" => rules.map do |rule|
                { "condition" => absolutize(rule["condition"], scope), "message" => rule["message"] }
              end
            }
          end
          { "checks" => checks, "inputs" => inputs.to_h { |input| [input[:path], input[:kind].to_s] }, "model" => data }
        end

        # @param value [Object]
        # @return [Boolean] whether the value is a `{ "path" => ... }` data binding
        def binding?(value)
          value.is_a?(Hash) && value.key?("path") && !value.key?("componentId")
        end

        # @param value [Object]
        # @return [Boolean] whether the value is a `{ "call" => ... }` function call
        def function_call?(value)
          value.is_a?(Hash) && value.key?("call")
        end

        # @param value [Object]
        # @return [Boolean] whether the value is a `{ "componentId", "path" }` template
        def template?(value)
          value.is_a?(Hash) && value.key?("componentId")
        end

        # Reads a bound path in a scope.
        #
        # @param path [String]
        # @param scope [String, nil]
        # @return [Object, nil]
        def read(path, scope = nil)
          Pointer.get(@data, Pointer.absolute(path, scope))
        end

        # Expands a child reference into `[id, scope]` pairs: an id array
        # keeps the scope, a template instantiates its component once per
        # item of the bound array with the item's pointer as the scope.
        #
        # @param reference [Array<String>, Hash, String, nil]
        # @param scope [String, nil]
        # @return [Array<Array(String, String)>]
        def expand(reference, scope = nil)
          case reference
          when String then [[reference, scope]]
          when Array then reference.grep(String).map { |child| [child, scope] }
          when Hash
            return [] unless template?(reference)

            path = Pointer.absolute(reference["path"].to_s, scope)
            items = Pointer.get(@data, path)
            return [] unless items.is_a?(Array)

            items.each_index.map { |index| [reference["componentId"], "#{path}/#{index}"] }
          else []
          end
        end

        # Walks the rendered tree depth-first from the root, yielding each
        # `[component, scope]` in render order (templates instantiate once
        # per item; a cycle guard keeps the walk finite).
        #
        # @yieldparam component [Hash]
        # @yieldparam scope [String, nil]
        # @return [void]
        def walk(&)
          walk_from("root", nil, [], &)
        end

        # Bound input descriptors of the rendered tree, absolute paths only.
        #
        # @return [Array<Hash>] `{ path:, kind: }` (kind: :string, :boolean, :number, :string_list)
        def inputs
          result = []
          walk do |component, scope|
            result.concat(Array(catalog.inputs(component, scope)))
          end
          result.uniq { |input| input[:path] }
        end

        # @return [Hash] a JSON-ready snapshot
        def to_h
          { "surfaceId" => id, "catalogId" => catalog_id, "sendDataModel" => send_data_model,
            "version" => version, "components" => components.values, "dataModel" => data }
        end

        private

        def bump!
          @version += 1
        end

        # Rewrites every binding in a value to its absolute pointer.
        def absolutize(value, scope)
          case value
          when Array then value.map { |item| absolutize(item, scope) }
          when Hash
            return { "path" => Pointer.absolute(value["path"].to_s, scope) } if binding?(value)

            value.transform_values { |item| absolutize(item, scope) }
          else value
          end
        end

        def walk_from(component_id, scope, stack, &)
          key = [component_id, scope]
          return if stack.include?(key)

          component = @components[component_id]
          return unless component

          yield component, scope
          Array(catalog.references(component)).each do |reference|
            expand(reference, scope).each do |child_id, child_scope|
              walk_from(child_id, child_scope, stack + [key], &)
            end
          end
        end

        def component_error(component, index)
          path = "/components/#{index}"
          return error(path, "component must be an object") unless component.is_a?(Hash)

          id = component["id"]
          name = component["component"]
          return error(path, "id (string) is required") unless id.is_a?(String) && !id.empty?
          return error("#{path}/component", "component (string) is required") unless name.is_a?(String)
          return error("#{path}/component", "#{name.inspect} is not an identifier") unless name.match?(NAME_PATTERN)
          return error("#{path}/component", "#{RESERVED_COMPONENT} is reserved") if name == RESERVED_COMPONENT

          nil
        end

        # Static edges (template components count) coloured depth-first.
        def cycle_errors
          state = {}
          errors = []
          @components.each_key do |component_id|
            visit(component_id, state, [], errors)
          end
          errors
        end

        def visit(component_id, state, stack, errors)
          return if state[component_id] == :done

          if state[component_id] == :open
            errors << error("/components/#{component_id}",
                            "circular reference: #{(stack + [component_id]).join(" -> ")}")
            return
          end

          state[component_id] = :open
          static_children(component_id).each { |child| visit(child, state, stack + [component_id], errors) }
          state[component_id] = :done
        end

        def static_children(component_id)
          component = @components[component_id]
          return [] unless component

          children = Array(catalog.references(component)).flat_map do |reference|
            case reference
            when String then [reference]
            when Array then reference.grep(String)
            when Hash then template?(reference) ? [reference["componentId"]] : []
            else []
            end
          end
          children.select { |child| @components.key?(child) }
        end

        def error(path, message)
          { code: "VALIDATION_FAILED", path: path, message: message }
        end

        def deep_copy(value)
          case value
          when Hash then value.to_h { |key, item| [key.to_s, deep_copy(item)] }
          when Array then value.map { |item| deep_copy(item) }
          else value
          end
        end
      end
    end
  end
end
