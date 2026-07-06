class ChartsController < ApplicationController
  def show
    @entry = DocsCatalog.find("charts", params[:slug])
    raise ActionController::RoutingError, "unknown chart #{params[:slug]}" unless @entry

    @examples = helpers.docs_examples_for("charts", @entry.slug)
    render template: "docs/page"
  end
end
