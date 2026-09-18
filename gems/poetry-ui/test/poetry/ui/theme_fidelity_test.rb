# frozen_string_literal: true

require "test_helper"
require "poetry/ui/theme_fidelity"

module Poetry
  module Ui
    # The theme fidelity contract on two small stylesheets: the parse, the
    # diff between a source and a port, and the reconciliation of that diff
    # against a record.
    class ThemeFidelityTest < ActiveSupport::TestCase
      UPSTREAM = <<~CSS
        /* the source */
        .cn-button { @apply inline-flex gap-2; color: red; }
        .dark .cn-card { @apply bg-black; }
      CSS

      POETRY = <<~CSS
        .cn-button {
          @apply inline-flex;
          color: blue;
        }
        .cn-badge { @apply px-2; }
      CSS

      test "the diff names the selectors only one side has and each shared selector's changes" do
        diff = ThemeFidelity.diff(ThemeFidelity.parse_css(UPSTREAM), ThemeFidelity.parse_css(POETRY))

        assert_equal ["[dark] .dark .cn-card"], diff["missing_selectors"]
        assert_equal [".cn-badge"], diff["poetry_selectors"]
        assert_equal({ ".cn-button" => { "dropped" => ["gap-2"], "raw_dropped" => ["color: red"],
                                         "raw_added" => ["color: blue"] } }, diff["rules"])
      end

      test "a matching record with reasons reconciles clean" do
        diff = ThemeFidelity.diff(ThemeFidelity.parse_css(UPSTREAM), ThemeFidelity.parse_css(POETRY))
        recorded = {
          "missing_selectors" => { "list" => ["[dark] .dark .cn-card"], "reason" => "no dark card" },
          "poetry_selectors" => { "list" => [".cn-badge"], "reason" => "an extra" },
          "rules" => { ".cn-button" => { "dropped" => ["gap-2"], "raw_dropped" => ["color: red"],
                                         "raw_added" => ["color: blue"], "reason" => "our own gap" } }
        }
        findings = []
        ThemeFidelity.send(:verify_selector_lists, "amber", diff, recorded, findings)
        ThemeFidelity.send(:verify_rules, "amber", diff, recorded, findings)

        assert_empty findings
      end

      test "an unrecorded, a stale and an unreasoned deviation each read as a finding" do
        diff = ThemeFidelity.diff(ThemeFidelity.parse_css(UPSTREAM), ThemeFidelity.parse_css(POETRY))
        recorded = {
          "poetry_selectors" => { "list" => [".cn-badge", ".cn-gone"] },
          "rules" => { ".cn-button" => { "dropped" => %w[gap-2 shadow], "raw_added" => ["color: blue"] },
                       ".cn-old" => { "added" => ["p-2"], "reason" => "stale" } }
        }
        findings = []
        ThemeFidelity.send(:verify_selector_lists, "amber", diff, recorded, findings)
        ThemeFidelity.send(:verify_rules, "amber", diff, recorded, findings)

        assert_includes findings,
                        "amber: missing selectors [dark] .dark .cn-card is not recorded - add it with a reason"
        assert_includes findings, "amber: recorded poetry selectors .cn-gone no longer differs - stale entry"
        assert_includes findings, "amber: poetry selectors needs a reason"
        assert_includes findings, "amber: .cn-button raw_dropped not recorded: color: red"
        assert_includes findings, "amber: .cn-button recorded dropped now stale: shadow"
        assert_includes findings, "amber: .cn-button needs a reason"
        assert_includes findings, "amber: recorded deviation for .cn-old no longer exists - stale entry"
      end
    end
  end
end
