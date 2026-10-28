# frozen_string_literal: true

require "test_helper"

module Poetry
  module Ui
    module Trace
      class ComponentTest < ViewComponent::TestCase
        def render_trace(&)
          render_inline(Component.new, &)
          Nokogiri::HTML5.fragment(rendered_content)
        end

        def test_a_step_is_a_line_of_icon_title_and_description
          fragment = render_trace do |trace|
            trace.with_step("Searched the docs", icon: :search, description: "3 results")
          end
          line = fragment.at_css('[data-slot="trace"] > [data-slot="trace-line"]')

          assert line, "a plain step's line sits directly in the column"
          assert_equal "true", line.at_css('[data-slot="trace-icon"]')["aria-hidden"]
          assert line.at_css('[data-slot="trace-icon"] svg')
          assert_equal "Searched the docs", line.at_css('[data-slot="trace-title"]').text
          assert_equal "3 results", line.at_css('[data-slot="trace-description"]').text
          refute line.key?("data-status"), "a finished step carries no status"
        end

        def test_status_is_the_lines_look
          fragment = render_trace do |trace|
            trace.with_step("Running the tests", status: :running)
            trace.with_step("Failed", status: :error)
          end

          assert_equal(%w[running error], fragment.css('[data-slot="trace-line"]').map { |line| line["data-status"] })
          assert_includes fragment.at_css('[data-slot="trace-line"]')["class"],
                          "data-[status=running]:*:data-[slot=trace-title]:shimmer"
        end

        def test_an_unknown_status_raises
          assert_raises(ArgumentError) { render_trace { |trace| trace.with_step("x", status: :done) } }
        end

        def test_href_makes_the_step_a_link
          link = render_trace do |trace|
            trace.with_step("Read the plan", href: "/plans/1")
          end.at_css('[data-slot="trace"] > a')

          assert_equal "/plans/1", link["href"]
          assert link.at_css('[data-slot="trace-line"]')
        end

        def test_a_block_makes_the_step_a_disclosure_on_the_collapsible_contract
          fragment = render_trace { |trace| trace.with_step("Ran git status", icon: :terminal) { "M app.rb" } }
          step = fragment.at_css('[data-slot="trace-collapsible"]')
          trigger = step.at_css('button[data-slot="trace-collapsible-trigger"]')
          content = step.at_css('[data-slot="trace-collapsible-content"]')

          assert_equal "poetry--core--state", step["data-controller"]
          assert step.key?("data-closed")
          assert_equal "false", trigger["aria-expanded"]
          assert_equal content["id"], trigger["aria-controls"]
          assert_equal "click->poetry--core--state#toggle", trigger["data-action"]
          assert content.key?("hidden")
          assert_includes content["class"], "h-(--collapsible-panel-height)"
          assert_equal "M app.rb", content.at_css('[data-slot="trace-collapsible-content-inner"]').text
          assert trigger.at_css('[data-slot="trace-line"]'), "the line is the trigger's label"
          assert_includes trigger.css('[data-slot="trace-icon"]').last["class"],
                          "group-aria-expanded/trace-collapsible-trigger:rotate-90"
        end

        def test_open_server_renders_the_detail
          fragment = render_trace { |trace| trace.with_step("Thought", open: true) { "because" } }

          assert_equal "true", fragment.at_css('[data-slot="trace-collapsible-trigger"]')["aria-expanded"]
          refute fragment.at_css('[data-slot="trace-collapsible-content"]').key?("hidden")
        end

        def test_detail_ids_are_unique_per_step
          fragment = render_trace do |trace|
            trace.with_step("One") { "a" }
            trace.with_step("Two") { "b" }
          end
          ids = fragment.css('[data-slot="trace-collapsible-content"]').map { |content| content["id"] }

          assert_equal 2, ids.uniq.size
        end

        def test_requires_a_step
          assert_raises(ArgumentError) { render_inline(Component.new) }
        end
      end
    end
  end
end
