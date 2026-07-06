class ComponentsController < ApplicationController
  def show
    @entry = DocsCatalog.find("components", params[:slug])
    raise ActionController::RoutingError, "unknown component #{params[:slug]}" unless @entry

    @examples = helpers.docs_examples_for("components", @entry.slug)
    render template: "docs/page"
  end
end
