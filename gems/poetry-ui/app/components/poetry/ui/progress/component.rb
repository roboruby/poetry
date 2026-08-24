# frozen_string_literal: true

module Poetry
  module Ui
    # A determinate progress bar.
    module Progress
      # A determinate task's completion, server-rendered: a
      # role=progressbar root carrying the value in aria, with a filled
      # track sized to the percentage. label: is the accessible name and
      # renders as the visible caption beside a percent readout. For an
      # unknown duration use Spinner - this bar has no indeterminate
      # state.
      #
      # @example
      #   render Poetry::Ui::Progress::Component.new(value: 60, label: "Uploading")
      class Component < Poetry::Core::Component
        # Projected into the registry, llms.txt, and the agent surface.
        AGENT_RULES = [
          "label: is REQUIRED - it is the progressbar's accessible name and the visible caption.",
          "value: is the current progress (0..max:, default max 100); the component computes the width.",
          "For an UNKNOWN duration use Spinner, not Progress - this bar is determinate."
        ].freeze

        # The current progress, clamped into 0..max:.
        option :value, :integer, required: true
        # The completion value.
        option :max, :integer, default: 100
        # The progressbar's accessible name and visible caption.
        option :label, :string, required: true
        # Set false to hide the percent readout.
        option :show_value, :boolean, default: true

        part "progress", "Root (role=progressbar, aria-value* and the accessible name) - " \
                         "label, value readout, and track stack here"
        part "progress-label", "The visible caption span (label:)"
        part "progress-value", "The tabular percent readout - renders unless show_value: false"
        part "progress-track", "The full-width rail the indicator fills"
        part "progress-indicator", "The filled bar - sized by an inline width percentage " \
                                   "computed from value:/max:"

        # Enforces the required label and a positive max.
        # @api private
        def before_render
          raise ArgumentError, "Progress requires label: (the progressbar's accessible name)" if label.blank?
          raise ArgumentError, "Progress max: must be positive" unless max.positive?
        end

        # @api private
        def call
          content_tag(:div, root_attributes.to_attributes) do
            safe_join([label_part, value_part, track].compact)
          end
        end

        # @api private
        def percent
          (value.to_f / max * 100).clamp(0, 100)
        end

        # @api private
        def percent_text
          "#{percent.round}%"
        end

        # @api private
        def root_attributes
          html_attributes.merge_if_not_set(
            {
              "data-slot" => "progress", "role" => "progressbar",
              "aria-valuemin" => 0, "aria-valuemax" => max, "aria-valuenow" => value.clamp(0, max),
              "aria-label" => label
            }.merge(component_data_attributes)
          )
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
