class DocsController < ApplicationController
  def index
  end

  def theming
  end

  # Rides the shared docs/page template: the recipes are ordinary example
  # partials under examples/docs/typography, so Preview/Code tabs, Rouge,
  # and the gallery gates all apply unchanged.
  def typography
    @entry = DocsCatalog.docs.find { |entry| entry.slug == "typography" }
    @examples = helpers.docs_examples_for("docs", "typography")
    render template: "docs/page"
  end
end
