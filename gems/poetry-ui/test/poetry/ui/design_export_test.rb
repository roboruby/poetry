# frozen_string_literal: true

require "test_helper"

module Poetry
  module Ui
    # The DESIGN.md export surface (N14 W1): the committed docs/design/
    # interop files must byte-match a fresh generation (the same drift
    # discipline as the registry and template-class artifacts), and the
    # roster metadata must cover exactly the shipped theme fragments.
    class DesignExportTest < Minitest::Test
      def components_count
        @components_count ||= YAML.safe_load_file(Poetry::Ui.root.join(Poetry::Core::Registry::RELATIVE_PATH))
                                  .fetch("components").size
      end

      def exports
        @exports ||= Themes.design_md_exports(components_count: components_count)
      end

      def test_theme_metadata_covers_exactly_the_shipped_fragments
        assert_equal Themes.names, Themes::DETAILS.keys.sort,
                     "themes/*.css and Themes::DETAILS must list the same roster"
      end

      def test_committed_exports_match_a_fresh_generation
        exports.each do |name, content|
          path = Poetry::Ui.root.join("docs/design/#{name}.design.md")

          assert_predicate path, :exist?, "missing export #{path} - run `bin/rake design:export_all`"
          assert_equal content, path.read,
                       "stale export docs/design/#{name}.design.md - run `bin/rake design:export_all` and commit"
        end
      end

      def test_exports_round_trip_through_parse
        exports.each_value do |content|
          assert_equal content, Poetry::Core::DesignMd.serialize(Poetry::Core::DesignMd.parse(content))
        end
      end

      def test_exports_share_tokens_and_differ_in_treatment
        fronts = exports.transform_values { |content| YAML.safe_load(content[/\A---\n(.*?)\n---\n/m, 1]) }

        # One token source across the roster (themes are treatment layers).
        colors = fronts.values.map { |front| front["colors"] }.uniq

        assert_equal 1, colors.size, "every theme export must carry the shared token palette"

        treatments = fronts.values.map { |front| front.dig("poetry", "treatment") }

        assert_equal treatments.uniq.size, treatments.size, "each theme must state its own treatment"
        assert_match(/JetBrains Mono/, fronts.dig("lyra", "poetry", "typography_pairing"))
        assert_match(/serif/i, fronts.dig("sera", "poetry", "typography_pairing"))
      end
    end
  end
end
