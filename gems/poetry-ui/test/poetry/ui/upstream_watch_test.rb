# frozen_string_literal: true

require "test_helper"
require "poetry/ui/upstream_watch"

module Poetry
  module Ui
    # The report-only upstream watch: pure token/diff mechanics. The rake
    # tasks (upstream:pin / upstream:watch) need a real checkout and stay
    # manual; everything they compute is exercised here on fixtures.
    class UpstreamWatchTest < ActiveSupport::TestCase
      TSX = <<~TSX
        import { cn } from "@/lib/utils"
        const buttonVariants = cva(
          "inline-flex items-center rounded-md",
          { variants: { size: { sm: 'h-8 px-3' } } }
        )
        const label = `gap-${size} shrink-0`
      TSX

      def test_extract_tokens_pulls_every_string_literal_flavor
        tokens = UpstreamWatch.extract_tokens(TSX)

        assert_includes tokens, "inline-flex"
        assert_includes tokens, "rounded-md"
        assert_includes tokens, "h-8", "single-quoted variant strings are scanned"
        assert_includes tokens, "shrink-0", "backtick templates are scanned"
        refute_includes tokens, "${size}", "interpolations are blanked, not tokenized"
        assert_equal tokens, tokens.uniq.sort, "deduped and sorted"
      end

      def test_diff_reports_added_removed_and_changed_families
        old_manifest = {
          "families" => { "ui/button" => %w[flex gap-2], "ui/badge" => %w[rounded] },
          "watched_files" => { "typeset.css" => "abc" }
        }
        current = {
          "families" => { "ui/button" => %w[flex gap-4], "ui/marker" => %w[border] },
          "watched_files" => { "typeset.css" => "def" }
        }

        diff = UpstreamWatch.diff(old_manifest, current)

        assert_equal ["ui/marker"], diff[:added_families]
        assert_equal ["ui/badge"], diff[:removed_families]
        assert_equal({ added: ["gap-4"], removed: ["gap-2"] }, diff[:changed]["ui/button"])
        assert_equal ["typeset.css"], diff[:watched_changed]
        assert UpstreamWatch.drift?(diff)
      end

      def test_identical_manifests_report_no_drift
        manifest = { "families" => { "ui/button" => %w[flex] }, "watched_files" => {} }

        diff = UpstreamWatch.diff(manifest, manifest)

        refute UpstreamWatch.drift?(diff)
        assert_equal ["No upstream drift since the pin."], UpstreamWatch.format_report(diff)
      end

      def test_verbatim_violations_flag_changed_and_removed_claimed_families
        diff = { added_families: [], removed_families: ["ui/kbd"],
                 changed: { "ui/typeset" => { added: ["x"], removed: [] } }, watched_changed: [] }

        violations = UpstreamWatch.verbatim_violations(diff, families: ["ui/typeset", "ui/kbd", "ui/button"])

        assert_equal ["ui/typeset", "ui/kbd"], violations
      end

      def test_format_report_names_families_and_caps_tokens
        diff = { added_families: ["ui/marker"], removed_families: [],
                 changed: { "ui/button" => { added: ("a".."z").map { |c| "tok-#{c}" }, removed: [] } },
                 watched_changed: ["typeset.css"] }

        report = UpstreamWatch.format_report(diff, roster: ["button"], token_cap: 3).join("\n")

        assert_includes report, "NEW upstream family: ui/marker (not ported)"
        assert_includes report, "CHANGED: ui/button (ported)"
        assert_includes report, "(+23 more)", "token cap keeps the report readable"
        assert_includes report, "CHANGED watched file: typeset.css"
      end
    end
  end
end
