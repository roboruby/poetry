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

  test "the skills index lists both skills with their file rosters" do
    get "/.well-known/skills/index.json"

    assert_response :success
    payload = JSON.parse(response.body)
    names = payload["skills"].map { |skill| skill["name"] }

    assert_equal %w[poetry poetry-design], names

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
end
