require "test_helper"

# The install-proof smoke, now over the real shell: every page renders
# inside poetry's own Sidebar + palette + nav chrome - if any host seam
# breaks (pins, tokens, safelist, engine load), these pages surface it.
class DocsControllerTest < ActionDispatch::IntegrationTest
  test "the home page serves the poetry shell" do
    get root_url

    assert_response :success
    assert_select "[data-controller~=?]", "poetry--core--sidebar"
    assert_select "[data-slot=sidebar-menu-button]", minimum: 40, text: /./ # the registry-driven nav
    assert_select "[data-controller~=?]", "poetry--core--command"
    assert_select "[data-controller~=?]", "poetry--core--navigation-menu"
    assert_select "[data-action=?]", "click->theme#toggle"
  end

  test "a component page renders examples with preview and code tabs" do
    get "/components/button"

    assert_response :success
    assert_select "[data-slot=button]", minimum: 6
    assert_select "[data-controller~=?]", "poetry--core--tabs"
    assert_select "[data-slot=code-block]", minimum: 1 # the Rouge code tab
  end

  test "a chart page renders a finished SVG through the kernel pipeline" do
    get "/charts/area"

    assert_response :success
    assert_select "svg[data-slot=chart-svg]", 2
    assert_select "path[data-slot=chart-area]", minimum: 2
    assert_select "script[data-slot=chart-live-payload]", 1 # the legend_toggle example
  end

  test "the gallery is fully populated - every page carries at least one example" do
    # (The docs/page Empty branch covers FUTURE registry additions; since
    # the 71-agent port there is no catalog entry without examples.)
    # The three GALLERY sections only: docs guides are prose-first pages
    # (theming carries no example partials by design).
    (DocsCatalog.components + DocsCatalog.charts + DocsCatalog.demos).each do |entry|
      dir = Rails.root.join("app/views/examples/#{entry.section}/#{entry.slug}")

      assert_predicate dir.glob("_*.html.erb"), :any?, "#{entry.path} has no example partials"
    end
  end

  test "the search index is fresh and the palette serves its deep links" do
    assert_equal SearchIndex.build, JSON.parse(SearchIndex::PATH.read),
                 "stale search index - run bin/rails docs:search_index and commit"

    get root_url

    assert_select "[data-slot=command-item][data-value=?]", "/typography#headings"
    assert_select "[data-slot=command-item][data-value=?]", "/theming#the-font-pairing"
    assert_select "[data-slot=command-item]", minimum: 300 # the Reference tier is in the DOM
  end

  test "the typography guide renders the upstream recipes as examples" do
    get "/typography"

    assert_response :success
    assert_select "h1.scroll-m-20", text: /Taxing Laughter/
    assert_select "h2[id=?]", "headings" # the example anchors feed search
    assert_select "code.font-mono", minimum: 1
    assert_select "[data-controller~=?]", "poetry--core--tabs"
    assert_select "[data-slot=code-block]", minimum: 7 # every recipe ships its source
  end

  test "the installation guide documents the upgrade path and the ownership tiers" do
    get "/installation"

    assert_response :success
    assert_select "h1", text: "Installation"
    assert_select "h2[id=?]", "upgrade" # the runbook anchor feeds search
    assert_select "h2[id=?]", "ownership"
    assert_select "[data-slot=code-block]", minimum: 4 # Gemfile/install/upgrade/diff snippets
    assert_select "code.font-mono", text: /poetry:diff/
  end

  test "a block page renders the real gem template and its exact source" do
    get "/blocks/data-index"

    assert_response :success
    assert_select "[data-slot=table]", 1, "the preview renders the block live"
    assert_select "[data-slot=badge]", minimum: 4
    assert_select "[data-slot=code-block]", 1 # the code tab: the source poetry:block copies in
    assert_select "code.font-mono", text: /bin\/rails g poetry:block data-index/
  end

  test "the blocks gallery covers every registry block" do
    assert_equal %w[action-bar app-shell data-index destructive-panel page-header section-card
                    stepper top-nav],
                 DocsCatalog.blocks.map(&:slug)

    DocsCatalog.blocks.each do |entry|
      get entry.path

      assert_response :success, "#{entry.path} must render"
    end
  end

  test "an unknown slug is a 404, not a blank page" do
    get "/components/sparkles"

    assert_response :not_found

    get "/demos/sparkles"

    assert_response :not_found

    get "/blocks/sparkles"

    assert_response :not_found
  end

  test "the interactive demo is a real form - params re-render the chart server-side" do
    get "/demos/interactive"

    assert_response :success
    assert_select "form[action=?]", "/demos/interactive"
    assert_select "[data-slot=chart-x-axis] text", 6 do |ticks|
      assert_equal "Jan", ticks.first.text
    end

    get "/demos/interactive", params: { period: "3m", dataset: "previous" }

    assert_response :success
    assert_select "option[value=previous][selected]"
    assert_select "[data-slot=chart-x-axis] text", 3 do |ticks|
      assert_equal "Apr", ticks.first.text
    end
  end

  test "the live and window demos ship the payload-script channel" do
    get "/demos/live"

    assert_response :success
    assert_select "script[data-slot=chart-live-payload]", 1

    get "/demos/window"

    assert_response :success
    assert_select "[data-slot=chart-brush]"
  end

  test "the sync demo pairs two charts in one sync group" do
    get "/demos/sync"

    assert_response :success
    assert_select "[data-poetry--charts--tooltip-sync-value=?]", "demo", count: 2
  end

  test "the agent docs ride the mounted engine" do
    get "/poetry/llms.txt"

    assert_response :success
  end

  test "every catalog page renders" do
    # The whole-gallery gate: a broken example partial 500s its page; a
    # page with no examples must still 200 with the Empty state.
    DocsCatalog.all.each do |entry|
      get entry.path

      assert_response :success, "#{entry.path} failed to render"
    end
  end
end
