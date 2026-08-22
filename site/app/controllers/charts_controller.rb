class ChartsController < ApplicationController
  include MarkdownMirror

  def show
    @entry = DocsCatalog.find("charts", params[:slug])
    raise ActionController::RoutingError, "unknown chart #{params[:slug]}" unless @entry

    @examples = helpers.docs_examples_for("charts", @entry.slug)
    render template: "docs/page"
  end

  private

  def markdown_mirror
    entry = DocsCatalog.find("charts", params[:slug])
    raise ActionController::RoutingError, "unknown chart #{params[:slug]}" unless entry

    DocsMarkdown.example_page(entry)
  end
end
