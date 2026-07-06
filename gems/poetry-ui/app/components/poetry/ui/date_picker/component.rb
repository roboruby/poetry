# frozen_string_literal: true

require "date"

module Poetry
  module Ui
    module DatePicker
      # The DatePicker - a text-field-shaped trigger that opens a Calendar in
      # a Popover. Composition, not a new primitive: the Popover owns the
      # overlay, the Calendar (W6 own-the-engine grid) owns selection + the
      # form value (name: -> its hidden input), and poetry--core--date-picker
      # glues them (formats the trigger label, closes on pick). Server-first:
      # a preselected value: renders the formatted label + the chosen day
      # with no JS.
      class Component < Poetry::Core::Component
        AGENT_RULES = [
          "name: is REQUIRED - the chosen date posts as an ISO string (the Calendar's hidden input).",
          "value: preselects a date (a Date or ISO string) - the trigger shows it formatted, no JS needed.",
          "min:/max: bound the selectable range; the label + placeholder are the trigger's text.",
          "For an always-visible grid use Calendar directly - DatePicker is the field+popover form."
        ].freeze

        CONTROLLER = %i[poetry core date_picker].freeze

        option :name, :string, required: true
        option :mode, :symbol, default: :single
        option :placeholder, :string, default: "Pick a date"
        option :label, :string # the trigger's accessible name (aria-label)

        def initialize(value: nil, min: nil, max: nil, month: nil, **)
          super(**)
          if range?
            @range_start, @range_end = parse_range(value)
          else
            @value = to_date(value)
          end
          @min = to_date(min)
          @max = to_date(max)
          @month = to_date(month)
        end

        attr_reader :value, :min, :max, :month, :range_start, :range_end

        def range? = mode == :range

        def before_render
          raise ArgumentError, "DatePicker requires name: (the form field)" if name.blank?
        end

        # Range mode joins the pair ("March 5, 2026 - March 12, 2026"); a
        # start-only value shows one date (the rdp/shadcn convention).
        def formatted
          if range?
            return placeholder unless @range_start

            [@range_start, @range_end].compact.map { |date| date.strftime("%B %-d, %Y") }.join(" – ")
          else
            @value ? @value.strftime("%B %-d, %Y") : placeholder
          end
        end

        def calendar_options
          selected = range? ? [@range_start, @range_end].compact.presence : @value
          { name: name, mode: (:range if range?), selected: selected,
            min: @min, max: @max, month: @month || @value || @range_start }.compact
        end

        def root_attributes
          html_attributes.merge_if_not_set(
            { "data-slot" => "date-picker", "class" => css }
              .merge(root_stimulus_attributes).merge(component_data_attributes)
          )
        end

        def trigger_options
          {
            variant: :outline,
            label: label.presence,
            class: "w-56 justify-start font-normal #{"text-muted-foreground" unless value}".strip,
            data: { slot: "date-picker-trigger" }
          }.compact
        end

        private

        def to_date(value)
          return if value.nil?
          return value if value.is_a?(Date)

          Date.parse(value.to_s)
        end

        # A preselected range: Date..Date, [start, end], or {start:, end:}.
        def parse_range(value)
          case value
          when nil then [nil, nil]
          when Range then [to_date(value.first), to_date(value.last)]
          when Array then [to_date(value[0]), to_date(value[1])]
          when Hash
            pair = value.symbolize_keys
            [to_date(pair[:start]), to_date(pair[:end])]
          else
            [to_date(value), nil]
          end
        end

        def root_stimulus_attributes
          attrs = Poetry::Core::HTML::Attributes.new
          picker = Poetry::Core::Stimulus::Builder.new(CONTROLLER, attrs)
          picker.register_controller
          picker.with_value(:placeholder, placeholder)
          picker.with_value(:mode, "range") if range?
          picker.with_action(:picked, on: "poetry--core--calendar:change")
          attrs.to_attributes
        end

        def label_target_attributes
          attrs = Poetry::Core::HTML::Attributes.new
          picker = Poetry::Core::Stimulus::Builder.new(CONTROLLER, attrs)
          picker.with_target(:label)
          attrs.to_attributes
        end
        public :label_target_attributes
      end
    end
  end
end
