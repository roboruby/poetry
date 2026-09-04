require "test_helper"

# The Resources menu is the site's front door for agents; the project's two
# public homes ride the headers as icon links, on the docs and the landing.
class SiteNavTest < ActionDispatch::IntegrationTest
  RESOURCES = %w[/llms.txt /poetry/llms.txt /installation.md /agent-skills /mcp-server /r/registry.json /openapi.json].freeze
  HOMES = %w[https://github.com/roboruby/poetry https://rubygems.org/gems/poetry].freeze

  test "the Resources panel lists the agent surfaces, one column" do
    get introduction_path

    assert_response :success
    RESOURCES.each { |href| assert_select "a[href=?]", href, { minimum: 1 }, "Resources must link #{href}" }
    %w[https://github.com/roboruby/poetry /docs.md].each do |href|
      assert_select "[data-slot='navigation-menu-content'] a[href=?]", href, { count: 0 }, "#{href} left the menu"
    end
  end

  test "every local Resources link answers" do
    RESOURCES.each do |path|
      get path

      assert_response :success, "#{path} should answer 200"
    end
  end

  test "the landing nav is Docs, Components, Libraries (the umbrella page) and AI" do
    get root_path


    links = css_select("header nav [data-slot='navigation-menu-link']").map { |a| [ a.text.strip, a["href"] ] }

    assert_equal [ [ "Docs", "/docs" ], [ "Components", DocsCatalog.components.first.path ],

                   [ "Libraries", "/libraries/poetry" ], [ "AI", "/mcp-server" ] ], links
  end


  test "the umbrella library page leads the Libraries section and mirrors as markdown" do
    assert_equal "poetry", DocsCatalog.libraries.first.slug


    get library_path("poetry")


    assert_response :success

    assert_select "h1", "Poetry"

    assert_select "a[href=?]", library_path("core")


    get "/libraries/poetry.md"


    assert_response :success

    assert_includes response.body, "gem \"poetry\""
  end


  test "the docs header and the landing header link the code and the gem" do
    get introduction_path
    HOMES.each { |href| assert_select "header a[href=?]", href, { minimum: 1 } }

    get root_path
    HOMES.each { |href| assert_select "header a[href=?]", href, { minimum: 1 } }
  end
end
