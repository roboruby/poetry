# frozen_string_literal: true

module Poetry
  module Core
    module Concerns
      # The agent-tool contract: class-level declarations of the
      # component's agent-callable tools - the "operate" projection of the
      # component's Stimulus surface. A tool names one action an in-page
      # agent may invoke on a rendered instance (WebMCP's
      # `document.modelContext`, or any client that reads the registry),
      # described in MCP `Tool` shape: name, description, JSON-Schema
      # input, and safety annotations.
      #
      #   tool :set_value,
      #        description: "Select the option whose value matches.",
      #        params: { value: { type: "string", required: true,
      #                           description: "The option value to select." } },
      #        executes: :set_value,
      #        mutating: true
      #
      # Declarations are validated at CLASS LOAD, like use_stimulus:
      # `executes:` resolves through {Concerns::Stimulus#stimulus_action}
      # against the component's declared controllers and the controllers
      # manifest, so a tool can never name an action the JS does not
      # define - declare `use_stimulus` before `tool`. The resolved
      # descriptor ("poetry--core--combobox#setValue") is the tool's wire
      # form: registration runtimes dispatch it verbatim.
      #
      # Safety doctrine (non-negotiable): tools are read-only unless
      # declared `mutating: true` (`annotations.readOnlyHint` inverts it),
      # `untrusted_content: true` marks tools whose output carries
      # user-authored content, and declaring a tool exposes NOTHING by
      # itself - emission is opt-in per rendered instance, owned by the
      # registration runtime, never default-on.
      #
      # Projection: {ClassMethods#tool_definitions} feeds the registry's
      # per-component `tools` section (plain strings, YAML-safe), which
      # the agent surfaces (llms.txt, MCP server, skills, docs) and the
      # WebMCP registration payload all read - one contract, every
      # surface.
      module AgentTools
        extend ActiveSupport::Concern

        # Raised at class load for an invalid tool declaration.
        class ToolError < Poetry::Core::Error; end

        # One declared tool. `executes` is the declared action spec
        # (`[method]` or `[controller, method]`) - resolved to a bare
        # Stimulus descriptor per PROJECTING class (see
        # {ClassMethods#tool_definitions}); `input_schema` is the
        # normalized JSON-Schema object (string keys) or nil for a
        # parameterless tool.
        Tool = Struct.new(:name, :title, :description, :input_schema,
                          :executes, :mutating, :untrusted_content,
                          keyword_init: true)

        # Tool and param names stay inside the WebMCP tool-name grammar
        # (ASCII alphanumerics, `_`, `-`, `.`) with poetry's stricter
        # snake_case convention, so a composed full name (instance prefix +
        # tool name) can never need escaping.
        NAME_PATTERN = /\A[a-z][a-z0-9_]*\z/

        # The house character budgets: names stay far under the spec's
        # 128-char full-name cap (instance prefixes join later);
        # descriptions stay inside the agent-legibility budget.
        NAME_LIMIT = 64
        # The agent-legibility budget for a tool description.
        DESCRIPTION_LIMIT = 500

        class_methods do
          # Declares one agent-callable tool of this component.
          #
          # @param name [Symbol] the tool's name (snake_case; composes into
          #   the registered full name, so it must satisfy the WebMCP name
          #   grammar)
          # @param description [String] what the tool does and when to use
          #   it - positive, single-function, non-empty (agents pick tools
          #   by this text)
          # @param executes [Symbol, Array(Symbol, Symbol)] the Stimulus
          #   action the tool dispatches: a bare method resolves across the
          #   component's declared controllers; `[:controller, :method]`
          #   pins one. Validated against the controllers manifest at
          #   class load.
          # @param params [Hash{Symbol => Hash}, nil] the tool's parameters
          #   as `name => spec`; each spec requires `type:` and may carry
          #   `required: true` (folded into the schema's `required` list)
          #   plus any JSON-Schema keywords (`description:`, `enum:`, ...)
          # @param input_schema [Hash, nil] a complete JSON-Schema object
          #   for advanced shapes - mutually exclusive with `params:`
          # @param title [String, nil] optional human-readable label for
          #   agent UIs
          # @param mutating [Boolean] declare true when invoking the tool
          #   changes state; tools are read-only by default
          #   (`annotations.readOnlyHint` is the inverse of this flag)
          # @param untrusted_content [Boolean] declare true when the
          #   tool's output can carry user-authored content
          # @return [void]
          # @raise [ToolError] at class load for a duplicate name, invalid
          #   name/description/params, or an `executes:` action the
          #   declared controllers do not define
          # @example A parameterless UI-state tool
          #   tool :open, description: "Open the dialog.",
          #        executes: :open, mutating: true
          # rubocop:disable Metrics/ParameterLists -- one keyword per MCP Tool field
          def tool(name, description:, executes:, params: nil, input_schema: nil,
                   title: nil, mutating: false, untrusted_content: false)
            name = validate_tool_name!(name)
            raise ToolError, "#{self}: tool #{name.inspect} declared twice" if own_tools.key?(name)

            validate_tool_action!(name, executes) # the class-load gate; resolution happens at projection
            own_tools[name] = AgentTools::Tool.new(
              name: name,
              title: title&.to_s,
              description: validate_tool_description!(name, description),
              input_schema: normalize_tool_schema!(name, params, input_schema),
              executes: Array(executes).map(&:to_sym),
              mutating: mutating ? true : false,
              untrusted_content: untrusted_content ? true : false
            )
          end
          # rubocop:enable Metrics/ParameterLists

          # This class's own tool declarations, name => {Tool}.
          #
          # @return [Hash{Symbol => Tool}]
          def own_tools
            @own_tools ||= {}
          end

          # The effective tools after inheritance: superclass chain
          # root-first, a subclass redeclaring a name replaces it.
          #
          # @return [Hash{Symbol => Tool}]
          def tools
            chain = []
            klass = self
            while klass.respond_to?(:own_tools)
              chain.unshift(klass)
              klass = klass.superclass
            end

            chain.each_with_object({}) do |ancestor, resolved|
              resolved.merge!(ancestor.own_tools)
            end
          end

          # The registry-shaped projection of the resolved tools: MCP
          # `Tool` fields (name / title / description / inputSchema /
          # annotations) plus the `executes` dispatch descriptor - plain
          # string keys, YAML round-trippable.
          #
          # `executes` resolves HERE, against the projecting class: a
          # subclass that re-controllers its root (Sheet over Dialog)
          # projects its own controller's descriptor for an inherited
          # bare `executes: :open`, and a pinned controller the subclass
          # no longer wires raises instead of projecting a descriptor the
          # rendered DOM cannot dispatch.
          #
          # @return [Array<Hash>]
          # @raise [ToolError] when an inherited tool's action does not
          #   resolve on this class's declared controllers
          def tool_definitions
            tools.values.map do |tool|
              definition = { "name" => tool.name.to_s }
              definition["title"] = tool.title if tool.title
              definition["description"] = tool.description
              definition["inputSchema"] = tool.input_schema if tool.input_schema
              definition["annotations"] = {
                "readOnlyHint" => !tool.mutating,
                "untrustedContentHint" => tool.untrusted_content
              }
              definition["executes"] = resolve_tool_action(tool)
              definition
            end
          end

          # The bare Stimulus descriptor a tool dispatches on THIS class.
          #
          # @param tool [Tool]
          # @return [String] e.g. "poetry--core--combobox#setValue"
          # @raise [ToolError] when the action does not resolve on the
          #   class's declared controllers, or resolves to a controller
          #   the class does not wire
          def resolve_tool_action(tool)
            descriptor = validate_tool_action!(tool.name, tool.executes)
            identifier = descriptor.split("#").first
            return descriptor if stimulus_identifiers.include?(identifier)

            raise ToolError,
                  "#{self}: tool #{tool.name.inspect} executes #{descriptor}, but #{self} does not " \
                  "wire #{identifier} (declared: #{stimulus_identifiers.join(", ")}) - redeclare the " \
                  "tool on #{self} with the controller it wires"
          end

          private

          # @api private
          def validate_tool_name!(name)
            unless name.is_a?(Symbol) || name.is_a?(String)
              raise ToolError, "#{self}: tool name must be a Symbol (got #{name.class})"
            end

            text = name.to_s
            unless NAME_PATTERN.match?(text) && text.length <= NAME_LIMIT
              raise ToolError,
                    "#{self}: invalid tool name #{name.inspect} - snake_case " \
                    "([a-z][a-z0-9_]*), at most #{NAME_LIMIT} characters"
            end
            text.to_sym
          end

          # @api private
          def validate_tool_description!(name, description)
            text = description.to_s.strip
            if text.empty? || text.length > DESCRIPTION_LIMIT
              raise ToolError,
                    "#{self}: tool #{name.inspect} description must be present and " \
                    "at most #{DESCRIPTION_LIMIT} characters"
            end
            text
          end

          # The `executes:` gate: build the bare descriptor through the
          # class's own stimulus_action, which resolves the controller
          # across the use_stimulus declarations and validates the method
          # against the controllers manifest. Returns the descriptor;
          # callers keep the spec (`Array(executes)`) for re-resolution.
          #
          # @api private
          def validate_tool_action!(name, executes)
            args = Array(executes)
            unless args.size.between?(1, 2) && args.all? { |arg| arg.is_a?(Symbol) || arg.is_a?(String) }
              raise ToolError,
                    "#{self}: tool #{name.inspect} executes: takes a method Symbol " \
                    "or [controller, method]"
            end

            begin
              stimulus_action(*args)
            rescue ArgumentError, Poetry::Core::Stimulus::Declarations::DeclarationError,
                   Poetry::Core::Stimulus::Manifest::UnknownName => e
              raise ToolError,
                    "#{self}: tool #{name.inspect} executes: #{executes.inspect} - " \
                    "#{e.message} (declare use_stimulus before tool)"
            end
          end

          # @api private
          def normalize_tool_schema!(name, params, input_schema)
            if params && input_schema
              raise ToolError,
                    "#{self}: tool #{name.inspect} takes ONE of params: or input_schema:"
            end
            return deep_stringify_tool_keys(validate_input_schema!(name, input_schema)) if input_schema
            return nil if params.nil? || params.empty?

            raise ToolError, "#{self}: tool #{name.inspect} params: must be a Hash" unless params.is_a?(Hash)

            properties = {}
            required = []
            params.each do |param_name, spec|
              param = validate_tool_name!(param_name).to_s
              unless spec.is_a?(Hash) && (spec[:type] || spec["type"])
                raise ToolError,
                      "#{self}: tool #{name.inspect} param #{param_name.inspect} needs " \
                      "a Hash spec with type:"
              end
              spec = deep_stringify_tool_keys(spec)
              required << param if spec.delete("required")
              properties[param] = spec
            end

            schema = { "type" => "object", "properties" => properties }
            schema["required"] = required if required.any?
            schema
          end

          # @api private
          def validate_input_schema!(name, input_schema)
            unless input_schema.is_a?(Hash) && (input_schema[:type] || input_schema["type"])
              raise ToolError,
                    "#{self}: tool #{name.inspect} input_schema: must be a JSON-Schema " \
                    "Hash with type:"
            end
            input_schema
          end

          # @api private
          def deep_stringify_tool_keys(value)
            case value
            when Hash then value.to_h { |key, inner| [key.to_s, deep_stringify_tool_keys(inner)] }
            when Array then value.map { |inner| deep_stringify_tool_keys(inner) }
            when Symbol then value.to_s
            else value
            end
          end
        end
      end
    end
  end
end
