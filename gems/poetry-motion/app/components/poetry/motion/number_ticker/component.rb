# frozen_string_literal: true

module Poetry
  module Motion
    module NumberTicker
      # A number that counts up to its value when it comes into view. The
      # server renders the final number, formatted, so the page is right
      # before any script runs; the count is decoration on top. Screen
      # readers get the final number once, never the count.
      #
      # @example
      #   <%= poetry_number_ticker(value: 12_480, format: { style: "currency", currency: "USD" }) %>
      class Component < Poetry::Core::Component
        include Poetry::Motion::Options

        AGENT_RULES = [
          "The value is the real number, rendered by the server; never put a placeholder there and let " \
          "the count fill it in.",
          "format: takes Intl.NumberFormat options (style, currency, minimumFractionDigits, ...); the " \
          "server formats the same number the browser counts to."
        ].freeze

        # The symbols the server writes for common currencies; any other code renders before the number.
        CURRENCY_UNITS = { "USD" => "$", "EUR" => "€", "GBP" => "£", "JPY" => "¥", "CAD" => "CA$",
                           "AUD" => "A$" }.freeze

        use_behavior :animate
        use_behavior :spring

        use_stimulus do
          on :root do
            controller :number_ticker do
              register
              value :value, from: :value_number
              value :from, from: :from_number
              value :locale, from: :locale_string, if: -> { locale.present? }
              value :format, from: :format_json, if: -> { format.present? }
              value :spring
              value :trigger
              value :delay, if: -> { delay.positive? }
              value :animate, false, unless: :animate
            end
          end
          on :display do
            controller(:number_ticker) { target :display }
          end
        end

        motion_options spring: :gentle, trigger: :in_view, delay: 0, triggers: %i[load in_view]
        option :value, :float, required: true, doc: "The final number."
        option :from, :float, default: 0, doc: "Where the count starts."
        option :format, ActiveModel::Type::Value.new,
               doc: "Intl.NumberFormat options, camelCase keys (style, currency, minimumFractionDigits, " \
                    "maximumFractionDigits, notation)."
        option :locale, :string, doc: "The locale the number is formatted for; the request's when blank."

        part "number-ticker", "The number; the count runs in the aria-hidden display"
        part "number-ticker-display", "The visible digits, counted up by the controller and restored to the " \
                                      "server's text when the count lands"

        def before_render
          ensure_motion_options!
        end

        def call
          tag.span(**root_attributes) do
            safe_join([tag.span(formatted, class: css(:reader)),
                       tag.span(formatted, "aria-hidden" => "true", "data-slot" => "number-ticker-display",
                                           class: css(:display), **stimulus_attributes_for(:display))])
          end
        end

        # The final number as the server shows it: Rails' number helpers
        # with the same precision, currency and percent the format names.
        #
        # @return [String]
        def formatted
          options = format_options
          precision = options["maximumFractionDigits"] || options["minimumFractionDigits"] ||
                      ((value.to_f % 1).zero? ? 0 : 2)
          number_options = { precision: precision, locale: locale.presence || I18n.locale }
          case options["style"]
          when "currency"
            code = options["currency"].to_s
            helpers.number_to_currency(value, **number_options, unit: CURRENCY_UNITS.fetch(code) { "#{code} " })
          when "percent" then helpers.number_to_percentage(value.to_f * 100, **number_options)
          else helpers.number_with_delimiter(helpers.number_with_precision(value, **number_options), **number_options)
          end
        end

        private

        def format_options = (format || {}).to_h.transform_keys(&:to_s)

        def value_number = value.to_f
        def from_number = from.to_f
        def locale_string = locale.to_s
        def format_json = format_options.to_json
      end
    end
  end
end
