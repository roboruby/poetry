# frozen_string_literal: true

module Poetry
  module Ui
    module Meter
      # The Meter: a QUANTITY within a
      # known range - battery, disk usage, seats taken, password strength -
      # never the progress of an operation over time (that is Progress;
      # concretely, a meter has no indeterminate state, by construction).
      # Wears Progress's visual chrome verbatim (the NumberField
      # composition precedent - zero new theme CSS); the semantic delta is
      # the ROLE: role=meter. (Older ports ship the 2019-era two-token
      # fallback "meter progressbar" for browsers without the meter role;
      # by 2026 support is universal, and axe 4.12 cannot resolve the
      # multi-token string - it falls back to generic and flags every
      # aria-value* attribute - so poetry ships the single honest token.)
      #
      # @example
      #   render Poetry::Ui::Meter::Component.new(value: 62, label: "Storage used")
      class Component < Poetry::Core::Component
        AGENT_RULES = [
          "A quantity within a range is a Meter (disk, seats, strength); an operation's " \
          "completion over time is Progress. There is NO indeterminate meter - unknown " \
          "duration means Spinner.",
          "label: is REQUIRED - the meter's accessible name and visible caption.",
          "value_text: replaces the visible readout verbatim (\"3 of 4 seats\"); without it " \
          "the readout shows the percentage of the RANGE. No aria-valuetext - ARIA 1.2 " \
          "deprecated it on role=meter; aria-valuenow carries the value."
        ].freeze

        option :value, :integer, required: true
        option :min, :integer, default: 0
        option :max, :integer, default: 100
        # required: the hand raise in before_render carries the message;
        # the flag carries the fact to the registry (the Progress twin).
        option :label, :string, required: true
        # Verbatim human-readable value ("3 of 4") - the visible readout.
        # One suite-wide name for the human-readable value (Slider's
        # value_text:). Visible readout only here - ARIA 1.2 deprecated
        # aria-valuetext on role=meter, aria-valuenow carries the value.
        option :value_text, :string
        option :show_value, :boolean, default: true

        part "meter", "Root (role=meter, aria-value*, and the accessible name); label, " \
                      "readout, and track stack here"
        part "meter-label", "The visible caption span (label:)"
        part "meter-value", "The readout - value_text: verbatim, else the range percentage; " \
                            "renders unless show_value: false"
        part "meter-track", "The full-width rail (Progress's cn chrome)"
        part "meter-indicator", "The filled bar - inline width percentage of the range"

        def before_render
          raise ArgumentError, "Meter requires label: (the meter's accessible name)" if label.blank?
          raise ArgumentError, "Meter max: must exceed min:" unless max > min
        end

        def call
          content_tag(:div, root_attributes.to_attributes) do
            safe_join([label_part, value_part, track].compact)
          end
        end

        # The fraction of the RANGE - (value - min)/(max - min), never the
        # raw value.
        def percent
          ((clamped - min).to_f / (max - min) * 100).clamp(0, 100)
        end

        def readout
          value_text.presence || "#{percent.round}%"
        end

        def root_attributes
          html_attributes.merge_if_not_set(
            {
              "data-slot" => "meter", "role" => "meter",
              # No aria-valuetext: ARIA 1.2 DEPRECATED it on role=meter
              # (axe 4.12 flags it) - the visible readout carries the
              # human string, aria-valuenow the value.
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
      end
    end
  end
end
