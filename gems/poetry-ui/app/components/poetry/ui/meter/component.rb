# frozen_string_literal: true

module Poetry
  module Ui
    # A quantity within a known range.
    module Meter
      # A QUANTITY within a known range - battery, disk usage, seats
      # taken, password strength - never the progress of an operation
      # over time (that is Progress; a meter has no indeterminate
      # state). Renders role=meter with a visible caption (label:), a
      # readout, and a filled track; visually it shares Progress's
      # chrome, so themes style both together.
      #
      # @example
      #   render Poetry::Ui::Meter::Component.new(value: 62, label: "Storage used")
      class Component < Poetry::Core::Component
        # Projected into the registry, llms.txt, and the agent surface.
        AGENT_RULES = [
          "A quantity within a range is a Meter (disk, seats, strength); an operation's " \
          "completion over time is Progress. There is NO indeterminate meter - unknown " \
          "duration means Spinner.",
          "label: is REQUIRED - the meter's accessible name and visible caption.",
          "value_text: replaces the visible readout verbatim (\"3 of 4 seats\"); without it " \
          "the readout shows the percentage of the RANGE. No aria-valuetext - ARIA 1.2 " \
          "deprecated it on role=meter; aria-valuenow carries the value."
        ].freeze

        option :value, :integer, required: true, doc: "The measured quantity, clamped into min:..max:."
        option :min, :integer, default: 0, doc: "The range's lower bound."
        option :max, :integer, default: 100, doc: "The range's upper bound - must exceed min:."
        option :label, :string, required: true, doc: "The meter's accessible name and visible caption."
        option :value_text, :string,
               doc: "Verbatim human-readable value (\"3 of 4 seats\") replacing the percentage readout. Visible " \
                    "readout only - ARIA 1.2 deprecated aria-valuetext on role=meter, so aria-valuenow carries the " \
                    "value."
        option :show_value, :boolean, default: true, doc: "Set false to hide the visible readout."

        part "meter", "Root (role=meter, aria-value*, and the accessible name); label, " \
                      "readout, and track stack here"
        part "meter-label", "The visible caption span (label:)"
        part "meter-value", "The readout - value_text: verbatim, else the range percentage; " \
                            "renders unless show_value: false"
        part "meter-track", "The full-width rail (Progress's cn chrome)"
        part "meter-indicator", "The filled bar - inline width percentage of the range"

        # Enforces the required label and a coherent range.
        # @api private
        def before_render
          raise ArgumentError, "Meter requires label: (the meter's accessible name)" if label.blank?
          raise ArgumentError, "Meter max: must exceed min:" unless max > min
        end

        # @api private
        def call
          content_tag(:div, root_attributes.to_attributes) do
            safe_join([label_part, value_part, track].compact)
          end
        end

        # The fraction of the RANGE - (value - min)/(max - min), never the
        # raw value.
        # @api private
        def percent
          ((clamped - min).to_f / (max - min) * 100).clamp(0, 100)
        end

        # @api private
        def readout
          value_text.presence || "#{percent.round}%"
        end

        # The role is the single token "meter" - a two-token fallback
        # ("meter progressbar") makes checkers treat the element as generic
        # and flag every aria-value* attribute.
        # @api private
        def root_attributes
          html_attributes.merge_if_not_set(
            {
              "data-slot" => "meter", "role" => "meter",
              # No aria-valuetext: ARIA 1.2 deprecated it on role=meter -
              # the visible readout carries the human string, aria-valuenow
              # the value.
              "aria-valuemin" => min, "aria-valuemax" => max, "aria-valuenow" => clamped,
              "aria-label" => label
            }.merge(component_data_attributes)
          )
        end

        private

        def clamped
          value.clamp(min, max)
        end

        def label_part
          content_tag(:span, label, "data-slot" => "meter-label", class: Progress::Style.css(:label))
        end

        def value_part
          return unless show_value

          content_tag(:span, readout, "data-slot" => "meter-value", class: Progress::Style.css(:value))
        end

        def track
          content_tag(:div, "data-slot" => "meter-track", class: Progress::Style.css(:track)) do
            content_tag(:div, nil, "data-slot" => "meter-indicator",
                                   class: Progress::Style.css(:indicator),
                                   style: "width: #{percent.round(4)}%")
          end
        end

        private :percent, :readout, :root_attributes
      end
    end
  end
end
