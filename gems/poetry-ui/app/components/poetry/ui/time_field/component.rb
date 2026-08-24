# frozen_string_literal: true

module Poetry
  module Ui
    module TimeField
      # The segmented time editor: DateField at hour granularity - one
      # segment engine, two components. The
      # native input is <input type=time>, the wire format HH:MM[:SS],
      # and the locale decides 12- vs 24-hour editing (a dayPeriod
      # segment appears exactly when the locale is twelve-hour;
      # hour_cycle: pins it). Segments share the date-field-* part
      # vocabulary - the controller builds them, and TimeField IS a
      # DateField underneath (the NumberField/InputGroup precedent for
      # cross-component slot reuse).
      #
      # @example
      #   render Poetry::Ui::TimeField::Component.new(
      #     name: "starts_at", label: "Start time", value: "09:30"
      #   )
      class Component < DateField::Component
        AGENT_RULES = [
          "Time entry is a TimeField (poetry_time_field / form.time_field) - never a masked " \
          "Input or a pair of selects; params[<name>] is HH:MM (HH:MM:SS with seconds:).",
          "12- vs 24-hour follows the user's locale automatically (the dayPeriod segment " \
          "appears only under twelve-hour cycles); hour_cycle: pins it when a product must.",
          "For a date AND a time, compose a DateField and a TimeField side by side - there " \
          "is no datetime component by design."
        ].freeze

        # EXTENDS DateField's root declaration (extend: true merges into
        # the inherited element) - same date-field controller, two more
        # values; group/input inherit untouched.
        use_stimulus do
          on :root, extend: true do
            controller :date_field do
              value :seconds, true, if: :seconds
              value :hour_cycle, if: -> { hour_cycle.present? }
            end
          end
        end

        # HH:MM[:SS] editing; seconds: adds the third segment.
        option :seconds, :boolean, default: false
        # Pin the hour cycle (h12/h23/h11/h24) instead of the locale's.
        option :hour_cycle, :string

        part "time-field", "Root - the controller and the enhanced/disabled surface ride " \
                           "here (segments inside share the date-field-* vocabulary)",
             states: {
               "data-enhanced" => "the controller connected and built segments (no JS = the " \
                                  "native input, visible and styled)",
               "data-disabled" => "disabled: is set",
               "data-invalid" => "invalid: is set (the group wears the destructive ring)"
             }
        part "time-field-group", "The bordered segment row - hidden until enhancement, then " \
                                 "the editing surface (cn-input chrome, focus-within ring)",
             states: {
               "data-disabled" => "disabled: is set (chrome dims, pointer events off)",
               "data-invalid" => "invalid: is set (destructive border + ring)"
             }
        part "time-field-input", "The native <input type=time> - THE form value in both " \
                                 "modes; tabindex -1 + aria-hidden once segments exist"

        private

        def input_type
          "time"
        end

        def slot_prefix
          "time-field"
        end

        def iso(candidate)
          candidate.respond_to?(:strftime) ? candidate.strftime("%H:%M#{":%S" if seconds}") : candidate.to_s
        end

        def placeholder_iso
          placeholder_value.present? ? iso(placeholder_value) : "12:00#{":00" if seconds}"
        end
      end
    end
  end
end
