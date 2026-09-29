# frozen_string_literal: true

require "reactionview"

# The ReActionView legs: POETRY_REACTIONVIEW names what the host switches on.
#
#   engine - every HTML template compiles through ReActionView, its
#            validators raising
#   server - the same, with slots in server mode
#   client - the same, with slots in client mode
#
# The components sit outside this host's root, so ReActionView treats their
# templates as a gem's, the way it does in a real host. Its default for those
# is to fall back to Rails' own ERB handler when a compile fails, which would
# turn a broken template into a quiet pass here, so the legs compile them
# with nothing rescued.
mode = ENV.fetch("POETRY_REACTIONVIEW")

unless %w[engine server client].include?(mode)
  abort "POETRY_REACTIONVIEW is #{mode.inspect}: set it to engine, server or client"
end

ReActionView.configure do |config|
  config.intercept_erb = true
  config.external_template_mode = :compile
  config.validation_mode = :raise
  config.slots = mode.to_sym unless mode == "engine"
  config.debug_mode = false
  config.dev_server = false
  config.instrumentation.enabled = false
end
