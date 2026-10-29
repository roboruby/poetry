# frozen_string_literal: true

require "json"
require "date"
require "time"
require "active_support"
require "active_support/number_helper"
require_relative "protocol"
require_relative "dialect"

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
        Definition = Struct.new(:name, :description, :returns, :params, :required, :activation, :callers, :impl,
                                keyword_init: true)

        # The spec's execution boundaries: who may invoke a function.
        CALLERS = %w[rendererOnly agentOnly rendererOrAgent].freeze

        # The email shape the basic catalog names: an ASCII local part, a
        # domain, and a top-level domain of two letters or more.
        EMAIL = /\A[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}\z/
        # What v1.0's `email` says of an address it refuses.
        EMAIL_FAILURE = { "valid" => false, "code" => "INVALID_EMAIL",
                          "message" => "Please enter a valid email address (e.g. user@example.com).",
                          "severity" => "error" }.freeze
        # JSON Schema's types, for a declared parameter's `type`.
        TYPES = { "string" => String, "boolean" => [TrueClass, FalseClass], "number" => Numeric, "array" => Array,
                  "object" => Hash }.freeze

        # The schemes `openUrl` opens.
        URL_SCHEMES = %w[http https mailto tel].freeze
        # Currency symbols (and fraction digits) by ISO 4217 code; other
        # codes render as a code prefix.
        CURRENCIES = { "USD" => ["$", 2], "EUR" => ["€", 2], "GBP" => ["£", 2], "JPY" => ["¥", 0],
                       "CNY" => ["CN¥", 2], "INR" => ["₹", 2], "KRW" => ["₩", 0], "BRL" => ["R$", 2],
                       "CAD" => ["CA$", 2], "AUD" => ["A$", 2], "MXN" => ["MX$", 2], "CHF" => ["CHF ", 2] }.freeze
        # The most fraction digits a formatter shows (a browser's own
        # limit), so a `decimals` argument cannot ask for a string of any length.
        MAX_DECIMALS = 100
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

        # The boolean reading of a value: strings by content, nil and false
        # as false. In v1.0 a ValidationResult reads as its `valid`; in v0.9
        # an object is simply present, so it reads as true.
        #
        # @param value [Object]
        # @param dialect [Dialect] the surface's protocol version
        # @return [Boolean]
        def self.truthy?(value, dialect = Dialect::V1_0)
          case value
          when Hash then dialect.v1? && [true, false].include?(value["valid"]) ? value["valid"] : true
          when String then !value.empty? && !%w[false 0].include?(value.downcase)
          when nil, false then false
          else true
          end
        end

        # A URL `openUrl` would open: a non-empty string whose scheme is one
        # it allows (http, https, mailto, tel).
        # @param url [Object]
        # @return [Boolean]
        def self.openable?(url)
          text = url.is_a?(String) ? url.strip : ""
          scheme = text[/\A([a-zA-Z][a-zA-Z0-9+.-]*):/, 1]
          !scheme.nil? && URL_SCHEMES.include?(scheme.downcase) && text.match?(/\A\S+\z/)
        end

        # A value as a number: numerics as they are, numeric strings parsed, anything else nil.
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

        # An empty function set.
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
        # @param callers [String] the execution boundary (`rendererOnly` - the default - keeps the
        #   function out of an agent's `callRendererFunction`; `agentOnly` / `rendererOrAgent` admit it)
        # @yieldparam args [Hash{String => Object}] the resolved arguments
        # @yieldparam evaluator [Evaluator] the calling evaluator
        # @return [Functions] self
        # @raise [ArgumentError] for an unknown boundary
        def define(name, description:, returns:, params: {}, required: [], activation: false, # rubocop:disable Metrics/ParameterLists
                   callers: "rendererOnly", &impl)
          raise ArgumentError, "callers must be one of #{CALLERS.join(", ")}" unless CALLERS.include?(callers)

          @definitions[name] = Definition.new(name: name, description: description, returns: returns, params: params,
                                              required: required, activation: activation, callers: callers, impl: impl)
          self
        end

        # Whether a declared function may be called by the agent.
        # @param name [String]
        # @return [Boolean] whether an agent may invoke the function through `callRendererFunction`
        def agent_callable?(name)
          definition = @definitions[name]
          !definition.nil? && definition.callers != "rendererOnly"
        end

        # Whether a declared function needs a user's gesture (an agent's call never is one).
        # @param name [String]
        # @return [Boolean]
        def activation?(name)
          @definitions[name]&.activation == true
        end

        # The declared function names.
        # @return [Array<String>] the declared names
        def names
          @definitions.keys
        end

        # Whether a function is declared.
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

          mistyped = definition.params.find { |param, schema| !args[param].nil? && !typed?(args[param], schema) }
          raise Error, "Invalid argument '#{mistyped.first}' for #{name}: expected #{mistyped.last["type"]}" if mistyped

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
                         "returnType" => definition.returns, "allowedCallers" => definition.callers }
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

        # Whether a resolved argument has its parameter's declared type (a
        # parameter without one takes anything).
        def typed?(value, schema)
          type = schema.is_a?(Hash) ? schema["type"] : nil
          return value.is_a?(Integer) || (value.is_a?(Float) && (value % 1).zero?) if type == "integer"
          return true unless TYPES.key?(type)

          Array(TYPES[type]).any? { |klass| value.is_a?(klass) }
        end

        # A function's argument schema: its params as properties, the required ones listed.
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

          # Declares the basic catalog's functions on a registry.
          # @param registry [Functions]
          # @return [void]
          def install(registry)
            validators(registry)
            formatters(registry)
            combinators(registry)
          end

          # Defines the validation functions: required, regex and the numeric bounds.
          def validators(registry)
            registry.define("required", description: "Checks that the value is not null, undefined, or empty.",
                                        returns: "validationResult", required: %w[value],
                                        params: CHECKED) do |args, evaluator|
              result(present?(args["value"]), evaluator)
            end
            pattern = { "pattern" => { "type" => "string", "description" => "The regular expression." } }
            registry.define("regex", description: "Checks that the value matches a regular expression string.",
                                     returns: "validationResult", required: %w[value pattern],
                                     params: CHECKED.merge(pattern)) do |args, evaluator|
              regex(args["value"], args["pattern"], evaluator)
            end
            bounds = { "min" => { "type" => "number", "description" => "The minimum." },
                       "max" => { "type" => "number", "description" => "The maximum." } }
            registry.define("length", description: "Checks string length constraints.", returns: "validationResult",
                                      required: %w[value], params: CHECKED.merge(bounds)) do |args, evaluator|
              result(within?(length_of(args["value"], evaluator), args["min"], args["max"]), evaluator)
            end
            registry.define("numeric", description: "Checks numeric range constraints.", returns: "validationResult",
                                       required: %w[value], params: CHECKED.merge(bounds)) do |args, evaluator|
              number = Functions.number(args["value"])
              result(!number.nil? && within?(number, args["min"], args["max"]), evaluator)
            end
            registry.define("email", description: "Checks that the value is a valid email address.",
                                     returns: "validationResult", required: %w[value],
                                     params: CHECKED) do |args, evaluator|
              email(args["value"], evaluator)
            end
          end

          # Defines the formatting functions: strings, numbers, currency, dates and plurals.
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
                                            params: amount.merge(grouping)) do |args, evaluator|
              format_number(args, evaluator)
            end
            money = amount.merge("currency" => DYNAMIC.call("String", "The ISO 4217 code."))
            registry.define("formatCurrency", description: "Formats a number as a currency string.", returns: "string",
                                              required: %w[value currency],
                                              params: money.merge(grouping)) do |args, evaluator|
              format_currency(args, evaluator)
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
            registry.define("openUrl",
                            description: "Opens a URL (http, https, mailto or tel); the renderer links to it.",
                            returns: "void",
                            activation: true, required: %w[url],
                            params: { "url" => { "description" => "The URL to open." } }) do |args, _|
              open_url(args["url"])
            end
          end

          # Defines the logical functions: and, or and not.
          def combinators(registry)
            registry.define("and", description: "Logical AND of a list of values.", returns: "boolean",
                                   required: %w[values], params: list) do |args, evaluator|
              operands("and", args["values"]).all? { |value| Functions.truthy?(value, dialect_of(evaluator)) }
            end
            registry.define("or", description: "Logical OR of a list of values.", returns: "boolean",
                                  required: %w[values], params: list) do |args, evaluator|
              operands("or", args["values"]).any? { |value| Functions.truthy?(value, dialect_of(evaluator)) }
            end
            registry.define("not", description: "Logical NOT of a value.", returns: "boolean", required: %w[value],
                                   params: { "value" => DYNAMIC.call("Boolean", "The value.") }) do |args, evaluator|
              !Functions.truthy?(args["value"], dialect_of(evaluator))
            end
          end

          # A validator's answer in the surface's version: v1.0's
          # ValidationResult (with its code when it fails), v0.9's boolean.
          # @api private
          def result(valid, evaluator, code: nil)
            return valid unless dialect_of(evaluator).v1?

            code ? { "valid" => valid, "code" => code } : { "valid" => valid }
          end

          # The protocol version a call runs in: its surface's, v1.0's without one.
          # @api private
          def dialect_of(evaluator)
            evaluator.respond_to?(:surface) && evaluator.surface ? evaluator.surface.dialect : Dialect::V1_0
          end

          # Whether a value is present: not nil, not a blank string, not an
          # empty list (an object, even an empty one, is present).
          # @api private
          def present?(value)
            return false if value.nil?
            return !value.strip.empty? if value.is_a?(String)
            return !value.empty? if value.is_a?(Array)

            true
          end

          # The length `length` checks: a list's items, nothing's zero, any
          # other value's characters as it displays.
          def length_of(value, evaluator)
            return value.size if value.is_a?(Array)
            return 0 if value.nil?

            evaluator.respond_to?(:stringify) ? evaluator.stringify(value).length : value.to_s.length
          end

          # v1.0's email answer carries its code and message; v0.9's is a boolean.
          def email(value, evaluator)
            valid = value.is_a?(String) && value.match?(EMAIL)
            return valid unless dialect_of(evaluator).v1?

            valid ? { "valid" => true } : EMAIL_FAILURE.dup
          end

          # A combinator's operands: a list of two or more.
          def operands(name, values)
            raise Error, "#{name} requires at least 2 values" unless values.is_a?(Array) && values.size >= 2

            values
          end

          # A boolean argument with a default: v1.0 reads a ValidationResult as its verdict.
          def flag(value, evaluator, default:)
            value.nil? ? default : Functions.truthy?(value, dialect_of(evaluator))
          end

          # Whether a number sits inside the optional min and max bounds.
          def within?(number, min, max)
            (min.nil? || number >= min) && (max.nil? || number <= max)
          end

          # A regex validation with a match timeout; a bad pattern raises.
          # @api private
          def regex(value, pattern, evaluator)
            expression = Regexp.new(pattern.to_s, timeout: 0.05)
            result(expression.match?(value.to_s), evaluator)
          rescue Regexp::TimeoutError
            result(false, evaluator, code: "REGEX_TIMEOUT")
          rescue RegexpError => e
            raise Error, "regex: #{e.message}"
          end

          # A number with thousands separators and the requested fraction digits; an empty string for no number.
          def format_number(args, evaluator)
            number = Functions.number(args["value"]) or return ""
            decimals = Functions.number(args["decimals"])&.clamp(0, MAX_DECIMALS)
            delimiter = flag(args["grouping"], evaluator, default: true) ? "," : ""
            if decimals
              ActiveSupport::NumberHelper.number_to_rounded(number, precision: decimals.to_i, delimiter: delimiter,
                                                                    separator: ".")
            else
              number = number.to_i if number.is_a?(Float) && number == number.floor
              ActiveSupport::NumberHelper.number_to_delimited(number, delimiter: delimiter, separator: ".")
            end
          end

          # A number as currency: the code's unit and digits, grouping and decimals from the arguments.
          def format_currency(args, evaluator)
            number = Functions.number(args["value"]) or return ""
            code = args["currency"].to_s.upcase
            unit, digits = CURRENCIES.fetch(code, ["#{code} ", 2])
            decimals = Functions.number(args["decimals"])&.clamp(0, MAX_DECIMALS)&.to_i || digits
            delimiter = flag(args["grouping"], evaluator, default: true) ? "," : ""
            ActiveSupport::NumberHelper.number_to_currency(number, unit: unit, precision: decimals, separator: ".",
                                                                   delimiter: delimiter, format: "%u%n",
                                                                   negative_format: "-%u%n")
          end

          # A time value rendered through a date pattern, or as an ISO 8601
          # UTC instant for the pattern "ISO"; an empty string when the value
          # is not a time.
          def format_date(value, pattern)
            time = parse_time(value) or return ""
            return time.utc.iso8601(3) if pattern.to_s == "ISO"

            time.strftime(strftime_pattern(pattern.to_s))
          end

          # A Time from a time, a number in seconds or milliseconds, or a string; nil otherwise.
          def parse_time(value)
            case value
            when Time then value
            when Numeric then Time.at(value.abs >= 1e11 ? value / 1000.0 : value).utc
            when String then parse_time_string(value.strip)
            end
          end

          # ISO 8601 first (a date alone is midnight UTC), then anything
          # Time.parse reads; nil when neither does.
          def parse_time_string(text)
            return if text.empty?

            date = text.match(/\A(\d{4})-(\d{2})-(\d{2})/)
            return if date && !Date.valid_date?(*date.captures.map(&:to_i))
            return Time.utc(*text.split("-").map(&:to_i)) if text.match?(/\A\d{4}-\d{2}-\d{2}\z/)

            Time.iso8601(text)
          rescue ArgumentError
            begin
              Time.parse(text)
            rescue ArgumentError
              nil
            end
          end

          # A date pattern in strftime form: quoted runs stay literal, letter runs map to their fields.
          def strftime_pattern(pattern)
            pattern.gsub(/'((?:[^']|'')*)'|([A-Za-z])\2*|%/) do |token|
              if token.start_with?("'") then token[1...-1].gsub("''", "'").gsub("%", "%%")
              elsif token == "%" then "%%"
              else DATE_FIELDS[token] || DATE_FIELDS[token[0] * [token.length, 4].min] || token
              end
            end
          end

          # The plural form for a number, falling back to the other form.
          # @api private
          def pluralize(args)
            number = Functions.number(args["value"])
            category = plural_category(number)
            form = args[category]
            form = args["other"] if form.nil? || (category != "other" && !args.key?(category))
            form.to_s
          end

          # The plural category of a number: zero, one, two, or other.
          def plural_category(number)
            return "other" if number.nil?
            return "zero" if number.zero?
            return "one" if number == 1
            return "two" if number == 2

            "other"
          end

          # Opening is the renderer's to do (it links to the URL), so the
          # call answers nothing; a URL it would not open is an error.
          def open_url(url)
            return if url.nil? || (url.is_a?(String) && url.strip.empty?)
            raise Error, "openUrl: only http, https, mailto and tel URLs open" unless Functions.openable?(url)

            nil
          end

          private_class_method :validators, :formatters, :combinators, :within?, :format_number, :format_currency,
                               :length_of, :email, :operands, :flag
          private_class_method :format_date, :parse_time, :parse_time_string, :strftime_pattern, :plural_category
          private_class_method :open_url
        end
      end
    end
  end
end
