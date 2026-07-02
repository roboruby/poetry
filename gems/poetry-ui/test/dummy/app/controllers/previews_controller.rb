# frozen_string_literal: true

# The dummy host's preview endpoint: GET /previews/<preview_name>/<example>
# (e.g. /previews/poetry/ui/button/default) renders one preview example via
# ViewComponent's stock preview machinery - the exact render path
# render_preview uses in unit tests - inside the component_preview layout,
# which loads the compiled Tailwind build and poetry's Stimulus controllers.
# The browser tasks (rake test:accessibility / test:visual) drive these URLs.
class PreviewsController < ApplicationController
  include ViewComponent::PreviewActions
end
