# frozen_string_literal: true

require "test_helper"
require "rake"

module Poetry
  module Agent
    # `bin/rails "poetry:gap[...]"`: the report an agent gets from report_gap,
    # printed for a person at a terminal.
    class GapTaskTest < Minitest::Test
      def run_task(*)
        capture_io do
          Rake.with_application do |rake|
            load File.expand_path("../../../lib/tasks/poetry/gap.rake", __dir__)
            rake["poetry:gap"].invoke(*)
          end
        end
      ensure
        %w[KIND COMPONENT].each { |name| ENV.delete(name) }
      end

      def test_it_prints_the_link_and_what_it_holds
        ENV["KIND"] = "variant"
        ENV["COMPONENT"] = "badge"
        output, = run_task("Badge has no warning variant")

        assert_includes output, "Nothing was sent."
        assert_includes output, "https://github.com/roboruby/poetry/issues/new?title=Gap%3A+Badge+has+no+warning+variant"
        assert_includes output, "**Kind:** variant"
        assert_includes output, "**Component:** badge"
        assert_includes output, "the rake task"
      end

      def test_a_comma_in_the_summary_is_kept_and_a_missing_one_stops_with_the_fix
        output, = run_task("No timeline", "no stepper either")

        assert_includes output, "Title: Gap: No timeline, no stepper either"
        refute_predicate assert_raises(SystemExit) { run_task }, :success?
      end
    end
  end
end
