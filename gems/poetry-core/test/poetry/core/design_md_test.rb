# frozen_string_literal: true

require "test_helper"

module Poetry
  module Core
    class DesignMdTest < Minitest::Test
      TYPOGRAPHY = { "pairing" => "system sans",
                     "family" => "system-ui, -apple-system, Roboto, sans-serif" }.freeze

      def doc
        @doc ||= DesignMd.build(
          tokens: Tokens.load, theme: "default",
          details: { "typography" => TYPOGRAPHY.dup,
                     "treatment" => "the neutral shadcn-parity treatment",
                     "components_count" => 27 }
        )
      end

      def fixture(name)
        File.read(File.expand_path("../../fixtures/design_md/#{name}", __dir__))
      end

      def test_serialize_opens_with_google_labs_front_matter
        front = YAML.safe_load(DesignMd.serialize(doc)[/\A---\n(.*?)\n---\n/m, 1])

        assert_equal "alpha", front["version"]
        assert_equal "poetry default", front["name"]
        # The spec's flat colors map = light mode, so foreign-tool
        # parsers read poetry files without knowing about modes.
        assert_equal "oklch(1 0 0)", front.dig("colors", "background")
        assert_equal "oklch(0.145 0 0)", front.dig("modes", "dark", "background")
        assert_equal "6px", front.dig("rounded", "sm") # resolved px for foreign tools
        assert_equal "default", front.dig("poetry", "theme")
        assert_kind_of Array, front.dig("poetry", "contrast_policy", "aa_exceptions")
      end

      def test_serialize_emits_sections_in_the_spec_canonical_order
        headings = DesignMd.serialize(doc).scan(/^## (.+)$/).flatten

        # "Intentional deviations" renders only when the host declared any
        # - the nine gem exports stay byte-stable.
        assert_equal DesignMd::SECTIONS - ["Intentional deviations"], headings
      end

      def test_deviations_render_in_order_and_round_trip
        deviations = [{ "cn" => "*", "files" => ["app/assets/tailwind/styles/style-*.css"],
                        "reason" => "docs switcher renders all nine themes", "created" => "2026-07-18" }]
        with = DesignMd.build(
          tokens: Tokens.load, theme: "default",
          details: { "typography" => TYPOGRAPHY.dup, "treatment" => "t", "components_count" => 27 },
          deviations: deviations
        )
        md = DesignMd.serialize(with)

        assert_equal DesignMd::SECTIONS, md.scan(/^## (.+)$/).flatten
        assert_match(/docs switcher renders all nine themes/, md)
        assert_equal md, DesignMd.serialize(DesignMd.parse(md)), "deviations must round-trip byte-stable"
        assert_equal deviations, DesignMd.parse(md)["deviations"]
      end

      def test_colors_table_carries_every_role_in_both_modes
        md = DesignMd.serialize(doc)
        tokens = Tokens.load
        tokens.color_names("light").each do |name|
          row = md[/^\| #{Regexp.escape(name)} \| .+ \| .+ \|$/]

          refute_nil row, "missing colors table row for #{name}"
          assert_includes row, tokens.color("dark", name).css
        end
      end

      def test_round_trip_is_byte_stable
        md = DesignMd.serialize(doc)

        assert_equal md, DesignMd.serialize(DesignMd.parse(md))
      end

      def test_parse_recovers_the_document
        parsed = DesignMd.parse(DesignMd.serialize(doc))

        assert_equal "default", parsed["theme"]
        assert_equal "oklch(1 0 0)", parsed.dig("colors", "light", "background").css
        assert_equal "oklch(0.985 0 0)", parsed.dig("colors", "dark", "foreground").css
        assert_equal 27, parsed.dig("components", "count")
        assert_equal "system sans", parsed.dig("typography", "pairing")
        assert_empty parsed.dig("unknown", "colors")
      end

      def test_parse_walks_a_prose_study_file
        parsed = DesignMd.parse(fixture("prose-study.design.md"))
        colors = parsed.dig("colors", "light")

        # British "Colour anchor" heading, hex + rgb() bullets.
        assert_equal Tokens::Color.parse("#1A1C1E").css, colors["ink"].css
        assert_equal Tokens::Color.parse("#C8553D").css, colors["accent"].css
        assert_equal Tokens::Color.parse("rgb(226, 229, 233)").css, colors["mist"].css
        assert_equal "Inter (400/500)", parsed.dig("typography", "family")
        assert_equal "4px", parsed["radius"]
        assert_includes parsed.dig("unknown", "sections"), "Macrostructure"
      end

      def test_parse_reads_a_front_matter_file
        parsed = DesignMd.parse(fixture("front-matter-brand.DESIGN.md"))
        colors = parsed.dig("colors", "light")

        assert_equal "Aster Finance", parsed["name"]
        assert_equal Tokens::Color.parse("#2F5D50").css, colors["primary"].css
        # Section-walked table rows join the front-matter map.
        assert_equal Tokens::Color.parse("#1E7F4F").css, colors["positive"].css
        # var() refs are DROPPED into the unknown report, never guessed.
        assert_equal "var(--glow)", parsed.dig("unknown", "colors", "brand-glow")
        assert_equal "Instrument Sans, system-ui, sans-serif", parsed.dig("typography", "family")
        assert_equal "4px", parsed["radius"]
      end

      def test_parse_without_front_matter_or_sections_is_empty_not_an_error
        parsed = DesignMd.parse("Just prose, no structure at all.\n")

        assert_empty parsed.dig("colors", "light")
        assert_nil parsed["radius"]
      end
    end
  end
end
