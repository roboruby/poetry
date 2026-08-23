# frozen_string_literal: true

# The block preview endpoint: GET /blocks/<name> renders one
# block template (lib/generators/poetry/block/templates/<name>.html.erb)
# inside the component_preview layout - the same compiled-Tailwind +
# live-Stimulus page the preview rig drives. The browser tiers walk these
# pages (axe + goldens), so every shipped block is held to the same
# rendered-truth gates as the component previews.
class BlocksController < ApplicationController
  TEMPLATES = "lib/generators/poetry/block/templates"

  def show
    path = Poetry::Ui.root.join(TEMPLATES, "#{params[:name]}.html.erb")
    raise ActionController::RoutingError, "unknown block #{params[:name]}" unless path.exist?

    render inline: path.read, layout: "component_preview"
  end
end
