class DocsController < ApplicationController
  include Pagy::Method

  def index
  end

  def installation
  end

  def editors
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

  def pagination
    @entry = DocsCatalog.docs.find { |entry| entry.slug == "pagination" }
    @examples = helpers.docs_examples_for("docs", "pagination")

    # One shared collection drives all three live navs: every gem reads the
    # same ?page= param, so clicking any nav pages them together. All three
    # adapters here are real poetry:pagination output (committed app code).
    page = params.fetch(:page, 3).to_i.clamp(1, 12)
    items = (1..120).to_a
    @kaminari_items = Kaminari.paginate_array(items).page(page).per(10)
    @pagy, _pagy_items = pagy(:offset, items, page: page, limit: 10)
    @will_paginate_items = WillPaginate::Collection.create(page, 10, items.size) do |pager|
      pager.replace(items[pager.offset, pager.per_page])
    end

    render template: "docs/page"
  end

  def forms
    @entry = DocsCatalog.docs.find { |entry| entry.slug == "forms" }
    @examples = helpers.docs_examples_for("docs", "forms")
    render template: "docs/page"
  end

  def optimistic_forms
    @entry = DocsCatalog.docs.find { |entry| entry.slug == "optimistic-forms" }
    @examples = helpers.docs_examples_for("docs", "optimistic-forms")
    render template: "docs/page"
  end

  # The live demo endpoints. The server contract on display:
  # success answers 204 - never a redirect (a redirect under morph
  # refreshes is a full reload and defeats the optimism); rejection
  # answers 422 so the client reconciles via morph refresh. Favorite
  # state rides the session - the morph after a rejection renders truth.
  def optimistic_favorite
    session[:docs_favorite] = params[:favorite] == "true"
    head :no_content
  end

  def optimistic_rejected
    flash[:alert] = "The server rejected this one on purpose - watch the morph put truth back."
    head :unprocessable_entity
  end
end
