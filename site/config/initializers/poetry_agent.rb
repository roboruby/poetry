# frozen_string_literal: true

# poetry-agent: the WebMCP runtime's delivery settings. Tokens enable the
# document.modelContext API for real visitors during the browser origin
# trials (Chrome and Edge issue separate tokens); with none set the
# middleware is a pass-through and local development relies on the browser
# flag (chrome://flags/#enable-webmcp-testing). Tools stay opt-in per
# rendered instance regardless.
Poetry::Agent.configure do |config|
  config.origin_trial_tokens = ENV.fetch("WEBMCP_ORIGIN_TRIAL_TOKENS", "").split(",").map(&:strip).reject(&:empty?)
end
