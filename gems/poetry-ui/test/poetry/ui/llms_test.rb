# frozen_string_literal: true

require "test_helper"

module Poetry
  module Ui
    # llms.txt / llms-full.txt: generated from the registry, served by the
    # engine ("llms.txt is served" is the contract).
    class LlmsTest < ActionDispatch::IntegrationTest
      def test_llms_txt_is_served_with_the_component_index
        get "/llms.txt"

        assert_response :success
        assert_includes response.body, "# Poetry for Rails"
        assert_includes response.body, "- button: `poetry_button`"
        assert_includes response.body, "default|destructive|outline|secondary|ghost|link"
      end

      def test_llms_full_txt_carries_contracts_and_agent_rules
        get "/llms-full.txt"

        assert_response :success
        assert_includes response.body, "## button (`poetry_button`)"
        assert_includes response.body, "- `variant:` (symbol) - one of default|destructive|outline|secondary|ghost|link"
        assert_includes response.body, "- RULE: Use poetry_button - never a raw <button> with hand-written Tailwind."
        assert_includes response.body, "## icon (`poetry_icon`)"
      end

      def test_llms_full_txt_carries_the_stimulus_wiring_surface
        get "/llms-full.txt"

        # Phase 5 element-level projection: an agent wiring by hand sees
        # WHICH element carries which controller, values, actions (with
        # their events), and targets - not just the controllers' API.
        assert_includes response.body, "- WIRING root: `poetry--core--dialog` registers; values dismissible"
        assert_includes response.body,
                        "- WIRING content: `poetry--core--dialog` actions close on cancel, " \
                        "backdropClose on click; targets dialog"
        assert_includes response.body, "- WIRING trigger: `poetry--core--dialog` actions open"
        # The command palette dialog helper is addressed by its full path,
        # not the last-segment poetry_dialog (which collides).
        assert_includes response.body, "## command_dialog (`poetry_command_dialog`)"
      end
    end
  end
end
