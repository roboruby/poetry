# frozen_string_literal: true

require "test_helper"
require "herb"
require "herb/analysis/render_analyzer"

# The render-graph dogfood (`herb actionview check`, as a test): every
# static `render` in the docs site resolves to a partial on disk, and every
# partial on disk is reachable. Both lists carry a reviewed allowlist with
# the DesignLintTest discipline - an allowlisted entry that stops appearing
# FAILS the run, so the ledger cannot go stale.
#
# The analysis runs in the test process. Up to Herb 0.10 it ran in a
# subprocess, because the analyzer re-entered Bundler while it worked and
# rewrote $LOAD_PATH under the parallel test workers; from 0.11 it leaves
# the load path alone.
class RenderGraphTest < ActiveSupport::TestCase
  # Render calls the analyzer reads out of code SAMPLES (heredoc strings in
  # a guide page), not real renders.
  UNRESOLVED_SAMPLES = {
    [ "app/views/poetry/docs/docs/testing.html.erb", "settings/notifications" ] =>
      "the Testing guide's ActionView::TestCase sample renders a host partial that does not exist here",
    [ "app/views/poetry/docs/docs/agui.html.erb", "assistant/item" ] =>
      "the AG-UI guide's page sample renders the host's own message partial",
    [ "app/views/poetry/docs/docs/agui.html.erb", "assistant/row" ] =>
      "the AG-UI guide's stream-action sample renders the host's own row partial",
    [ "app/views/poetry/docs/docs/agui.html.erb", "assistant/activity" ] =>
      "the AG-UI guide's activity sample renders the host's own activity partial"
  }.freeze

  # Partials nothing in app/views renders by name.
  UNUSED_PARTIALS = {
    "kaminari/paginator" => "Kaminari theme partial - the gem renders it by convention",
    "poetry/docs/landing/components_flyout" => "parked mega-flyout (32c34a0); the Components nav link points at the catalog head"
  }.freeze

  test "every static render resolves and every partial is reachable" do
    report = analyze

    unresolved = report.fetch(:unresolved)
    unexpected = unresolved - UNRESOLVED_SAMPLES.keys
    stale = UNRESOLVED_SAMPLES.keys - unresolved
    assert_empty unexpected, "render calls that resolve to no partial on disk: #{unexpected.inspect}"
    assert_empty stale, "allowlisted unresolved samples that no longer appear (drop them from the ledger): #{stale.inspect}"

    unused = report.fetch(:unused)
    unexpected = unused - UNUSED_PARTIALS.keys
    stale = UNUSED_PARTIALS.keys - unused
    assert_empty unexpected, "partials nothing renders (delete, or allowlist with a reason): #{unexpected.inspect}"
    assert_empty stale, "allowlisted unused partials that are now rendered (drop them from the ledger): #{stale.inspect}"
  end

  private

  def analyze
    root = Poetry::Docs.root.to_s
    result = Herb::Analysis::RenderAnalyzer.new(root).analyze

    {
      unresolved: result.unresolved.map { |call| [ call[:file].to_s.delete_prefix("#{root}/"), call[:partial] ] },
      unused: result.unused.map(&:first)
    }
  end
end
