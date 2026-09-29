# frozen_string_literal: true

# The ReActionView legs: the suite and the behaviour tier, run again in a
# host that compiles every template through ReActionView - as the engine
# alone, then with slots in server mode, then in client mode. A component
# has to render the same in all three as it does in a plain Rails host, and
# a template that stops doing so fails here.
#
# Kept out of `default`: three more runs of both suites. CI runs each mode
# as its own job; POETRY_REACTIONVIEW_MODES narrows a local run.
namespace :test do
  desc "Run the suite and the behaviour tier under ReActionView (engine, then slots in server and client mode)"
  task :reactionview do
    modes = ENV.fetch("POETRY_REACTIONVIEW_MODES", "engine server client").split

    modes.each do |mode|
      puts "reactionview: #{mode}"
      sh({ "POETRY_REACTIONVIEW" => mode, "COVERAGE" => "0" }, "bundle exec rake test test:dommy")
    end
  end
end
