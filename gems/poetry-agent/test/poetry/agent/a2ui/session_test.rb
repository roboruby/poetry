# frozen_string_literal: true

require "test_helper"
require "json"

class SessionTest < Minitest::Test
  A2UI = Poetry::Agent::A2UI
  FIXTURES = File.expand_path("../../../fixtures/a2ui/upstream/catalogs/basic/v1/examples", __dir__)

  def rpc(id, call)
    { "version" => "1.0", "callRendererFunction" => { "functionCallId" => id, "callFunction" => call } }
  end

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
    session.apply({ "version" => "1.0",
                    "createSurface" => { "surfaceId" => "card", "catalogId" => A2UI::Catalogs::Basic::ID,
                                         "sendDataModel" => true, "dataModel" => { "name" => "Ada" },
                                         "components" => [{ "id" => "root", "component" => "Text",
                                                            "text" => { "@path" => "/name" } }] } })
    surface = session.surface("card")

    assert surface.send_data_model
    assert_equal "Ada", surface.resolve(surface.root["text"])
  end

  def test_an_unknown_catalog_is_refused_unless_the_host_names_a_fallback
    create = { "version" => "1.0", "createSurface" => { "surfaceId" => "x", "catalogId" => "https://example.com/mine.json" } }
    session = A2UI::Session.new
    session.apply(create)

    assert_nil session.surface("x")
    expected = { "code" => "CATALOG_ERROR", "message" => "Catalog not found: https://example.com/mine.json",
                 "surfaceId" => "x" }

    assert_equal expected, session.errors.last["error"]
    lenient = A2UI::Session.new(fallback_catalog: A2UI::Catalogs::Native.new)
    lenient.apply(create)

    assert_instance_of A2UI::Catalogs::Native, lenient.surface("x").catalog
  end

  def test_components_and_calls_name_their_own_catalogs_in_v1
    session = A2UI::Session.new
    basic = A2UI::Catalogs::Basic::ID
    session.apply({ "version" => "1.0", "createSurface" => { "surfaceId" => "m", "components" => [
                    { "id" => "root", "component" => "Column", "catalogId" => basic, "children" => %w[card] },
                    { "id" => "card", "component" => "Badge", "catalogId" => A2UI::Catalog::DEFAULT_ID,
                      "text" => { "@call" => "formatNumber", "catalogId" => basic, "args" => { "value" => 3 } } }
                  ] } })
    surface = session.surface("m")

    assert_empty session.errors, "a surface without a default takes components that name their catalog"
    assert_instance_of A2UI::Catalogs::Native, surface.catalog_of(surface.component("card"))
    assert_equal "3", surface.resolve(surface.component("card")["text"])
    session.apply({ "version" => "1.0", "updateComponents" => { "surfaceId" => "m", "components" => [
                    { "id" => "loose", "component" => "Text", "text" => "x" },
                    { "id" => "elsewhere", "component" => "Text", "catalogId" => "urn:none", "text" => "x" }
                  ] } })

    assert_equal(["loose: Surface 'm' has no default catalogId", "elsewhere: Catalog not found: urn:none"],
                 session.errors.last(2).map { |error| error.dig("error", "message") })
    assert_nil surface.component("loose")
  end

  def test_update_data_model_upserts_deletes_and_replaces
    session = A2UI::Session.new
    session.apply({ "version" => "1.0",
                    "createSurface" => { "surfaceId" => "s", "dataModel" => { "a" => 1, "b" => 2 } } })
    session.apply({ "version" => "1.0", "updateDataModel" => { "surfaceId" => "s", "path" => "/a", "value" => 9 } })
    session.apply({ "version" => "1.0", "updateDataModel" => { "surfaceId" => "s", "path" => "/b", "value" => nil } })

    assert_equal({ "a" => 9 }, session.surface("s").data)

    session.apply({ "version" => "1.0", "updateDataModel" => { "surfaceId" => "s", "value" => { "c" => 3 } } })

    assert_equal({ "c" => 3 }, session.surface("s").data)
    assert_equal 3, session.surface("s").version
  end

  def test_update_data_model_refuses_an_index_past_the_cap
    session = A2UI::Session.new
    session.apply({ "version" => "1.0",
                    "createSurface" => { "surfaceId" => "s", "dataModel" => { "items" => %w[a] } } })

    write = { "surfaceId" => "s", "path" => "/items/999999999", "value" => "x" }

    assert_empty session.apply({ "version" => "1.0", "updateDataModel" => write })
    error = session.errors.last["error"]

    assert_equal "DATA_ERROR", error["code"]
    assert_equal "s", error["surfaceId"]
    assert_match(/exceeds maximum supported index \(10000\)/, error["message"])
    assert_equal({ "items" => %w[a] }, session.surface("s").data)
    assert_equal 0, session.surface("s").version, "a refused write changes nothing"
  end

  def test_rejections_become_renderer_to_agent_errors
    session = A2UI::Session.new
    session.apply({ "version" => "1.0", "createSurface" => { "surfaceId" => "s" } })

    assert_empty session.apply({ "version" => "v0.9", "deleteSurface" => { "surfaceId" => "s" } })
    assert_empty session.apply({ "version" => "1.0",
                                 "updateComponents" => { "surfaceId" => "nope", "components" => [] } })
    assert_empty session.apply({ "version" => "1.0", "createSurface" => { "surfaceId" => "s" } })
    assert_empty session.apply({ "version" => "1.0", "updateDataModel" => { "surfaceId" => "s", "path" => "/a" } })
    assert_empty session.apply({ "version" => "1.0",
                                 "updateComponents" => { "surfaceId" => "s", "components" => "x" } })
    assert_empty session.apply({ "version" => "1.0", "updateComponents" => { "surfaceId" => "s" },
                                 "deleteSurface" => { "surfaceId" => "s" } })
    assert_empty session.apply("junk")
    assert_empty session.apply({ "version" => "1.0", "createSurface" => "junk" })

    codes = session.errors.map { |error| error.dig("error", "code") }

    assert_equal %w[INVALID_MESSAGE UNKNOWN_SURFACE DUPLICATE_SURFACE INVALID_MESSAGE INVALID_MESSAGE INVALID_MESSAGE
                    INVALID_MESSAGE INVALID_MESSAGE], codes
    assert(session.errors.all? { |error| error["version"] == "1.0" })
    assert_equal "nope", session.errors[1].dig("error", "surfaceId")
  end

  def test_errors_carry_the_surface_and_a_validation_error_its_path
    session = A2UI::Session.new
    session.apply({ "version" => "1.0",
                    "createSurface" => { "surfaceId" => "s", "catalogId" => A2UI::Catalogs::Basic::ID } })
    session.apply({ "version" => "1.0", "updateComponents" => { "surfaceId" => "s",
                                                                "components" => [{ "id" => "a", "component" => "Column",
                                                                                   "children" => ["a"] }] } })
    error = session.errors.last["error"]

    assert_equal "RECURSION_ERROR", error["code"]
    assert_equal "s", error["surfaceId"]
    assert_match(/Self-reference detected/, error["message"])
    refute error.key?("path"), "only VALIDATION_FAILED carries a path"
    session.apply({ "version" => "1.0",
                    "updateComponents" => { "surfaceId" => "s", "components" => [{ "id" => "b" }] } })

    assert_equal({ "code" => "VALIDATION_FAILED", "surfaceId" => "s", "path" => "/components/0/component",
                   "message" => "Cannot create component b without a type" },
                 session.errors.map { |message| message["error"] }.find { |body| body["code"] == "VALIDATION_FAILED" })
  end

  def response_error(session) = session.responses.last.dig("rendererFunctionResponse", "error")

  def test_a_refused_call_is_answered_inside_its_response
    session = A2UI::Session.new
    session.apply(rpc("f1", { "@call" => "getScreenResolution", "catalogId" => "x" }))

    assert_equal({ "code" => "INVALID_FUNCTION_CALL", "message" => "Catalog not found: x" }, response_error(session),
                 "a call names its catalog, and there is no fallback")
    assert_equal "f1", session.responses.last.dig("rendererFunctionResponse", "functionCallId")

    session.apply(rpc("f2", { "@call" => "required", "catalogId" => A2UI::Catalogs::Basic::ID,
                              "args" => { "value" => 1 } }))

    assert_equal "Function 'required' is not invocable by an agent.", response_error(session)["message"]
    session.apply(rpc("f3", { "@call" => "required", "args" => { "value" => 1 } }))

    assert_equal "callRendererFunction.callFunction.catalogId is required",
                 session.errors.last.dig("error", "message")
    assert_equal 2, session.responses.size
    assert_empty session.apply({ "version" => "1.0",
                                 "agentFunctionResponse" => { "functionCallId" => "f4", "value" => 1 } })
  end

  def test_agent_callable_functions_answer_with_a_response
    functions = A2UI::Functions.new
    functions.define("screen", description: "The screen size.", returns: "string", callers: "rendererOrAgent",
                               params: { "unit" => { "type" => "string" } }) do |args, _|
      "1280x800#{args["unit"]}"
    end
    functions.define("shout", description: "Upcases.", returns: "string", callers: "agentOnly",
                              required: %w[value]) { |args, _| args["value"].to_s.upcase }
    functions.define("open", description: "Opens a page.", returns: "void", callers: "rendererOrAgent",
                             activation: true) { |_, _| "opened" }
    catalog = A2UI::Catalogs::Basic.new
    catalog.define_singleton_method(:functions) { functions }
    session = A2UI::Session.new(catalogs: { "https://example.com/cat.json" => catalog })
    call = ->(name, args = {}) { { "@call" => name, "catalogId" => "https://example.com/cat.json", "args" => args } }
    session.apply(rpc("f1", call.call("screen", { "unit" => "px" })))
    session.apply(rpc("f2", call.call("shout")))
    session.apply(rpc("f3", call.call("screen", { "unit" => 5 })))
    session.apply(rpc("f4", call.call("open")))
    session.apply(rpc("f5", call.call("open")), user_activated: true)

    answers = session.responses.map { |response| response["rendererFunctionResponse"] }

    assert_equal({ "functionCallId" => "f1", "value" => "1280x800px" }, answers[0])
    assert_equal "shout: missing value", answers[1].dig("error", "message")
    assert_equal "Invalid argument 'unit' for screen: expected string", answers[2].dig("error", "message")
    assert_equal "Function 'open' requires user activation context to execute.", answers[3].dig("error", "message")
    assert_equal "opened", answers[4]["value"], "a call that answers the user's gesture may open"
    assert(session.responses.all? { |response| response["version"] == "1.0" })
  end

  def test_a_function_that_raises_answers_an_execution_error
    functions = A2UI::Functions.new
    functions.define("lookup", description: "Looks up a record.", returns: "string",
                               callers: "rendererOrAgent") { |_, _| raise "connection refused to 10.0.0.5" }
    catalog = A2UI::Catalogs::Basic.new
    catalog.define_singleton_method(:functions) { functions }
    session = A2UI::Session.new(catalogs: { "https://example.com/cat.json" => catalog })

    assert_empty session.apply(rpc("f1", { "@call" => "lookup", "catalogId" => "https://example.com/cat.json" }))
    expected = { "code" => "EXECUTION_ERROR",
                 "message" => "An error occurred during function execution (RuntimeError)." }

    assert_equal expected, response_error(session), "the exception's own message stays with the host"
    assert_empty session.errors
  end

  def test_capabilities_and_the_renderer_data_model_by_version
    session = A2UI::Session.new
    v09 = A2UI::Catalogs::Basic::V0_9_IDS.first
    session.apply_all([{ "version" => "1.0", "createSurface" => { "surfaceId" => "a", "sendDataModel" => true,
                                                                  "dataModel" => { "n" => 1 } } },
                       { "version" => "v0.9", "createSurface" => { "surfaceId" => "b", "catalogId" => v09,
                                                                   "sendDataModel" => true } },
                       { "version" => "1.0", "createSurface" => { "surfaceId" => "c" } }])

    assert_includes session.capabilities["1.0"]["supportedCatalogIds"], A2UI::Catalogs::Basic::ID
    assert_includes session.capabilities["v0.9"]["supportedCatalogIds"], v09
    refute_includes session.capabilities["v0.9"]["supportedCatalogIds"], A2UI::Catalogs::Basic::ID
    assert_equal({ "version" => "1.0", "surfaces" => { "a" => { "n" => 1 } } },
                 session.renderer_data_model(version: "1.0"))
    assert_equal({ "version" => "v0.9", "surfaces" => { "b" => {} } }, session.renderer_data_model(version: "v0.9"))
    assert_nil A2UI::Session.new.renderer_data_model(version: "1.0")
  end

  def test_middleware_activities_build_then_replay_whole
    session = A2UI::Session.new
    create = { "version" => "v0.9",
               "createSurface" => { "surfaceId" => "signup", "catalogId" => A2UI::Catalogs::Basic::V0_9_IDS.last } }
    components = { "version" => "v0.9", "updateComponents" => { "surfaceId" => "signup", "components" => [
      { "id" => "root", "component" => "Text", "text" => { "path" => "/greeting" } }
    ] } }
    data = { "version" => "v0.9",
             "updateDataModel" => { "surfaceId" => "signup", "value" => { "greeting" => "Hi" } } }

    assert_empty session.apply_activity({ "status" => "building", "progressTokens" => 20 })
    assert_equal({ "status" => "building", "progressTokens" => 20 }, session.status)
    assert_equal ["signup"], session.apply_activity({ "a2ui_operations" => [create, components] })
    assert_equal ["signup"], session.apply_activity({ "a2ui_operations" => [create, components, data] })
    assert_empty session.errors, "a replacing snapshot repeats its createSurface"
    assert_equal "Hi", session.surface("signup").resolve({ "path" => "/greeting" })

    session.apply(create)

    assert_equal "DUPLICATE_SURFACE", session.errors.last.dig("error", "code"),
                 "outside an activity a repeat is a duplicate"
  end

  def test_delete_surface
    session = A2UI::Session.new
    session.apply({ "version" => "1.0", "createSurface" => { "surfaceId" => "s" } })

    assert_equal ["s"], session.apply({ "version" => "1.0", "deleteSurface" => { "surfaceId" => "s" } })
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

    assert_equal({ "version" => "1.0",
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
    session.apply({ "version" => "1.0", "createSurface" => {
                    "surfaceId" => "p", "catalogId" => A2UI::Catalogs::Basic::ID, "sendDataModel" => true,
                    "dataModel" => { "news" => true, "toppings" => [], "volume" => 1, "rows" => [{ "n" => 1 }] },
                    "components" => [
                      { "id" => "root", "component" => "Column", "children" => %w[news toppings volume list] },
                      { "id" => "news", "component" => "CheckBox", "label" => "News",
                        "value" => { "@path" => "/news" } },
                      { "id" => "toppings", "component" => "ChoicePicker", "label" => "T",
                        "variant" => "multipleSelection",
                        "options" => [], "value" => { "@path" => "/toppings" } },
                      { "id" => "volume", "component" => "Slider", "label" => "V", "max" => 10,
                        "value" => { "@path" => "/volume" } },
                      { "id" => "list", "component" => "List",
                        "children" => { "componentId" => "row", "path" => "/rows" } },
                      { "id" => "row", "component" => "Button", "child" => "lbl",
                        "action" => { "event" => { "name" => "pick", "userMessage" => "Picked",
                                                   "context" => { "n" => { "@path" => "n" },
                                                                  "all" => { "@path" => "/rows" } } } } },
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
    session.apply({ "version" => "1.0", "createSurface" => {
                    "surfaceId" => "f", "catalogId" => A2UI::Catalogs::Basic::ID, "sendDataModel" => true,
                    "dataModel" => { "formData" => { "terms" => "", "email" => "", "phone" => "" } },
                    "components" => [
                      { "id" => "root", "component" => "Column", "children" => %w[email submit] },
                      { "id" => "email", "component" => "TextField", "label" => "Email",
                        "value" => { "@path" => "/formData/email" },
                        "checks" => [{ "condition" => { "@call" => "email",
                                                        "args" => { "value" => { "@path" => "/formData/email" } } },
                                       "message" => "Invalid email format" }] },
                      { "id" => "submit", "component" => "Button", "child" => "l",
                        "action" => { "event" => { "name" => "submit_form" } },
                        "checks" => [{ "condition" => { "@call" => "and", "args" => { "values" => [
                          { "@call" => "required", "args" => { "value" => { "@path" => "/formData/terms" } } },
                          { "@call" => "or", "args" => { "values" => [
                            { "@call" => "required", "args" => { "value" => { "@path" => "/formData/email" } } },
                            { "@call" => "required", "args" => { "value" => { "@path" => "/formData/phone" } } }
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
    assert_equal A2UI::Functions::EMAIL_FAILURE["message"], rejected.errors["email"].first[:message],
                 "the result's message wins; the rule's is the fallback"
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
    button = { "id" => "root", "component" => "Button", "child" => "t",
               "action" => { "functionCall" => { "@call" => "openUrl" } } }
    session.apply({ "version" => "1.0",
                    "createSurface" => { "surfaceId" => "p", "catalogId" => A2UI::Catalogs::Basic::ID,
                                         "components" => [button, { "id" => "t", "component" => "Text",
                                                                    "text" => "x" }] } })

    assert_nil session.action(surface_id: "p", source: "root")
    assert_nil session.action(surface_id: "p", source: "missing")
    assert_nil session.action(surface_id: "nope", source: "root")
  end

  def test_capabilities_inline_each_version_s_catalogs_in_its_shape
    v09 = A2UI::Catalogs::Basic::V0_9_IDS.first
    session = A2UI::Session.new(catalogs: { A2UI::Catalogs::Basic::ID => A2UI::Catalogs::Basic.new,
                                            A2UI::Catalog::DEFAULT_ID => A2UI::Catalogs::Native.new,
                                            v09 => A2UI::Catalogs::Basic.new(dialect: A2UI::Dialect::V0_9) })

    refute session.capabilities["1.0"].key?("inlineCatalogs"), "ids alone by default"
    inline = session.capabilities(inline: true)
    current = inline["1.0"]["inlineCatalogs"]

    assert_equal([A2UI::Catalogs::Basic::ID, A2UI::Catalog::DEFAULT_ID], current.map { |catalog| catalog["catalogId"] })
    assert_equal "Text", current.first["components"].keys.first, "a v1.0 catalog is its document"
    assert current.last["components"].key?("Button"), "Poetry's catalog is its document too"
    assert_equal "https://json-schema.org/draft/2020-12/schema", current.last["$schema"]
    legacy = inline["v0.9"]["inlineCatalogs"]

    assert_equal([v09], legacy.map { |catalog| catalog["catalogId"] })
    assert legacy.first["components"]["Text"].key?("allOf"), "a v0.9 catalog is inlined in the legacy shape"
    assert_kind_of Array, legacy.first["functions"]
    assert_equal({ "name" => "required", "returnType" => "boolean" },
                 legacy.first["functions"].find do |function|
                   function["name"] == "required"
                 end.slice("name", "returnType"))
  end
end
