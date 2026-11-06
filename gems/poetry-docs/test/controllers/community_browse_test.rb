# frozen_string_literal: true

require "test_helper"
require "tmpdir"

# The Community section as a place of its own: its layout (the site's
# header, the section's tabs, the search and filters as the sidebar), and
# the component browser's search, filters, counts and order.
class CommunityBrowseTest < ActionDispatch::IntegrationTest
  ITEMS = [
    { "name" => "acme-pricing-table", "type" => "registry:component", "title" => "Pricing table",
      "description" => "Plans side by side.", "registryDependencies" => %w[button card],
      "meta" => { "javascript" => "stimulus", "traits" => %w[animated], "source" => { "registry" => "@acme", "item" => "pricing-table" } } },
    { "name" => "acme-hero-01", "type" => "registry:block", "title" => "Hero with a headline",
      "description" => "A headline over a photo.", "registryDependencies" => %w[button],
      "meta" => { "javascript" => "none", "traits" => %w[animated gradient], "source" => { "registry" => "@acme", "item" => "hero-01" } } },
    { "name" => "beta-card", "type" => "registry:style", "title" => "Beta cards", "description" => "A restyle of the card.",
      "registryDependencies" => %w[card],
      "meta" => { "javascript" => "none", "restyles" => "card", "source" => { "registry" => "@beta", "item" => "card" } } },
    { "name" => "note-pad", "type" => "registry:component", "title" => "Note pad", "description" => "A pad made for Poetry.",
      "meta" => { "javascript" => "none" } }
  ].freeze

  setup do
    @dir = Dir.mktmpdir
    FileUtils.mkdir_p(File.join(@dir, "about"))
    ITEMS.each { |entry| File.write(File.join(@dir, "about/#{entry["name"]}.json"), JSON.generate(entry)) }
    Poetry::Docs.config.community_registry = @dir
  end

  teardown do
    Poetry::Docs.config.community_registry = nil
    Poetry::Docs.config.community_tabs = nil
    FileUtils.rm_rf(@dir)
  end

  def cards = css_select("[data-community-card]").map { |card| card["data-community-card"] }

  def options(param)
    css_select("[data-filter=#{param}] a").to_h { |a| [ a.at_css("span").text.strip, a.css("span").last.text.strip ] }
  end

  test "the section wears its own layout: the site's header, its tabs, and the filters where the docs have their nav" do
    get community_path

    assert_response :success
    assert_select "header a[href='/agent-skills']", minimum: 1
    assert_select "[data-slot=sidebar] [data-community-filters]", 1
    assert_select "[data-sidebar-sections-section-param]", 0, "the docs' nav is not here"
    assert_select "[data-community-tabs] a[aria-current=page]", "Components"
    assert_select "[data-community-tabs] a[href='/community-items']", "Guide"
    assert_equal %w[acme-hero-01 acme-pricing-table beta-card note-pad].sort, cards.sort
    assert_select "[data-community-count]", text: /\A\s*4\s+items\s*\z/
    assert_select "button[data-community-filters-toggle][data-action*=\"sidebar#toggle\"]", text: /Filters/
  end

  test "each filter lists its choices with how many items each would give" do
    get community_path

    assert_equal({ "Component" => "2", "Block" => "1", "Restyle" => "1" }, options("type"))
    assert_equal({ "@acme" => "2", "@beta" => "1", "Made for Poetry" => "1" }, options("library"))
    assert_equal({ "None of its own" => "3", "Stimulus controller" => "1" }, options("javascript"))
    assert_equal({ "animated" => "2", "gradient" => "1" }, options("trait"))
    assert_equal({ "button" => "2", "card" => "2" }, options("needs"))
  end

  test "a filter narrows the list, the counts follow, and the chosen one links back out" do
    get community_path(library: "acme")

    assert_equal %w[acme-hero-01 acme-pricing-table], cards.sort
    assert_select "[data-community-count]", text: /2 of 4/
    assert_equal({ "Component" => "1", "Block" => "1" }, options("type"))
    assert_select "[data-filter=library] a[aria-current=true][href='/community']", text: /@acme/
    assert_select "[aria-label='Filters in force'] a[href='/community']", text: /@acme/
    get community_path(library: "acme", type: "block")

    assert_equal %w[acme-hero-01], cards
    assert_select "[data-filter=library] a[aria-current=true][href='/community?type=block']"
    get community_path(javascript: "stimulus")

    assert_equal %w[acme-pricing-table], cards
    get community_path(trait: "gradient")

    assert_equal %w[acme-hero-01], cards
    get community_path(needs: "card")

    assert_equal %w[acme-pricing-table beta-card], cards.sort
    get community_path(library: "poetry")

    assert_equal %w[note-pad], cards
  end

  test "the search looks in what an item says of itself, keeps the filters, and says when nothing matches" do
    get community_path(q: "headline")

    assert_equal %w[acme-hero-01], cards
    assert_select "input[type=search][name=q][value=headline]"
    get community_path(q: "acme card")

    assert_equal %w[acme-pricing-table], cards, "every word has to be there"
    get community_path(q: "plans", type: "component")

    assert_select "form[role=search] input[type=hidden][name=type][value=component]"
    assert_select "[aria-label='Filters in force'] a", text: /plans/
    get community_path(q: "nothing-like-this")

    assert_empty cards
    assert_select "[data-community-results] a[href='/community']", "Clear the search and the filters"
  end

  test "the list is in name order, or by library" do
    get community_path

    assert_equal [ "Beta cards", "Hero with a headline", "Note pad", "Pricing table" ], css_select("[data-community-card] h3").map { _1.text.strip }
    get community_path(sort: "library")

    assert_equal %w[note-pad acme-hero-01 acme-pricing-table beta-card], cards
    assert_select "[data-community-results] a[aria-current=true]", "Library"
  end

  test "a component's page is at full width, with the tabs and the way back, and no filters" do
    get community_item_path("acme-pricing-table")

    assert_response :success
    assert_select "[data-slot=sidebar]", 0
    assert_select "[data-community-filters]", 0
    assert_select "header a[aria-label='Poetry home'][href='/']"
    assert_select "[data-community-tabs] a[aria-current=page]", "Components"
    assert_select "a[data-community-back][href='/community']", text: /All components/
  end

  test "a host that serves the section names its tabs, and a page is under the longest path its own begins with" do
    Poetry::Docs.config.community_tabs = [ [ "Overview", "/community" ], [ "Components", "/community/components" ],
                                           [ "Libraries", "/community/libraries" ] ]
    get community_path

    assert_equal %w[Overview Components Libraries Guide], css_select("[data-community-tabs] a").map { _1.text.strip }
    assert_select "[data-community-tabs] a[aria-current=page]", "Overview"
    get community_item_path("acme-pricing-table")

    assert_select "[data-community-tabs] a[aria-current=page]", "Components"
    assert_select "a[data-community-back][href='/community/components']", text: /All components/
  end

  test "a long filter shows its first choices with the chosen one, and all of them once opened" do
    many = (1..14).map do |n|
      { "name" => "lib#{n}-card", "type" => "registry:component", "title" => "Card #{n}",
        "meta" => { "javascript" => "none", "source" => { "registry" => format("@lib%02d", n), "item" => "card" } } }
    end
    many.each { |entry| File.write(File.join(@dir, "about/#{entry["name"]}.json"), JSON.generate(entry)) }
    get community_path

    assert_equal 10, css_select("[data-filter=library] li").size
    assert_select "[data-filter=library] a[data-filter-more][href=?]", "/community?more=library", text: "Show all 17"
    get community_path, params: { library: "lib14" }

    assert_equal 11, css_select("[data-filter=library] li").size, "the chosen library stays in view"
    assert_select "[data-filter=library] a[aria-current=true]", text: /@lib14/
    get community_path, params: { more: "library" }

    assert_equal 17, css_select("[data-filter=library] li").size
    assert_select "[data-filter=library] a[data-filter-more][href='/community']", "Show fewer"
    assert_select "[data-filter=type] a[href=?]", "/community?more=library&type=component", 1, "a choice keeps the filter open"
  end

  # A host's own page in the section, through Poetry::Docs::CommunityLayout.
  class LibrariesController < ActionController::Base
    include Poetry::Docs::CommunityLayout

    def index
      render inline: <<~ERB, layout: true
        <% content_for :title, "Libraries" %>
        <% content_for(:community_sidebar) { tag.p("Library filters", data: { host_filters: true }) } if params[:filters] %>
        <h1>Every library</h1>
      ERB
    end
  end

  test "a host's page wears the section's layout, under its own tab, with or without a sidebar" do
    Poetry::Docs.config.community_tabs = [ [ "Components", "/community" ], [ "Libraries", "/community/libraries" ] ]
    with_routing do |routes|
      routes.draw do
        get "/community/libraries" => "community_browse_test/libraries#index"
        mount Poetry::Docs::Engine => "/"
      end

      get "/community/libraries"

      assert_response :success
      assert_select "title", "Libraries — poetry"
      assert_select "h1", "Every library"
      assert_select "[data-community-tabs] a[aria-current=page]", "Libraries"
      assert_select "[data-slot=sidebar]", 0
      get "/community/libraries", params: { filters: 1 }

      assert_select "[data-slot=sidebar] [data-host-filters]", "Library filters"
    end
  end

  # A host's browser that gives its list in pages: the engine's own state
  # with the two readers a paged list answers.
  class PagedBrowse < SimpleDelegator
    def page = 2

    def pages = 3
  end

  class PagedController < ActionController::Base
    include Poetry::Docs::CommunityLayout

    def index
      browse = PagedBrowse.new(Poetry::Docs::CommunityBrowse.new(Poetry::Docs::CommunityRegistry.items, params))
      render inline: <<~ERB, locals: { browse: browse }, layout: true
        <%= render "poetry/docs/community/results", browse: browse, path: "/community/paged", heading: "Paged" %>
        <%= render "poetry/docs/community/install_note" %>
      ERB
    end
  end

  test "a host's list in pages gets a pager that keeps the filters, and shares the install note" do
    with_routing do |routes|
      routes.draw do
        get "/community/paged" => "community_browse_test/paged#index"
        mount Poetry::Docs::Engine => "/"
      end

      get "/community/paged", params: { type: "component" }

      assert_response :success
      assert_select "nav[aria-label='Pages of components'] a[href=?]", "/community/paged?type=component", minimum: 1
      assert_select "nav[aria-label='Pages of components'] a[href=?]", "/community/paged?page=3&type=component", minimum: 1
      assert_select "nav[aria-label='Pages of components'] [aria-current=page]", "2"
      assert_select "[data-community-install-note] a[href='/community-items']", "Using community items"
    end
    get community_path

    assert_select "nav[aria-label='Pages of components']", 0, "the engine's own list is whole"
    assert_select "[data-community-install-note]", 1
  end
