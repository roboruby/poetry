# frozen_string_literal: true

# The conformance harness's half for calls to the agent's functions (A2UI
# v1.0's `callAgentFunction`): the routing suite's `route_agent_function`
# cases, and the `handle_rpc` cases that send a call or play a surface
# through one. Poetry evaluates a binding again whenever its surface
# changes, so the harness does too: every binding and check rule of a case
# is read again after a step that changed the surface, and a problem an
# evaluation meets is counted the first time that evaluation meets it.
module A2UIConformance
  # A catalog whose functions are a case's: the basic ones it names, and the agent's declared without code.
  class RoutingCatalog < A::Catalogs::Basic
    def initialize(functions, dialect:)
      super(dialect: dialect)
      @functions = functions
    end

    attr_reader :functions
  end

  # One binding or check rule a routing case evaluates: what it last read and the problems it last met.
  Reading = Struct.new(:kind, :node, :value, :problems, keyword_init: true)

  module_function

  # ---- route_agent_function

  def run_route_agent_function(test_case)
    dialect = A::Dialect.for(wire(version_of(test_case)))
    spec = test_case["surface"] || {}
    session = A::Session.new(catalogs: routing_catalogs(test_case["catalogs"], dialect),
                             agent_functions: spec["outboundListener"] != false)
    create = { "surfaceId" => "main" }
    create["catalogId"] = spec["catalogId"] if spec.key?("catalogId")
    session.apply({ "version" => dialect.version, "createSurface" => create })
    if test_case.key?("dataModel")
      session.apply({ "version" => dialect.version,
                      "updateDataModel" => { "surfaceId" => "main", "path" => "/",
                                             "value" => test_case["dataModel"] } })
    end
    fail!("the surface was not created: #{session.errors.last.inspect}") unless session.surface("main")

    state = { session: session, readings: [], actions: [], sent: [], seen: session.errors.size, dispatched: 0 }
    Array(test_case["steps"]).each_with_index { |step, index| route_step(state, step, index) }
  end

  # A case's catalogs: each one's local functions run the basic set's, its agent functions are declarations.
  def routing_catalogs(list, dialect)
    Array(list).to_h do |entry|
      registry = A::Functions.new
      Array(entry["localFunctions"]).each do |name|
        registry.define(name, description: name, returns: "any") do |args, evaluator|
          A::Functions.basic.call(name, args, evaluator)
        end
      end
      (entry["agentFunctions"] || {}).each do |name, declared|
        registry.define(name, description: name, returns: declared["returnType"] || "any", schema: declared["args"],
                              activation: declared["requiresUserActivation"] == true,
                              callers: declared["allowedCallers"] || "rendererOnly")
      end
      [entry["catalogId"], RoutingCatalog.new(registry, dialect: dialect)]
    end
  end

  def route_step(state, step, index)
    session = state[:session]
    found = []
    if step.key?("evaluate") then route_evaluate(state, step, found)
    elsif step.key?("respond") then route_respond(state, step["respond"], found)
    elsif step.key?("updateData")
      session.apply({ "version" => "1.0", "updateDataModel" => { "surfaceId" => "main" }.merge(step["updateData"]) })
      reread(state, found)
    elsif step["cancelSurfaceCalls"] then session.cancel_agent_calls("main")
    elsif step["deleteSurface"] then session.apply({ "version" => "1.0", "deleteSurface" => { "surfaceId" => "main" } })
    else fail!("step #{index}: nothing to do in #{step.keys.inspect}")
    end
    route_check(state, step, index, found)
  end

  # Evaluates a step's call the way it names: a binding, a check rule's condition, an action's call or its event.
  def route_evaluate(state, step, found)
    session = state[:session]
    surface = session.surface("main")
    case step["as"] || "binding"
    when "binding", "check"
      kind = step["as"] == "check" ? :check : :binding
      state[:readings] << Reading.new(kind: kind, node: step["evaluate"], problems: nil)
      reread(state, found)
    when "action"
      state[:actions] << session.send(:start,
                                      A::Session::Step.new(surface: surface, call: step["evaluate"], local: true))
    when "event"
      state[:actions] << session.send(:start, A::Session::Step.new(surface: surface, event: step["evaluate"],
                                                                   source: "source", timestamp: Time.now.utc,
                                                                   context: {}, at: 0))
    end
  end

  def route_respond(state, respond, found)
    sent = state[:sent][respond["call"]] or fail!("the case answers call #{respond["call"]}, which was never sent")
    body = { "functionCallId" => sent.dig("callAgentFunction", "functionCallId") }
    respond.key?("error") ? body["error"] = respond["error"] : body["value"] = respond["value"]
    changed = state[:session].apply({ "version" => "1.0", "agentFunctionResponse" => body })
    reread(state, found) if changed.include?("main")
  end

  # Reads every binding and check rule again, as a render does, noting the problems an evaluation had not met before.
  def reread(state, found)
    surface = state[:session].surface("main") or return
    state[:readings].each do |reading|
      evaluator = A::Evaluator.new(surface, nil, waits: :binding)
      reading.value = if reading.kind == :check
                        A::Checks.failures({ "checks" => [{ "condition" => reading.node }] }, evaluator).empty?
                      else
                        evaluator.resolve(reading.node)
                      end
      problems = evaluator.problems.map { |problem| problem.slice(:code, :message) }
      found.concat(problems) unless problems == reading.problems
      reading.problems = problems
    end
  end

  def route_check(state, step, index, found)
    session = state[:session]
    sent = session.agent_calls.shift(session.agent_calls.size)
    state[:sent].concat(sent)
    route_check_outbound(step, index, sent)
    reported = session.errors[state[:seen]..].map do |error|
      { code: error["error"]["code"], message: error["error"]["message"] }
    end
    state[:seen] = session.errors.size
    route_check_errors(step, index, reported + found)
    route_check_values(state, step, index)
    route_check_actions(state, step, index)
  end

  def route_check_outbound(step, index, sent)
    bodies = sent.map { |message| message["callAgentFunction"] }
    unless bodies.all? { |b| b["surfaceId"] == "main" }
      fail!("step #{index}: a call names surface #{bodies.map do |b|
        b["surfaceId"]
      end.inspect}")
    end
    got = bodies.map { |body| body["callFunction"] }
    want = step["expectOutbound"] || []
    if step["outboundInAnyOrder"]
      got = got.sort_by { |call| JSON.generate(call) }
      want = want.sort_by { |call| JSON.generate(call) }
    end
    return if got.size == want.size && got.zip(want).all? { |left, right| deep_eq(left, right) }

    fail!("step #{index}: sent #{JSON.generate(got)[0, 220]}, expected #{JSON.generate(want)[0, 220]}")
  end

  def route_check_errors(step, index, got)
    want = step["expectErrors"] || []
    matches = got.size == want.size && got.zip(want).all? do |error, expected|
      said = expected["message"]
      error[:code] == expected["code"] && (said.nil? || error[:message].to_s.include?(said))
    end
    return if matches

    fail!("step #{index}: reported #{got.map { |e| "#{e[:code]} #{e[:message].to_s[0, 70]}" }.inspect}, " \
          "expected #{JSON.generate(want)[0, 200]}")
  end

  def route_check_values(state, step, index)
    return unless step.key?("expectValues")

    got = state[:readings].map(&:value)
    return if got.size == step["expectValues"].size && got.zip(step["expectValues"]).all? { |l, r| deep_eq(l, r) }

    fail!("step #{index}: values #{got.inspect}, expected #{step["expectValues"].inspect}")
  end

  def route_check_actions(state, step, index)
    # By identity: two actions dispatched in the same millisecond are equal as records.
    ready = state[:actions].select(&:valid?)
    done = state.fetch(:done, [])
    fresh = ready.reject { |action| done.any? { |held| held.equal?(action) } }
    state[:done] = ready
    want = step["expectActions"] || []
    matches = fresh.size == want.size && fresh.zip(want).all? do |action, expected|
      body = action.message["action"]
      body["name"] == expected["name"] && deep_eq(body["context"], expected["context"] || {}) &&
        (!expected.key?("userMessage") || body["userMessage"] == expected["userMessage"])
    end
    return if matches

    fail!("step #{index}: dispatched #{fresh.map do |a|
      a.message["action"].slice("name", "context", "userMessage")
    end.inspect}, " \
          "expected #{want.inspect}")
  end

  # ---- handle_rpc: a call the renderer makes itself

  def run_agent_rpc(test_case)
    args = test_case["args"]
    outbound = args["outboundCall"]
    session = A::Session.new(agent_functions: args["outboundListener"] != false)
    call = agent_rpc_call(session, outbound)
    second = args["secondOutboundCall"] && agent_rpc_call(session, args["secondOutboundCall"])
    session.expire_agent_calls(Process.clock_gettime(Process::CLOCK_MONOTONIC) + 60) if outbound["timeoutMs"]
    session.cancel_agent_calls(outbound["surfaceId"]) if args["afterCall"] == "cancel"
    session.dispose_agent_calls if args["afterCall"] == "dispose"
    session.apply(args["inboundResponse"]) if args["inboundResponse"]
    held = [call.state, call.value, call.error]
    session.apply(args["lateInboundResponse"]) if args["lateInboundResponse"]
    check_agent_rpc(test_case, session, call, second, held)
  end

  def agent_rpc_call(session, outbound)
    function = outbound["callFunction"]
    session.call_agent_function(surface_id: outbound["surfaceId"], catalog_id: function["catalogId"],
                                name: function["@call"], args: function["args"] || {}, id: outbound["functionCallId"],
                                timeout: outbound["timeoutMs"] && (outbound["timeoutMs"] / 1000.0))
  end

  def check_agent_rpc(test_case, session, call, second, held)
    expect = test_case["expect"] || {}
    if expect.key?("correlatedCallId") && call.id != expect["correlatedCallId"]
      fail!("the call's id is #{call.id.inspect}, expected #{expect["correlatedCallId"].inspect}")
    end
    if expect.key?("result") && !(call.state == :settled && deep_eq(call.value, expect["result"]))
      fail!("the call is #{call.state} with #{call.value.inspect}, expected #{expect["result"].inspect}")
    end
    judged = second || call
    if expect.key?("code") && judged.error&.[]("code") != expect["code"]
      fail!("the call ended #{judged.error.inspect}, expected #{expect["code"]}")
    end
    if (flight = expect["inFlightError"]) && call.error&.[]("code") != flight["code"]
      fail!("the call in flight ended #{call.error.inspect}, expected #{flight["code"]}")
    end
    if expect["lateResponseIgnored"] && held != [call.state, call.value, call.error]
      fail!("a late answer changed the call: #{held.inspect} became #{[call.state, call.value, call.error].inspect}")
    end
    return unless (after = test_case["expectError"]) && after["code"]

    # After a dispose the case's error is a later call's; anywhere else it is how the judged call ended.
    if test_case.dig("args", "afterCall") == "dispose"
      judged = session.call_agent_function(surface_id: call.surface_id, catalog_id: call.catalog_id, name: call.name)
    end
    return if judged.error&.[]("code") == after["code"]

    fail!("the call ended #{judged.error.inspect}, expected #{after["code"]}")
  end

  # ---- handle_rpc: a surface played through a call

  # The basic catalog with a scenario's local functions, each doing what the case says it does.
  class ScenarioCatalog < A::Catalogs::Basic
    def initialize(local, dialect:)
      super(dialect: dialect)
      @functions = A::Functions.basic.dup
      (local || {}).each do |name, declared|
        @functions.define(name, description: name, returns: declared["returnType"] || "any") do |_args, evaluator|
          effect = declared.dig("effect", "setData")
          evaluator.surface.update_data(effect["path"], effect["value"]) if effect
          true
        end
      end
    end

    attr_reader :functions
  end

  def scenario_session(scenario)
    catalog = ScenarioCatalog.new(scenario["localFunctions"], dialect: A::Dialect::V1_0)
    session = A::Session.new(catalogs: { scenario["catalogId"] => catalog }, agent_functions: true)
    session.apply({ "version" => "1.0",
                    "createSurface" => { "surfaceId" => scenario["surfaceId"], "catalogId" => scenario["catalogId"] } })
    session
  end

  def scenario_answer(session, scenario)
    sent = session.agent_calls.first or fail!("nothing was sent to the agent")
    body = { "functionCallId" => sent.dig("callAgentFunction", "functionCallId") }
    if scenario.key?("inboundResponseError") then body["error"] = scenario["inboundResponseError"]
    else body["value"] = scenario["inboundResponseValue"]
    end
    session.apply({ "version" => "1.0", "agentFunctionResponse" => body })
    sent
  end

  def check_scenario(test_case, session, sent, surface_id)
    expect = test_case["expect"]
    if (want = expect["outboundCall"])
      got = { "version" => sent["version"],
              "callAgentFunction" => sent["callAgentFunction"].except("functionCallId") }
      fail!("sent #{JSON.generate(got)[0, 240]}, expected #{JSON.generate(want)[0, 240]}") unless deep_eq(got, want)
    end
    if (want = expect["dataModel"]) && !deep_eq(session.surface(surface_id).data, want)
      fail!("data model #{JSON.generate(session.surface(surface_id).data)}, expected #{JSON.generate(want)}")
    end
    return unless (want = expect["surfaceError"])

    error = session.errors.last&.fetch("error") or fail!("no error was reported; expected #{want["code"]}")
    id = sent.dig("callAgentFunction", "functionCallId")
    return if error["code"] == want["code"] && (!want.key?("functionCallId") || error["functionCallId"] == id)

    fail!("reported #{error.inspect}, expected #{want["code"]} for call #{id}")
  end

  def run_ui_binding(test_case)
    scenario = test_case.dig("args", "uiBindingScenario")
    session = scenario_session(scenario)
    components = scenario["components"] || [scenario["component"]]
    id = scenario["surfaceId"]
    session.apply({ "version" => "1.0", "updateComponents" => { "surfaceId" => id, "components" => components } })
    surface = session.surface(id)
    observed = surface.component(scenario.dig("observe", "componentId") || components.first["id"])
    property = scenario.dig("observe", "property") || observed.keys.find { |key| surface.function_call?(observed[key]) }
    read = -> { property && surface.resolve(observed[property], nil, waits: :binding) }
    expect = test_case["expect"]
    first = read.call
    failing = surface.failures
    early = expect.key?("initialValue") && !deep_eq(first, expect["initialValue"])
    fail!("the binding is #{first.inspect} before the answer") if early
    fail!("a rule that waits on the agent fails: #{failing.inspect}") if failing.any?

    sent = scenario_answer(session, scenario)
    check_scenario(test_case, session, sent, id)
    if expect.key?("resolvedValue") && !deep_eq(read.call, expect["resolvedValue"])
      fail!("the binding is #{read.call.inspect} after the answer, expected #{expect["resolvedValue"].inspect}")
    end
    (expect["siblings"] || {}).each do |sibling, properties|
      properties.each do |name, value|
        got = surface.resolve(surface.component(sibling)[name], nil, waits: :binding)
        fail!("sibling #{sibling}.#{name} is #{got.inspect}, expected #{value.inspect}") unless deep_eq(got, value)
      end
    end
    return unless (want = expect["validationResult"])

    failure = surface.failures.values.flatten.first
    got = if failure
            { "valid" => false, "message" => failure[:message],
              "severity" => failure[:severity] || "error" }
          else
            { "valid" => true }
          end
    fail!("the rule reads #{got.inspect}, expected #{want.inspect}") unless want.all? { |key, value| got[key] == value }
  end

  def run_ui_action(test_case)
    scenario = test_case.dig("args", "uiActionFallbackScenario")
    session = scenario_session(scenario)
    id = scenario["surfaceId"]
    button = { "id" => "root", "component" => "Button", "child" => "label", "action" => scenario["actionPayload"] }
    session.apply({ "version" => "1.0",
                    "updateComponents" => { "surfaceId" => id,
                                            "components" => [button,
                                                             { "id" => "label", "component" => "Text",
                                                               "text" => "Go" }] } })
    action = session.action(surface_id: id,
                            source: "root") or fail!("the action did not start: #{session.errors.last.inspect}")
    fail!("the action does not wait on the agent") unless action.pending?

    sent = scenario_answer(session, scenario)
    fail!("the action still waits after the answer") if action.pending?
    check_scenario(test_case, session, sent, id)
    expect = test_case["expect"]
    return unless expect.key?("result") && !deep_eq(action.value, expect["result"])

    fail!("the action answered #{action.value.inspect}, expected #{expect["result"].inspect}")
  end
end
