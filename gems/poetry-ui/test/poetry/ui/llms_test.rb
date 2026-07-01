# frozen_string_literal: true

require "test_helper"

module Poetry
  module Ui
    # llms.txt / llms-full.txt: generated from the registry, served by the
    # engine (the M4 DoD: "llms.txt is served").
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
    end
  end
end
