# frozen_string_literal: true

require_relative "functions"

module Poetry
  module Agent
    module A2UI
      # Evaluates a component's `checks`: each rule's condition (a binding
      # or a function call) yields a ValidationResult - `{ "valid",
      # "code", "message", "severity" }` - or a boolean (v0.9's validators
      # answer booleans). A failing rule is a failure unless its result
      # names a severity other than error; it carries the result's message,
      # the rule's as the fallback.
      module Checks
        # The message when neither the result nor the rule carries one.
        DEFAULT_MESSAGE = "Check failed"

        module_function

        # The checks that fail for a component and block it (severity error,
        # the default), each as an outcome.
        # @param component [Hash]
        # @param evaluator [Evaluator]
        # @return [Array<Hash>] failures as `{ valid:, code:, message:, severity: }`, `severity` only when the
        #   result named one
        def failures(component, evaluator)
          Array(component["checks"]).filter_map do |rule|
            condition = rule.is_a?(Hash) && condition(rule, evaluator.surface.dialect)
            next unless condition

            outcome = interpret(evaluator.resolve(condition), rule, evaluator)
            outcome unless outcome[:valid] || (outcome[:severity] || "error") != "error"
          end
        end

        # A rule's condition: its `condition`, or in v0.9 a flat rule's own
        # call (`{ "call", "args", "message" }`, as the v0.9 docs write rules).
        # @param rule [Hash]
        # @param dialect [Dialect]
        # @return [Object, nil]
        def condition(rule, dialect)
          return rule["condition"] if rule.key?("condition")

          rule.slice(dialect.call_key, "args") if !dialect.v1? && dialect.call?(rule)
        end

        # A check's result as a validation: a hash carries its own verdict and message, anything else is read as a
        # boolean.
        def interpret(result, rule, evaluator)
          if result.is_a?(Hash)
            { valid: result["valid"] == true, code: result["code"],
              message: result["message"] || rule["message"] || DEFAULT_MESSAGE, severity: result["severity"] }
          else
            { valid: Functions.truthy?(result, evaluator.surface.dialect), code: nil,
              message: rule["message"] || DEFAULT_MESSAGE, severity: nil }
          end
        end

        private_class_method :interpret
      end
    end
  end
end
