# frozen_string_literal: true

require "json"
require_relative "expression"
require_relative "functions"

module Poetry
  module Agent
    module A2UI
      # Resolves dynamic values in a scope, spelled as the surface's
      # protocol version spells them ({Dialect}): a binding reads the data
      # model, a call invokes a registered function with its arguments
      # resolved first (a string argument with `${}` blocks interpolates, an
      # array resolves item by item), and `@index` reads the collection index
      # the scope carries. Problems (an unknown function, a bad argument, a
      # malformed expression, a v1.0 reserved key) resolve to nil and reach
      # the `on_error` callback.
      #
      # On a v1.0 surface whose session reaches the agent, a function no
      # catalog implements here is the agent's ({AgentCalls}): an evaluation
      # that can wait (`waits:`, a binding's or an action's) sends it and
      # resolves to nil until the answer arrives, and a call whose argument
      # still waits, or failed, neither runs nor is sent. {#outcome} says
      # which of the three happened.
      #
      # @example
      #   Evaluator.new(surface, "/items/2").resolve({ "@call" => "@index", "args" => { "offset" => 1 } }) # => 3
      class Evaluator
        # What a call that has no value yet resolves to inside an
        # evaluation: `state` is `:pending` (the agent has not answered) or
        # `:failed` (it answered with an error, or the call was refused),
        # with the failure's message.
        Unsettled = Data.define(:state, :message)
        # The value of a call the agent has not answered.
        PENDING = Unsettled.new(state: :pending, message: nil)

        # Why a call to another `@` name fails: the namespace is the system's.
        SYSTEM_FUNCTIONS = "the @ namespace holds system functions, and @index is the only one"
        # Why `@index` fails outside a template.
        OUTSIDE_TEMPLATE = "@index function can only be evaluated inside a collection template iteration scope."

        # The surface whose data model the evaluator reads.
        # @return [Surface]
        attr_reader :surface
        # The collection-item pointer in effect.
        # @return [String, nil] the collection-item pointer in effect
        attr_reader :scope
        # Every problem met so far, in order: `{ code:, message: }`, the code
        # the protocol's (`EXPRESSION_ERROR` for a call that was refused or
        # could not be read, `CATALOG_ERROR` for one whose catalog does not
        # resolve, `EXECUTION_ERROR` for a function that ran and raised).
        # @return [Array<Hash>]
        attr_reader :problems

        # An evaluator over a surface in a scope, reporting problems to the callback.
        # @param surface [Surface]
        # @param scope [String, nil]
        # @param on_error [#call, nil] receives each problem's message
        # @param gesture [Boolean] whether a user's gesture runs the evaluation
        #   (a button's action), so a function that needs one (`openUrl`) may run,
        #   and a call whose arguments met a problem does not
        # @param waits [Symbol, AgentCalls::Run, nil] whether the evaluation can wait on the agent:
        #   `:binding` for a property or a check rule, evaluated again on every render; an action's
        #   run; nil for a read that cannot wait, which never sends a call
        def initialize(surface, scope = nil, on_error: nil, gesture: false, waits: nil)
          @surface = surface
          @scope = scope
          @on_error = on_error
          @gesture = gesture
          @waits = waits
          @problems = []
          @unsettled = false
        end

        # Resolves a component property: bindings and calls resolve, a list
        # or a plain object resolves what it holds, anything else is a literal.
        #
        # @param value [Object]
        # @return [Object, nil]
        def resolve(value)
          settled(raw(value))
        end

        # Resolves a value and says how it settled: with its value, still
        # waiting on a call to the agent, or failed because one failed.
        #
        # @param value [Object]
        # @return [Array(Object, Symbol, String)] the value (nil unless settled), `:settled`,
        #   `:pending` or `:failed`, and a failed call's message
        def outcome(value)
          result = raw(value)
          held = unsettled(result)
          held ? [nil, held.state, held.message] : [result, :settled, nil]
        end

        # Resolves a function argument: like {#resolve}, plus strings
        # interpolate.
        #
        # @param value [Object]
        # @return [Object, nil]
        def argument(value)
          settled(raw_argument(value))
        end

        # Calls a function by name.
        #
        # @param name [String]
        # @param args [Hash, nil] raw arguments (resolved here unless `resolved:`)
        # @param resolved [Boolean] whether the arguments are already resolved
        # @param via [Hash, nil] the call object, whose `catalogId` names the catalog in v1.0 (nil: the default)
        # @return [Object, nil]
        def call(name, args, resolved: false, via: nil)
          settled(invoke(name, args, resolved: resolved, via: via))
        end

        # Interpolates a `formatString` template.
        #
        # @param text [String]
        # @return [String]
        def interpolate(text)
          evaluate(Expression.parse(text))
        rescue Expression::SyntaxError => e
          fail!("formatString: #{e.message}")
          ""
        end

        # Evaluates a parsed expression node.
        #
        # @param node [Array]
        # @return [Object, nil]
        def evaluate(node)
          case node[0]
          when :text, :literal then node[1]
          when :path then surface.read(node[1], scope)
          when :call
            # A template part cannot wait, so it never reaches the agent.
            settled(invoke(node[1], node[2].transform_values { |item| evaluate(item) }, resolved: true, part: true))
          when :template then node[1].map { |item| stringify(evaluate(item)) }.join
          end
        end

        # The string a value displays as (the spec's conversion rules: nil
        # is empty, containers are JSON, whole floats drop their fraction).
        #
        # @param value [Object]
        # @return [String]
        def stringify(value)
          case value
          when nil then ""
          when Float then value.finite? && value == value.floor && value.abs < 1e15 ? value.to_i.to_s : value.to_s
          when Hash, Array then JSON.generate(value)
          else value.to_s
          end
        end

        # Whether resolved arguments have a faithful JSON form: no number
        # that is not finite anywhere in them.
        #
        # @param value [Object]
        # @return [Boolean]
        def self.json?(value)
          case value
          when Float then value.finite?
          when Hash then value.each_value.all? { |item| json?(item) }
          when Array then value.all? { |item| json?(item) }
          else true
          end
        end

        # The scope's item index, or nil outside a template.
        # @return [Integer, nil] the collection index the scope carries
        def index
          token = scope.to_s.split("/").last
          token&.match?(/\A\d+\z/) ? token.to_i : nil
        end

        private

        # {#resolve} before what is unsettled reads as nothing.
        def raw(value)
          case value
          when Hash
            return surface.read(surface.binding_path(value), scope) if surface.binding?(value)
            return invoke(surface.dialect.call_name(value), value["args"], via: value) if surface.function_call?(value)

            plain(value) { |item| raw(item) }
          when Array then value.map { |item| raw(item) }
          else value
          end
        end

        # {#argument} before what is unsettled reads as nothing.
        def raw_argument(value)
          case value
          when String then Expression.dynamic?(value) ? interpolate(value) : value
          when Array then value.map { |item| raw_argument(item) }
          when Hash
            return raw(value) if surface.binding?(value) || surface.function_call?(value)

            plain(value) { |item| raw_argument(item) }
          else value
          end
        end

        # Runs one call: its arguments first, then the function where a
        # catalog implements it here, else the agent where the evaluation
        # can wait for it. A call whose argument is unsettled is unsettled
        # the same way and does nothing; in an action, one whose arguments
        # met a problem does not run either.
        def invoke(name, args, resolved: false, via: nil, part: false)
          run = @waits.is_a?(AgentCalls::Run) ? @waits : nil
          return answer(run.memo[via]) if run && via && run.memo.key?(via)

          met = @problems.size
          args = (args.is_a?(Hash) ? args : {}).to_h { |key, value| [key.to_s, resolved ? value : raw_argument(value)] }
          blocked = unsettled(args)
          return blocked if blocked
          return nil if @gesture && @problems.size > met

          result = dispatch(name, args, via, part)
          run.memo[via] = [:value, result] if run && via && !result.is_a?(Unsettled)
          result
        rescue Functions::Error, Expression::SyntaxError => e
          fail!("function #{name.inspect}: #{e.message}")
        rescue StandardError => e
          # A function that raises on its arguments (a host's, or a
          # built-in handed a value it cannot use) fails the call, not the render.
          fail!("function #{name.inspect} raised #{e.class}: #{e.message}", "EXECUTION_ERROR", e.class.name)
        end

        # A call with its arguments resolved: `@index`, a function its catalog implements, or the agent's.
        def dispatch(name, args, via, part)
          return index_of(args) if name == "@index"
          return fail!("function #{name.inspect}: #{SYSTEM_FUNCTIONS}") if name.to_s.start_with?("@")
          return fail!("function #{name.inspect}: a function name is an identifier") if name.to_s.empty?

          catalog, problem = surface.lookup(via)
          return fail!("function #{name.inspect}: #{problem}", "CATALOG_ERROR") unless catalog

          name = name.to_s
          functions = catalog.functions
          return route(name, args, via, functions) if !part && !functions.implemented?(name) && surface.agent_calls
          return fail!(Functions.agent_only_refusal(name)) if functions.agent_only?(name, surface.dialect)
          if !@gesture && functions.activation?(name)
            return fail!("Function '#{name}' requires user activation context to execute.")
          end

          functions.call(name, args, self)
        end

        # A call to a function the renderer does not implement, on a surface
        # that reaches the agent: refused when its declaration forbids it or
        # its arguments break the declared schema or have no JSON form, else
        # sent (a binding's shared and kept, an action's fresh), or, for a
        # read that cannot wait, answered from what the surface already holds.
        def route(name, args, node, functions)
          catalog_id = node.is_a?(Hash) && node["catalogId"].is_a?(String) ? node["catalogId"] : surface.catalog_id
          if functions.declared?(name)
            return refuse(Functions.agent_only_refusal(name)) if functions.agent_only?(name, surface.dialect)
            if !@gesture && functions.activation?(name)
              return refuse("Function '#{name}' requires user activation context to execute.")
            end

            args = functions.parse(name, args)
          end
          unless Evaluator.json?(args)
            return refuse("function #{name.inspect}: an argument has no JSON form, so the call is not sent")
          end

          answer(ask(name, args, node, catalog_id))
        rescue Functions::Error => e
          refuse("function #{name.inspect}: #{e.message}")
        end

        # Asks the surface's ledger: an action's call fresh, a binding's
        # shared, and a read that cannot wait only for what is already held.
        def ask(name, args, node, catalog_id)
          calls = surface.agent_calls
          case @waits
          when AgentCalls::Run then calls.imperative(@waits, node, catalog_id, name, args)
          when :binding then calls.reactive(surface.id, node, scope, catalog_id, name, args)
          else
            calls.held(surface.id, catalog_id, name, args) ||
              [:refused, "function #{name.inspect}: unknown function #{name.inspect}"]
          end
        end

        # What the ledger said, as a value an evaluation carries.
        def answer(held)
          case held[0]
          when :value then held[1]
          when :pending then unsettle(PENDING)
          when :refused then refuse(held[1])
          else unsettle(Unsettled.new(state: :failed, message: held[1]))
          end
        end

        # A call refused before it ran or was sent: reported, and failed for whatever encloses it.
        def refuse(message)
          fail!(message)
          unsettle(Unsettled.new(state: :failed, message: message))
        end

        # Notes that this evaluation met a value that is not settled.
        def unsettle(value)
          @unsettled = true
          value
        end

        # The first unsettled value inside a resolved one, a failure before a wait; nil when all of it is settled.
        def unsettled(value)
          return unless @unsettled

          found = []
          gather(value, found)
          found.find { |held| held.state == :failed } || found.first
        end

        # Collects the unsettled values a resolved value holds.
        def gather(value, found)
          case value
          when Unsettled then found << value
          when Hash then value.each_value { |item| gather(item, found) }
          when Array then value.each { |item| gather(item, found) }
          end
        end

        # A resolved value as callers read it: what is unsettled is nothing.
        def settled(value)
          return value unless @unsettled

          case value
          when Unsettled then nil
          when Hash then value.transform_values { |item| settled(item) }
          when Array then value.map { |item| settled(item) }
          else value
          end
        end

        # The item index with the offset argument applied; raises outside a template.
        def index_of(args)
          position = index or raise Functions::Error, OUTSIDE_TEMPLATE

          position + (Functions.number(args["offset"]) || 0)
        end

        # A plain object with its values resolved by the block. In v1.0 a
        # reserved key fails it, and a doubled `@@` key reads as its literal.
        def plain(object)
          reserved = surface.dialect.reserved_keys(object)
          return fail!("reserved key #{reserved.first.inspect}: a literal @ key is escaped as @@") if reserved.any?

          object.to_h { |key, item| [surface.dialect.unescape(key), yield(item)] }
        end

        # Reports a problem and returns nil.
        def fail!(message, code = "EXPRESSION_ERROR", raised = nil)
          @problems << { code: code, message: message, raised: raised }.compact
          @on_error&.call(message)
          nil
        end
      end
    end
  end
end
