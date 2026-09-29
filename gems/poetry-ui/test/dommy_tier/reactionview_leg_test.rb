# frozen_string_literal: true

require_relative "dommy_helper"

module DommyTier
  # The behaviour tier of the ReActionView legs runs with the slot markers
  # in the page, where the controllers meet them: nothing strips them here.
  # This checks that they are there. A plain run defines no test.
  class ReactionviewLegTest < TestCase
    MODE = ENV.fetch("POETRY_REACTIONVIEW", nil)

    if MODE
      def test_the_page_carries_slot_markers_exactly_when_the_mode_asks
        harness = render_in_dommy(Poetry::Ui::Switch::Component.new(name: "notify"))
        markup = harness.evaluate("document.documentElement.outerHTML")

        assert_no_js_errors harness
        assert_equal MODE != "engine", markup.include?("herb-slot")
      end
    end
  end
end
