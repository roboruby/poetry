# frozen_string_literal: true

require "test_helper"

module Poetry
  module Core
    class TokenImportTest < Minitest::Test
      def fixture(name)
        File.read(File.expand_path("../../fixtures/token_import/#{name}", __dir__))
      end

      # --- Figma / DTCG -------------------------------------------------

      def figma_doc
        @figma_doc ||= TokenImport.figma(JSON.parse(fixture("figma-variables.json")))
      end

      def test_figma_maps_hex_and_dtcg_color_objects_into_light_roles
        light = figma_doc.dig("colors", "light")

        assert_equal "oklch(1 0 0)", light.fetch("background").css # hex string
        assert_kind_of Tokens::Color, light.fetch("foreground") # DTCG srgb object
      end

      def test_figma_flattens_default_and_foreground_group_leaves
        light = figma_doc.dig("colors", "light")

        assert light.key?("primary"), "primary/DEFAULT collapses to the primary role"
        assert light.key?("primary-foreground"), "primary/foreground collapses to primary-foreground"
      end

      def test_figma_resolves_aliases_to_their_target_color
        light = figma_doc.dig("colors", "light")

        assert_equal light.fetch("primary").css, light.fetch("ring").css
      end

      def test_figma_separates_dark_mode_tokens
        assert_equal %w[background foreground], figma_doc.dig("colors", "dark").keys.sort
      end

      def test_figma_extracts_radius_and_ignores_non_color_tokens
        assert_equal "0.625rem", figma_doc["radius"]
        light = figma_doc.dig("colors", "light")

        refute light.key?("spacing-lg"), "dimensions are not colors"
        refute light.key?("logo"), "strings are not colors"
      end

      def test_figma_reports_unresolvable_color_tokens_as_unknown_never_guessed
        assert figma_doc.dig("unknown", "colors").key?("ghost"), "a broken alias is dropped and reported"
      end

      # --- CSS custom properties (Paper / shadcn) ----------------------

      def css_doc
        @css_doc ||= TokenImport.css_vars(fixture("paper-theme.css"))
      end

      def test_css_reads_root_as_light_and_dark_block_as_dark
        assert css_doc.dig("colors", "light").key?("background")
        assert_equal %w[background foreground], css_doc.dig("colors", "dark").keys.sort
      end

      def test_css_parses_hex_rgb_and_oklch_values
        light = css_doc.dig("colors", "light")

        assert_kind_of Tokens::Color, light.fetch("foreground")        # hex
        assert_kind_of Tokens::Color, light.fetch("muted-foreground")  # rgb()
        assert_equal "oklch(1 0 0)", light.fetch("background").css # oklch kept verbatim
      end

      def test_css_resolves_var_references
        light = css_doc.dig("colors", "light")

        assert_equal light.fetch("primary").css, light.fetch("ring").css
      end

      def test_css_extracts_radius_and_reports_non_colors
        assert_equal "0.5rem", css_doc["radius"]
        assert css_doc.dig("unknown", "colors").key?("font-sans")
      end

      def test_css_strips_the_tailwind_color_namespace_from_theme_blocks
        doc = TokenImport.css_vars(<<~CSS)
          @theme {
            --color-primary: #2563eb;
            --color-accent: oklch(0.97 0 0);
          }
        CSS
        assert doc.dig("colors", "light").key?("primary")
        assert doc.dig("colors", "light").key?("accent")
      end

      # --- dispatch + end-to-end into the AA-gated planner --------------

      def test_load_dispatches_by_extension
        json = File.expand_path("../../fixtures/token_import/figma-variables.json", __dir__)
        css = File.expand_path("../../fixtures/token_import/paper-theme.css", __dir__)

        assert TokenImport.load(json).dig("colors", "light").key?("primary")
        assert TokenImport.load(css).dig("colors", "light").key?("primary")
      end

      def test_an_imported_doc_feeds_the_existing_aa_gated_planner
        plan = DesignMd::Import.new.plan(figma_doc)

        assert_predicate plan, :any_overrides?, "a real Figma palette produces surviving token overrides"
        assert_kind_of Array, plan.contrast, "the same contrast gate runs on imported tokens"
      end
    end
  end
end
