# frozen_string_literal: true

require "test_helper"

# The Community section's place in the site: the entry in the top nav
# where the site has the section, the sidebar group, the browser's
# address, and a host's own pages in the sitemap.
class CommunitySectionTest < ActionDispatch::IntegrationTest
  FIXTURE = Poetry::Docs.root.join("test/fixtures/files/community")
  NAV_LINK = "[data-slot=navigation-menu] a[href='/community']"

  def with_registry
    Poetry::Docs.config.community_registry = FIXTURE
    yield
  ensure
    Poetry::Docs.config.community_registry = nil
  end

  def with_section(value)
    Poetry::Docs.config.community_section = value
    yield
  ensure
    Poetry::Docs.config.community_section = nil
  end

  test "Community is in the top nav of the docs and of the landing page where the registry lists an item" do
    with_registry do
      get "/installation"

      assert_select NAV_LINK, text: "Community", count: 1
      get "/"

      assert_select NAV_LINK, text: "Community", count: 1
    end
  end

  test "a site with no community registry has no Community entry, unless the host says it has the section" do
    get "/installation"

    assert_select NAV_LINK, 0
    get "/"

    assert_select NAV_LINK, 0
    with_section(true) do
      get "/installation"

      assert_select NAV_LINK, text: "Community", count: 1
    end
  end

  test "a host can say it has no section, whatever the registry lists" do
    with_registry do
      with_section(false) do
        get "/installation"

        assert_select NAV_LINK, 0
      end
    end
  end

  test "the sidebar has a Community group, open on a component's page" do
    with_registry do
      get community_item_path("note-card")

      assert_response :success
      assert_select "[data-slot=collapsible][data-open] [data-slot=sidebar-menu-button][href='/community']", minimum: 1
    end
  end

  test "the browser's address leads to the index, which lists every item" do
    get "/community/components"

    assert_redirected_to "/community"
  end

  test "the sitemap lists the paths a host names, given as a list or asked on each request" do
    Poetry::Docs.config.sitemap_paths = [ "/community/libraries/acme" ]
    get "/sitemap.xml"

    assert_includes response.body, "<loc>http://www.example.com/community/libraries/acme</loc>"
    calls = 0
    Poetry::Docs.config.sitemap_paths = -> { calls += 1; [ "/community/libraries/asked-#{calls}" ] }
    get "/sitemap.xml"
    get "/sitemap.xml"

    assert_includes response.body, "/community/libraries/asked-2</loc>"
  ensure
    Poetry::Docs.config.sitemap_paths = nil
  end
end

# The Community guides: using an item, and publishing your own.
class CommunityGuidesTest < ActionDispatch::IntegrationTest
  test "Using community items covers installing, using, naming, the record and the review" do
    get "/community-items"

    assert_response :success
    assert_select "h1", "Using community items"
    %w[what-they-are install use names record reviewed-not-audited].each { |id| assert_select "h2##{id}" }
    assert_select "pre", text: %r{bin/rails g poetry:add @poetry/acme-pricing-table}
    assert_select "pre", text: /acme_pricing_table\(plans: @plans\)/
    assert_select "a[href='/community']", minimum: 1
  end

  test "Publishing components covers a registry of your own, the item and the Poetry registry" do
    get "/community-publishing"

    assert_response :success
    assert_select "h1", "Publishing components"
    %w[your-own-registry private the-item names-and-helpers versions the-poetry-registry].each { |id| assert_select "h2##{id}" }
    assert_select "pre", text: %r{"@acme": "https://acme.dev/r/\{name\}.json"}
    assert_select "pre", text: /Bearer \$\{ACME_TOKEN\}/
    assert_select "a[href='https://github.com/roboruby/poetry/issues']"
  end

  test "both guides mirror as markdown, and the index points at them" do
    get "/community-items.md"

    assert_response :success
    assert_includes response.body, "# Using community items"
    assert_includes response.body, "## How items are named"
    get "/community-publishing.md"

    assert_response :success
    assert_includes response.body, "## A registry at your own address"
    get "/community.md"

    assert_includes response.body, "[Using community items](/community-items)"
    get "/community"

    assert_select "a[href='/community-items']", minimum: 1
    assert_select "a[href='/community-publishing']", minimum: 1
  end

  test "the guides are in the sidebar's Community group" do
    get "/community-items"

    assert_select "[data-slot=sidebar-menu-button][href='/community-items']", minimum: 1
    assert_select "[data-slot=sidebar-menu-button][href='/community-publishing']", minimum: 1
  end
end
