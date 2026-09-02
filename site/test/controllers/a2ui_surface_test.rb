# frozen_string_literal: true

require "test_helper"

# The A2UI surface demo: two catalogs rendered as forms on the server, a
# surface streamed progressively, and a submission answered with the
# action message plus the scripted agent's reply.
class A2uiSurfaceTest < ActionDispatch::IntegrationTest
  test "the demo page renders both surfaces as forms and the stream source" do
    get "/demos/a2ui-surface"

    assert_response :success
    assert_select "form#a2ui-signin[action='/demos/a2ui-surface/action']"
    assert_select "form#a2ui-signin input[name='a2ui[values][/email]'][type=email][required]"
    assert_select "form#a2ui-signin input[name='a2ui[values][/password]'][type=password]"
    assert_select "form#a2ui-signin button[type=submit][name='a2ui[action]'][value=submit]"
    assert_select "form#a2ui-plan input[name='a2ui[values][/seats]'][type=number]"
    assert_select "form#a2ui-plan button[name='a2ui[action]'][value=cta]"
    assert_includes response.body, "/demos/a2ui-surface/stream"
  end

  test "the stream appends the order surface then replaces it with rising versions" do
    get "/demos/a2ui-surface/stream"

    assert_response :success
    assert_includes response.body, 'action="append" target="a2ui-stage"'
    assert_includes response.body, 'action="vreplace" target="a2ui-order"'
    versions = response.body.scan(/data-version="(\d+)"/).flatten.map(&:to_i)

    assert_equal versions.sort, versions
    assert_operator versions.length, :>=, 5
    assert_includes response.body, "Flat white"
    assert_includes response.body, "Order #4821, placed Sep 1, 18:05"
    assert_includes response.body, "Delivered: 3 items, $14.50"
    assert_includes response.body, "<p>2.</p>"
    assert_includes response.body, "<p>x2</p>"
    assert_includes response.body, 'action="remove" target="a2ui-surface-source"'
  end

  test "a failing server-side check re-renders the surface with its errors" do
    post "/demos/a2ui-surface/action",
         params: { a2ui: { surface: "signin", action: "submit",
                           values: { "/email" => "ada@example.com", "/password" => "pw", "/remember" => "true" } } }

    assert_response :unprocessable_entity
    assert_includes response.body, 'action="vreplace" target="a2ui-signin"'
    assert_includes response.body, "Use your work email, not an example.com address."
    assert_includes response.body, 'value="ada@example.com"'
    assert_includes response.body, "A check failed on the server"
    refute_includes response.body, "Welcome back"
  end

  test "submitting the sign-in surface yields the action message and the agent's reply" do
    post "/demos/a2ui-surface/action",
         params: { a2ui: { surface: "signin", action: "submit",
                           values: { "/email" => "ada@roboruby.com", "/password" => "pw", "/remember" => "false" } } }

    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", response.media_type
    assert_includes response.body, 'action="vreplace" target="a2ui-signin"'
    assert_includes response.body, "Welcome back, ada@roboruby.com"
    assert_includes response.body, "sign in again"
    assert_includes response.body, 'target="a2ui-action-log"'
    assert_includes response.body, "sign_in"
    assert_includes response.body, "forwardedProps"
  end

  test "submitting the plan surface answers through the native catalog" do
    post "/demos/a2ui-surface/action", params: { a2ui: { surface: "plan", action: "cta", values: { "/seats" => "12" } } }

    assert_response :success
    assert_includes response.body, 'action="vreplace" target="a2ui-plan"'
    assert_includes response.body, "Team, 12 seats"
    assert_includes response.body, "Chosen: 12 seats"
    assert_includes response.body, "choose_plan"
  end

  test "a submission naming no agent action is rejected" do
    post "/demos/a2ui-surface/action", params: { a2ui: { surface: "signin", action: "title" } }

    assert_response :unprocessable_entity
    assert_includes response.body, 'target="a2ui-action-log"'
  end
end
