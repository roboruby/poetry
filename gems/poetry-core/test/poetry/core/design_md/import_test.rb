# frozen_string_literal: true

require "test_helper"

module Poetry
  module Core
    class DesignMd
      class ImportTest < Minitest::Test
        def import
          @import ||= Import.new(tokens: Tokens.load)
        end

        def fixture_plan(name, force: false)
          import.plan(DesignMd.parse(File.read(File.expand_path("../../../fixtures/design_md/#{name}", __dir__))),
                      force: force)
        end

        def doc_with(light_colors)
          { "colors" => { "light" => light_colors, "dark" => {} }, "unknown" => { "colors" => {} } }
        end

        def test_exact_roles_aliases_and_on_pattern_map
          plan = import.plan(doc_with(
            "primary" => Tokens::Color.parse("#2F5D50"),
            "brand-glow" => nil # never present after parse; exercised via fixtures
          ).tap { |doc| doc["colors"]["light"].compact! })

          assert_equal([%w[primary primary]], plan.applied.map { |a| [a.role, a.from] })
        end

        def test_unmapped_names_are_dropped_with_the_reason_never_guessed
          plan = import.plan(doc_with("ink" => Tokens::Color.parse("#1A1C1E")))

          assert_empty plan.applied
          drop = plan.dropped.first

          assert_equal "ink", drop.name
          assert_match(/never guessed/, drop.reason)
        end

        def test_on_pattern_without_a_foreground_token_is_dropped
          plan = import.plan(doc_with("on-danger" => Tokens::Color.parse("#ffffff")))

          assert_empty plan.applied
          assert_match(/destructive-foreground/, plan.dropped.first.reason)
        end

        def test_failing_pair_is_dropped_with_a_deterministic_suggestion
          # A light-gray primary under the default near-white
          # primary-foreground cannot hold AA - the gate drops it and walks
          # L away from the foreground for the suggestion.
          plan = import.plan(doc_with("primary" => Tokens::Color.parse("oklch(0.8 0.05 250)")))

          assert_empty plan.overrides["light"]
          failure = plan.contrast.find { |result| !result.pass }

          refute_nil failure
          assert_match(/--primary: oklch\(/, failure.suggestion)
          drop = plan.dropped.find { |d| d.name == "primary" }

          assert_match(/fails AA/, drop.reason)
        end

        def test_force_ships_the_failing_pair_and_says_so
          plan = import.plan(doc_with("primary" => Tokens::Color.parse("oklch(0.8 0.05 250)")), force: true)

          assert plan.overrides["light"].key?("primary"), "force keeps the failing override"
          assert plan.contrast.any?(&:shipped)
          assert_match(/SHIPPED FAILING/, plan.contrast.find(&:shipped).to_s)
        end

        def test_nearest_aa_walks_lightness_with_chroma_held
          against = Tokens::Color.parse("oklch(0.985 0 0)")
          candidate = Tokens::Color.parse("oklch(0.8 0.05 250)")
          walked = import.nearest_aa(candidate, against)

          assert_operator walked.contrast_ratio(against), :>=, Import::AA
          assert_in_delta candidate.c, walked.c, 1e-9, "chroma held"
          assert_in_delta candidate.h, walked.h, 1e-9, "hue held"
          assert_operator walked.l, :<, candidate.l, "walked away from the near-white foreground"
        end

        def test_nearest_aa_returns_nil_when_no_lightness_passes
          # Against mid-gray, some low-chroma candidates cannot reach AA
          # before L leaves [0,1] on the chosen side - never invent one.
          against = Tokens::Color.parse("oklch(0.62 0 0)")

          assert_nil import.nearest_aa(Tokens::Color.parse("oklch(0.63 0 0)"), against)
        end

        def test_light_only_import_pins_dark_to_the_shipped_defaults
          plan = import.plan(doc_with("primary" => Tokens::Color.parse("#2F5D50")))

          assert_equal ["primary"], plan.pins.keys
          assert_equal Tokens.load.color("dark", "primary").css, plan.pins["primary"].css
        end

        def test_front_matter_fixture_maps_five_roles_and_passes_the_gate
          plan = fixture_plan("front-matter-brand.DESIGN.md")

          assert_equal({ "primary" => "primary", "primary-foreground" => "on-primary",
                         "background" => "background", "card" => "surface", "foreground" => "text" },
                       plan.applied.to_h { |a| [a.role, a.from] })
          assert plan.contrast.all?(&:pass), "every touched ledger pair holds AA on the merged set"
          assert_equal plan.overrides["light"].keys.sort, plan.pins.keys.sort
          assert_equal "4px", plan.radius
          assert_equal %w[brand-glow negative positive], plan.dropped.map(&:name).sort
        end

        def test_prose_study_fixture_demonstrates_drop_and_the_aa_door
          plan = fixture_plan("prose-study.design.md")

          # accent maps (exact role) but fails AA against the default
          # accent-foreground - dropped with the L-walk suggestion.
          assert_empty plan.overrides["light"]
          failure = plan.contrast.find { |result| !result.pass }

          assert_equal "accent-foreground on accent", failure.label
          assert_match(/--accent: oklch\(/, failure.suggestion)
          assert_equal %w[accent accent-hover ink mist paper], plan.dropped.map(&:name).sort
          assert_match(/font-family: Inter/, plan.typography_note)
        end
      end
    end
  end
end
