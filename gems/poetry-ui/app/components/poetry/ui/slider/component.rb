# frozen_string_literal: true

module Poetry
  module Ui
    module Slider
      # The control with real math (Slider): a
      # numeric value (or a [low, high] range - two thumbs) on a
      # continuous track. ONE new controller (poetry--core--slider), not
      # composition - no shared primitive covers value-math keyboard
      # (roving-focus moves FOCUS between items; slider keys move VALUES
      # on one focused thumb). Every thumb is its own Tab stop
      # (Radix-exact, APG multithumb - no roving).
      #
      # The server renders everything the controller would: aria-value*
      # per thumb (range bounds NEIGHBOR-CLAMPED - APG multithumb), the
      # --slider-start/--slider-end geometry vars (no first-paint jump),
      # and one hidden <input type=hidden> per thumb - name single,
      # name[] range, which is precisely Rails' array-param convention
      # (params: "50" / ["200", "800"]). Change fires per mutation,
      # commit once per gesture; native input/change fire on COMMIT only.
      class Component < Poetry::Core::Component
        use_stimulus do
          on :root do
            controller :slider do
              register
              value :min, from: :min_number
              value :max, from: :max_number
              value :step, from: :step_number
              value :value, from: :value_numbers
              value :min_steps_between_thumbs
              value :orientation
              value :inverted
              action :pointerdown, on: :pointerdown
            end
          end
          on :track do
            controller(:slider) { target :track }
          end
          on :range do
            controller(:slider) { target :range }
          end
          on :thumb do
            controller :slider do
              target :thumb
              action :keydown, on: :keydown
            end
          end
          # The form bridge: hidden inputs submit the server value even
          # when disabled.
          on :input do
            controller(:slider) { target :input }
          end
        end
        ORIENTATIONS = %i[horizontal vertical].freeze

        AGENT_RULES = [
          "Use poetry_slider / form.slider - never hand-roll a draggable div.",
          "Every thumb MUST have a distinct accessible name (label: - array of two for ranges). " \
          "ArgumentError otherwise.",
          "Give value_text: whenever the number alone is meaningless ('$200', '80%') - SR users hear " \
          "aria-valuetext.",
          "Range mode: values must be sorted [low, high]; use min_steps_between_thumbs to keep a " \
          "meaningful gap.",
          "Do not use Slider for precise known-number entry (use Input type=number) or in " \
          "no-JS-required forms (native input type=range).",
          "Debounce on poetry:slider:commit, never on :change (change fires every drag frame).",
          "Never transition the thumb/range position with CSS - geometry must track the pointer."
        ].freeze

        # Form name; single thumb -> name; range -> name + "[]" per input
        # (Rails array param - Radix-exact).
        option :name, :string, required: true
        # Single-thumb value. ArgumentError if given with values:.
        option :value, ActiveModel::Type::Value.new
        # Range mode: [low, high] -> two thumbs, sorted. ArgumentError if
        # given with value:, unsorted, or length != 2.
        option :values, ActiveModel::Type::Value.new
        option :min, :float, default: 0.0
        option :max, :float, default: 100.0
        # Snap increment; decimal steps supported (precision-aware
        # rounding lives in the controller's math core).
        option :step, :float, default: 1.0
        # Range-mode minimum gap in STEPS (Radix minStepsBetweenThumbs):
        # high - low >= n*step; thumbs can never cross.
        option :min_steps_between_thumbs, :integer, default: 0
        option :orientation, :symbol, default: :horizontal
        # Flip the value direction along the axis (Radix inverted);
        # composes with RTL (both = ltr math).
        option :inverted, :boolean, default: false
        option :disabled, :boolean, default: false
        # Per-thumb accessible names -> aria-label; range REQUIRES two.
        # Alternatively labelled_by (external wiring). Enforced.
        option :label, ActiveModel::Type::Value.new
        # aria-labelledby for the thumb(s) - the Field-wrapped single
        # slider derives its name from the field label this way.
        option :labelled_by, :string
        # aria-valuetext formatter: a proc (v -> "$200") or an i18n key
        # with %{value}; optional - falls back to the bare number.
        option :value_text, ActiveModel::Type::Value.new
        # Field hint/error wiring -> aria-describedby on EACH thumb.
        option :described_by, :string

        validates :orientation, inclusion: { in: ORIENTATIONS }

        part "slider", "Root - the controller, the geometry vars, and pointer capture ride here",
             states: {
               "data-orientation" => { condition: "always - the axis",
                                       values: ORIENTATIONS.map(&:to_s) },
               "data-disabled" => "disabled: is set (the control is inert; the hidden inputs " \
                                  "still submit)",
               "data-dragging" => "a pointer drag is in flight (the controller sets it for the " \
                                  "gesture; never rendered server-side)"
             },
             vars: {
               "--slider-start" => "the filled range's start edge as a percentage - " \
                                   "server-rendered (no first-paint jump), rewritten by the " \
                                   "controller on every move",
               "--slider-end" => "the filled range's end edge as a percentage (the single-thumb " \
                                 "value rides here)"
             }
        part "slider-track", "The full-length rail the range paints over",
             states: {
               "data-orientation" => { condition: "always - mirrors the root",
                                       values: ORIENTATIONS.map(&:to_s) }
             }
        part "slider-range", "The filled span between --slider-start and --slider-end",
             states: {
               "data-orientation" => { condition: "always - mirrors the root",
                                       values: ORIENTATIONS.map(&:to_s) }
             }
        part "slider-anchor", "Absolutely positioned thumb wrapper (one per thumb, with its " \
                              "hidden input alongside) seated on the geometry vars",
             states: {
               "data-orientation" => { condition: "always - mirrors the root",
                                       values: ORIENTATIONS.map(&:to_s) }
             }
        part "slider-thumb", "The role=slider handle - its own Tab stop, carrying the " \
                             "aria-value* surface (bounds neighbor-clamped in range mode)",
             states: {
               "data-orientation" => { condition: "always - mirrors the root",
                                       values: ORIENTATIONS.map(&:to_s) },
               "data-disabled" => "disabled: is set (tabindex drops to -1)",
               "data-dragging" => "this thumb is the one being dragged (the controller pairs it " \
                                  "with the root's)"
             }

        def initialize(attributes = {})
          if attributes.values_at(:value, "value").any? && attributes.values_at(:values, "values").any?
            raise ArgumentError, "value: is the single-thumb API and values: the range API - pass one"
          end

          super

          validate_numbers!
          validate_labels!
        end

        # Always an array internally: [v] single, [low, high] range.
        def thumb_values
          @thumb_values ||= if values.present?
                              Array(values).map { |item| numeric(item, "values") }
                            else
                              # No value at all -> ONE thumb at min (a
                              # documented divergence from shadcn's
                              # [min, max] two-thumb useMemo fallback).
                              [numeric(value.presence || min, "value")]
                            end
        end

        def range?
          thumb_values.length > 1
        end

        def input_name
          range? ? "#{name}[]" : name
        end

        def control_id
          @control_id ||= html_attributes["id"].presence || "poetry-slider-#{SecureRandom.hex(4)}"
        end

        def thumb_id(index)
          "#{control_id}-thumb-#{index}"
        end

        # The thumb's EFFECTIVE bounds (APG multithumb: the high thumb's
        # min is the low thumb's value + the gap) - server-rendered, then
        # rewritten by the controller on every neighbor move.
        def thumb_min(index)
          index.zero? ? number(min) : number(thumb_values[index - 1] + gap)
        end

        def thumb_max(index)
          index == thumb_values.length - 1 ? number(max) : number(thumb_values[index + 1] - gap)
        end

        def thumb_label(index)
          Array(label)[index]
        end

        def thumb_text(index)
          return unless value_text.present?

          value = number(thumb_values[index])
          value_text.respond_to?(:call) ? value_text.call(value) : I18n.t(value_text, value: value)
        end

        def root_attributes
          attrs = {
            "data-slot" => "slider", "id" => control_id,
            "data-orientation" => orientation, "style" => geometry_style
          }
          attrs["data-disabled"] = "" if disabled
          html_attributes.merge_if_not_set(
            attrs.merge(stimulus_attributes_for(:root)).merge(component_data_attributes)
          )
        end

        def track_attributes
          { class: css(:track), "data-slot" => "slider-track", "data-orientation" => orientation }
            .merge(stimulus_attributes_for(:track))
        end

        def range_attributes
          { class: css(:range), "data-slot" => "slider-range", "data-orientation" => orientation }
            .merge(stimulus_attributes_for(:range))
        end

        def anchor_attributes(index)
          anchor = range? && index.zero? ? :anchor_start : :anchor_end
          { class: classnames(css(:anchor), css(anchor)), "data-slot" => "slider-anchor",
            "data-orientation" => orientation }
        end

        def thumb_attributes(index)
          attrs = {
            role: "slider", id: thumb_id(index), class: css(:thumb),
            tabindex: disabled ? "-1" : "0",
            "data-slot" => "slider-thumb", "data-orientation" => orientation,
            "aria-valuemin" => thumb_min(index), "aria-valuemax" => thumb_max(index),
            "aria-valuenow" => number(thumb_values[index]),
            "aria-orientation" => orientation
          }
          attrs["aria-valuetext"] = thumb_text(index) if value_text.present?
          attrs["aria-label"] = thumb_label(index) if thumb_label(index).present?
          attrs["aria-labelledby"] = labelled_by if labelled_by.present?
          attrs["aria-describedby"] = described_by if described_by.present?
          attrs["data-disabled"] = "" if disabled
          attrs.merge(stimulus_attributes_for(:thumb))
        end

        # The form bridge: hidden inputs submit the server value even when
        # disabled (a slider always HAS a value; the control is inert, the
        # datum is not) - contrast native disabled fields.
        def input_attributes(index)
          { type: "hidden", name: input_name, value: number(thumb_values[index]) }
            .merge(stimulus_attributes_for(:input))
        end

        # Trailing-zero-free rendering: 50.0 -> "50", 0.5 -> "0.5" (aria
        # announcements and params never carry float noise).
        def number(value)
          value == value.to_i ? value.to_i : value
        end

        private

        def gap
          min_steps_between_thumbs * step
        end

        def percent(value)
          span = max - min
          return 0 if span <= 0

          ((value - min) / span * 100).round(4)
        end

        def geometry_style
          start = range? ? percent(thumb_values.first) : 0
          "--slider-start: #{number(start.to_f)}%; --slider-end: #{number(percent(thumb_values.last).to_f)}%;"
        end

        def numeric(value, option_name)
          Float(value)
        rescue ArgumentError, TypeError
          raise ArgumentError, "Slider #{option_name}: must be numeric - got #{value.inspect}"
        end

        def validate_numbers!
          raise ArgumentError, "Slider max: must be greater than min:" unless max > min
          raise ArgumentError, "Slider step: must be positive" unless step.positive?

          if values.present?
            list = thumb_values
            raise ArgumentError, "Slider values: takes two or more thumbs" unless list.length >= 2
            raise ArgumentError, "Slider values: must be sorted ascending" unless list.each_cons(2).all? { |a, b| a <= b }
          end
          return if thumb_values.all? { |item| item.between?(min, max) }

          raise ArgumentError, "Slider value(s) #{thumb_values.inspect} outside #{number(min)}..#{number(max)}"
        end

        # Per-thumb accessible names, ENFORCED: a range announcing
        # "slider, 200" twice is useless to AT.
        def validate_labels!
          if range?
            labels = Array(label)
            return if labels.length == thumb_values.length && labels.all?(&:present?)

            raise ArgumentError, "a multi-thumb Slider requires one distinct name per thumb - " \
                                 "label: ['Minimum price', 'Maximum price']"
          else
            return if Array(label).first.present? || labelled_by.present?

            raise ArgumentError, "Slider requires an accessible name - label: (aria-label) or " \
                                 "labelled_by: (aria-labelledby)"
          end
        end

        def min_number = number(min)
        def max_number = number(max)
        def step_number = number(step)
        def value_numbers = thumb_values.map { |item| number(item) }
      end
    end
  end
end
