class DocsController < ApplicationController
  def index
  end

  def installation
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

  def deferred
    @entry = DocsCatalog.docs.find { |entry| entry.slug == "deferred" }
    @examples = helpers.docs_examples_for("docs", "deferred")
    render template: "docs/page"
  end

  # One fragment serves every demo frame: Turbo sends the requesting frame
  # id and the response echoes it. The pause makes the Skeleton visible.
  def deferred_fragment
    sleep 0.5 unless Rails.env.test?
    render layout: false
  end
end
