# frozen_string_literal: true

module Poetry
  module Ui
    # The declarative WebMCP form contract: the attribute vocabulary
    # Chrome's declarative API registers straight from markup - a <form>
    # carrying `toolname` + `tooldescription` IS an agent-callable tool,
    # its controls are the parameters (the browser synthesizes the JSON
    # Schema from control types, `required`, and select options, reading
    # each parameter's description from the associated <label>), and
    # `toolparamdescription` overrides a label where the label alone is
    # not agent-sufficient. No JavaScript, inert markup without an agent.
    #
    # Safety by construction: `toolautosubmit` (the agent submits without
    # the user pressing Submit) is only allowed on GET forms - read-only
    # lookups. A mutating form keeps the user in the loop, always.
    #
    # Consumers: {ComponentsHelper#poetry_webmcp_form} (the form), the
    # FormBuilder's `tool_description:` field option (the override), and
    # poetry-agent's imperative runtime, which shares this vocabulary.
    module Webmcp
      # The WebMCP tool-name grammar: 1-128 ASCII alphanumerics, `_`,
      # `-`, `.` (declarative forms register their full name directly).
      TOOL_NAME_PATTERN = /\A[A-Za-z0-9_.-]{1,128}\z/
      # The agent-legibility budget for descriptions.
      DESCRIPTION_LIMIT = 500
      # The keys a `tool:` declaration may carry.
      TOOL_KEYS = %i[name description autosubmit].freeze

      module_function

      # The <form> attributes for a declarative tool.
      #
      # @param tool [Hash] `name:` (tool-name grammar), `description:`
      #   (present, at most {DESCRIPTION_LIMIT} chars), optional
      #   `autosubmit: true`
      # @param method [Symbol, String, nil] the form's HTTP method -
      #   autosubmit requires :get
      # @return [Hash{Symbol => String}] `toolname`, `tooldescription`,
      #   and `toolautosubmit` (empty-valued boolean attribute) when set
      # @raise [ArgumentError] for an unknown key, an invalid name or
      #   description, or autosubmit on a non-GET form
      # @example
      #   Poetry::Ui::Webmcp.form_attributes({ name: "find_order", description: "Find an order." }, method: :get)
      #   # => { toolname: "find_order", tooldescription: "Find an order." }
      def form_attributes(tool, method: nil)
        tool = tool.to_h.transform_keys(&:to_sym)
        unknown = tool.keys - TOOL_KEYS
        raise ArgumentError, "tool: unknown key(s) #{unknown.inspect} - allowed: #{TOOL_KEYS.inspect}" if unknown.any?

        name = tool[:name].to_s
        unless TOOL_NAME_PATTERN.match?(name)
          raise ArgumentError, "tool: name #{tool[:name].inspect} must be 1-128 chars of [A-Za-z0-9_.-]"
        end

        attributes = { toolname: name, tooldescription: description!(tool[:description], "tool: description") }
        if tool[:autosubmit]
          unless method.to_s.casecmp?("get")
            raise ArgumentError,
                  "tool: autosubmit is only allowed on GET forms (read-only lookups) - a mutating form " \
                  "keeps the user's confirmation"
          end
          attributes[:toolautosubmit] = ""
        end
        attributes
      end

      # The control attribute for a parameter-description override.
      #
      # @param description [String] the parameter's description for agents
      # @return [Hash{Symbol => String}] `toolparamdescription`
      # @raise [ArgumentError] for a blank or over-budget description
      def param_attributes(description)
        { toolparamdescription: description!(description, "tool_description:") }
      end

      # @api private
      def description!(value, context)
        text = value.to_s.strip
        if text.empty? || text.length > DESCRIPTION_LIMIT
          raise ArgumentError, "#{context} must be present and at most #{DESCRIPTION_LIMIT} characters"
        end

        text
      end
    end
  end
end
