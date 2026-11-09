# frozen_string_literal: true

require "json"
require_relative "dialect"

module Poetry
  module Agent
    module A2UI
      # The checks A2UI's strict validation adds to a surface's update, for
      # `Session.new(strict: true)`: the code half of the tier (the catalog
      # schemas are the other). Each check answers problems as
      # `{ code:, path:, message: }`, worded as the spec's processors word
      # them; an update with any problem is refused whole.
      #
      # - limits: no value nests deeper than {MAX_DEPTH}, no function call
      #   deeper than {MAX_CALL_DEPTH}, and every bound path is a pointer;
      # - topology: the surface has its `root`, every child reference names a
      #   component, and every component is reachable from the root;
      # - identifiers: a v1.0 component id and function name is a UAX #31
      #   identifier, and every call names a function its catalog declares;
      # - composition: a catalog's `allowedParents` and `allowedChildren`.
      module Strict
        # How deep any value may nest.
        MAX_DEPTH = 50
        # How deep function calls may nest inside one another.
        MAX_CALL_DEPTH = 5
        # A JSON Pointer, absolute or relative, with only `~0` and `~1` escapes.
        PATH = %r{\A(?:(?:/(?:[^~/]|~[01])*)*|(?:[^~/]|~[01])+(?:/(?:[^~/]|~[01])*)*)\z}
        # A UAX #31 identifier.
        IDENTIFIER = /\A[\p{XID_Start}_]\p{XID_Continue}*\z/u
        # A function name: an identifier, a system function's with a leading `@`.
        FUNCTION = /\A@?[\p{XID_Start}_]\p{XID_Continue}*\z/u
        # The component every surface renders from.
        ROOT = "root"

        module_function

        # The first limit a value breaks: nesting, call depth, or a bound path
        # that is not a pointer.
        # @param value [Object] a message body, a component, or data
        # @param depth [Integer] how deep the value sits (a caller starts at 0)
        # @param calls [Integer] how many calls enclose it (a caller starts at 0)
        # @return [Hash, nil] `{ code:, path:, message: }`
        def limit_problem(value, depth = 0, calls = 0)
          if depth > MAX_DEPTH
            return problem("RECURSION_ERROR", "Global recursion limit exceeded: Depth > #{MAX_DEPTH}")
          end

          case value
          when Array then first(value) { |item| limit_problem(item, depth + 1, calls) }
          when Hash then hash_limit_problem(value, depth, calls)
          end
        end

        # The topology problems of a surface's candidate component set: no
        # root, a child reference to no component, a component the root does
        # not reach, each check one the caller may waive.
        # @param components [Hash{String => Hash}] the candidate set by id
        # @param surface [Surface] whose catalogs say which properties are references
        # @param root [Boolean] whether a set without its root is a problem (strict mode's rule)
        # @param orphans [Boolean] whether a component the root does not reach is a problem
        # @param dangling [Boolean] whether a reference to a component the set lacks is a problem
        # @return [Array<Hash>]
        def topology_problems(components, surface, root: true, orphans: true, dangling: true)
          return [] if components.empty?
          if root && !components.key?(ROOT)
            return [problem("INTEGRITY_ERROR", "Missing root component: No component has id='#{ROOT}'")]
          end

          if dangling
            missing = components.each_value.flat_map { |component| dangling_problems(component, components, surface) }
            return missing if missing.any?
          end

          depth = tree_depth(components, surface)
          if depth > MAX_DEPTH
            return [problem("RECURSION_ERROR", "Global recursion limit exceeded: logical depth > #{MAX_DEPTH}")]
          end

          orphan = orphans ? (components.keys - reachable(components, surface)).first : nil
          return [] unless orphan

          [problem("INTEGRITY_ERROR", "Component '#{orphan}' is not reachable from '#{ROOT}' " \
                                      "(Orphaned component '#{orphan}' is not reachable from root)")]
        end

        # The identifier problems of incoming components: a v1.0 id is a UAX #31 identifier.
        # @param list [Array<Hash>]
        # @param dialect [Dialect]
        # @return [Array<Hash>]
        def identifier_problems(list, dialect)
          return [] unless dialect.v1?

          list.grep(Hash).filter_map do |component|
            id = component["id"]
            next if !id.is_a?(String) || id.match?(IDENTIFIER)

            problem("VALIDATION_FAILED", "Component id '#{id}' must be a valid UAX #31 identifier", "/components/#{id}")
          end
        end

        # The call problems of incoming components: a v1.0 function name that
        # is not an identifier, and a call to a function its catalog does not
        # declare (`@index` is the system's).
        # @param list [Array<Hash>]
        # @param surface [Surface]
        # @return [Array<Hash>]
        def call_problems(list, surface)
          list.grep(Hash).filter_map do |component|
            first(component.except("id", "component", "catalogId").values) { |value| call_problem(value, surface) }
          end
        end

        # The composition problems of a candidate set: a child its container's
        # `allowedChildren` leaves out, a component under a parent its
        # `allowedParents` leaves out (the root's parent is the `Surface`).
        # @param components [Hash{String => Hash}]
        # @param surface [Surface]
        # @return [Array<Hash>]
        def composition_problems(components, surface)
          root = components[ROOT]
          problems = if root
                       [parent_problem(root, { "id" => "Surface", "component" => "Surface" },
                                       surface)].compact
                     else
                       []
                     end
          components.each_value do |parent|
            fields = surface.catalog_of(parent)&.then { |catalog| reference_fields(catalog, parent) } || []
            fields.flat_map { |field, reference| named(field, reference).map(&:last) }.each do |child_id|
              child = components[child_id] or next
              problems.concat([child_problem(parent, child, surface), parent_problem(child, parent, surface)].compact)
            end
          end
          problems
        end

        # The component ids a reference names, each with the field it sits in.
        # @param field [String]
        # @param reference [Object] an id, an id list, or a template
        # @return [Array<Array(String, String)>] `[field, id]` pairs
        def named(field, reference)
          case reference
          when String then [[field, reference]]
          when Array then reference.each_with_index.filter_map do |id, index|
            ["#{field}[#{index}]", id] if id.is_a?(String)
          end
          when Hash then reference["componentId"].is_a?(String) ? [[field, reference["componentId"]]] : []
          else []
          end
        end

        # A problem record.
        # @api private
        def problem(code, message, path = nil)
          { code: code, path: path, message: message }
        end

        # The first problem a block finds among items.
        # @api private
        def first(items, &)
          items.lazy.filter_map(&).first
        end

        # An object's limit problem: a bound path that is not a pointer, a
        # call nested too deep, or a value nested too deep.
        def hash_limit_problem(value, depth, calls)
          [value["path"], value["@path"]].each do |path|
            if path.is_a?(String) && !path.match?(PATH)
              return problem("VALIDATION_FAILED",
                             "Invalid path syntax: '#{path}'")
            end
          end
          call = value.key?("args") && (value.key?("call") || value.key?("@call"))
          if call && calls >= MAX_CALL_DEPTH
            return problem("RECURSION_ERROR", "Recursion limit exceeded: functionCall depth > #{MAX_CALL_DEPTH}")
          end

          first(value) { |key, item| limit_problem(item, depth + 1, calls + (call && key == "args" ? 1 : 0)) }
        end

        # A call's problem, or one in the calls of its arguments.
        def call_problem(value, surface)
          case value
          when Array then first(value) { |item| call_problem(item, surface) }
          when Hash
            own = surface.function_call?(value) ? function_problem(value, surface) : nil
            own || first(value.values) { |item| call_problem(item, surface) }
          end
        end

        # Why one call's function cannot run: a name that is not an
        # identifier, another `@` name, or one its catalog does not declare.
        def function_problem(call, surface)
          name = surface.dialect.call_name(call)
          if surface.dialect.v1? && !name.match?(FUNCTION)
            return problem("VALIDATION_FAILED", "Function name '#{name}' must be a valid UAX #31 identifier")
          end
          return if name == "@index"

          catalog = surface.lookup(call).first
          return if catalog.nil?
          return problem("VALIDATION_FAILED", "Unrecognized function '#{name}'") if name.start_with?("@")
          unless catalog.functions.declared?(name)
            return problem("VALIDATION_FAILED",
                           "Unrecognized function '#{name}'")
          end

          argument = catalog.functions.argument_problem(name, call["args"].is_a?(Hash) ? call["args"] : {},
                                                        surface.dialect)
          problem("VALIDATION_FAILED", argument) if argument
        end

        # A component's catalog definition, when its binding has the catalog's document.
        def definition(component, surface)
          catalog = surface.catalog_of(component)
          catalog.respond_to?(:definition) ? catalog.definition(component["component"]) : nil
        end

        # A child its container's `allowedChildren` leaves out.
        def child_problem(parent, child, surface)
          allowed = definition(parent, surface)&.dig("allowedChildren")
          return if allowed.nil? || allowed.include?(child["component"])

          problem("UNALLOWED_CHILD", "Container '#{parent["id"]}' (#{parent["component"]}) cannot contain child " \
                                     "'#{child["id"]}' (#{child["component"]}). Allowed children: #{names(allowed)}.",
                  "/components/#{parent["id"]}")
        end

        # A component under a parent its `allowedParents` leaves out.
        def parent_problem(child, parent, surface)
          allowed = definition(child, surface)&.dig("allowedParents")
          return if allowed.nil? || allowed.include?(parent["component"])

          problem("UNALLOWED_PARENT", "Component '#{child["id"]}' (#{child["component"]}) cannot be placed under " \
                                      "parent '#{parent["id"]}' (#{parent["component"]}). Allowed parents: " \
                                      "#{names(allowed)}.", "/components/#{child["id"]}")
        end

        # A list of component names as the spec's messages print one (`['Text', 'Button']`).
        def names(list)
          "[#{list.map { |name| "'#{name}'" }.join(", ")}]"
        end

        # How deep the component tree under the root goes (a cycle stops the walk).
        def tree_depth(components, surface, id = ROOT, seen = [])
          component = components[id]
          return 0 if component.nil? || seen.include?(id)

          fields = surface.catalog_of(component)&.then { |catalog| reference_fields(catalog, component) } || []
          children = fields.flat_map { |field, reference| named(field, reference).map(&:last) }
          1 + (children.map { |child| tree_depth(components, surface, child, seen + [id]) }.max || 0)
        end

        # A component's references to components the set does not hold.
        def dangling_problems(component, components, surface)
          fields = surface.catalog_of(component)&.then { |catalog| reference_fields(catalog, component) } || []
          fields.flat_map { |field, reference| named(field, reference) }.filter_map do |field, id|
            next if components.key?(id)

            problem("INTEGRITY_ERROR", "Component '#{component["id"]}' references non-existent component '#{id}' " \
                                       "in field '#{field}' (Dangling reference '#{id}' in component " \
                                       "'#{component["id"]}')")
          end
        end

        # A binding's references with their fields; one that names no fields reports each without one.
        def reference_fields(catalog, component)
          return catalog.reference_fields(component) if catalog.respond_to?(:reference_fields)

          Array(catalog.references(component)).map { |reference| ["children", reference] }
        end

        # The ids the root reaches through static references (a template's component counts).
        def reachable(components, surface)
          seen = []
          queue = [ROOT]
          until queue.empty?
            id = queue.shift
            next if seen.include?(id) || !components.key?(id)

            seen << id
            component = components[id]
            fields = surface.catalog_of(component)&.then { |catalog| reference_fields(catalog, component) } || []
            queue.concat(fields.flat_map { |field, reference| named(field, reference).map(&:last) })
          end
          seen
        end

        private_class_method :problem, :first, :hash_limit_problem, :dangling_problems, :reference_fields,
                             :reachable, :call_problem, :function_problem, :definition, :child_problem,
                             :parent_problem, :names, :tree_depth
      end
    end
  end
end
