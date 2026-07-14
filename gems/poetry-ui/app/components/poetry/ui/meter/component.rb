# frozen_string_literal: true

module Poetry
  module Ui
    module Meter
      # The Meter (the react-aria wave): a QUANTITY within a
      # known range - battery, disk usage, seats taken, password strength -
      # never the progress of an operation over time (that is Progress;
      # concretely, a meter has no indeterminate state, by construction).
      # Wears Progress's visual chrome verbatim (the NumberField
      # composition precedent - zero new theme CSS); the semantic delta is
      # the ROLE: the two-token fallback `meter progressbar` (Chrome
      # historically fell back from meter on its own, Firefox lacked
      # role=meter entirely - react-aria useMeter.ts:40-45), so AT that
      # understands meter uses it and everything else lands on progressbar.
      class Component < Poetry::Core::Component
        AGENT_RULES = [
          "A quantity within a range is a Meter (disk, seats, strength); an operation's " \
          "completion over time is Progress. There is NO indeterminate meter - unknown " \
          "duration means Spinner.",
          "label: is REQUIRED - the meter's accessible name and visible caption.",
          "value_label: replaces the percent readout AND aria-valuetext verbatim " \
          "(\"3 of 4 seats\"); without it both show the percentage of the RANGE."
        ].freeze

        option :value, :integer, required: true
        option :min, :integer, default: 0
        option :max, :integer, default: 100
        # required: the hand raise in before_render carries the message;
        # the flag carries the fact to the registry (the Progress twin).
        option :label, :string, required: true
        # Verbatim human-readable value ("3 of 4") - readout + valuetext.
        option :value_label, :string
        option :show_value, :boolean, default: true

        part "meter", "Root (role=\"meter progressbar\" - the two-token fallback - plus " \
                      "aria-value* and the accessible name); label, readout, and track " \
                      "stack here"
        part "meter-label", "The visible caption span (label:)"
        part "meter-value", "The readout - value_label: verbatim, else the range percentage; " \
                            "renders unless show_value: false"
        part "meter-track", "The full-width rail (Progress's cn chrome)"
        part "meter-indicator", "The filled bar - inline width percentage of the range"

        def before_render
          raise ArgumentError, "Meter requires label: (the meter's accessible name)" if label.blank?
          raise ArgumentError, "Meter max: must exceed min:" unless max > min
        end

        # The fraction of the RANGE (react-aria's percent trap: valuetext
        # formats (value-min)/(max-min), not the raw value).
        def percent
          ((clamped - min).to_f / (max - min) * 100).clamp(0, 100)
        end

        def readout
          value_label.presence || "#{percent.round}%"
        end

        def root_attributes
          html_attributes.merge_if_not_set(
            {
              "data-slot" => "meter", "role" => "meter progressbar",
              "aria-valuemin" => min, "aria-valuemax" => max, "aria-valuenow" => clamped,
              "aria-valuetext" => readout,
              "aria-label" => label
            }.merge(component_data_attributes)
          )
        end

        def call
          content_tag(:div, root_attributes.to_attributes) do
            safe_join([label_part, value_part, track].compact)
          end
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
      end
    end
  end
end
