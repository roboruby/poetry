# frozen_string_literal: true

require "json"
require_relative "expression"
require_relative "functions"

module Poetry
  module Agent
    module A2UI
      # Resolves dynamic values in a scope: a `{ "path" }` binding reads
      # the data model, a `{ "call", "args" }` invokes a registered
      # function with its arguments resolved first (a string argument with
      # `${}` blocks interpolates, an array resolves item by item), and
      # `@index` reads the collection index the scope carries. Problems
      # (an unknown function, a bad argument, a malformed expression)
      # resolve to nil and reach the `on_error` callback.
      #
      # @example
      #   Evaluator.new(surface, "/items/2").resolve({ "call" => "@index", "args" => { "offset" => 1 } }) # => 3
      class Evaluator
        # @return [Surface]
        attr_reader :surface
        # @return [String, nil] the collection-item pointer in effect
        attr_reader :scope

        # @param surface [Surface]
        # @param scope [String, nil]
        # @param on_error [#call, nil] receives each problem's message
        def initialize(surface, scope = nil, on_error: nil)
          @surface = surface
          @scope = scope
          @on_error = on_error
        end

        # Resolves a component property: bindings and calls resolve,
        # everything else is a literal.
        #
        # @param value [Object]
        # @return [Object, nil]
        def resolve(value)
          return value unless value.is_a?(Hash)
          return surface.read(value["path"], scope) if surface.binding?(value)
          return call(value["call"], value["args"]) if surface.function_call?(value)

          value
        end

        # Resolves a function argument: like {#resolve}, plus strings
        # interpolate and arrays and plain objects resolve inside.
        #
        # @param value [Object]
        # @return [Object, nil]
        def argument(value)
          case value
          when String then Expression.dynamic?(value) ? interpolate(value) : value
          when Array then value.map { |item| argument(item) }
          when Hash
            return resolve(value) if surface.binding?(value) || surface.function_call?(value)

            value.transform_values { |item| argument(item) }
          else value
          end
        end

        # Calls a function by name.
        #
        # @param name [String]
        # @param args [Hash, nil] raw arguments (resolved here unless `resolved:`)
        # @param resolved [Boolean] whether the arguments are already resolved
        # @return [Object, nil]
        def call(name, args, resolved: false)
          args = (args.is_a?(Hash) ? args : {}).to_h { |key, value| [key.to_s, resolved ? value : argument(value)] }
          return index_of(args) if name == "@index"

          surface.catalog.functions.call(name.to_s, args, self)
        rescue Functions::Error, Expression::SyntaxError => e
          fail!("function #{name.inspect}: #{e.message}")
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

        # @return [Integer, nil] the collection index the scope carries
        def index
          token = scope.to_s.split("/").last
          token&.match?(/\A\d+\z/) ? token.to_i : nil
        end

        private

        def index_of(args)
          position = index or raise Functions::Error, "@index is only available inside a template"

          position + (Functions.number(args["offset"]) || 0)
        end

        def fail!(message)
          @on_error&.call(message)
          nil
        end
      end
    end
  end
end
