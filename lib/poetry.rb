# frozen_string_literal: true

require_relative "poetry/version"

# The umbrella: one `gem "poetry"` installs the library proper - the engine
# and component DSL (poetry-core), the components (poetry-ui), and the
# default icon set (poetry-lucide). Each is a hard runtime dependency; the
# opt-in gems (poetry-charts, poetry-agent, poetry-extract,
# poetry-simple_form) are added by the host on their own.
require "poetry/core"
require "poetry/ui"
require "poetry/lucide"

module Poetry
  class Error < StandardError; end
end
