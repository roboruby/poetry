# frozen_string_literal: true

module Poetry
  module Ui
    module Progress
      # The Progress bar - a determinate task's completion, server-rendered:
      # role=progressbar + aria-value* on the root, the indicator sized by
      # width%. label: is required (the progressbar's accessible name) and
      # renders alongside the tabular value readout.
      class Component < Poetry::Core::Component
        AGENT_RULES = [
          "label: is REQUIRED - it is the progressbar's accessible name and the visible caption.",
          "value: is the current progress (0..max:, default max 100); the component computes the width.",
          "For an UNKNOWN duration use Spinner, not Progress - this bar is determinate."
        ].freeze

        option :value, :integer, required: true
        option :max, :integer, default: 100
        # required: the hand raise in before_render carries the message;
        # the flag carries the fact to the registry (: the floating
        # crash - a required option the static tier could not see).
        option :label, :string, required: true
        option :show_value, :boolean, default: true

        def before_render
          raise ArgumentError, "Progress requires label: (the progressbar's accessible name)" if label.blank?
          raise ArgumentError, "Progress max: must be positive" unless max.positive?
        end

        def percent
          (value.to_f / max * 100).clamp(0, 100)
        end

        def percent_text
          "#{percent.round}%"
        end

        def root_attributes
          html_attributes.merge_if_not_set(
            {
              "data-slot" => "progress", "role" => "progressbar",
              "aria-valuemin" => 0, "aria-valuemax" => max, "aria-valuenow" => value.clamp(0, max),
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

        def label_part
          content_tag(:span, label, "data-slot" => "progress-label", class: css(:label))
        end

        def value_part
          return unless show_value

          content_tag(:span, percent_text, "data-slot" => "progress-value", class: css(:value))
        end

        def track
          content_tag(:div, "data-slot" => "progress-track", class: css(:track)) do
            content_tag(:div, nil, "data-slot" => "progress-indicator", class: css(:indicator),
                                   style: "width: #{percent.round(4)}%")
          end
        end
      end
    end
  end
end
