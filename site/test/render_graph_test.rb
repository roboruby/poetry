# frozen_string_literal: true

require "test_helper"
require "json"
require "open3"

# The render-graph dogfood (`herb actionview check`, as a test): every
# static `render` in the docs site resolves to a partial on disk, and every
# partial on disk is reachable. Both lists carry a reviewed allowlist with
# the DesignLintTest discipline - an allowlisted entry that stops appearing
# FAILS the run, so the ledger cannot go stale.
#
# The analysis runs in a SUBPROCESS: Herb::ActionView::RenderAnalyzer#analyze
# re-enters Bundler while it works (its Ruby-side reference scan), which
# rewrites $LOAD_PATH in the calling process - in the parallel test workers
# that made every later `require` of a Rails dependency fail. Isolating it
# keeps the gate and leaves the workers alone.
class RenderGraphTest < ActiveSupport::TestCase
  # Render calls the analyzer reads out of code SAMPLES (heredoc strings in
  # a guide page), not real renders.
  UNRESOLVED_SAMPLES = {
    [ "app/views/docs/testing.html.erb", "settings/notifications" ] =>
      "the Testing guide's ActionView::TestCase sample renders a host partial that does not exist here"
  }.freeze

  # Partials nothing in app/views renders by name.
  UNUSED_PARTIALS = {
    "kaminari/paginator" => "Kaminari theme partial - the gem renders it by convention",
    "landing/components_flyout" => "parked mega-flyout (32c34a0); the Components nav link points at the catalog head"
  }.freeze

  ANALYSIS = <<~'RUBY'
    require "herb"
    require "herb/action_view/render_analyzer"
    require "json"
    result = Herb::ActionView::RenderAnalyzer.new(Dir.pwd).analyze
    puts JSON.generate(
      unresolved: result.unresolved.map { |call| [ call[:file].delete_prefix("#{Dir.pwd}/"), call[:partial] ] },
      unused: result.unused.map(&:first)
    )
  RUBY

  test "every static render resolves and every partial is reachable" do
    report = analyze

    unresolved = report.fetch("unresolved")
    unexpected = unresolved - UNRESOLVED_SAMPLES.keys
    stale = UNRESOLVED_SAMPLES.keys - unresolved
    assert_empty unexpected, "render calls that resolve to no partial on disk: #{unexpected.inspect}"
    assert_empty stale, "allowlisted unresolved samples that no longer appear (drop them from the ledger): #{stale.inspect}"

    unused = report.fetch("unused")
    unexpected = unused - UNUSED_PARTIALS.keys
    stale = UNUSED_PARTIALS.keys - unused
    assert_empty unexpected, "partials nothing renders (delete, or allowlist with a reason): #{unexpected.inspect}"
    assert_empty stale, "allowlisted unused partials that are now rendered (drop them from the ledger): #{stale.inspect}"
  end

  private

  def analyze
    out, err, status = Open3.capture3("bundle", "exec", "ruby", "-e", ANALYSIS, chdir: Rails.root.to_s)
    assert status.success?, "render analysis failed:\n#{err}"

    JSON.parse(out.lines.last)
  end
end
