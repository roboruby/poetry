# frozen_string_literal: true

require "test_helper"

# The operator register (the docs-site self-embed): the
# GUI-operator projection of the component contract, and the opt-in
# page-agent demo that consumes it.
class OperatorRegisterTest < ActionDispatch::IntegrationTest
  test "the register covers every catalog page and names only real components" do
    get "/operator-register.json"

    assert_response :success
    payload = JSON.parse(response.body)

    assert payload["system"].include?("data-component"), "system instructions must teach the part contract"
    assert payload["default"].present?

    DocsCatalog.all.each do |entry|
      assert payload["pages"].key?(entry.path), "register missing #{entry.path}"
    end

    slugs = DocsCatalog.components.map(&:slug)
    OperatorRegister::FAMILY_VERBS.each_key do |key|
      assert_includes slugs, key, "FAMILY_VERBS has a dead key: #{key}"
    end
  end

  test "component pages get their family verbs, keyboard-first ones say so" do
    get "/operator-register.json"
    pages = JSON.parse(response.body)["pages"]

    assert_includes pages["/components/select"], "click an option in the popup listbox"
    assert_includes pages["/components/slider"], "keyboard-first"
    assert_includes pages["/components/date-field"], "keyboard-first"
    assert_includes pages["/blocks/app-shell"], "block"
  end

  test "register data-component claims match what the DOM actually stamps" do
    get "/operator-register.json"
    pages = JSON.parse(response.body)["pages"]

    # A live run caught the register claiming kebab values where the
    # DOM stamps underscores (date_field, navigation_menu) - gate the claim
    # against the RENDERED page for the tricky shapes.
    { "/components/date-field" => "date_field",
      "/components/navigation-menu" => "navigation_menu",
      "/components/command-dialog" => "command-dialog",
      "/components/select" => "select" }.each do |path, expected|
      assert_includes pages[path], "data-component=#{expected}", "register claim for #{path}"

      get path

      assert_includes response.body, %(data-component="#{expected}"),
                      "#{path} DOM does not stamp #{expected}"
    end
  end

  test "the demo is opt-in: the vendored script rides no server-rendered page" do
    get "/page-agent"

    assert_response :success
    assert_includes response.body, "Activate agent"
    assert_includes response.body, "EXPECTED FAILURE"
    # The sample-implementation section DISPLAYS the loader source (which
    # names the vendored file); the opt-in contract is about script TAGS.
    refute_match %r{<script[^>]*src="[^"]*page-agent}, response.body,
                 "the script must load on demand, never via a server-rendered tag"

    get "/components/button"

    # The nav legitimately links /page-agent everywhere; the opt-in
    # contract is that no page ships the vendored script itself.
    refute_match %r{<script[^>]*src="[^"]*page-agent}, response.body
    refute_includes response.body, "vendor/page-agent"
  end

  test "the agent page mirrors as markdown" do
    get "/page-agent.md"

    assert_response :success
    assert_includes response.body, "operator register".upcase.downcase
    assert_includes response.body, "/operator-register.json"
  end

  test "the vendored build serves with its license and provenance" do
    get "/vendor/page-agent/page-agent-1.12.2.js"

    assert_response :success

    get "/vendor/page-agent/LICENSE"

    assert_response :success
    assert_includes response.body, "MIT License"

    get "/vendor/page-agent/VENDORED_VERSION"

    assert_response :success
    assert_includes response.body, "autoInit=false"
  end
end
