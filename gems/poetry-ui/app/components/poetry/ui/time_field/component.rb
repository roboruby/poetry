# frozen_string_literal: true

module Poetry
  module Ui
    # Segmented time-of-day editors.
    module TimeField
      # A segmented time editor: hour, minute, and - with seconds: -
      # second segments, each typed or stepped independently. The form
      # value is a native <input type=time> submitting HH:MM[:SS], and
      # without JS that native input simply renders, so the field always
      # works. The user's locale decides 12- vs 24-hour editing (an
      # AM/PM segment appears exactly when the locale is twelve-hour);
      # hour_cycle: pins it explicitly.
      #
      # A TimeField is a DateField specialized to time-of-day - segments
      # share the date-field-* part vocabulary.
      #
      # @example
      #   render Poetry::Ui::TimeField::Component.new(
      #     name: "starts_at", label: "Start time", value: "09:30"
      #   )
      class Component < DateField::Component
        # Projected into the registry, llms.txt, and the agent surface.
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

        # Adds the seconds segment; the wire format becomes HH:MM:SS.
        option :seconds, :boolean, default: false
        # Pins the hour cycle (h12/h23/h11/h24) instead of the locale's.
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
