require "test_helper"
require "tmpdir"

# The official registry endpoints: shadcn-schema
# payloads generated live from the gems' committed registries - if these
# facts drift from the source trees, the gem-side registry sync tests fail
# first; here we prove the docs host actually serves them.
class RegistryControllerTest < ActionDispatch::IntegrationTest
  test "registry.json serves the official index across ui and charts" do
    get "/r/registry.json"

    assert_response :success
    payload = JSON.parse(response.body)

    assert_equal "poetry", payload["name"]
    names = payload["items"].map { |item| item["name"] }

    assert_includes names, "button"
    assert_includes names, "app-shell", "blocks are items"
    assert_includes names, "line-chart", "charts aggregate in"
    payload["items"].each do |item|
      (item["files"] || []).each { |file| assert_not file.key?("content"), "the index strips content" }
    end
  end

  test "an item serves its full payload with embedded source" do
    get "/r/button.json"

    assert_response :success
    item = JSON.parse(response.body)

    assert_equal "registry:component", item["type"]
    assert_equal %w[icon], item["registryDependencies"]
    component = item["files"].find { |file| file["path"].end_with?("component.rb") }

    assert_match(/class Component/, component["content"])
  end

  test "a block item is copy-in with an app views target" do
    get "/r/app-shell.json"

    assert_response :success
    item = JSON.parse(response.body)

    assert_equal "registry:block", item["type"]
    assert_equal "app/views/blocks/_app_shell.html.erb", item.dig("files", 0, "target")
    assert_equal "copy-in", item.dig("meta", "provided")
  end

  test "unknown items 404" do
    get "/r/no-such-thing.json"

    assert_response :not_found
  end

  test "the public directory advertises @poetry with a url template" do
    get "/r/registries.json"

    assert_response :success
    entry = JSON.parse(response.body).dig("registries", "@poetry")

    assert_match %r{/r/\{name\}\.json\z}, entry["url"]
    assert entry["verified"], "@poetry is verified by construction (CI-gated registries)"
  end
  test "community items serve where the gems ship no item of that name" do
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, "registry.json"), JSON.generate({ "name" => "poetry-community", "items" => [ { "name" => "phone-mockup" } ] }))
      File.write(File.join(dir, "phone-mockup.json"), JSON.generate({ "name" => "phone-mockup", "type" => "registry:component" }))
      File.write(File.join(dir, "button.json"), JSON.generate({ "name" => "button", "type" => "registry:lib" }))
      Poetry::Docs.config.community_registry = dir

      get "/r/phone-mockup.json"

      assert_response :success
      assert_equal "phone-mockup", JSON.parse(response.body)["name"]
      get "/r/button.json"

      assert_equal "registry:component", JSON.parse(response.body)["type"], "the gems' item wins"
      get "/r/community/registry.json"

      assert_equal [ "phone-mockup" ], JSON.parse(response.body)["items"].map { it["name"] }
      get "/r/absent.json"

      assert_response :not_found
    ensure
      Poetry::Docs.config.community_registry = nil
    end
  end

  test "no community registry configured serves none" do
    get "/r/community/registry.json"

    assert_response :not_found
  end
end
