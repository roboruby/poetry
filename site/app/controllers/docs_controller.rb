class DocsController < ApplicationController
  include MarkdownMirror
  include Pagy::Method

  # Guide pages that ride the shared docs/page template: their mirrors are
  # the generic gallery projection (header + example sources).
  EXAMPLE_GUIDES = %w[typography deferred pagination forms optimistic_forms].freeze

  def index
  end

  # The root llms.txt: the whole site indexed for agents, served at the
  # conventional root address.
  def llms
    render plain: DocsMarkdown.site_index, content_type: "text/markdown"
  end

  def installation
  end

  def editors
  end

  def testing
  end

  def accessibility
  end

  def caching
  end

  def stable_ids
  end

  def data_table
  end

  def mcp
  end

  # The per-gem library pages (/libraries/:slug) - templates live under
  # docs/libraries/, named by the underscored slug.
  def library
    @entry = library_entry
    render template: "docs/libraries/#{@entry.slug.tr("-", "_")}"
  end

  # The icon-set pages (/icons/:slug).
  def icon_set
    @entry = icon_entry
    render template: "docs/icons/#{@entry.slug.tr("-", "_")}"
  end


  def recipes
    @recipes = Poetry::Ui.recipe_items.summaries
  end

  # The human half of the skills surface: cards projected from the same
  # SkillCatalog the discovery index serves, with install commands built
  # on the live origin.
  def agent_skills
    @skills = SkillCatalog.sets.map do |name, files|
      { name: name, description: SkillCatalog.description(files),
        files: files.keys.sort, single: SkillCatalog.single_file?(files),
        payload_path: SkillCatalog.payload_path(name, files) }
    end
  end

  def agent
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

  # The optimistic-form live demo endpoints. The server contract on display:
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

  private

  # One dispatch for every guide page's mirror. `installation` serves the
  # curated agent instructions - the SAME file the static /installation.md
  # fast-path serves (public/), so the suffix and the Accept header agree.
  def markdown_mirror
    case action_name
    when "index" then DocsMarkdown.site_index
    when "installation" then Rails.public_path.join("installation.md").read
    when "theming" then DocsMarkdown.theming(guide_entry("theming"))
    when "editors" then DocsMarkdown.editors(guide_entry("editors"))
    when "testing" then DocsMarkdown.testing(guide_entry("testing"))
    when "accessibility" then DocsMarkdown.accessibility(guide_entry("accessibility"))
    when "caching" then DocsMarkdown.caching(guide_entry("caching"))
    when "stable_ids" then DocsMarkdown.stable_ids(guide_entry("stable-ids"))
    when "data_table" then DocsMarkdown.data_table(guide_entry("data-table"))
    when "mcp" then DocsMarkdown.mcp(guide_entry("mcp"))
    when "library" then DocsMarkdown.public_send("library_#{library_entry.slug.tr('-', '_')}", library_entry)
    when "icon_set" then DocsMarkdown.public_send("icons_#{icon_entry.slug}", icon_entry)
    when "recipes" then DocsMarkdown.recipes(guide_entry("recipes"))
    when "agent" then DocsMarkdown.agent(guide_entry("agent"))
    when "agent_skills" then DocsMarkdown.agent_skills(guide_entry("agent-skills"), base_url: request.base_url)
    when *EXAMPLE_GUIDES then DocsMarkdown.example_page(guide_entry(action_name.tr("_", "-")))
    end
  end

  # Entry lookups shared by the actions and the markdown-mirror
  # before_action (which runs before the action sets @entry); unknown
  # slugs 404 through the concern's RoutingError contract.
  def library_entry
    DocsCatalog.libraries.find { |e| e.slug == params[:slug] } ||
      raise(ActionController::RoutingError, "unknown library")
  end

  def icon_entry
    DocsCatalog.icons.find { |e| e.slug == params[:slug] } ||
      raise(ActionController::RoutingError, "unknown icon set")
  end

  def guide_entry(slug)
    DocsCatalog.docs.find { |entry| entry.slug == slug }
  end
end
