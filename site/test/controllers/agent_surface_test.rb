# frozen_string_literal: true

require "test_helper"
require "rubygems/package"

# The agent surface: markdown mirrors (append .md to a component
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

  test "the skills index lists every skill with its file roster" do
    get "/.well-known/skills/index.json"

    assert_response :success
    payload = JSON.parse(response.body)
    names = payload["skills"].map { |skill| skill["name"] }

    assert_equal %w[poetry poetry-design poetry-component poetry-docs-site], names

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

  # === The site-wide mirror matrix (agent legibility) ===

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
      "/typography", "/theming", "/docs" ].each do |path|
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

  # === Discovery surfaces ===

  test "the root llms.txt indexes every docs page" do
    get "/llms.txt"

    assert_response :success
    assert_match %r{text/markdown}, response.content_type
    DocsCatalog.all.each do |entry|
      assert_includes response.body, "(#{entry.path})", "llms.txt missing #{entry.path}"
    end
  end

  test "the agent-skills discovery index is a conformant RFC document" do
    get "/.well-known/agent-skills/index.json"

    assert_response :success
    doc = JSON.parse(response.body)

    assert_equal "https://schemas.agentskills.io/discovery/0.2.0/schema.json", doc["$schema"]
    assert_equal %w[$schema skills], doc.keys.sort
    assert_equal %w[poetry poetry-design poetry-component poetry-docs-site], doc["skills"].map { |skill| skill["name"] }

    doc["skills"].each do |entry|
      assert_equal %w[name description type url digest], entry.keys, "no fields the schema does not define"
      assert_match(/\A[a-z0-9]+(?:-[a-z0-9]+)*\z/, entry["name"])
      assert entry["description"].present?, "#{entry["name"]} needs its use-this-when line"
      assert_match(/\Asha256:[0-9a-f]{64}\z/, entry["digest"])
      assert entry["type"] == "archive" ?
               entry["url"].end_with?("/agent-skills/#{entry["name"]}.tar.gz") :
               entry["url"].end_with?("/agent-skills/#{entry["name"]}/SKILL.md"),
             "#{entry["name"]} url must match its type"
    end
    assert_equal "skill-md", doc["skills"].find { |s| s["name"] == "poetry-docs-site" }["type"],
                 "a lone SKILL.md is served as itself"
    assert_equal "archive", doc["skills"].find { |s| s["name"] == "poetry" }["type"]
  end

  test "every advertised digest matches the exact bytes its url serves" do
    get "/.well-known/agent-skills/index.json"

    JSON.parse(response.body)["skills"].each do |entry|
      get URI.parse(entry["url"]).path

      assert_response :success
      assert_equal entry["digest"], "sha256:#{Digest::SHA256.hexdigest(response.body)}",
                   "the digest for #{entry["name"]} must be computed over what is served"
    end
  end

  test "skill archives are flat, deterministic, and reject unknown names" do
    get "/agent-skills/poetry.tar.gz"

    assert_response :success
    assert_equal "application/gzip", response.media_type
    first = response.body

    names = []
    Zlib::GzipReader.wrap(StringIO.new(first)) do |gz|
      Gem::Package::TarReader.new(gz) { |tar| tar.each { |entry| names << entry.full_name } }
    end

    assert_includes names, "SKILL.md", "SKILL.md must sit at the archive root"
    assert(names.none? { |name| name.start_with?("poetry/") }, "a wrapping folder is the classic broken install")

    get "/agent-skills/poetry.tar.gz"

    assert_equal first, response.body, "the advertised digest depends on byte-identical rebuilds"

    get "/agent-skills/nope.tar.gz"

    assert_response :not_found
  end

  test "the agent-skills path still serves individual skill files" do
    get "/.well-known/agent-skills/poetry-docs-site/SKILL.md"

    assert_response :success
    assert_includes response.body, "/llms.txt"
  end

  test "path-scoped discovery serves the same document under the /agent-skills prefix" do
    get "/.well-known/agent-skills/index.json"
    root_doc = response.body

    get "/agent-skills/.well-known/agent-skills/index.json"

    assert_response :success
    assert_equal root_doc, response.body, "the installer scopes by path and must find the same index there"

    get "/agent-skills/.well-known/skills/index.json"

    assert_equal root_doc, response.body
  end

  test "the human catalog page lists every skill with path-scoped install commands" do
    get "/agent-skills"

    assert_response :success
    SkillCatalog.sets.each_key do |name|
      assert_includes response.body, "npx skills add http://www.example.com/agent-skills --skill #{name}"
    end
    assert_includes response.body, "/.well-known/agent-skills/index.json"
    assert_includes response.body, "poetry.tar.gz", "archive curl commands point at the payloads"

    get "/agent-skills.md"

    assert_response :success
    assert_match %r{text/markdown}, response.content_type
    assert_includes response.body, "npx skills add http://www.example.com/agent-skills --skill poetry"
  end

  test "openapi.json documents only endpoints that actually answer" do
    get "/openapi.json"

    assert_response :success
    doc = JSON.parse(response.body)

    assert_equal "3.1.0", doc["openapi"]

    substitutions = { "{name}" => "registry.json", "{skill}/{file}" => "poetry/SKILL.md",
                      "{archive}" => "poetry.tar.gz" }
    doc["paths"].each do |path, item|
      concrete = substitutions.reduce(path) { |p, (from, to)| p.sub(from, to) }
      next if concrete.include?("{")

      if item.key?("post")
        post concrete, params: { jsonrpc: "2.0", id: 1, method: "initialize", params: {} }.to_json,
                       headers: { "CONTENT_TYPE" => "application/json" }
      else
        get concrete
      end

      assert_response :success, "documented endpoint #{path} does not answer at #{concrete}"
    end
  end

  test "HTML pages advertise their markdown twin via link tag and Link header" do
    get "/components/badge"

    assert_response :success
    assert_includes response.headers["Link"], '</components/badge.md>; rel="alternate"; type="text/markdown"'
    assert_includes response.body, '<link rel="alternate" type="text/markdown" href="/components/badge.md">'

    get "/docs"

    assert_includes response.headers["Link"], "</llms.txt>"
    assert_includes response.body, 'href="/llms.txt"'
  end

  test "every HTML page carries a describedby pointer at the llms.txt index" do
    [ "/components/badge", "/theming", "/agent-skills", "/docs" ].each do |path|
      get path

      assert_response :success, path
      assert_includes response.headers["Link"],
                      '</llms.txt>; rel="describedby"; type="text/markdown"', path
    end
  end

  test "HEAD requests answer the mirror and carry the same Link headers" do
    head "/components/badge.md"

    assert_response :success
    assert_match %r{text/markdown}, response.content_type

    head "/components/badge"

    assert_response :success
    assert_includes response.headers["Link"], '</components/badge.md>; rel="alternate"; type="text/markdown"'
    assert_includes response.headers["Link"], '</llms.txt>; rel="describedby"; type="text/markdown"'
  end

  test "robots.txt welcomes crawlers with Content-Signal and the sitemap pointer" do
    get "/robots.txt"

    assert_response :success
    assert_includes response.body, "Content-Signal: search=yes, ai-input=yes, ai-train=yes"
    assert_includes response.body, "Allow: /"
    assert_match %r{Sitemap: http://[^/]+/sitemap\.xml}, response.body
  end

  test "the sitemap covers the root and every catalog page" do
    get "/sitemap.xml"

    assert_response :success
    assert_match %r{application/xml}, response.content_type
    assert_includes response.body, "<urlset"
    DocsCatalog.all.each do |entry|
      assert_includes response.body, "#{entry.path}</loc>", "sitemap missing #{entry.path}"
    end
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
