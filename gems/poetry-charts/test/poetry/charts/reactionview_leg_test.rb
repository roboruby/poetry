# frozen_string_literal: true

require "test_helper"

module Poetry
  module Charts
    # The ReActionView legs (rake test:reactionview) have to be what they
    # say. A run that stopped compiling through ReActionView, or stopped
    # compiling slots, would pass every other test and prove nothing, so the
    # leg checks its own footing. A plain run defines no test here.
    class ReactionviewLegTest < Minitest::Test
      MODE = ENV.fetch("POETRY_REACTIONVIEW", nil)
      TEMPLATE = Poetry::Charts.root.join("app/components/poetry/charts/container/component.html.erb")

      if MODE
        def test_templates_compile_through_reactionview
          assert_operator handler, :<=, ReActionView::Template::Handlers::ERB
        end

        def test_a_component_template_is_compiled_with_nothing_rescued
          assert_equal :compile, ReActionView.config.external_template_mode
          assert_equal :raise, ReActionView.config.validation_mode
        end

        def test_slot_markers_are_compiled_in_exactly_when_the_mode_asks
          assert_equal MODE != "engine", compiled.include?("herb-region")
        end
      end

      private

      def handler
        ActionView::Template.handler_for_extension(:erb)
      end

      def compiled
        template = ViewComponent::Template::DataWithSource.new(
          format: :html, identifier: TEMPLATE.to_s, short_identifier: "container/component.html.erb",
          type: ActionView::Template::Types[:html]
        )
        handler.call(template, TEMPLATE.read)
      end
    end
  end
end
