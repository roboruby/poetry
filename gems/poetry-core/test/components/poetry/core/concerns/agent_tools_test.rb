# frozen_string_literal: true

require "test_helper"

module Poetry
  module Core
    module Concerns
      class AgentToolsTest < ViewComponent::TestCase
        # Real manifest controllers keep the class-load gate live: accordion
        # defines toggle, action-bar defines clear/keydown, and both define
        # connect/disconnect (the ambiguity fixture).
        class ToolComponent < Poetry::Core::Component
          use_stimulus do
            on :root do
              controller :accordion do
                register
                action :toggle, on: :click
              end
            end
            on :bar do
              controller(:action_bar) { register }
            end
          end

          tool :toggle_section,
               title: "Toggle section",
               description: "Expand or collapse the section whose value matches.",
               params: { value: { type: "string", required: true, description: "The section value." },
                         animate: { type: :boolean, enum: [true, false] } },
               executes: :toggle,
               mutating: true

          tool :clear_selection,
               description: "Clear the current selection.",
               executes: %i[action_bar clear]

          def call = tag.div("tools", **stimulus_attributes_for(:root))
        end

        class SubclassComponent < ToolComponent
          tool :clear_selection,
               description: "Clear the selection (subclass wording).",
               executes: %i[action_bar clear],
               untrusted_content: true

          tool :count, description: "Read the selection count.", executes: %i[action_bar keydown]
        end

        def test_tool_definitions_project_mcp_tool_shape
          toggle, clear = ToolComponent.tool_definitions

          assert_equal(
            {
              "name" => "toggle_section",
              "title" => "Toggle section",
              "description" => "Expand or collapse the section whose value matches.",
              "inputSchema" => {
                "type" => "object",
                "properties" => {
                  "value" => { "type" => "string", "description" => "The section value." },
                  "animate" => { "type" => "boolean", "enum" => [true, false] }
                },
                "required" => ["value"]
              },
              "annotations" => { "readOnlyHint" => false, "untrustedContentHint" => false },
              "executes" => "poetry--core--accordion#toggle"
            },
            toggle
          )
          assert_equal(
            {
              "name" => "clear_selection",
              "description" => "Clear the current selection.",
              "annotations" => { "readOnlyHint" => true, "untrustedContentHint" => false },
              "executes" => "poetry--core--action-bar#clear"
            },
            clear
          )
        end

        def test_definitions_are_plain_string_keyed_data
          ToolComponent.tool_definitions.each do |definition|
            assert(deep_plain?(definition), "expected plain data: #{definition.inspect}")
          end
        end

        def test_subclass_redeclaration_replaces_and_additions_append
          names = SubclassComponent.tool_definitions.map { |tool| tool["name"] }

          assert_equal %w[toggle_section clear_selection count], names

          clear = SubclassComponent.tools[:clear_selection]

          assert_equal "Clear the selection (subclass wording).", clear.description
          assert clear.untrusted_content
          # The parent is untouched.
          assert_equal "Clear the current selection.", ToolComponent.tools[:clear_selection].description
        end

        def test_executes_must_name_a_declared_controller_action
          error = assert_raises(AgentTools::ToolError) do
            Class.new(Poetry::Core::Component) do
              use_stimulus { on(:root) { controller(:accordion) { register } } }
              tool :nope, description: "Missing action.", executes: :vanish
            end
          end
          assert_match(/executes: :vanish/, error.message)
        end

        def test_ambiguous_executes_demands_a_controller
          error = assert_raises(AgentTools::ToolError) do
            Class.new(ToolComponent) do
              tool :attach, description: "Ambiguous across controllers.", executes: :connect
            end
          end
          assert_match(/ambiguous/, error.message)
        end

        def test_tool_before_use_stimulus_raises_with_ordering_hint
          error = assert_raises(AgentTools::ToolError) do
            Class.new(Poetry::Core::Component) do
              tool :early, description: "Declared before wiring.", executes: :toggle
            end
          end
          assert_match(/declare use_stimulus before tool/, error.message)
        end

        def test_duplicate_name_in_one_class_raises
          error = assert_raises(AgentTools::ToolError) do
            Class.new(ToolComponent) do
              tool :twice, description: "First.", executes: :toggle
              tool :twice, description: "Second.", executes: :toggle
            end
          end
          assert_match(/declared twice/, error.message)
        end

        def test_name_and_description_budgets
          assert_raises(AgentTools::ToolError) do
            Class.new(ToolComponent) { tool :"Bad-Name", description: "x", executes: :toggle }
          end
          assert_raises(AgentTools::ToolError) do
            Class.new(ToolComponent) { tool :blank, description: "   ", executes: :toggle }
          end
          assert_raises(AgentTools::ToolError) do
            Class.new(ToolComponent) { tool :long, description: "x" * 501, executes: :toggle }
          end
        end

        def test_params_require_a_typed_hash_spec
          error = assert_raises(AgentTools::ToolError) do
            Class.new(ToolComponent) do
              tool :untyped, description: "No type.", executes: :toggle, params: { value: { description: "?" } }
            end
          end
          assert_match(/needs a Hash spec with type:/, error.message)
        end

        def test_input_schema_override_is_exclusive_with_params
          schema = { type: "object", properties: { q: { type: "string" } }, additionalProperties: false }
          klass = Class.new(ToolComponent) do
            tool :search, description: "Search.", executes: :toggle, input_schema: schema
          end

          assert_equal(
            { "type" => "object", "properties" => { "q" => { "type" => "string" } },
              "additionalProperties" => false },
            klass.tools[:search].input_schema
          )

          assert_raises(AgentTools::ToolError) do
            Class.new(ToolComponent) do
              tool :both, description: "Both.", executes: :toggle, input_schema: schema,
                          params: { a: { type: "string" } }
            end
          end
        end

        # Sheet over Dialog: the subclass re-controllers its root, so a bare
        # inherited action re-resolves to the subclass's controller (accordion
        # and dialog both define toggle in the manifest).
        class ReControlledComponent < ToolComponent
          use_stimulus do
            on :root do
              controller(:dialog) { register }
            end
          end
        end

        def test_bare_executes_re_resolves_on_a_re_controlled_subclass
          base = Class.new(Poetry::Core::Component) do
            use_stimulus { on(:root) { controller(:accordion) { register } } }
            tool :flip, description: "Flip the section.", executes: :toggle
          end
          sub = Class.new(base) do
            use_stimulus { on(:root) { controller(:dialog) { register } } }
          end

          assert_equal "poetry--core--accordion#toggle", base.tool_definitions.first["executes"]
          assert_equal "poetry--core--dialog#toggle", sub.tool_definitions.first["executes"]
        end

        def test_pinned_executes_must_be_wired_by_the_projecting_class
          # ToolComponent pins clear_selection to action-bar; the subclass
          # keeps :bar declared, so it projects - but a subclass that drops
          # the controller raises instead of projecting a dead descriptor.
          assert_equal "poetry--core--action-bar#clear",
                       ReControlledComponent.tool_definitions.find { |t|
                         t["name"] == "clear_selection"
                       }["executes"]

          dropped = Class.new(Poetry::Core::Component) do
            use_stimulus { on(:root) { controller(:action_bar) { register } } }
            tool :wipe, description: "Wipe.", executes: %i[action_bar clear]
          end
          orphan = Class.new(dropped) do
            use_stimulus { on(:root) { controller(:accordion) { register } } }
          end
          error = assert_raises(AgentTools::ToolError) { orphan.tool_definitions }

          assert_match(/does not wire poetry--core--action-bar/, error.message)
        end

        def test_components_without_tools_project_nothing
          assert_empty Poetry::Core::Component.tool_definitions
        end

        private

        def deep_plain?(value)
          case value
          when Hash then value.all? { |k, v| k.is_a?(String) && deep_plain?(v) }
          when Array then value.all? { |v| deep_plain?(v) }
          else [String, Integer, Float, TrueClass, FalseClass, NilClass].any? { |t| value.is_a?(t) }
          end
        end
      end
    end
  end
end
