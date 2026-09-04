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

  test "the docs header and the landing header link the code and the gem" do
    get introduction_path
    HOMES.each { |href| assert_select "header a[href=?]", href, { minimum: 1 } }

    get root_path
    HOMES.each { |href| assert_select "header a[href=?]", href, { minimum: 1 } }
  end
end
