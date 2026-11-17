# frozen_string_literal: true

require "test_helper"
require "rake"

module Poetry
  module Ui
    # `bin/rails "poetry:icons[delete]"`: the app's icon set asked which
    # icon means a thing.
    class IconsTaskTest < Minitest::Test
      def run_task(*)
        capture_io do
          Rake.with_application do |rake|
            rake.define_task(Rake::Task, :environment)
            load File.expand_path("../../../lib/tasks/poetry/icons.rake", __dir__)
            rake["poetry:icons"].invoke(*)
          end
        end
      end

      def test_it_prints_the_names_that_answer_best_first_with_their_tags
        output, = run_task("delete")
        lines = output.lines.map(&:chomp)

        assert_match(/\Adelete +backspace, remove\z/, lines.first)
        assert(lines.any? { |line| line.match?(/\Atrash +delete, /) }, "trash answers delete, its matching tag first")
        assert_operator lines.size, :<=, 12
      end

      def test_words_after_a_comma_are_part_of_the_description
        output, = run_task("warning", "triangle")

        assert_match(/\Atriangle-alert +warning, /, output.lines.first)
      end

      def test_it_stops_with_the_fix_when_nothing_is_asked_or_nothing_answers
        error = assert_raises(SystemExit) { run_task }
        nothing = assert_raises(SystemExit) { run_task("zeppelin") }

        refute_predicate error, :success?
        refute_predicate nothing, :success?
      end
    end
  end
end
