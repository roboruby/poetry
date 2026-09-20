# frozen_string_literal: true

# The dummy host's preview endpoint: GET /previews/<preview_name>/<example>
# (e.g. /previews/poetry/charts/container/default) renders one preview
# example via ViewComponent's stock preview machinery inside the
# component_preview layout. The browser tasks (rake test:accessibility /
# test:visual) drive these URLs - the poetry-ui rig, charts-sized.
class PreviewsController < ApplicationController
  include ViewComponent::PreviewActions
end
