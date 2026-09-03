# frozen_string_literal: true

require_relative "poetry/version"

# The library proper, loaded together: the engine and component DSL
# (poetry-core), the components (poetry-ui), and the default icon set
# (poetry-lucide). Each is a hard runtime dependency; the opt-in gems
# (poetry-charts, poetry-agent, poetry-extract, poetry-simple_form) are
# added by the host on their own.
require "poetry/core"
require "poetry/ui"
require "poetry/lucide"

# The Poetry namespace, shared by every gem in the family. The umbrella
# adds nothing to it beyond {VERSION}: one `gem "poetry"` line installs the
# library proper, and the sibling gems own every constant beneath it.
module Poetry
end
