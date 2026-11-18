# frozen_string_literal: true

require "test_helper"
require "tmpdir"
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

      def test_hook_trees_are_watched_file_by_file
        Dir.mktmpdir do |root|
          hook = File.join(root, "packages/react/src/message-scroller")
          FileUtils.mkdir_p(hook)
          File.write(File.join(hook, "use-controller.ts"), "if (scrolledUp) release()\n")
          pinned = UpstreamWatch.build_manifest(root, pin: "abc", generated_at: "2026-10-28")

          assert pinned["watched_files"].key?("packages/react/src/message-scroller/use-controller.ts")

          # A guard added to the hook carries no new string literal: only the digest moves.
          File.write(File.join(hook, "use-controller.ts"), "if (scrolledUp && atEnd) release()\n")
          File.write(File.join(hook, "geometry.ts"), "export const EPSILON = 0.5\n")
          diff = UpstreamWatch.diff(pinned, UpstreamWatch.build_manifest(root, pin: nil, generated_at: nil))

          assert_equal ["packages/react/src/message-scroller/use-controller.ts"], diff[:watched_changed]
          assert_equal ["packages/react/src/message-scroller/geometry.ts"], diff[:watched_added]
          assert UpstreamWatch.drift?(diff)
          assert_includes UpstreamWatch.format_report(diff).join("\n"),
                          "CHANGED watched file: packages/react/src/message-scroller/use-controller.ts " \
                          "(ported: poetry-core message_scroller_controller.js)"
        end
      end

      def test_a_watched_file_gone_upstream_is_reported_removed
        diff = UpstreamWatch.diff({ "families" => {}, "watched_files" => { "packages/react/src/a.ts" => "abc" } },
                                  { "families" => {}, "watched_files" => {} })

        assert_equal ["packages/react/src/a.ts"], diff[:watched_removed]
        assert_includes UpstreamWatch.format_report(diff), "REMOVED watched file: packages/react/src/a.ts"
      end

      def test_verbatim_violations_flag_changed_and_removed_claimed_families
        diff = { added_families: [], removed_families: ["ui/kbd"],
                 changed: { "ui/typeset" => { added: ["x"], removed: [] } }, watched_changed: [],
                 watched_added: [], watched_removed: [] }

        violations = UpstreamWatch.verbatim_violations(diff, families: ["ui/typeset", "ui/kbd", "ui/button"])

        assert_equal ["ui/typeset", "ui/kbd"], violations
      end

      def test_format_report_names_families_and_caps_tokens
        diff = { added_families: ["ui/marker"], removed_families: [],
                 changed: { "ui/button" => { added: ("a".."z").map { |c| "tok-#{c}" }, removed: [] } },
                 watched_changed: ["typeset.css"], watched_added: [], watched_removed: [] }

        report = UpstreamWatch.format_report(diff, roster: ["button"], token_cap: 3).join("\n")

        assert_includes report, "NEW upstream family: ui/marker (not ported)"
        assert_includes report, "CHANGED: ui/button (ported)"
        assert_includes report, "(+23 more)", "token cap keeps the report readable"
        assert_includes report, "CHANGED watched file: typeset.css"
      end
    end
  end
end
