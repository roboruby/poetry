# frozen_string_literal: true

require "test_helper"

module Poetry
  module Charts
    # The Rails main leg (rake test:rails_main) has to be what it says. A
    # run that resolved a released Rails, or compiled through Erubi, would
    # pass every other test and prove nothing, so the leg checks its own
    # footing. A plain run defines no test here.
    class RailsMainLegTest < Minitest::Test
      TEMPLATE = Poetry::Charts.root.join("app/components/poetry/charts/container/component.html.erb")

      if ENV["POETRY_RAILS"] == "main"
        def test_the_bundle_resolved_rails_from_its_main_branch
          assert_predicate Rails.gem_version, :prerelease?
          assert_includes Gem.loaded_specs.fetch("rails").full_gem_path, "bundler/gems/rails-"
        end

        # The dummy raises when a framework is loaded before initialization
        # completes, so the boot this suite ran on is the proof that Poetry
        # loads nothing early.
        def test_the_host_raises_on_an_early_load_and_booted
          assert_equal :raise, Rails.configuration.action_on_early_load_hook
          assert_predicate Rails.application, :initialized?
        end

        def test_html_templates_compile_through_herb
          assert_operator ActionView::Template::Handlers::ERB.erb_implementation, :<=, ::Herb::Engine
          assert_predicate Poetry::Core::Check::Compile, :rendering?
        end

        def test_a_component_template_is_compiled_by_the_engine
          template = ViewComponent::Template::DataWithSource.new(
            format: :html, identifier: TEMPLATE.to_s, short_identifier: "container/component.html.erb",
            type: ActionView::Template::Types[:html]
          )
          source = TEMPLATE.read
          compiled = ActionView::Template.handler_for_extension(:erb).call(template, source)

          assert_equal ActionView::Template::Handlers::ERB::Herb.new(source, trim: true, escape: false).src,
                       compiled
        end
      end
    end
  end
end
