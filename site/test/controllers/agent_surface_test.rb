# frozen_string_literal: true

require "test_helper"

# The agent surface: markdown mirrors (append.md to a component
# page) and the web-installable skills at .well-known/skills - both served
# from the same generators the installed skills use, so they cannot drift.
class AgentSurfaceTest < ActionDispatch::IntegrationTest
  test "a component page mirrors as markdown under the same address" do
    get "/components/badge.md"

    assert_response :success
    assert_match %r{text/markdown}, response.content_type
    assert_includes response.body, "poetry_badge"
  end

  test "an unknown component's markdown mirror 404s" do
    get "/components/never-shipped.md"

    assert_response :not_found
  end

  test "the skills index lists all three skills with their file rosters" do
    get "/.well-known/skills/index.json"

    assert_response :success
    payload = JSON.parse(response.body)
    names = payload["skills"].map { |skill| skill["name"] }

    assert_equal %w[poetry poetry-design poetry-docs-site], names

    usage = payload["skills"].first

    assert_includes usage["files"], "SKILL.md"
    assert_includes usage["files"], "references/deciding.md"
    assert_match(/component library/i, usage["description"])
  end

  test "skill files serve as markdown, straight from the generators" do
    get "/.well-known/skills/poetry/references/deciding.md"

    assert_response :success
    assert_includes response.body, "INTERACTION MODEL"

    get "/.well-known/skills/poetry-design/references/audit.md"

    assert_response :success
    assert_includes response.body, "Score it (deterministic)"
  end

  test "unknown skill files never resolve (map lookup, not filesystem)" do
    get "/.well-known/skills/poetry/references/../../../secrets.md"

    assert_response :not_found

    get "/.well-known/skills/poetry/references/nope.md"

    assert_response :not_found
  end

  # === The site-wide mirror matrix (agent-legibility S0+S2) ===

  test "every catalog page mirrors as markdown under its own address" do
    DocsCatalog.all.each do |entry|
      get "#{entry.path}.md"

      assert_response :success, "#{entry.path}.md"
      assert_match %r{text/(markdown|plain)}, response.content_type, "#{entry.path}.md"
      assert response.body.present?, "#{entry.path}.md is blank"
      # Components mirror their registry contract (helper name, not the
      # page title); /installation.md is the curated agent variant whose
      # H1 deliberately differs from the page title.
      unless entry.section == "components" || entry.slug == "installation"
        assert_includes response.body, entry.title, "#{entry.path}.md missing its title"
      end
    end
  end

  test "Accept: text/markdown serves the same mirrors - and never 500s" do
    [ "/components/badge", "/charts/#{DocsCatalog.charts.first.slug}",
      "/blocks/#{DocsCatalog.blocks.first.slug}", "/demos/interactive",
      "/typography", "/theming", "/" ].each do |path|
      get path, headers: { "Accept" => "text/markdown" }

      assert_response :success, path
      assert_match %r{text/markdown}, response.content_type, path
    end
  end

  test "a page with no mirror answers 406 to a markdown ask, not a 500" do
    get "/deferred/fragment", headers: { "Accept" => "text/markdown" }

    assert_response :not_acceptable
  end

  test "a block mirror carries the generator source and composition roster" do
    entry = DocsCatalog.blocks.first
    get "/blocks/#{entry.slug}.md"

    assert_response :success
    assert_includes response.body, "poetry:block #{entry.slug}"
    assert_includes response.body, "```erb"
  end

  # === Discovery surfaces (S1, S3, S4) ===

  test "the root llms.txt indexes every docs page" do
    get "/llms.txt"

    assert_response :success
    assert_match %r{text/markdown}, response.content_type
    DocsCatalog.all.each do |entry|
      assert_includes response.body, "(#{entry.path})", "llms.txt missing #{entry.path}"
    end
  end

  test "the agent-skills alias serves the same index and files" do
    get "/.well-known/agent-skills/index.json"

    assert_response :success
    assert_equal %w[poetry poetry-design poetry-docs-site],
                 JSON.parse(response.body)["skills"].map { |skill| skill["name"] }

    get "/.well-known/agent-skills/poetry-docs-site/SKILL.md"

    assert_response :success
    assert_includes response.body, "/llms.txt"
  end

  test "openapi.json documents only endpoints that actually answer" do
    get "/openapi.json"

    assert_response :success
    doc = JSON.parse(response.body)

    assert_equal "3.1.0", doc["openapi"]

    substitutions = { "{name}" => "registry.json", "{skill}/{file}" => "poetry/SKILL.md" }
    doc["paths"].each_key do |path|
      concrete = substitutions.reduce(path) { |p, (from, to)| p.sub(from, to) }
      next if concrete.include?("{")

      get concrete

      assert_response :success, "documented endpoint #{path} does not answer at #{concrete}"
    end
  end

  test "HTML pages advertise their markdown twin via link tag and Link header" do
    get "/components/badge"

    assert_response :success
    assert_includes response.headers["Link"], '</components/badge.md>; rel="alternate"; type="text/markdown"'
    assert_includes response.body, '<link rel="alternate" type="text/markdown" href="/components/badge.md">'

    get "/"

    assert_includes response.headers["Link"], "</llms.txt>"
    assert_includes response.body, 'href="/llms.txt"'
  end

  test "robots.txt welcomes crawlers with a Content-Signal line" do
    get "/robots.txt"

    assert_response :success
    assert_includes response.body, "Content-Signal: search=yes, ai-input=yes, ai-train=yes"
    assert_includes response.body, "Allow: /"
  end

  test "root llms-full.txt redirects to the engine's full catalog" do
    get "/llms-full.txt"

    assert_redirected_to "/poetry/llms-full.txt"
  end

  test "the api catalog is an RFC 9727 linkset pointing at the OpenAPI description" do
    get "/.well-known/api-catalog"

    assert_response :success
    assert_match %r{application/linkset\+json}, response.content_type
    linkset = JSON.parse(response.body)["linkset"]

    assert_equal "/openapi.json", linkset.first["service-desc"].first["href"]
  end
end
