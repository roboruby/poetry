# frozen_string_literal: true

require_relative "functions"

module Poetry
  module Agent
    module A2UI
      # Evaluates a component's `checks`: each rule's condition (a binding
      # or a function call) yields a ValidationResult - `{ "valid",
      # "code", "message", "severity" }` - or a boolean; a failing rule
      # of error severity is a failure, carrying the result's message or
      # the rule's fallback.
      module Checks
        # The message when neither the result nor the rule carries one.
        DEFAULT_MESSAGE = "Check failed"

        module_function

        # @param component [Hash]
        # @param evaluator [Evaluator]
        # @return [Array<Hash>] failures as `{ code:, message:, severity: }`
        def failures(component, evaluator)
          Array(component["checks"]).filter_map do |rule|
            next unless rule.is_a?(Hash) && rule["condition"]

            outcome = interpret(evaluator.resolve(rule["condition"]), rule)
            outcome unless outcome[:valid] || outcome[:severity] != "error"
          end
        end

        # @api private
        def interpret(result, rule)
          if result.is_a?(Hash)
            { valid: result["valid"] == true, code: result["code"],
              message: result["message"] || rule["message"] || DEFAULT_MESSAGE,
              severity: result["severity"] || "error" }
          else
            { valid: Functions.truthy?(result), code: nil, message: rule["message"] || DEFAULT_MESSAGE,
              severity: "error" }
          end
        end
      end
    end
  end
end
