# frozen_string_literal: true

require "zeitwerk"
require_relative "poetry/version"

loader = Zeitwerk::Loader.for_gem
loader.ignore("#{__dir__}/poetry/version.rb")
loader.setup

module Poetry
  class Error < StandardError; end
end

# poetry-core supplies the Rails engine, the component DSL, and the primitives.
# It is wired as a dev path dependency until it is published and added to the
# gemspec; the rescue lets the umbrella load standalone until then.
begin
  require "poetry/core"
rescue LoadError
  # poetry-core is not installed yet — the umbrella still loads on its own.
end

# poetry-agent supplies the MCP server and the WebMCP runtime; same dev-path
# arrangement until published.
begin
  require "poetry/agent"
rescue LoadError
  # poetry-agent is not installed yet — the umbrella still loads without it.
end
