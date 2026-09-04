require "test_helper"

# The Resources menu is the site's front door for agents and the project's
# public homes; every entry must resolve, and the agent surfaces must be
# listed there, not only in llms.txt.
class SiteNavTest < ActionDispatch::IntegrationTest
  test "the Resources panel lists the agent surfaces and the project homes" do
    get introduction_path

    assert_response :success
    %w[/llms.txt /poetry/llms.txt /installation.md /agent-skills /mcp-server
       https://github.com/roboruby/poetry https://rubygems.org/gems/poetry
       /r/registry.json /openapi.json /docs.md].each do |href|
      assert_select "a[href=?]", href, { minimum: 1 }, "Resources must link #{href}"
    end
  end

  test "every local Resources link answers" do
    %w[/llms.txt /poetry/llms.txt /installation.md /agent-skills /mcp-server /r/registry.json /openapi.json /docs.md].each do |path|
      get path

      assert_response :success, "#{path} should answer 200"
    end
  end
end
