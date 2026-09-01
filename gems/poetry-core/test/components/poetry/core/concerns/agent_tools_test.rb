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
                "required" => ["value"],
                "additionalProperties" => false
              },
              "annotations" => { "readOnlyHint" => false, "untrustedContentHint" => false },
              "executes" => "poetry--core--accordion#toggle"
            },
            toggle
          )
          assert_equal(
            {
              "name" => "clear_selection",
              "title" => "Clear selection",
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

        def test_param_descriptions_have_a_budget
          error = assert_raises(AgentTools::ToolError) do
            Class.new(ToolComponent) do
              tool :verbose, description: "Verbose.", executes: :toggle,
                             params: { value: { type: "string", description: "x" * 151 } }
            end
          end

          assert_match(/param "value" description must be present and at most 150 characters/, error.message)
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

        def test_webmcp_opt_in_wires_the_registrar_on_the_root
          with_registrar_manifest do
            attrs = ToolComponent.new(webmcp: "sections").stimulus_attributes_for(:root)

            assert_includes attrs["data-controller"], "poetry--core--accordion"
            assert_includes attrs["data-controller"], "poetry--agent--webmcp"
            assert_equal "sections", attrs["data-poetry--agent--webmcp-name-value"]
            tools = JSON.parse(attrs["data-poetry--agent--webmcp-tools-value"])

            assert_equal(%w[toggle_section clear_selection], tools.map { |t| t["name"] })
            assert_equal "poetry--core--accordion#toggle", tools.first["executes"]
          end
        end

        def test_webmcp_budget_rides_the_root_only_when_configured_away_from_the_default
          with_registrar_manifest do
            config = Poetry::Core::Config.current
            attrs = ToolComponent.new(webmcp: "sections").stimulus_attributes_for(:root)

            refute attrs.key?("data-poetry--agent--webmcp-budget-value")

            config.webmcp_registration_budget = 12
            attrs = ToolComponent.new(webmcp: "sections").stimulus_attributes_for(:root)

            assert_equal "12", attrs["data-poetry--agent--webmcp-budget-value"]
          ensure
            config.webmcp_registration_budget = AgentTools::WEBMCP_DEFAULT_BUDGET
          end
        end

        def test_webmcp_true_names_the_instance_after_the_component
          with_registrar_manifest do
            component = ToolComponent.new(webmcp: true)

            assert_predicate component, :webmcp_enabled?
            assert_equal ToolComponent.component_title.tr("-", "_"), component.webmcp_name
          end
        end

        def test_webmcp_is_inert_without_opt_in
          component = ToolComponent.new
          attrs = component.stimulus_attributes_for(:root)

          refute_predicate component, :webmcp_enabled?
          refute_includes attrs["data-controller"], "poetry--agent--webmcp"
          refute attrs.key?("data-poetry--agent--webmcp-tools-value")
        end

        def test_webmcp_without_the_runtime_gem_raises_a_configuration_error
          catalog = Poetry::Core::Stimulus::Manifest.catalog
          removed = catalog.delete("poetry--agent--webmcp")
          error = assert_raises(AgentTools::ToolError) do
            ToolComponent.new(webmcp: "x").stimulus_attributes_for(:root)
          end

          assert_match(/requires the poetry-agent gem/, error.message)
        ensure
          catalog["poetry--agent--webmcp"] = removed if removed
        end

        def test_webmcp_on_a_component_without_tools_raises
          with_registrar_manifest do
            toolless = Class.new(Poetry::Core::Component) do
              use_stimulus { on(:root) { controller(:accordion) { register } } }
            end
            error = assert_raises(AgentTools::ToolError) { toolless.new(webmcp: true).stimulus_attributes_for(:root) }

            assert_match(/declares no tools/, error.message)
          end
        end

        def test_webmcp_tool_definition_hook_enriches_the_payload
          with_registrar_manifest do
            enriched = Class.new(ToolComponent) do
              def webmcp_tool_definition(definition)
                return definition unless definition["name"] == "toggle_section"

                definition.merge("inputSchema" => definition["inputSchema"].merge("x-rendered" => true))
              end
            end
            attrs = enriched.new(webmcp: "s").stimulus_attributes_for(:root)
            tools = JSON.parse(attrs["data-poetry--agent--webmcp-tools-value"])

            assert tools.first.dig("inputSchema", "x-rendered")
            assert_equal "poetry--core--accordion#toggle", tools.first["executes"]
          end
        end

        private

        # The registrar's manifest entry joins the catalog when poetry-agent
        # loads; core's tests stand it up inline (the cross-gem seam is the
        # WEBMCP_CONTROLLER constant, which poetry-agent's manifest test pins).
        def with_registrar_manifest
          catalog = Poetry::Core::Stimulus::Manifest.catalog
          had = catalog.key?(AgentTools::WEBMCP_CONTROLLER)
          catalog[AgentTools::WEBMCP_CONTROLLER] ||= {
            "targets" => [],
            "values" => { "name" => { "type" => "String" }, "tools" => { "type" => "Array" },
                          "budget" => { "type" => "Number", "default" => 20 } },
            "classes" => [], "methods" => %w[connect disconnect register unregister], "events" => []
          }
          yield
        ensure
          catalog.delete(AgentTools::WEBMCP_CONTROLLER) unless had
        end

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