end

# CommunityBrowse on its own: the state an address holds.
class CommunityBrowseStateTest < ActiveSupport::TestCase
  def items
    CommunityBrowseTest::ITEMS.map { |entry| Poetry::Docs::CommunityRegistry::Item.new(entry) }
  end

  test "the parameters an address needs, with one changed or taken away" do
    browse = Poetry::Docs::CommunityBrowse.new(items, q: "card", type: "component", sort: "library")

    assert_equal({ "q" => "card", "sort" => "library", "type" => "component" }, browse.params_for)
    assert_equal({ "q" => "card", "sort" => "library", "type" => "block" }, browse.params_for("type" => "block"))
    assert_equal({ "sort" => "library", "type" => "component" }, browse.params_for("q" => nil))
    assert_equal({}, Poetry::Docs::CommunityBrowse.new(items).params_for)
    assert_equal({ "more" => "library" }, Poetry::Docs::CommunityBrowse.new(items, more: "library").params_for)
    assert_equal({}, Poetry::Docs::CommunityBrowse.new(items, more: "widgets").params_for, "only a filter can be opened")
  end

  test "an unknown order is the name's, a filter nothing answers gives nothing, and a blank one is no filter" do
    assert_equal "name", Poetry::Docs::CommunityBrowse.new(items, sort: "stars").sort
    assert_empty Poetry::Docs::CommunityBrowse.new(items, type: "widget").items
    browse = Poetry::Docs::CommunityBrowse.new(items, type: " ", q: " ")

    assert_equal 4, browse.count
    refute_predicate browse, :narrowed?
  end

  test "a filter with one choice and none chosen is left out" do
    one = items.select { |item| item.library == "acme" }
    facets = Poetry::Docs::CommunityBrowse.new(one).facets.map(&:param)

    refute_includes facets, "library"
    assert_includes facets, "type"
    assert_includes Poetry::Docs::CommunityBrowse.new(one, library: "acme").facets.map(&:param), "library"
  end
end
