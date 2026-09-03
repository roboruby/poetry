# frozen_string_literal: true

module Poetry
  module Ui
    # Segmented date-and-time editors.
    module DateTimeField
      # A segmented date-and-time editor: one control, one value. The form
      # value is a native <input type=datetime-local> submitting local wall
      # time as YYYY-MM-DDTHH:MM (HH:MM:SS with seconds:), and without JS
      # that native input simply renders, so the field always works.
      # Enhanced, the date segments and the time segments share one row in
      # the locale's own order and separators; the locale decides 12- vs
      # 24-hour editing (hour_cycle: pins it). No zone travels on the wire:
      # the value is the wall time the user typed, for the app to place.
      #
      # A DateTimeField is a DateField specialized to a date and a time -
      # segments share the date-field-* part vocabulary.
      #
      # @example
      #   render Poetry::Ui::DateTimeField::Component.new(
      #     name: "event[starts_at]", label: "Starts", value: "2026-07-13T09:30"
      #   )
      class Component < DateField::Component
        # Projected into the registry, llms.txt, and the agent surface.
        AGENT_RULES = [
          "Date-and-time entry is a DateTimeField (poetry_date_time_field / form.datetime_field) - " \
          "never a DateField beside a TimeField, three selects, or a bare input type=datetime-local " \
          "when the design system is in play; params[<name>] is YYYY-MM-DDTHH:MM (with :SS under " \
          "seconds:), with or without JS.",
          "No zone rides the wire: the value is the wall time the user typed on their own clock - the " \
          "app places it (Time.zone.parse in the controller, or the model's zone).",
          "12- vs 24-hour follows the user's locale automatically (the dayPeriod segment appears only " \
          "under twelve-hour cycles); hour_cycle: pins it when a product must."
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

        option :seconds, :boolean, default: false,
                                   doc: "Adds the seconds segment; the wire format becomes YYYY-MM-DDTHH:MM:SS."
        option :hour_cycle, :string, doc: "Pins the hour cycle (h12/h23/h11/h24) instead of the locale's."

        part "date-time-field", "Root - the controller and the enhanced/disabled surface ride " \
                                "here (segments inside share the date-field-* vocabulary)",
             states: {
               "data-enhanced" => "the controller connected and built segments (no JS = the " \
                                  "native input, visible and styled)",
               "data-disabled" => "disabled: is set",
               "data-invalid" => "invalid: is set (the group wears the destructive ring)"
             }
        part "date-time-field-group", "The bordered segment row - hidden until enhancement, then " \
                                      "the editing surface (cn-input chrome, focus-within ring)",
             states: {
               "data-disabled" => "disabled: is set (chrome dims, pointer events off)",
               "data-invalid" => "invalid: is set (destructive border + ring)"
             }
        part "date-time-field-input", "The native <input type=datetime-local> - THE form value in " \
                                      "both modes; tabindex -1 + aria-hidden once segments exist"

        private

        def input_type
          "datetime-local"
        end

        def slot_prefix
          "date-time-field"
        end

        def iso(candidate)
          candidate.respond_to?(:strftime) ? candidate.strftime("%FT%H:%M#{":%S" if seconds}") : candidate.to_s
        end

        def placeholder_iso
          return iso(placeholder_value) if placeholder_value.present?

          "#{Date.current.strftime("%F")}T12:00#{":00" if seconds}"
        end
      end
    end
  end
end
