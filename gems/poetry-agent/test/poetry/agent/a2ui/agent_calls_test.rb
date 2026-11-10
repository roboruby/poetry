# frozen_string_literal: true

require "test_helper"

# Calls to the agent's functions (A2UI v1.0's callAgentFunction): what a
# surface sends, what it shows while it waits, and what an answer, a
# failure, a timeout and a cancellation each leave behind.
class AgentCallsTest < Minitest::Test
  A2UI = Poetry::Agent::A2UI

  # The basic catalog with the agent's functions declared, and one of the renderer's own.
  class Shop < A2UI::Catalogs::Basic
    QUOTE = { "type" => "object", "required" => ["symbol"], "additionalProperties" => false,
              "properties" => { "symbol" => { "type" => "string" },
                                "currency" => { "type" => "string", "default" => "USD" } } }.freeze

    def functions
      @functions ||= A2UI::Functions.basic.dup.tap do |registry|
        registry.define("quote", description: "A price.", returns: "number", schema: QUOTE)
        registry.define("audit", description: "The agent's own.", returns: "any", callers: "agentOnly")
        registry.define("confirm", description: "Needs a gesture.", returns: "boolean", activation: true)
        registry.define("mark", description: "Marks the data.", returns: "boolean") do |_args, evaluator|
          evaluator.surface.update_data("/marked", true)
          true
        end
      end
    end
  end

  def session(**)
    A2UI::Session.new(catalogs: { "shop" => Shop.new }, agent_functions: true, **).tap do |held|
      held.apply({ "version" => "1.0",
                   "createSurface" => { "surfaceId" => "s", "catalogId" => "shop",
                                        "dataModel" => { "base" => "EUR" } } })
    end
  end

  def answer(session, message, value: nil, error: nil)
    body = { "functionCallId" => message.dig("callAgentFunction", "functionCallId") }
    error ? body["error"] = error : body["value"] = value
    session.apply({ "version" => "1.0", "agentFunctionResponse" => body })
  end

  def read(session, node) = session.surface("s").resolve(node, nil, waits: :binding)

  def problems(session, node, **)
    evaluator = A2UI::Evaluator.new(session.surface("s"), nil, waits: :binding, **)
    evaluator.resolve(node)
    evaluator.problems.map { |problem| problem[:message] }
  end

  def rate = { "@call" => "fetchRate", "args" => { "base" => { "@path" => "/base" } } }

  def button(action)
    [{ "id" => "root", "component" => "Button", "child" => "label", "action" => action },
     { "id" => "label", "component" => "Text", "text" => "Go" }]
  end

  def test_a_binding_to_a_function_no_catalog_implements_asks_the_agent_and_reads_its_answer
    held = session
    node = rate
    version = held.surface("s").version

    assert_nil read(held, node), "nothing until the agent answers"
    message = held.agent_calls.shift
    id = message.dig("callAgentFunction", "functionCallId")

    assert_match(/\Afn-\h{24}\z/, id)
    assert_equal({ "version" => "1.0",
                   "callAgentFunction" => { "surfaceId" => "s", "functionCallId" => id,
                                            "callFunction" => { "@call" => "fetchRate", "catalogId" => "shop",
                                                                "args" => { "base" => "EUR" } } } }, message)
    assert_nil read(held, node)
    assert_empty held.agent_calls, "the call in flight is not sent again"
    assert_equal ["s"], answer(held, message, value: 1.08), "the surface shows something new"
    assert_in_delta 1.08, read(held, node)
    assert_equal version + 1, held.surface("s").version, "a versioned replace takes the answer"
    twin = { "@call" => "fetchRate", "catalogId" => "shop", "args" => { "base" => "EUR" } }

    assert_in_delta 1.08, read(held, twin), 0.001, "the surface holds the answer for every identical call"
    assert_empty held.agent_calls
    assert_empty held.errors
  end

  def test_identical_calls_ride_one_request_whatever_order_their_arguments_are_written_in
    held = session
    first = { "@call" => "cross", "args" => { "base" => "EUR", "quote" => "USD" } }
    second = { "@call" => "cross", "args" => { "quote" => "USD", "base" => "EUR" } }
    other = { "@call" => "cross", "args" => { "base" => "GBP", "quote" => "USD" } }

    [first, second, other].each { |node| assert_nil read(held, node) }

    assert_equal([{ "base" => "EUR", "quote" => "USD" }, { "base" => "GBP", "quote" => "USD" }],
                 held.agent_calls.map { |message| message.dig("callAgentFunction", "callFunction", "args") })
  end

  def test_a_failed_call_is_reported_once_and_not_sent_again_by_the_binding_that_made_it
    held = session
    node = rate
    read(held, node)
    message = held.agent_calls.shift
    id = message.dig("callAgentFunction", "functionCallId")

    assert_equal ["s"], answer(held, message, error: { "code" => "UNKNOWN_FUNCTION", "message" => "No such function" })
    assert_equal [{ "version" => "1.0",
                    "error" => { "code" => "EXPRESSION_ERROR", "message" => "No such function",
                                 "functionCallId" => id } }], held.errors
    assert_nil read(held, node)
    assert_empty held.agent_calls, "the binding does not ask again as it stands"
    read(held, rate)

    refute_equal id, held.agent_calls.shift.dig("callAgentFunction", "functionCallId"), "another binding asks afresh"
    held.surface("s").update_data("/base", "USD")
    read(held, node)

    assert_equal({ "base" => "USD" }, held.agent_calls.shift.dig("callAgentFunction", "callFunction", "args"),
                 "and the binding asks again once its arguments changed")
    assert_equal 1, held.errors.size
  end

  def test_a_session_rebuilt_from_its_messages_asks_nothing_twice
    first = session
    read(first, rate)
    sent = first.agent_calls.shift
    rebuilt = session
    version = rebuilt.surface("s").version

    assert_empty answer(rebuilt, sent, value: 1.08), "an answer to no call in flight changes nothing"
    assert_empty rebuilt.errors
    assert_in_delta 1.08, read(rebuilt, rate), 0.001, "the answer was in hand when the binding asked"
    assert_empty rebuilt.agent_calls
    assert_equal version + 1, rebuilt.surface("s").version
    failed = session
    answer(failed, sent, error: { "code" => "EXECUTION_ERROR", "message" => "Rate feed offline" })

    assert_empty failed.errors
    assert_nil read(failed, rate)
    assert_empty failed.agent_calls, "a failure in hand is not asked again either"
    assert_equal "Rate feed offline", failed.errors.last.dig("error", "message")
  end

  def test_a_read_that_cannot_wait_never_sends
    held = session
    surface = held.surface("s")
    said = []

    assert_nil surface.resolve(rate, nil, on_error: ->(message) { said << message })
    assert_equal ['function "fetchRate": unknown function "fetchRate"'], said
    assert_empty held.agent_calls
    read(held, rate)
    answer(held, held.agent_calls.shift, value: 1.08)

    assert_in_delta 1.08, surface.resolve(rate), 0.001, "it reads what the surface already holds"
    template = { "@call" => "formatString", "args" => { "value" => "Rate: ${fetchRate(base: ${/base})}" } }

    assert_equal "Rate: ", read(held, template), "a template part never reaches the agent, held answer or not"
    assert_empty held.agent_calls
  end

  def test_without_the_agent_or_on_a_v0_9_surface_the_function_fails_where_it_is_called
    plain = A2UI::Session.new(catalogs: { "shop" => Shop.new })
    plain.apply({ "version" => "1.0", "createSurface" => { "surfaceId" => "s", "catalogId" => "shop" } })

    assert_nil plain.surface("s").agent_calls
    assert_equal ['function "fetchRate": unknown function "fetchRate"'], problems(plain, rate)
    assert_equal ['function "quote": function "quote" is declared without an implementation here'],
                 problems(plain, { "@call" => "quote", "args" => { "symbol" => "GOOG" } })
    assert_empty plain.agent_calls
    old = A2UI::Session.new(catalogs: { "shop" => Shop.new(dialect: A2UI::Dialect::V0_9) }, agent_functions: true)
    old.apply({ "version" => "v0.9", "createSurface" => { "surfaceId" => "s", "catalogId" => "shop" } })

    assert_nil old.surface("s").agent_calls, "v0.9 has no calls to the agent"
    assert_equal ['function "fetchRate": unknown function "fetchRate"'],
                 problems(old, { "call" => "fetchRate", "args" => {} })
    assert_empty old.agent_calls
  end

  def test_a_declared_function_is_held_to_its_declaration_before_it_is_sent
    held = session

    assert_empty problems(held, { "@call" => "quote", "args" => { "symbol" => "GOOG" } })
    assert_equal({ "symbol" => "GOOG", "currency" => "USD" },
                 held.agent_calls.shift.dig("callAgentFunction", "callFunction", "args"), "defaults filled in")
    assert_match(/Validation failed for function 'quote': /,
                 problems(held, { "@call" => "quote", "args" => { "symbol" => 42 } }).first)
    assert_equal ["Function 'audit' cannot be called by renderer: its allowedCallers is agentOnly"],
                 problems(held, { "@call" => "audit" })
    assert_equal ["Function 'confirm' requires user activation context to execute."],
                 problems(held, { "@call" => "confirm" })
    assert_match(/an argument has no JSON form/,
                 problems(held, { "@call" => "fetchRate", "args" => { "amount" => Float::NAN } }).first)
    assert_empty held.agent_calls, "a refused call is not sent"
    assert_empty problems(held, { "@call" => "confirm" }, gesture: true)
    assert_equal "confirm", held.agent_calls.shift.dig("callAgentFunction", "callFunction", "@call")
  end

  def test_a_call_waits_for_the_agent_s_answers_in_its_arguments
    held = session
    greeting = { "@call" => "formatString", "args" => { "value" => { "@call" => "fetchGreeting" } } }
    evaluator = A2UI::Evaluator.new(held.surface("s"), nil, waits: :binding)

    assert_equal [nil, :pending, nil], evaluator.outcome(greeting)
    answer(held, held.agent_calls.shift, value: "Hello")

    assert_equal ["Hello", :settled, nil], evaluator.outcome(greeting),
                 "the local function ran once its argument arrived"
    outer = { "@call" => "outer",
              "args" => { "rate" => { "@call" => "fetchA" }, "stock" => [{ "@call" => "fetchB" }] } }

    assert_nil read(held, outer)
    first, second = held.agent_calls.shift(2)

    assert_equal(%w[fetchA fetchB], [first, second].map do |message|
      message.dig("callAgentFunction", "callFunction", "@call")
    end)
    answer(held, first, error: { "code" => "EXECUTION_ERROR", "message" => "Sibling lookup failed" })
    answer(held, second, value: 3)

    assert_equal [nil, :failed, "Sibling lookup failed"], evaluator.outcome(outer)
    assert_empty held.agent_calls, "the enclosing call is never sent"
    assert_equal 1, held.errors.size, "and the failure is reported once"
  end

  def test_a_check_rule_that_waits_does_not_fail_and_one_whose_call_failed_does
    held = session
    field = lambda do |name, rule|
      { "id" => name, "component" => "TextField", "label" => name, "value" => name,
        "checks" => [rule.merge("condition" => { "@call" => "isFree", "args" => { "name" => name } })] }
    end
    root = { "id" => "root", "component" => "Column", "children" => %w[ada bo cy] }
    held.apply({ "version" => "1.0",
                 "updateComponents" => { "surfaceId" => "s",
                                         "components" => [root, field.call("ada", { "message" => "Name is taken" }),
                                                          field.call("bo", {}), field.call("cy", {})] } })

    assert_empty held.surface("s").failures, "a rule that waits is not failing"
    ada, bo, cy = held.agent_calls.shift(3)
    answer(held, ada, value: false)
    answer(held, bo, error: { "code" => "EXECUTION_ERROR", "message" => "Directory unavailable" })
    answer(held, cy, value: { "valid" => false, "message" => "Taken by Cy" })

    assert_equal({ "ada" => ["Name is taken"], "bo" => ["Directory unavailable"], "cy" => ["Taken by Cy"] },
                 held.surface("s").failures.transform_values { |found| found.map { |failure| failure[:message] } })
  end

  def test_an_event_action_waits_on_each_call_in_order_and_is_dispatched_with_the_answers
    held = session
    event = { "name" => "checkout", "userMessage" => { "@call" => "greeting" },
              "context" => { "rate" => rate, "stock" => { "@call" => "lookup", "args" => { "sku" => "A-1" } } } }
    held.apply({ "version" => "1.0",
                 "updateComponents" => { "surfaceId" => "s", "components" => button({ "event" => event }) } })
    action = held.action(surface_id: "s", source: "root", timestamp: Time.utc(2026, 11, 9, 12, 0, 0))

    assert_predicate action, :pending?
    refute_predicate action, :valid?
    assert_empty action.forwarded_props
    names = []
    [1.08, 3, "Ada is checking out"].each do |value|
      assert_equal 1, held.agent_calls.size, "one call at a time, in the order the event writes them"
      names << held.agent_calls.first.dig("callAgentFunction", "callFunction", "@call")

      assert_empty answer(held, held.agent_calls.shift, value: value), "an action's answer changes no surface"
    end

    assert_equal %w[fetchRate lookup greeting], names
    refute_predicate action, :pending?
    assert_equal({ "version" => "1.0",
                   "action" => { "name" => "checkout", "surfaceId" => "s", "sourceComponentId" => "root",
                                 "timestamp" => "2026-11-09T12:00:00.000Z",
                                 "context" => { "rate" => 1.08, "stock" => 3 },
                                 "userMessage" => "Ada is checking out" } }, action.to_h)
    again = held.action(surface_id: "s", source: "root")

    assert_predicate again, :pending?, "every press asks afresh: an action reads nothing the surface holds"
    assert_equal 1, held.agent_calls.size
  end

  def test_an_action_ends_on_the_first_failure_and_goes_with_its_surface
    held = session
    event = { "name" => "checkout", "context" => { "rate" => rate, "stock" => { "@call" => "lookup" } } }
    held.apply({ "version" => "1.0",
                 "updateComponents" => { "surfaceId" => "s", "components" => button({ "event" => event }) } })
    action = held.action(surface_id: "s", source: "root")
    answer(held, held.agent_calls.shift, error: { "code" => "EXECUTION_ERROR", "message" => "Rate feed offline" })

    refute_predicate action, :pending?
    refute_predicate action, :valid?
    assert_equal({ "action" => "Rate feed offline" }, action.errors)
    assert_empty held.agent_calls, "no later entry is read"
    assert_equal(["EXPRESSION_ERROR"], held.errors.map { |error| error.dig("error", "code") })
    waiting = held.action(surface_id: "s", source: "root")
    held.apply({ "version" => "1.0", "deleteSurface" => { "surfaceId" => "s" } })

    refute_predicate waiting, :pending?
    refute_predicate waiting, :valid?
    assert_equal 1, held.errors.size, "a cancelled call reports nothing"
  end

  def test_an_event_s_user_message_is_a_string_or_nothing
    held = session
    event = ->(message) { { "event" => { "name" => "send", "userMessage" => message } } }
    press = lambda do |message|
      held.apply({ "version" => "1.0",
                   "updateComponents" => { "surfaceId" => "s", "components" => button(event.call(message)) } })
      held.action(surface_id: "s", source: "root")
    end

    assert_equal "EUR", press.call({ "@path" => "/base" }).to_h.dig("action", "userMessage")
    refute press.call({ "@path" => "/missing" }).to_h["action"].key?("userMessage"), "nothing is no message"
    held.surface("s").update_data("/count", 3)
    refused = press.call({ "@path" => "/count" })

    refute_predicate refused, :valid?
    assert_equal({ "userMessage" => "must be a string" }, refused.errors)
    assert_equal "INVALID_ACTION", held.errors.last.dig("error", "code")
    malformed = press.call({ "@unknown" => 1 })

    refute_predicate malformed, :valid?
    assert_match(/\AAction event userMessage is invalid: reserved key/, held.errors.last.dig("error", "message"))
  end

  def test_a_function_call_action_runs_on_the_agent_when_no_catalog_implements_it
    held = session
    call = { "@call" => "submitOrder", "args" => { "steps" => [{ "@call" => "mark" }, { "@call" => "remote" }] } }
    held.apply({ "version" => "1.0",
                 "updateComponents" => { "surfaceId" => "s", "components" => button({ "functionCall" => call }) } })
    action = held.action(surface_id: "s", source: "root")

    assert_predicate action, :pending?
    assert_predicate action, :local?
    assert held.surface("s").data["marked"], "the renderer's own step ran"
    held.surface("s").update_data("/marked", "once")
    answer(held, held.agent_calls.shift, value: "shipped")

    assert_equal({ "steps" => [true, "shipped"] },
                 held.agent_calls.first.dig("callAgentFunction", "callFunction", "args"), "then the call itself goes")
    assert_equal "once", held.surface("s").data["marked"], "a step that ran is not run again"
    answer(held, held.agent_calls.shift, value: { "accepted" => true })

    refute_predicate action, :pending?
    assert_equal({ "accepted" => true }, action.value)
    assert_empty action.errors
    assert_empty held.errors
  end

  def test_a_call_times_out_is_cancelled_or_ends_with_the_session
    held = session(agent_call_timeout: 5)
    node = rate
    read(held, node)
    late = held.agent_calls.shift
    later = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 6

    assert_equal ["s"], held.expire_agent_calls(later)
    assert_equal({ "code" => "EXPRESSION_ERROR", "message" => "Agent function 'fetchRate' timed out",
                   "functionCallId" => late.dig("callAgentFunction", "functionCallId") }, held.errors.last["error"])
    assert_empty answer(held, late, value: 1.08), "a late answer changes nothing"
    assert_nil read(held, node)
    assert_empty held.agent_calls, "the binding that timed out does not ask again"
    other = { "@call" => "lookup" }
    read(held, other)
    first = held.agent_calls.shift
    held.cancel_agent_calls("s")
    read(held, other)

    assert_equal first, held.agent_calls.shift, "a cancelled call is asked again the next time it is read"
    assert_equal 1, held.errors.size, "and reports nothing"
    assert_empty held.expire_agent_calls, "nothing is due yet"
  end

  # ---- the agent's functions answered in this process

  def in_process(handlers)
    A2UI::Session.new(catalogs: { "shop" => Shop.new }, agent_functions: handlers).tap do |held|
      created = { "surfaceId" => "s", "catalogId" => "shop", "dataModel" => { "base" => "EUR" } }
      held.apply({ "version" => "1.0", "createSurface" => created })
    end
  end

  def test_a_handler_in_this_process_answers_a_call_the_moment_it_is_made
    asked = []
    held = in_process("fetchRate" => ->(args) { asked << args and 1.08 },
                      :quote => ->(args, call) { [args, call.surface_id, call.catalog_id, call.id[0, 3]] })
    version = held.surface("s").version

    assert_in_delta 1.08, read(held, rate), 0.001, "nothing waits"
    assert_in_delta 1.08, read(held, rate), 0.001
    assert_equal [{ "base" => "EUR" }], asked, "identical calls are answered once for the surface"
    assert_equal version + 1, held.surface("s").version
    assert_equal [{ "symbol" => "GOOG", "currency" => "USD" }, "s", "shop", "fn-"],
                 read(held, { "@call" => "quote", "args" => { "symbol" => "GOOG" } }),
                 "a declared function's defaults are filled in, and a handler may take the call"
    assert_empty held.agent_calls, "nothing is sent"
    assert_empty held.errors
    direct = held.call_agent_function(surface_id: "s", catalog_id: "shop", name: "fetchRate")

    assert_equal [:settled, 1.08], [direct.state, direct.value]
  end

  def test_a_handler_fails_its_call_and_a_function_without_one_is_unknown
    failure = A2UI::AgentCalls::Failure.new("Provider PRV-102 was not found", code: "NOT_FOUND")
    held = in_process("lookup" => ->(_args) { raise failure }, "crash" => ->(_args) { raise IOError, "disk on fire" },
                      "clock" => ->(_args) { Time.now.to_f / 0 })
    said = lambda do |name|
      node = { "@call" => name }
      [read(held, node), read(held, node), held.errors.last.dig("error", "message")]
    end

    assert_equal [nil, nil, "Provider PRV-102 was not found"], said.call("lookup")
    assert_equal [nil, nil, "An error occurred during function execution (IOError)."], said.call("crash")
    assert_equal [nil, nil, "No such function: missing"], said.call("missing")
    assert_match(/\AAn error occurred during function execution \(JSON::/, said.call("clock").last,
                 "a value with no JSON form is a failure")
    assert_equal ["EXPRESSION_ERROR"] * 4, held.errors.map { |error| error.dig("error", "code") },
                 "each reported once, as an agent's error is: the binding does not ask again as it stands"
    assert(held.errors.all? { |error| error["error"].key?("functionCallId") })
  end

  def test_an_action_over_handlers_is_finished_when_it_comes_back
    order = []
    handlers = { "fetchRate" => ->(_args) { order << :rate and 1.08 }, "lookup" => ->(_args) { order << :stock and 3 },
                 "greeting" => ->(_args) { order << :greeting and "Ada is checking out" },
                 "submitOrder" => ->(args) { { "accepted" => args["id"] } } }
    held = in_process(handlers)
    event = { "name" => "checkout", "userMessage" => { "@call" => "greeting" },
              "context" => { "rate" => rate, "stock" => { "@call" => "lookup" } } }
    held.apply({ "version" => "1.0",
                 "updateComponents" => { "surfaceId" => "s", "components" => button({ "event" => event }) } })
    action = held.action(surface_id: "s", source: "root")

    refute_predicate action, :pending?
    assert_predicate action, :valid?
    assert_equal({ "rate" => 1.08, "stock" => 3 }, action.to_h.dig("action", "context"))
    assert_equal "Ada is checking out", action.to_h.dig("action", "userMessage")
    assert_equal %i[rate stock greeting], order, "in the order the event writes them"
    held.action(surface_id: "s", source: "root")

    assert_equal 6, order.size, "every press asks afresh"
    call = { "functionCall" => { "@call" => "submitOrder", "args" => { "id" => "o-1" } } }
    held.apply({ "version" => "1.0", "updateComponents" => { "surfaceId" => "s", "components" => button(call) } })
    pressed = held.action(surface_id: "s", source: "root")

    refute_predicate pressed, :pending?
    assert_equal({ "accepted" => "o-1" }, pressed.value)
    assert_empty held.errors
  end

  def test_an_action_over_handlers_ends_where_a_handler_fails
    reached = []
    held = in_process("fetchRate" => ->(_args) { raise "feed offline" }, "lookup" => ->(_args) { reached << :stock })
    event = { "name" => "checkout", "context" => { "rate" => rate, "stock" => { "@call" => "lookup" } } }
    held.apply({ "version" => "1.0",
                 "updateComponents" => { "surfaceId" => "s", "components" => button({ "event" => event }) } })
    action = held.action(surface_id: "s", source: "root")

    refute_predicate action, :pending?
    refute_predicate action, :valid?
    assert_equal({ "action" => "An error occurred during function execution (RuntimeError)." }, action.errors)
    assert_empty reached, "no later entry is read"
    assert_equal 1, held.errors.size
  end

  def test_a_check_rule_over_a_handler_is_judged_at_once
    held = in_process("isFree" => ->(args) { args["name"] != "ada" })
    field = lambda do |name|
      { "id" => name, "component" => "TextField", "label" => name, "value" => name,
        "checks" => [{ "message" => "Name is taken",
                       "condition" => { "@call" => "isFree", "args" => { "name" => name } } }] }
    end
    root = { "id" => "root", "component" => "Column", "children" => %w[ada bo] }
    components = [root, field.call("ada"), field.call("bo")]
    held.apply({ "version" => "1.0", "updateComponents" => { "surfaceId" => "s", "components" => components } })

    assert_equal(%w[ada], held.surface("s").failures.keys)
  end

  def test_a_session_takes_the_agent_as_a_switch_or_as_handlers
    error = assert_raises(ArgumentError) { A2UI::Session.new(agent_functions: "yes") }

    assert_equal "agent_functions is true, false or the agent's handlers by function name", error.message
    assert_empty A2UI::Session.new(agent_functions: {}).agent_calls
  end

  def test_a_host_calls_the_agent_itself
    held = session
    call = held.call_agent_function(surface_id: "s", catalog_id: "shop", name: "inventory", args: { "sku" => "A-1" },
                                    id: "call-1")

    assert_predicate call, :pending?
    assert_equal "call-1", held.agent_calls.first.dig("callAgentFunction", "functionCallId")
    twice = held.call_agent_function(surface_id: "s", catalog_id: "shop", name: "inventory", id: "call-1")

    assert_equal "DUPLICATE", twice.error["code"]
    held.apply({ "version" => "1.0", "agentFunctionResponse" => { "functionCallId" => "call-1", "value" => 12 } })

    assert_equal [:settled, 12], [call.state, call.value]
    waiting = held.call_agent_function(surface_id: "s", catalog_id: "shop", name: "inventory")
    held.dispose_agent_calls

    assert_equal "CANCELLED", waiting.error["code"]
    assert_equal "DISPOSED", held.call_agent_function(surface_id: "s", catalog_id: "shop", name: "x").error["code"]
    assert_empty held.errors, "a call the host made itself is the host's to judge"
    silent = A2UI::Session.new.call_agent_function(surface_id: "s", catalog_id: "shop", name: "x")

    assert_equal "NO_LISTENER", silent.error["code"]
  end
end
