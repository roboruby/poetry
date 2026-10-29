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
      # @example
      #   Evaluator.new(surface, "/items/2").resolve({ "@call" => "@index", "args" => { "offset" => 1 } }) # => 3
      class Evaluator
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

        # An evaluator over a surface in a scope, reporting problems to the callback.
        # @param surface [Surface]
        # @param scope [String, nil]
        # @param on_error [#call, nil] receives each problem's message
        # @param gesture [Boolean] whether a user's gesture runs the evaluation
        #   (a button's action), so a function that needs one (`openUrl`) may run
        def initialize(surface, scope = nil, on_error: nil, gesture: false)
          @surface = surface
          @scope = scope
          @on_error = on_error
          @gesture = gesture
        end

        # Resolves a component property: bindings and calls resolve, a list
        # or a plain object resolves what it holds, anything else is a literal.
        #
        # @param value [Object]
        # @return [Object, nil]
        def resolve(value)
          case value
          when Hash
            return surface.read(surface.binding_path(value), scope) if surface.binding?(value)
            return call(surface.dialect.call_name(value), value["args"], via: value) if surface.function_call?(value)

            plain(value) { |item| resolve(item) }
          when Array then value.map { |item| resolve(item) }
          else value
          end
        end

        # Resolves a function argument: like {#resolve}, plus strings
        # interpolate.
        #
        # @param value [Object]
        # @return [Object, nil]
        def argument(value)
          case value
          when String then Expression.dynamic?(value) ? interpolate(value) : value
          when Array then value.map { |item| argument(item) }
          when Hash
            return resolve(value) if surface.binding?(value) || surface.function_call?(value)

            plain(value) { |item| argument(item) }
          else value
          end
        end

        # Calls a function by name.
        #
        # @param name [String]
        # @param args [Hash, nil] raw arguments (resolved here unless `resolved:`)
        # @param resolved [Boolean] whether the arguments are already resolved
        # @param via [Hash, nil] the call object, whose `catalogId` names the catalog in v1.0 (nil: the default)
        # @return [Object, nil]
        def call(name, args, resolved: false, via: nil)
          args = (args.is_a?(Hash) ? args : {}).to_h { |key, value| [key.to_s, resolved ? value : argument(value)] }
          return index_of(args) if name == "@index"
          return fail!("function #{name.inspect}: #{SYSTEM_FUNCTIONS}") if name.to_s.start_with?("@")
          return fail!("function #{name.inspect}: a function name is an identifier") if name.to_s.empty?

          catalog, problem = surface.lookup(via)
          return fail!("function #{name.inspect}: #{problem}") unless catalog
          if !@gesture && catalog.functions.activation?(name.to_s)
            return fail!("Function '#{name}' requires user activation context to execute.")
          end

          catalog.functions.call(name.to_s, args, self)
        rescue Functions::Error, Expression::SyntaxError => e
          fail!("function #{name.inspect}: #{e.message}")
        rescue StandardError => e
          # A function that raises on its arguments (a host's, or a
          # built-in handed a value it cannot use) fails the call, not the render.
          fail!("function #{name.inspect} raised #{e.class}: #{e.message}")
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
          when :call then call(node[1], node[2].transform_values { |item| evaluate(item) }, resolved: true)
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

        # The scope's item index, or nil outside a template.
        # @return [Integer, nil] the collection index the scope carries
        def index
          token = scope.to_s.split("/").last
          token&.match?(/\A\d+\z/) ? token.to_i : nil
        end

        private

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
        def fail!(message)
          @on_error&.call(message)
          nil
        end
      end
    end
  end
end
