# frozen_string_literal: true

require "test_helper"

module Poetry
  module Core
    class Tokens
      class ContrastGateTest < Minitest::Test
        def setup
          @tokens = Tokens.load
          @gate = ContrastGate.new(@tokens)
        end

        # The gate itself: the shipped theme clears every locked pair
        # in both modes. This is the CI contrast gate - a token edit that
        # regresses any pair below its locked class fails the build here.
        def test_shipped_theme_has_no_contrast_violations
          assert_empty @gate.violations.map(&:to_s)
        end

        def test_every_foreground_role_is_gated_in_both_modes
          assert_empty @gate.ungated_foregrounds,
                       "every *-foreground token must appear in the ledger for every mode"
        end

        def test_aaa_locked_pairs_actually_clear_seven_to_one
          aaa = @gate.results.select { |r| r.lock == :aaa }

          refute_empty aaa
          aaa.each { |r| assert_operator r.ratio, :>=, 7.0, r.to_s }
        end

        def test_aa_exceptions_are_the_locked_explicit_list
          # The reviewed exception ledger - exceptions surface explicitly;
          # if this list changes, the change must be deliberate.
          expected = [
            %w[light muted-foreground_on_muted],
            %w[light muted-foreground_on_background],
            %w[light white_on_destructive],
            %w[dark muted-foreground_on_muted],
            %w[dark white_on_destructive/60%_over_background],
            %w[dark sidebar-primary-foreground_on_sidebar-primary]
          ].sort

          actual = @gate.results
                        .select { |r| r.lock == :aa }
                        .map { |r| [r.mode, r.label.tr(" ", "_")] }.sort

          assert_equal expected, actual
        end

        def test_dark_destructive_is_measured_as_the_rendered_composite
          composite = @gate.results.find { |r| r.mode == "dark" && r.label.include?("destructive") }

          assert_in_delta 6.48, composite.ratio, 0.05
          # And the reason the composite is the honest pair: solid dark
          # destructive under white text would fail AA outright.
          solid = Color::WHITE.contrast_ratio(@tokens.color("dark", "destructive"))

          assert_operator solid, :<, 4.5
        end

        # The gate fails on a seeded regression.
        def test_gate_fails_on_a_seeded_regression
          data = JSON.parse(File.read(Tokens.default_path))
          # Regression: light primary-foreground repainted almost equal to primary.
          data["color"]["light"]["primary-foreground"]["$value"]["components"] = [0.25, 0.0, 0.0]
          gate = ContrastGate.new(Tokens.new(data))
          violations = gate.violations.map(&:to_s)

          refute_empty violations
          assert(violations.any? { |v| v.include?("primary-foreground on primary") })
        end

        def test_gate_fails_when_an_aaa_pair_slips_to_merely_aa
          data = JSON.parse(File.read(Tokens.default_path))
          # foreground lightened: still AA-readable (~5:1) but below its AAA lock.
          data["color"]["light"]["foreground"]["$value"]["components"] = [0.53, 0.0, 0.0]
          gate = ContrastGate.new(Tokens.new(data))

          assert(gate.violations.any? { |v| v.lock == :aaa && v.label == "foreground on background" },
                 "an AAA-locked pair regressing to AA must be a violation")
        end
      end
    end
  end
end
