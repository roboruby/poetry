# frozen_string_literal: true

require "test_helper"

module Poetry
  module Core
    # Icons.suggest and the FileSet error surface: the reversed-
    # compound Lucide renames resolve, edit distance still works, and the
    # runtime unknown-icon error names the fix.
    class IconsTest < Minitest::Test
      def test_suggest_bridges_the_reversed_compound_renames
        assert_equal "circle-alert", Icons.suggest(:"alert-circle", %w[circle-alert circle-x])
        assert_equal "circle-x", Icons.suggest("x-circle", %w[circle-alert circle-x])
      end

      def test_suggest_falls_back_to_edit_distance
        assert_equal "circle-alert", Icons.suggest("cirle-alert", %w[circle-alert circle-x])
      end

      def test_suggest_tolerates_underscores_and_returns_nil_when_nothing_is_close
        assert_equal "circle-alert", Icons.suggest(:alert_circle, %w[circle-alert])
        assert_nil Icons.suggest("zzzz", %w[circle-alert])
      end

      def test_fetch_names_the_closest_icon_in_the_unknown_error
        Dir.mktmpdir("icons") do |dir|
          File.write(File.join(dir, "circle-alert.svg"), %(<path d="M0 0"/>))
          set = Icons::FileSet.new(dir: dir)

          error = assert_raises(ArgumentError) { set.fetch(:"alert-circle") }

          assert_includes error.message, %(did you mean :"circle-alert"?)
        end
      end

      def test_fetch_stays_terse_when_nothing_is_close
        Dir.mktmpdir("icons") do |dir|
          File.write(File.join(dir, "circle-alert.svg"), "<path/>")
          set = Icons::FileSet.new(dir: dir)

          error = assert_raises(ArgumentError) { set.fetch(:zzzz) }

          refute_includes error.message, "did you mean"
        end
      end
    end
  end
end
