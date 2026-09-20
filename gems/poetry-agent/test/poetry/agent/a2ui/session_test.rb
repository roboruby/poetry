# frozen_string_literal: true

require "test_helper"
require "json"

class SessionTest < Minitest::Test
  A2UI = Poetry::Agent::A2UI
  FIXTURES = File.expand_path("../../../fixtures/a2ui", __dir__)

  def fixture(name)
    JSON.parse(File.read(File.join(FIXTURES, "#{name}.json")))["messages"]
  end

  def test_folds_the_login_form_example
    session = A2UI::Session.new

    assert_equal ["gallery-simple-login-form"], session.apply_all(fixture("00_simple-login-form"))
    assert_empty session.errors

    surface = session.surface("gallery-simple-login-form")

    assert_instance_of A2UI::Catalogs::Basic, surface.catalog
    assert_equal %w[root form_title username_field password_field submit_button submit_label], surface.components.keys
    assert_equal [{ path: "/username", kind: :string }, { path: "/password", kind: :string }], surface.inputs
  end

  def test_create_surface_carries_components_and_data_and_send_data_model
    session = A2UI::Session.new
    session.apply({ "version" => "v1.0",
                    "createSurface" => { "surfaceId" => "card", "catalogId" => A2UI::Catalogs::Basic::ID,
                                         "sendDataModel" => true, "dataModel" => { "name" => "Ada" },
                                         "components" => [{ "id" => "root", "component" => "Text",
                                                            "text" => { "path" => "/name" } }] } })
    surface = session.surface("card")

    assert surface.send_data_model
    assert_equal "Ada", surface.resolve(surface.root["text"])
  end

  def test_unknown_catalog_ids_fall_back_to_the_native_binding
    session = A2UI::Session.new
    session.apply({ "createSurface" => { "surfaceId" => "x", "catalogId" => "https://example.com/mine.json" } })

    assert_instance_of A2UI::Catalogs::Native, session.surface("x").catalog
  end

  def test_update_data_model_upserts_deletes_and_replaces
    session = A2UI::Session.new
    session.apply({ "createSurface" => { "surfaceId" => "s", "dataModel" => { "a" => 1, "b" => 2 } } })
    session.apply({ "updateDataModel" => { "surfaceId" => "s", "path" => "/a", "value" => 9 } })
    session.apply({ "updateDataModel" => { "surfaceId" => "s", "path" => "/b", "value" => nil } })

    assert_equal({ "a" => 9 }, session.surface("s").data)

    session.apply({ "updateDataModel" => { "surfaceId" => "s", "value" => { "c" => 3 } } })

    assert_equal({ "c" => 3 }, session.surface("s").data)
    assert_equal 3, session.surface("s").version
  end

  def test_rejections_become_renderer_to_agent_errors
    session = A2UI::Session.new
    session.apply({ "createSurface" => { "surfaceId" => "s" } })

    assert_empty session.apply({ "version" => "v0.9", "deleteSurface" => { "surfaceId" => "s" } })
    assert_empty session.apply({ "updateComponents" => { "surfaceId" => "nope", "components" => [] } })
    assert_empty session.apply({ "createSurface" => { "surfaceId" => "s" } })
    assert_empty session.apply({ "updateDataModel" => { "surfaceId" => "s", "path" => "/a" } })
    assert_empty session.apply({ "updateComponents" => { "surfaceId" => "s", "components" => "x" } })
    assert_empty session.apply({ "updateComponents" => { "surfaceId" => "s" },
                                 "deleteSurface" => { "surfaceId" => "s" } })
    assert_empty session.apply("junk")
    assert_empty session.apply({ "createSurface" => "junk" })

    codes = session.errors.map { |error| error.dig("error", "code") }

    assert_equal %w[INVALID_MESSAGE UNKNOWN_SURFACE DUPLICATE_SURFACE INVALID_MESSAGE INVALID_MESSAGE INVALID_MESSAGE
                    INVALID_MESSAGE INVALID_MESSAGE], codes
    assert(session.errors.all? { |error| error["version"] == "v1.0" })
    assert_equal "nope", session.errors[1].dig("error", "surfaceId")
  end

  def test_validation_errors_carry_the_surface_and_path
    session = A2UI::Session.new
    session.apply({ "createSurface" => { "surfaceId" => "s" } })
    session.apply({ "updateComponents" => { "surfaceId" => "s",
                                            "components" => [{ "id" => "a", "component" => "Column",
                                                               "children" => ["a"] }] } })
    error = session.errors.last["error"]

    assert_equal "VALIDATION_FAILED", error["code"]
    assert_equal "s", error["surfaceId"]
    assert_equal "/components/a", error["path"]
  end

  def test_renderer_only_functions_are_refused_to_agents
    session = A2UI::Session.new
    session.apply({ "callRendererFunction" => { "functionCallId" => "f1",
                                                "callFunction" => { "call" => "getScreenResolution",
                                                                    "catalogId" => "x" } } })
    error = session.errors.last["error"]

    assert_equal "INVALID_FUNCTION_CALL", error["code"]
    assert_equal "f1", error["functionCallId"]
    assert_match(/not invocable by an agent/, error["message"])

    session.apply({ "callRendererFunction" => { "functionCallId" => "f2",
                                                "callFunction" => { "call" => "required",
                                                                    "args" => { "value" => 1 } } } })

    assert_equal "f2", session.errors.last.dig("error", "functionCallId")
    assert_empty session.responses
    assert_empty session.apply({ "agentFunctionResponse" => { "functionCallId" => "f3", "value" => 1 } })
  end

  def test_agent_callable_functions_answer_with_a_response
    functions = A2UI::Functions.new
    functions.define("screen", description: "The screen size.", returns: "string", callers: "rendererOrAgent",
                               params: { "unit" => { "type" => "string" } }) do |args, _|
      "1280x800#{args["unit"]}"
    end
    functions.define("shout", description: "Upcases.", returns: "string", callers: "agentOnly",
                              required: %w[value]) { |args, _| args["value"].to_s.upcase }
    catalog = A2UI::Catalogs::Basic.new
    catalog.define_singleton_method(:functions) { functions }
    session = A2UI::Session.new(catalogs: { "https://example.com/cat.json" => catalog })
    session.apply({ "callRendererFunction" => { "functionCallId" => "f1",
                                                "callFunction" => { "call" => "screen", "catalogId" => "https://example.com/cat.json",
                                                                    "args" => { "unit" => "px" } } } })
    session.apply({ "callRendererFunction" => { "functionCallId" => "f2",
                                                "callFunction" => { "call" => "shout",
                                                                    "catalogId" => "https://example.com/cat.json" } } })

    assert_equal [{ "version" => "v1.0",
                    "rendererFunctionResponse" => { "functionCallId" => "f1", "value" => "1280x800px" } }],
                 session.responses
    assert_equal "f2", session.errors.last.dig("error", "functionCallId")
    assert_match(/missing value/, session.errors.last.dig("error", "message"))
  end

  def test_delete_surface
    session = A2UI::Session.new
    session.apply({ "createSurface" => { "surfaceId" => "s" } })

    assert_equal ["s"], session.apply({ "deleteSurface" => { "surfaceId" => "s" } })
    assert_nil session.surface("s")
    assert_equal ["s"], session.deleted
  end

  def test_apply_activity_accepts_the_middleware_shapes
    messages = fixture("00_simple-login-form")

    assert_equal ["gallery-simple-login-form"], A2UI::Session.new.apply_activity({ "a2ui_operations" => messages })
    assert_equal ["gallery-simple-login-form"], A2UI::Session.new.apply_activity({ "messages" => messages })
    assert_equal ["gallery-simple-login-form"], A2UI::Session.new.apply_activity(messages)
    assert_equal ["gallery-simple-login-form"], A2UI::Session.new.apply_activity(messages.first)
    assert_empty A2UI::Session.new.apply_activity("junk")
  end

  def test_action_writes_bound_inputs_then_resolves_the_context
    session = A2UI::Session.new
    session.apply_all(fixture("00_simple-login-form"))
    action = session.action(surface_id: "gallery-simple-login-form", source: "submit_button",
                            values: { "/username" => "ada", "/password" => "pw", "/evil" => "x" },
                            timestamp: Time.utc(2026, 9, 1, 12, 0, 0))

    assert_equal({ "version" => "v1.0",
                   "action" => { "name" => "login_submitted", "surfaceId" => "gallery-simple-login-form",
                                 "sourceComponentId" => "submit_button", "timestamp" => "2026-09-01T12:00:00.000Z",
                                 "context" => { "user" => "ada", "pass" => "pw" } } }, action.to_h)
    assert_equal({ "username" => "ada", "password" => "pw" }, session.surface("gallery-simple-login-form").data)
    assert_equal({ "a2uiAction" => { "userAction" => action.to_h["action"],
                                     "dataModel" => { "username" => "ada", "password" => "pw" } } },
                 action.forwarded_props)
  end

  def test_action_coerces_by_input_kind_and_honors_scopes
    session = A2UI::Session.new
    session.apply({ "createSurface" => {
                    "surfaceId" => "p", "catalogId" => A2UI::Catalogs::Basic::ID, "sendDataModel" => true,
                    "dataModel" => { "news" => true, "toppings" => [], "volume" => 1, "rows" => [{ "n" => 1 }] },
                    "components" => [
                      { "id" => "root", "component" => "Column", "children" => %w[news toppings volume list] },
                      { "id" => "news", "component" => "CheckBox", "label" => "News",
                        "value" => { "path" => "/news" } },
                      { "id" => "toppings", "component" => "ChoicePicker", "label" => "T",
                        "variant" => "multipleSelection",
                        "options" => [], "value" => { "path" => "/toppings" } },
                      { "id" => "volume", "component" => "Slider", "label" => "V", "max" => 10,
                        "value" => { "path" => "/volume" } },
                      { "id" => "list", "component" => "List",
                        "children" => { "componentId" => "row", "path" => "/rows" } },
                      { "id" => "row", "component" => "Button", "child" => "lbl",
                        "action" => { "event" => { "name" => "pick", "userMessage" => "Picked",
                                                   "context" => { "n" => { "path" => "n" },
                                                                  "all" => { "path" => "/rows" } } } } },
                      { "id" => "lbl", "component" => "Text", "text" => "Pick" }
                    ]
                  } })
    action = session.action(surface_id: "p", source: "row@/rows/0",
                            values: { "/news" => "false", "/toppings" => ["", "cream"], "/volume" => "7.5" })

    assert_equal({ "n" => 1, "all" => [{ "n" => 1 }] }, action.to_h.dig("action", "context"))
    assert_equal "Picked", action.to_h.dig("action", "userMessage")
    assert_equal "row", action.to_h.dig("action", "sourceComponentId")

    data = session.surface("p").data

    refute data["news"]
    assert_equal ["cream"], data["toppings"]
    assert_in_delta 7.5, data["volume"]
    assert_equal data, action.forwarded_props.dig("a2uiAction", "dataModel")
  end

  def test_a_failing_check_rejects_the_action_with_errors_by_component
    session = A2UI::Session.new
    session.apply({ "createSurface" => {
                    "surfaceId" => "f", "catalogId" => A2UI::Catalogs::Basic::ID, "sendDataModel" => true,
                    "dataModel" => { "formData" => { "terms" => "", "email" => "", "phone" => "" } },
                    "components" => [
                      { "id" => "root", "component" => "Column", "children" => %w[email submit] },
                      { "id" => "email", "component" => "TextField", "label" => "Email",
                        "value" => { "path" => "/formData/email" },
                        "checks" => [{ "condition" => { "call" => "email",
                                                        "args" => { "value" => { "path" => "/formData/email" } } },
                                       "message" => "Invalid email format" }] },
                      { "id" => "submit", "component" => "Button", "child" => "l",
                        "action" => { "event" => { "name" => "submit_form" } },
                        "checks" => [{ "condition" => { "call" => "and", "args" => { "values" => [
                          { "call" => "required", "args" => { "value" => { "path" => "/formData/terms" } } },
                          { "call" => "or", "args" => { "values" => [
                            { "call" => "required", "args" => { "value" => { "path" => "/formData/email" } } },
                            { "call" => "required", "args" => { "value" => { "path" => "/formData/phone" } } }
                          ] } }
                        ] } }, "message" => "You must accept terms AND provide either email or phone" }] },
                      { "id" => "l", "component" => "Text", "text" => "Go" }
                    ]
                  } })
    rejected = session.action(surface_id: "f", source: "submit", values: { "/formData/email" => "nope" })

    refute_predicate rejected, :valid?
    assert_nil rejected.to_h
    assert_empty rejected.forwarded_props
    assert_equal %w[email submit], rejected.errors.keys
    assert_equal "Invalid email format", rejected.errors["email"].first[:message]
    assert_equal "You must accept terms AND provide either email or phone", rejected.errors["submit"].first[:message]
    assert_equal "nope", session.surface("f").data.dig("formData", "email")

    session.surface("f").update_data("/formData/terms", "yes")
    accepted = session.action(surface_id: "f", source: "submit", values: { "/formData/email" => "ada@example.com" })

    assert_predicate accepted, :valid?
    assert_equal "submit_form", accepted.to_h.dig("action", "name")
    assert_equal({ "formData" => { "terms" => "yes", "email" => "ada@example.com", "phone" => "" } },
                 accepted.forwarded_props.dig("a2uiAction", "dataModel"))
  end

  def test_action_returns_nil_without_an_agent_event
    session = A2UI::Session.new
    session.apply({ "createSurface" => { "surfaceId" => "p", "catalogId" => A2UI::Catalogs::Basic::ID,
                                         "components" => [{ "id" => "root", "component" => "Button", "child" => "t",
                                                            "action" => { "functionCall" => { "call" => "openUrl" } } },
                                                          { "id" => "t", "component" => "Text", "text" => "x" }] } })

    assert_nil session.action(surface_id: "p", source: "root")
    assert_nil session.action(surface_id: "p", source: "missing")
    assert_nil session.action(surface_id: "nope", source: "root")
  end
end
