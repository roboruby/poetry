# frozen_string_literal: true

require "json"
require "time"
require "active_support"
require "active_support/number_helper"
require_relative "protocol"

module Poetry
  module Agent
    module A2UI
      # The renderer's function registry: named functions an agent may
      # reference in a component's dynamic values and checks, each with the
      # declaration a catalog document publishes (`functions` and
      # `$defs.anyFunction`). {Functions.basic} holds the spec's basic
      # catalog set - the validators, the formatters, the boolean
      # combinators, `openUrl` - implemented from their descriptions;
      # `@index` is the evaluator's own system function.
      #
      # @example
      #   Functions.basic.call("pluralize", { "value" => 2, "one" => "item", "other" => "items" }, evaluator)
      #   # => "items"
      class Functions
        # A missing function or a bad argument list.
        class Error < StandardError; end

        # One declared function.
        Definition = Struct.new(:name, :description, :returns, :params, :required, :activation, :impl,
                                keyword_init: true)

        # The email shape the basic catalog names.
        EMAIL = /\A[^\s@]+@[^\s@]+\.[^\s@]+\z/
        # Currency symbols (and fraction digits) by ISO 4217 code; other
        # codes render as a code prefix.
        CURRENCIES = { "USD" => ["$", 2], "EUR" => ["€", 2], "GBP" => ["£", 2], "JPY" => ["¥", 0],
                       "CNY" => ["CN¥", 2], "INR" => ["₹", 2], "KRW" => ["₩", 0], "BRL" => ["R$", 2],
                       "CAD" => ["CA$", 2], "AUD" => ["A$", 2], "MXN" => ["MX$", 2], "CHF" => ["CHF ", 2] }.freeze
        # Unicode TR35 date-pattern fields to strftime.
        DATE_FIELDS = { "yyyy" => "%Y", "yy" => "%y", "y" => "%Y", "MMMM" => "%B", "MMM" => "%b", "MM" => "%m",
                        "M" => "%-m", "dd" => "%d", "d" => "%-d", "EEEE" => "%A", "EEE" => "%a", "EE" => "%a",
                        "E" => "%a", "HH" => "%H", "H" => "%-H", "hh" => "%I", "h" => "%-I", "mm" => "%M",
                        "m" => "%-M", "ss" => "%S", "s" => "%-S", "a" => "%p", "z" => "%Z", "Z" => "%z",
                        "X" => "%:z", "XXX" => "%:z" }.freeze

        # The basic catalog's functions.
        #
        # @return [Functions]
        def self.basic
          @basic ||= new.tap { |registry| Basic.install(registry) }
        end

        # The boolean reading of a value: a ValidationResult by its
        # `valid`, strings by content, nil and false as false.
        #
        # @param value [Object]
        # @return [Boolean]
        def self.truthy?(value)
          case value
          when Hash then value["valid"] == true
          when String then !value.empty? && !%w[false 0].include?(value.downcase)
          when nil, false then false
          else true
          end
        end

        # @param value [Object]
        # @return [Numeric, nil] the value as a number, when it is one
        def self.number(value)
          case value
          when Numeric then value
          when String
            text = value.strip
            return if text.empty?

            text.match?(/\A-?\d+\z/) ? text.to_i : Float(text, exception: false)
          end
        end

        def initialize
          @definitions = {}
        end

        # Declares a function.
        #
        # @param name [String]
        # @param description [String]
        # @param returns [String] the spec's `returnType`
        # @param params [Hash{String => Hash}] argument schemas by name
        # @param required [Array<String>] required argument names
        # @param activation [Boolean] whether the call needs a user activation
        # @yieldparam args [Hash{String => Object}] the resolved arguments
        # @yieldparam evaluator [Evaluator] the calling evaluator
        # @return [Functions] self
        def define(name, description:, returns:, params: {}, required: [], activation: false, &impl)
          @definitions[name] = Definition.new(name: name, description: description, returns: returns, params: params,
                                              required: required, activation: activation, impl: impl)
          self
        end

        # @return [Array<String>] the declared names
        def names
          @definitions.keys
        end

        # @param name [String]
        # @return [Boolean]
        def declared?(name)
          @definitions.key?(name)
        end

        # Calls a function with resolved arguments.
        #
        # @param name [String]
        # @param args [Hash{String => Object}]
        # @param evaluator [Evaluator]
        # @return [Object]
        # @raise [Error] for an unknown function or a missing argument
        def call(name, args, evaluator)
          definition = @definitions[name] or raise Error, "unknown function #{name.inspect}"
          missing = definition.required - args.keys
          raise Error, "#{name}: missing #{missing.join(", ")}" if missing.any?

          definition.impl.call(args, evaluator)
        end

        # The catalog document's `functions` section.
        #
        # @return [Hash{String => Hash}]
        def schema
          @definitions.transform_values do |definition|
            call = { "type" => "object",
                     "properties" => { "call" => { "const" => definition.name },
                                       "args" => arguments_schema(definition) },
                     "required" => ["call", *("args" if definition.required.any?)] }
            document = { "type" => "object", "description" => definition.description,
                         "returnType" => definition.returns }
            document["requiresUserActivation"] = true if definition.activation
            document.merge("allOf" => [{ "$ref" => "#{COMMON_TYPES}FunctionCommon" }, call],
                           "unevaluatedProperties" => false)
          end
        end

        # The catalog document's `$defs.anyFunction`.
        #
        # @return [Hash]
        def any_function
          { "oneOf" => names.map { |name| { "$ref" => "#/functions/#{name}" } } }
        end

        private

        def arguments_schema(definition)
          schema = { "type" => "object", "properties" => definition.params, "unevaluatedProperties" => false }
          schema["required"] = definition.required if definition.required.any?
          schema
        end

        # The basic catalog's set, from the spec's descriptions.
        module Basic
          # A parameter schema referencing one of the common dynamic types.
          DYNAMIC = lambda { |kind, description|
            { "$ref" => "#{COMMON_TYPES}Dynamic#{kind}", "description" => description }
          }
          # The CLDR plural categories `pluralize` selects among.
          PLURAL_CATEGORIES = %w[zero one two few many other].freeze
          # The argument every validator checks.
          CHECKED = { "value" => { "description" => "The value to check." } }.freeze

          module_function

          # A boolean list argument (`and`, `or`).
          #
          # @return [Hash]
          def list
            { "values" => { "type" => "array", "description" => "The values to combine.",
                            "items" => { "$ref" => "#{COMMON_TYPES}DynamicBoolean" }, "minItems" => 2 } }
          end

          # @param registry [Functions]
          # @return [void]
          def install(registry)
            validators(registry)
            formatters(registry)
            combinators(registry)
          end

          # @api private
          def validators(registry)
            registry.define("required", description: "Checks that the value is not null, undefined, or empty.",
                                        returns: "validationResult", required: %w[value], params: CHECKED) do |args, _|
              result(present?(args["value"]))
            end
            pattern = { "pattern" => { "type" => "string", "description" => "The regular expression." } }
            registry.define("regex", description: "Checks that the value matches a regular expression string.",
                                     returns: "validationResult", required: %w[value pattern],
                                     params: CHECKED.merge(pattern)) do |args, _|
              regex(args["value"], args["pattern"])
            end
            bounds = { "min" => { "type" => "number", "description" => "The minimum." },
                       "max" => { "type" => "number", "description" => "The maximum." } }
            registry.define("length", description: "Checks string length constraints.", returns: "validationResult",
                                      required: %w[value], params: CHECKED.merge(bounds)) do |args, _|
              result(within?(args["value"].to_s.length, args["min"], args["max"]))
            end
            registry.define("numeric", description: "Checks numeric range constraints.", returns: "validationResult",
                                       required: %w[value], params: CHECKED.merge(bounds)) do |args, _|
              number = Functions.number(args["value"])
              result(!number.nil? && within?(number, args["min"], args["max"]))
            end
            registry.define("email", description: "Checks that the value is a valid email address.",
                                     returns: "validationResult", required: %w[value], params: CHECKED) do |args, _|
              result(args["value"].to_s.match?(EMAIL))
            end
          end

          # @api private
          def formatters(registry)
            grouping = { "decimals" => DYNAMIC.call("Number", "Fraction digits to show."),
                         "grouping" => DYNAMIC.call("Boolean", "Thousands separators (default true).") }
            template = { "value" => DYNAMIC.call("String", "The string with ${} blocks.") }
            registry.define("formatString", description: "Interpolates data model values and function results " \
                                                         "into a string: ${/path}, ${name(arg: value)}.",
                                            returns: "string", required: %w[value],
                                            params: template) do |args, evaluator|
              evaluator.stringify(args["value"])
            end
            amount = { "value" => DYNAMIC.call("Number", "The number.") }
            registry.define("formatNumber", description: "Formats a number with grouping and decimal precision.",
                                            returns: "string", required: %w[value],
                                            params: amount.merge(grouping)) do |args, _|
              format_number(args)
            end
            money = amount.merge("currency" => DYNAMIC.call("String", "The ISO 4217 code."))
            registry.define("formatCurrency", description: "Formats a number as a currency string.", returns: "string",
                                              required: %w[value currency],
                                              params: money.merge(grouping)) do |args, _|
              format_currency(args)
            end
            registry.define("formatDate", description: "Formats a timestamp with a Unicode TR35 pattern " \
                                                       "(yyyy-MM-dd, MMM d, HH:mm).",
                                          returns: "string", required: %w[value format],
                                          params: { "value" => DYNAMIC.call("Value", "An ISO 8601 string or epoch."),
                                                    "format" => DYNAMIC.call("String",
                                                                             "The TR35 pattern.") }) do |args, _|
              format_date(args["value"], args["format"])
            end
            forms = PLURAL_CATEGORIES.to_h { |category| [category, DYNAMIC.call("String", "The #{category} form.")] }
            forms["value"] = DYNAMIC.call("Number", "The number.")
            registry.define("pluralize", description: "Picks the string for a number's CLDR plural category.",
                                         returns: "string", required: %w[value other], params: forms) do |args, _|
              pluralize(args)
            end
            registry.define("openUrl", description: "Opens an http(s) URL; the renderer links to it.", returns: "void",
                                       activation: true, required: %w[url],
                                       params: { "url" => { "description" => "The URL to open." } }) do |args, _|
              open_url(args["url"])
            end
          end

          # @api private
          def combinators(registry)
            registry.define("and", description: "Logical AND of a list of values.", returns: "boolean",
                                   required: %w[values], params: list) do |args, _|
              Array(args["values"]).all? { |value| Functions.truthy?(value) }
            end
            registry.define("or", description: "Logical OR of a list of values.", returns: "boolean",
                                  required: %w[values], params: list) do |args, _|
              Array(args["values"]).any? { |value| Functions.truthy?(value) }
            end
            registry.define("not", description: "Logical NOT of a value.", returns: "boolean", required: %w[value],
                                   params: { "value" => DYNAMIC.call("Boolean", "The value.") }) do |args, _|
              !Functions.truthy?(args["value"])
            end
          end

          # @api private
          def result(valid, code: nil)
            code ? { "valid" => valid, "code" => code } : { "valid" => valid }
          end

          # @api private
          def present?(value)
            return false if value.nil?
            return !value.strip.empty? if value.is_a?(String)
            return !value.empty? if value.respond_to?(:empty?)

            true
          end

          # @api private
          def within?(number, min, max)
            (min.nil? || number >= min) && (max.nil? || number <= max)
          end

          # @api private
          def regex(value, pattern)
            expression = Regexp.new(pattern.to_s, timeout: 0.05)
            result(expression.match?(value.to_s))
          rescue Regexp::TimeoutError
            result(false, code: "REGEX_TIMEOUT")
          rescue RegexpError => e
            raise Error, "regex: #{e.message}"
          end

          # @api private
          def format_number(args)
            number = Functions.number(args["value"]) or return ""
            decimals = Functions.number(args["decimals"])
            delimiter = args["grouping"] == false ? "" : ","
            if decimals
              ActiveSupport::NumberHelper.number_to_rounded(number, precision: decimals.to_i, delimiter: delimiter,
                                                                    separator: ".")
            else
              number = number.to_i if number.is_a?(Float) && number == number.floor
              ActiveSupport::NumberHelper.number_to_delimited(number, delimiter: delimiter, separator: ".")
            end
          end

          # @api private
          def format_currency(args)
            number = Functions.number(args["value"]) or return ""
            code = args["currency"].to_s.upcase
            unit, digits = CURRENCIES.fetch(code, ["#{code} ", 2])
            decimals = Functions.number(args["decimals"])&.to_i || digits
            ActiveSupport::NumberHelper.number_to_currency(number, unit: unit, precision: decimals, separator: ".",
                                                                   delimiter: args["grouping"] == false ? "" : ",",
                                                                   format: "%u%n", negative_format: "-%u%n")
          end

          # @api private
          def format_date(value, pattern)
            time = parse_time(value) or return ""
            time.strftime(strftime_pattern(pattern.to_s))
          end

          # @api private
          def parse_time(value)
            case value
            when Time then value
            when Numeric then Time.at(value.abs >= 1e11 ? value / 1000.0 : value).utc
            when String then parse_time_string(value.strip)
            end
          end

          # ISO 8601 first (a date alone is midnight UTC), then anything
          # Time.parse reads; nil when neither does.
          # @api private
          def parse_time_string(text)
            return if text.empty?
            return Time.utc(*text.split("-").map(&:to_i)) if text.match?(/\A\d{4}-\d{2}-\d{2}\z/)

            Time.iso8601(text)
          rescue ArgumentError
            begin
              Time.parse(text)
            rescue ArgumentError
              nil
            end
          end

          # @api private
          def strftime_pattern(pattern)
            pattern.gsub(/'((?:[^']|'')*)'|([A-Za-z])\2*|%/) do |token|
              if token.start_with?("'") then token[1...-1].gsub("''", "'").gsub("%", "%%")
              elsif token == "%" then "%%"
              else DATE_FIELDS[token] || DATE_FIELDS[token[0] * [token.length, 4].min] || token
              end
            end
          end

          # @api private
          def pluralize(args)
            number = Functions.number(args["value"])
            category = plural_category(number)
            form = args[category]
            form = args["other"] if form.nil? || (category != "other" && !args.key?(category))
            form.to_s
          end

          # @api private
          def plural_category(number)
            return "other" if number.nil?
            return "zero" if number.zero?
            return "one" if number == 1
            return "two" if number == 2

            "other"
          end

          # @api private
          def open_url(url)
            text = url.to_s.strip
            raise Error, "openUrl: only http and https URLs open" unless text.match?(%r{\Ahttps?://\S+\z})

            text
          end
        end
      end
    end
  end
end
