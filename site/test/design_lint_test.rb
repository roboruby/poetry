# frozen_string_literal: true

require "test_helper"

# The gallery dogfood: every view and example partial in this app
# lints clean against the DesignLint AST tier - the docs site is the
# standing proof that poetry-built pages carry none of the slop the rules
# target.
#
# Skip ledger, axe-skips discipline (the ONLY mechanism, reviewed reasons):
# a key that stops producing findings FAILS the run so the ledger cannot
# go stale.
class DesignLintTest < ActiveSupport::TestCase
  DESIGN_LINT_SKIPS = {
    # The typography recipes are byte-transcribed from upstream shadcn
    # (exact upstream classes, kept deliberately); px-[0.3rem]/py-[0.2rem]
    # are upstream's own inline-code spellings, kept verbatim.
    "app/views/examples/docs/typography/_inline_code.html.erb" =>
      "upstream shadcn typography recipe, byte-transcribed - off-scale paddings are upstream's own",
    # The hero's readability scrim: the one sanctioned gradient - a
    # left-weighted, token-built scrim over the hero artwork (a
    # directional scrim over imagery is the documented exception to the
    # flat-background rule; see the comment at the scrim itself).
    "app/views/landing/show.html.erb" =>
      "hero readability scrim - deliberate token-built gradient over the artwork"
  }.freeze

  test "the docs corpus carries no design slop" do
    by_file = Dir.glob(Rails.root.join("app/views/**/*.erb")).to_h do |path|
      relative = Pathname.new(path).relative_path_from(Rails.root).to_s
      [ relative, Poetry::Core::DesignLint.lint(File.read(path), file: relative) ]
    end.reject { |_file, findings| findings.empty? }

    unexpected = by_file.reject { |file, _| DESIGN_LINT_SKIPS.key?(file) }
    stale = DESIGN_LINT_SKIPS.keys - by_file.keys

    assert_empty stale, "stale design-lint skips (no longer firing): #{stale.join(", ")}"
    assert_empty unexpected.flat_map { |_file, findings| findings.map(&:to_s) }
  end
end
