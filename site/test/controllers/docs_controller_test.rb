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
    assert_select "div.highlight", minimum: 1 # the Rouge code tab
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
    DocsCatalog.all.each do |entry|
      dir = Rails.root.join("app/views/examples/#{entry.section}/#{entry.slug}")

      assert_predicate dir.glob("_*.html.erb"), :any?, "#{entry.path} has no example partials"
    end
  end

  test "an unknown slug is a 404, not a blank page" do
    get "/components/sparkles"

    assert_response :not_found
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
