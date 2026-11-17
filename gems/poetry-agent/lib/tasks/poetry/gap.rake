# frozen_string_literal: true

# Something Poetry lacked for a task, written up as a link that opens a
# prefilled issue: `bin/rails "poetry:gap[Badge has no warning variant]"`.
# Nothing is sent; the link is printed for a person to open. KIND
# (component, variant, option, block, docs), COMPONENT, WANTED and
# WORKAROUND fill in the rest. The MCP server's report_gap tool gives an
# agent the same report.
namespace :poetry do
  desc "Print a link that reports something Poetry lacked: bin/rails \"poetry:gap[Badge has no warning variant]\""
  task :gap, [:summary] do |_task, args|
    summary = [args[:summary], *args.extras].compact.join(", ").strip
    abort %(poetry:gap: say what was missing - bin/rails "poetry:gap[Badge has no warning variant]") if summary.empty?

    puts Poetry::Agent::GapReport.new(
      summary: summary, kind: ENV.fetch("KIND", "other"), component: ENV.fetch("COMPONENT", nil),
      wanted: ENV.fetch("WANTED", nil), workaround: ENV.fetch("WORKAROUND", nil), client: "the rake task"
    )
  end
end
