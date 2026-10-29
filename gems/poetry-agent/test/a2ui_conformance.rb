# frozen_string_literal: true

require "json"
require "yaml"

# Runs one case of A2UI's language-agnostic conformance suites
# (test/fixtures/a2ui/upstream/conformance/core) against Poetry's renderer
# and raises Failure with the reason when Poetry's answer differs. The pass
# criteria follow the official runners: expressions compare parts with
# adjacent literals joined; an expected error needs its category and a
# message match; `validate` resolves every rendered component after each
# step; surface expectations compare by deep equality or Python's str().
# The harness binds the basic catalog to any catalogId a case names, as the
# official harnesses do, except in a case that expects a CatalogError.
module A2UIConformance
  A = Poetry::Agent::A2UI
  ROOT = File.expand_path("fixtures/a2ui/upstream", __dir__)

  # The suites a renderer runs (the others test an SDK's generated models,
  # catalog loader, reactive node layer or v0.8, or need a browser).
  SUITES = %w[actions composition_constraints data_context data_deletion data_model data_model_pointers expressions
              functions index_function message_processor_v0_9 message_processor_v1_0 multi_catalog reserved_keys
              rpc_functions validation_result validator_v0_9 validator_v1_0].freeze

  # A suite's error categories and the ones that satisfy each.
  ACCEPTS = { "ParseError" => %w[ParseError ExpressionError], "IntegrityError" => %w[IntegrityError RecursionError] }
            .freeze

  # Poetry's renderer-to-agent error codes, read as the suite's categories.
  CODE_CATEGORY = { "VALIDATION_FAILED" => "ValidationError", "INVALID_MESSAGE" => "ValidationError",
                    "DUPLICATE_SURFACE" => "IntegrityError", "UNKNOWN_SURFACE" => "IntegrityError",
                    "INVALID_FUNCTION_CALL" => "ValidationError", "DATA_ERROR" => "DataError",
                    "EXECUTION_ERROR" => "ExecutionError", "CATALOG_ERROR" => "CatalogError" }.freeze

  # What a case expected and Poetry did instead.
  class Failure < StandardError; end

  # A call naming a catalog the surface cannot resolve, as Poetry's updateComponents check reports it.
  class CatalogProblem < StandardError; end

  # An error Poetry raised or reported, as a suite category.
  Raised = Struct.new(:category, :message, :source, keyword_init: true)

  module_function

  # The cases of one suite.
  def cases(suite)
    YAML.safe_load_file(File.join(ROOT, "conformance", "core", "#{suite}.yaml"), aliases: true)
  end

  # Runs a case: nil when Poetry passes it, Failure otherwise.
  def run(test_case)
    send(:"run_#{test_case["action"]}", test_case)
    nil
  rescue NoMethodError => e
    raise unless e.name.to_s.start_with?("run_")

    raise Failure, "no handler for action #{test_case["action"]}"
  end

  def fail!(reason) = raise(Failure, reason)

  # The protocol version a case targets: declared, then the catalog's, then
  # its first message's, then a version-named catalog id, else v0.9 (as both
  # official harnesses default).
  def version_of(test_case)
    version = test_case["protocolVersion"]
    version ||= test_case["catalog"]["protocolVersion"] if test_case["catalog"].is_a?(Hash)
    version ||= messages_of(test_case).filter_map { |message| message["version"] }.first
    version ||= test_case.dig("args", "message", "version")
    id = (test_case["catalogId"] || (test_case["catalog"].is_a?(Hash) && test_case["catalog"]["catalogId"])).to_s
    version ||= "0.9" if id.match?(/v0_9|v09/)
    version ||= "1.0" if id.match?(/v1_0|v10/)
    label = (version || "0.9").to_s.delete_prefix("v")
    label.start_with?("0.") ? "v#{label}" : label
  end

  def at_least_v1?(version) = version.to_s.delete_prefix("v").split(".").first.to_i >= 1

  # The case's version as a message's `version` field.
  def wire(version) = at_least_v1?(version) ? "1.0" : version.to_s.sub(/\A(?=0)/, "v")

  def messages_of(node)
    case node
    when Array then node.grep(Hash)
    when Hash
      if node["steps"].is_a?(Array) then node["steps"].flat_map { |step| messages_of(step) }
      elsif node.key?("messages") || node.key?("payload")
        raw = node["messages"] || node["payload"]
        raw = raw["messages"] if raw.is_a?(Hash) && raw["messages"].is_a?(Array)
        raw.is_a?(Hash) ? [raw] : Array(raw).grep(Hash)
      else []
      end
    else []
    end
  end

  def deep_copy(value) = JSON.parse(JSON.generate(value))

  # Deep equality with integers and floats compared numerically (JS and Dart semantics).
  def deep_eq(left, right)
    case left
    when Hash then right.is_a?(Hash) && left.keys.sort == right.keys.sort && left.all? { |k, v| deep_eq(v, right[k]) }
    when Array then right.is_a?(Array) && left.size == right.size && left.zip(right).all? { |x, y| deep_eq(x, y) }
    when Integer, Float then right.is_a?(Numeric) && left == right
    else left == right && left.instance_of?(right.class)
    end
  end

  # Python's str() of a value, for the harness's `str(actual) == str(expected)` comparisons.
  def py_str(value)
    case value
    when nil then "None"
    when true then "True"
    when false then "False"
    when Float then value.finite? && value == value.floor && value.abs < 1e16 ? "#{value.to_i}.0" : value.to_s
    when Hash then "{#{value.map { |k, v| "#{py_repr(k)}: #{py_repr(v)}" }.join(", ")}}"
    when Array then "[#{value.map { |v| py_repr(v) }.join(", ")}]"
    else value.to_s
    end
  end

  def py_repr(value) = value.is_a?(String) ? "'#{value}'" : py_str(value)

  # The official harnesses' message matching: a substring or regex match, plus their schema-wording equivalences.
  def message_matches?(expected, actual)
    return true if expected.nil? || expected.to_s.empty?

    expected = expected.to_s
    actual = actual.to_s
    begin
      return true if actual.include?(expected) || actual.match?(Regexp.new(expected))
    rescue RegexpError
      nil
    end
    wanted = expected.downcase
    said = actual.downcase
    [wanted.include?("not of type") && (said.include?("input should be") || said.include?("must be a")),
     wanted.include?("is a required property") && (said.include?("field required") || said.include?("missing")),
     wanted.include?("additional properties are not allowed") && said.include?("extra"),
     wanted.include?("circular") && (said.include?("circular") || said.include?("self-reference")),
     wanted.include?("orphan") && said.include?("orphan"),
     wanted.include?("was unexpected") && (said.include?("unrecognized") || said.include?("unexpected"))].any?
  end

  def expect_error!(expected, raised)
    expected = { "category" => nil, "message" => expected } unless expected.is_a?(Hash)
    category = expected["category"]
    message = expected["message"]
    fail!("expected #{category || "an error"} #{message.inspect}; Poetry reported nothing") if raised.nil?
    if category && !Array(ACCEPTS.fetch(category, category)).include?(raised.category)
      fail!("expected #{category} #{message.inspect}; Poetry reported #{raised.category} " \
            "#{raised.message.inspect} (#{raised.source})")
    end
    return if message_matches?(message, raised.message)

    fail!("#{raised.category} as expected, but the message differs: expected /#{message}/, " \
          "Poetry said #{raised.message.inspect} (#{raised.source})")
  end

  def reported(error)
    body = error["error"] || {}
    Raised.new(category: CODE_CATEGORY.fetch(body["code"], "ValidationError"), message: body["message"].to_s,
               source: "error #{body["code"]}")
  end

  # ---- parse_expression_template

  def node_to_part(node)
    case node[0]
    when :text, :literal then node[1]
    when :path then { "path" => node[1] }
    when :call
      { "call" => node[1], "args" => node[2].transform_values { |item| node_to_part(item) }, "returnType" => "any" }
    when :template then node[1].map { |item| node_to_part(item) }
    end
  end

  def join_literals(parts)
    joined = parts.compact.each_with_object([]) do |part, out|
      part.is_a?(String) && out.last.is_a?(String) ? out[-1] += part : out << part
    end
    joined.reject { |part| part == "" }
  end

  def run_parse_expression_template(test_case)
    expected_error = test_case["expect_error"] || test_case["expectError"]
    begin
      tree = A::Expression.parse(test_case["input"].to_s)
    rescue A::Expression::SyntaxError => e
      fail!("parse raised #{e.message.inspect}; expected #{JSON.generate(test_case["expect"])}") unless expected_error

      return expect_error!(expected_error, Raised.new(category: "ParseError", message: e.message, source: "parse"))
    end
    actual = join_literals(tree[1].map { |node| node_to_part(node) })
    fail!("parsed #{JSON.generate(actual)[0, 200]}; expected #{expected_error}") if expected_error
    return if deep_eq(actual, test_case["expect"])

    fail!("parsed #{JSON.generate(actual)[0, 300]}, expected #{JSON.generate(test_case["expect"])[0, 300]}")
  end

  # ---- sessions and messages

  def catalog_error_case?(test_case)
    [test_case, *Array(test_case["steps"])].any? do |node|
      node.is_a?(Hash) && node["expectError"].is_a?(Hash) && node["expectError"]["category"] == "CatalogError"
    end
  end

  # A session with the basic catalog bound to every catalog id the case
  # names, each in the protocol version its definition (or the message
  # naming it, or the case) gives.
  def session_for(test_case)
    A::Session.new(catalogs: case_catalogs(test_case))
  end

  def case_catalogs(test_case)
    catalogs = A.catalogs
    version = version_of(test_case)
    bind = lambda do |id, given|
      catalogs[id] ||= A::Catalogs::Basic.new(dialect: A::Dialect.for(wire(given || version))) if id.is_a?(String)
    end
    Array(test_case["catalogs"]).grep(Hash).each do |entry|
      bind.call(entry["catalogId"] || entry.dig("catalogSchema", "catalogId"), entry["protocolVersion"])
    end
    Array(test_case["catalogPaths"]).each do |path|
      doc = JSON.parse(File.read(File.join(ROOT, path)))
      bind.call(doc["catalogId"], doc["protocolVersion"] || (path.include?("v0_9") ? "v0.9" : nil))
    end
    if test_case["catalog"].is_a?(Hash)
      bind.call(test_case["catalog"]["catalogId"],
                test_case["catalog"]["protocolVersion"])
    end
    unless catalog_error_case?(test_case)
      messages_of(test_case).each { |message| bind.call(message.dig("createSurface", "catalogId"), message["version"]) }
      bind.call("basic", nil)
    end
    catalogs
  end

  # Applies messages and returns the first error Poetry reported.
  def apply_step(session, messages)
    before = session.errors.size
    list = messages.is_a?(Hash) && messages["messages"].is_a?(Array) ? messages["messages"] : messages
    Array(list.is_a?(Hash) ? [list] : list).each { |message| session.apply(message) }
    session.errors[before] && reported(session.errors[before])
  end

  # Resolves every rendered component's properties and checks, as `validate`
  # does; the first problem is the step's error.
  def resolve_all(session)
    session.surfaces.each_value do |surface|
      found = nil
      on_error = ->(message) { found ||= message }
      surface.walk do |component, scope|
        component.each { |prop, value| surface.resolve(value, scope, on_error:) unless %w[id component].include?(prop) }
        Array(component["checks"]).grep(Hash).each do |rule|
          surface.resolve(rule["condition"], scope, on_error:) if rule["condition"]
        end
      end
      return Raised.new(category: "ValidationError", message: found, source: "evaluation") if found
    end
    nil
  end

  # Instance key => [component, scope]: walked from the root, then the
  # unreached components; template instances keyed id_N, as the official
  # harness keys them.
  def instances(surface)
    out = {}
    surface.walk do |component, scope|
      index = scope.to_s.split("/").last if scope
      out[index&.match?(/\A\d+\z/) ? "#{component["id"]}_#{index}" : component["id"]] ||= [component, scope]
    end
    surface.components.each { |id, component| out[id] ||= [component, nil] }
    out
  end

  def prop_matches?(actual, expected)
    deep_eq(actual, expected) || py_str(actual) == py_str(expected) ||
      (expected.is_a?(String) && !actual.is_a?(String) && A::Evaluator.new(nil).stringify(actual) == expected)
  end

  def check_surfaces(session, expected)
    return unless expected.is_a?(Hash) && expected["surfaces"].is_a?(Hash)

    expected["surfaces"].each do |id, want|
      surface = session.surfaces[id]
      if want["exists"] == false
        fail!("surface #{id} should not exist") if surface
        next
      end
      messages = session.errors.map { |error| error.dig("error", "message") }.first(2)
      fail!("surface #{id} missing (errors: #{messages})") unless surface
      check_surface(surface, want)
    end
  end

  def check_surface(surface, want)
    if want.key?("theme") && !deep_eq(surface.theme, want["theme"])
      fail!("theme #{surface.theme.inspect}, expected #{want["theme"].inspect}")
    end
    %w[sendDataModel catalogId].each do |key|
      got = key == "sendDataModel" ? surface.send_data_model : surface.catalog_id
      fail!("#{key} #{got.inspect}, expected #{want[key].inspect}") if want.key?(key) && got != want[key]
    end
    if want.key?("dataModel") && !deep_eq(surface.data, want["dataModel"])
      fail!("dataModel #{JSON.generate(surface.data)[0, 200]}, expected #{JSON.generate(want["dataModel"])[0, 200]}")
    end
    check_components(surface, want["components"]) if want.key?("components")
    check_validation_results(surface, want["validationResult"]) if want.key?("validationResult")
  end

  def check_components(surface, expected)
    list = expected.is_a?(Hash) ? expected.map { |id, props| (props || {}).merge("id" => id) } : Array(expected)
    if expected.is_a?(Array) && surface.components.size != list.size
      fail!("surface holds #{surface.components.size} components, expected #{list.size}")
    end
    found = instances(surface)
    list.each do |want|
      component, scope = found[want["id"]]
      fail!("component #{want["id"]} missing") unless component
      want.each do |prop, value|
        next if prop == "id"

        got = prop == "component" ? component["component"] : surface.resolve(component[prop], scope)
        next if prop_matches?(got, value)

        fail!("#{want["id"]}.#{prop} resolved to #{JSON.generate(got)[0, 160]}, " \
              "expected #{JSON.generate(value)[0, 160]}")
      end
    end
  end

  def check_validation_results(surface, expected)
    found = instances(surface)
    expected.each do |id, want|
      component, scope = found[id]
      fail!("component #{id} missing") unless component
      failure = A::Checks.failures(component, A::Evaluator.new(surface, scope)).first
      got = { "valid" => true }
      got = { "valid" => false, **failure.slice(:code, :message, :severity).compact.transform_keys(&:to_s) } if failure
      fail!("validationResult(#{id}) #{JSON.generate(got)}, expected #{JSON.generate(want)}") unless deep_eq(got, want)
    end
  end

  # Steps run in order on one session: a step expecting an error needs Poetry
  # to report one, any other step fails on any error Poetry reports.
  def run_messages(test_case, validate:)
    session = session_for(test_case)
    steps = test_case["steps"].is_a?(Array) ? test_case["steps"] : [test_case]
    steps.each_with_index do |step, index|
      payload = step["messages"] || step["payload"] || (step["message"] && [step["message"]])
      next unless payload

      last = index == steps.size - 1
      want_error = step["expectError"] || step["expect_error"]
      want_error ||= test_case["expectError"] || test_case["expect_error"] if last && !step.equal?(test_case)
      raised = apply_step(session, payload)
      raised ||= resolve_all(session) if validate
      if want_error
        expect_error!(want_error, raised)
      elsif raised
        fail!("Poetry reported #{raised.category} #{raised.message[0, 140].inspect} (#{raised.source}); " \
              "the step expects success")
      end
      expected = if step.equal?(test_case)
                   test_case["expect"]
                 else
                   step["expect"] || (last ? test_case["expect"] : nil)
                 end
      check_surfaces(session, expected) if expected
    end
  end

  def run_validate(test_case) = run_messages(test_case, validate: true)

  def run_process_messages(test_case) = run_messages(test_case, validate: false)

  # ---- evaluate_function

  def run_evaluate_function(test_case)
    version = version_of(test_case)
    want_error = test_case["expectError"] || test_case["expect_error"]
    errors = []
    raised = nil
    begin
      value = evaluate(test_case, version, ->(message) { errors << message })
    rescue A::Functions::Error, A::Expression::SyntaxError => e
      raised = Raised.new(category: "ExpressionError", message: e.message, source: e.class.name)
    rescue CatalogProblem => e
      raised = Raised.new(category: "CatalogError", message: e.message, source: "catalog resolution")
    end
    raised ||= Raised.new(category: "ExpressionError", message: errors.first, source: "evaluation") if errors.any?
    return expect_error!(want_error, raised) if want_error

    if raised
      fail!("reported #{raised.category} #{raised.message.inspect}; expected #{JSON.generate(test_case["expect"])}")
    end
    return if deep_eq(value, test_case["expect"])

    fail!("returned #{JSON.generate(value)[0, 200]}, expected #{JSON.generate(test_case["expect"])}")
  end

  # A case with a `surface` block evaluates a call on a surface; one without
  # invokes the function directly with its arguments resolved.
  def evaluate(test_case, version, on_error)
    unless test_case["surface"].is_a?(Hash)
      surface = A::Surface.new(id: "main", catalog: A::Catalogs::Basic.new, data: test_case["dataModel"] || {},
                               dialect: A::Dialect.for(version))
      evaluator = A::Evaluator.new(surface, nil, on_error:)
      args = (test_case["args"] || {}).to_h { |key, value| [key.to_s, evaluator.argument(value)] }
      return A::Functions.basic.call(test_case["function"], args, evaluator)
    end

    dialect = A::Dialect.for(version)
    session = session_for(test_case)
    catalog_id = test_case["surface"]["catalogId"]
    surface = A::Surface.new(id: "main", catalog: catalog_id && session.catalog_for(catalog_id), catalog_id: catalog_id,
                             data: test_case["dataModel"] || {}, dialect: dialect,
                             catalogs: session.catalogs_for(dialect))
    call = { dialect.call_key => test_case["function"], "args" => test_case["args"] || {} }
    call["catalogId"] = test_case["catalogId"] if test_case.key?("catalogId")
    problem = surface.call_catalog_problem(call)
    raise CatalogProblem, problem if problem

    surface.resolve(call, nil, on_error:)
  end

  # ---- handle_rpc

  # A catalog binding holding only a case's functions.
  RpcCatalog = Struct.new(:id, :functions, :dialect) do
    def references(_) = []
    def inputs(*) = []
    def render(*) = ""
  end

  # The case's declared functions, each answering as the official harness's fakes do.
  def rpc_functions(metadata)
    registry = A::Functions.new
    metadata.each do |name, meta|
      parameters = meta["parameters"].is_a?(Hash) ? meta["parameters"] : {}
      registry.define(name, description: name, returns: meta["returnType"] || "any",
                            params: parameters["properties"] || {}, required: parameters["required"] || [],
                            callers: meta["allowedCallers"] || "rendererOrAgent",
                            activation: meta["requiresUserActivation"] == true) do |args, _|
        case name
        when "playMedia" then { "playing" => true, "timestamp" => 0 }
        when "openExternalUrl" then { "opened" => true }
        when "failingFunction" then raise "An error occurred during function execution."
        when "calculateTax" then (args["amount"] || 0) * 0.1
        end
      end
    end
    registry
  rescue ArgumentError => e
    fail!("Functions#define refused the case's metadata: #{e.message}")
  end

  def run_handle_rpc(test_case)
    args = test_case["args"] || {}
    fail!("callAgentFunction: Poetry never calls agent functions") if args["outboundCall"]

    message = args["message"]
    call = message.is_a?(Hash) ? message.dig("callRendererFunction", "callFunction") : nil
    expected_message = test_case.dig("expect", "response", "rendererFunctionResponse", "error", "message").to_s
    catalog_id = args["catalogId"]
    catalog_id ||= call["catalogId"] if call.is_a?(Hash) && !expected_message.include?("Catalog not found")
    catalog_id ||= "basic"
    registry = rpc_functions(args["functionMetadata"] || {})
    dialect = A::Dialect.for(args["catalogVersion"].to_s) || A::Dialect::V1_0
    session = A::Session.new(catalogs: { catalog_id => RpcCatalog.new(catalog_id, registry, dialect) })
    before = session.errors.size
    activated = args["userActivationPresent"] == true
    Array(message.is_a?(Array) ? message : [message]).each { |item| session.apply(item, user_activated: activated) }
    check_rpc(test_case, session, before)
  end

  def check_rpc(test_case, session, before)
    expect = test_case["expect"] || {}
    if (want = expect["error"] || test_case["expectError"])
      raised = session.errors[before] && reported(session.errors[before])
      return expect_error!(want.is_a?(Hash) ? { "category" => "ValidationError" }.merge(want) : want, raised)
    end
    return unless expect.key?("response")

    want = expect["response"]
    return fail!("expected no response; Poetry sent #{session.responses.size}") if want.nil? && session.responses.any?
    return if want.nil?

    if session.responses.size != 1
      error = session.errors[before]
      fail!("expected one rendererFunctionResponse; Poetry sent #{session.responses.size}" +
            (error ? " and an error #{JSON.generate(error["error"])[0, 160]}" : ""))
    end
    check_response(session.responses.first, want)
  end

  def check_response(got, want)
    fail!("version #{got["version"].inspect}, expected #{want["version"].inspect}") if got["version"] != want["version"]
    response = got["rendererFunctionResponse"] || {}
    wanted = want["rendererFunctionResponse"] || {}
    if response["functionCallId"] != wanted["functionCallId"]
      fail!("functionCallId #{response["functionCallId"].inspect}, expected #{wanted["functionCallId"].inspect}")
    end
    if wanted.key?("value") && !deep_eq(response["value"], wanted["value"])
      fail!("value #{JSON.generate(response["value"])}, expected #{JSON.generate(wanted["value"])}")
    end
    return unless wanted.key?("error")

    fail!("expected error #{wanted["error"]["code"]}; Poetry returned a value") unless response["error"]
    return if response["error"]["code"] == wanted["error"]["code"]

    fail!("error code #{response["error"]["code"]}, expected #{wanted["error"]["code"]}")
  end

  # ---- data_model and resolve_path

  def run_data_model(test_case)
    surface = A::Surface.new(id: "dm", catalog: A::Catalogs::Basic.new, data: deep_copy(test_case["initial"] || {}))
    Array(test_case["steps"]).each_with_index do |step, index|
      data_step(surface, step, index)
    end
    return if !test_case.key?("expect") || deep_eq(surface.data, test_case["expect"])

    fail!("final model #{JSON.generate(surface.data)[0, 160]}, expected #{JSON.generate(test_case["expect"])[0, 160]}")
  end

  def data_step(surface, step, index)
    if step.key?("expect_notified") || step.key?("expect_values")
      fail!("step #{index} checks change notification; Poetry's data model has no observers")
    end
    want_error = step["expect_error"] || step["expectError"]
    path = step["path"].to_s
    begin
      case step["op"]
      when "get" then data_get(surface, step, index, want_error)
      when "set" then surface.update_data(path, deep_copy(step["value"]))
      when "delete" then surface.update_data(path, nil)
      end
    rescue Failure
      raise
    rescue StandardError => e
      data_error = want_error && want_error["category"] == "DataError"
      return if data_error && message_matches?(want_error["message"], e.message)

      fail!("step #{index} (#{step["op"]} #{path}) raised #{e.class}: #{e.message[0, 120]}")
    end
    return unless want_error && step["op"] != "get"

    fail!("step #{index}: #{step["op"]} #{path} should raise DataError; Poetry accepted it")
  end

  def data_get(surface, step, index, want_error)
    path = step["path"].to_s
    actual = A::Pointer.get(surface.data, path)
    fail!("step #{index}: get #{path} should raise #{want_error["category"]}") if want_error
    if step["expect_absent"] == true && !actual.nil?
      fail!("step #{index}: get #{path} = #{JSON.generate(actual)}, expected absent")
    end
    kind = { "list" => Array, "object" => Hash }[step["expect_type"]]
    if kind && !actual.is_a?(kind)
      fail!("step #{index}: get #{path} is #{actual.class}, expected #{step["expect_type"]}")
    end
    return if !step.key?("expect") || deep_eq(actual, step["expect"])

    fail!("step #{index}: get #{path} = #{JSON.generate(actual)[0, 160]}, " \
          "expected #{JSON.generate(step["expect"])[0, 160]}")
  end

  def run_resolve_path(test_case)
    args = test_case["args"] || {}
    actual = A::Pointer.absolute(args["path"].to_s, args["contextPath"] || args["context_path"])
    want = test_case["expect"]
    want = want["result"] if want.is_a?(Hash) && want.key?("result")
    fail!("resolved #{actual.inspect}, expected #{want.inspect}") unless actual == want
  end

  # ---- dispatch_action

  # The case's button on a surface of its version: created, given the
  # button, then its data model, as v0.9 allows no inline components.
  def run_dispatch_action(test_case)
    surface_id = test_case["surfaceId"] || "main"
    version = wire(version_of(test_case))
    session = session_for(test_case)
    button = { "id" => "test_comp", "component" => "Button", "child" => "t", "action" => test_case["actionPayload"] }
    create = { "surfaceId" => surface_id, "catalogId" => "basic" }
    session.apply_all([{ "version" => version, "createSurface" => create },
                       { "version" => version,
                         "updateComponents" => { "surfaceId" => surface_id, "components" => [button] } },
                       { "version" => version,
                         "updateDataModel" => { "surfaceId" => surface_id, "path" => "/",
                                                "value" => deep_copy(test_case["dataModel"] || {}) } }])
    source = test_case["scope"] ? "test_comp@#{test_case["scope"]}" : "test_comp"
    action = session.action(surface_id: surface_id, source: source)
    if test_case["expectError"]
      fail!("expected #{test_case["expectError"]}; Poetry dispatched #{action&.message.inspect}") if action&.valid?
      return
    end
    check_dispatched(action, test_case["expectDispatched"]) if test_case["expectDispatched"]
    return unless test_case["expectDataModel"]

    data = session.surfaces[surface_id].data
    want = test_case["expectDataModel"]
    fail!("data model #{JSON.generate(data)}, expected #{JSON.generate(want)}") unless deep_eq(data, want)
  end

  def check_dispatched(action, want)
    fail!("nothing dispatched") unless action&.valid?

    got = action.message["action"]
    if want.key?("name") && got["name"] != want["name"]
      fail!("name #{got["name"].inspect}, expected #{want["name"].inspect}")
    end
    if want.key?("context") && !deep_eq(got["context"], want["context"])
      fail!("context #{JSON.generate(got["context"])}, expected #{JSON.generate(want["context"])}")
    end
    return unless want.key?("userMessage") && got["userMessage"] != want["userMessage"]

    fail!("userMessage #{got["userMessage"].inspect}, expected #{want["userMessage"].inspect}")
  end

  # ---- APIs Poetry does not have yet

  def run_get_renderer_data_model(test_case)
    session = session_for(test_case)
    steps = test_case["steps"].is_a?(Array) ? test_case["steps"] : [test_case]
    steps.each { |step| apply_step(session, step["messages"]) if step["messages"] }
    got = session.renderer_data_model(version: wire(test_case.dig("args", "version")))
    fail!("renderer data model #{JSON.generate(got)}, expected #{JSON.generate(test_case["expect"])}") unless deep_eq(
      got, test_case["expect"]
    )
  end

  # The case's catalogs, each in its own version (the case's when it names none).
  def run_get_renderer_capabilities(test_case)
    fail!("inline catalogs from the suite's catalog definitions") if test_case.dig("args", "includeInlineCatalogs")

    version = wire(test_case.dig("args", "version"))
    catalogs = Array(test_case["catalogs"]).to_h do |entry|
      dialect = A::Dialect.for(wire(entry["protocolVersion"] || version))
      [entry["catalogId"], A::Catalogs::Basic.new(dialect: dialect)]
    end
    got = A::Session.new(catalogs: catalogs).capabilities(versions: [version])
    want = test_case["expect"]
    fail!("capabilities #{JSON.generate(got)}, expected #{JSON.generate(want)}") unless deep_eq(got, want)
  end

  # The catalog a component or call resolves to on a v1.0 surface whose
  # catalogs are the case's supported ones; the case expects the last one.
  def run_select_catalog(test_case)
    args = test_case["args"]
    spec = args["surface"]
    catalogs = Array(spec["supportedCatalogIds"]).to_h do |id|
      [id, A::Catalogs::Basic.new(dialect: A::Dialect.for(wire(args.dig("catalogs", id, "protocolVersion") || "1.0")))]
    end
    session = A::Session.new(catalogs: catalogs)
    session.apply({ "version" => "1.0",
                    "createSurface" => { "surfaceId" => spec["id"], "catalogId" => spec["defaultCatalogId"] } })
    surface = session.surface(spec["id"])
    owners = Array(args["components"]).map(&:last) + [args["functionCall"]].compact
    problem = session.errors.last&.dig("error", "message") unless surface
    selected = nil
    owners.each do |owner|
      problem ||= surface.lookup(owner).last
      selected = owner.key?("catalogId") ? owner["catalogId"] : surface.catalog_id
    end
    raised = problem && Raised.new(category: "CatalogError", message: problem, source: "catalog resolution")
    return expect_error!(test_case["expectError"], raised) if test_case["expectError"]

    fail!("reported #{problem}") if problem
    return if selected == test_case["expectSelected"]

    fail!("selected #{selected.inspect}, expected #{test_case["expectSelected"].inspect}")
  end
end
