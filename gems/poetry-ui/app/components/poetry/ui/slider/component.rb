# frozen_string_literal: true

module Poetry
  module Ui
    # A draggable numeric value (or range) on a continuous track.
    module Slider
      # A numeric value (or a [low, high] range - two thumbs) picked by
      # dragging along a continuous track. Reach for it when the value is
      # approximate by nature; precise known-number entry belongs in a
      # number input. Every thumb is its own Tab stop, and arrow keys move
      # the focused thumb by step:.
      #
      # The server renders everything the controller would: aria-value*
      # per thumb (range bounds clamped to the neighboring thumb), the
      # --slider-start/--slider-end geometry vars (no first-paint jump),
      # and one hidden <input type=hidden> per thumb - name single,
      # name[] range, which is precisely Rails' array-param convention
      # (params: "50" / ["200", "800"]). Change fires per mutation,
      # commit once per gesture; native input/change fire on COMMIT only.
      #
      # @example
      #   render Poetry::Ui::Slider::Component.new(name: "volume", value: 50, label: "Volume")
      class Component < Poetry::Core::Component
        # The closed vocabulary for the axis option.
        ORIENTATIONS = %i[horizontal vertical].freeze

        # Projected into the registry, llms.txt, and the agent surface.
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

        # One dedicated controller on purpose: slider keys move VALUES on
        # one focused thumb - value-math no focus-moving primitive covers.
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

        option :name, :string, required: true,
                               doc: "Form name; single thumb -> name; range -> name + \"[]\" per input (the Rails " \
                                    "array-param convention)."
        option :value, ActiveModel::Type::Value.new, doc: "Single-thumb value. ArgumentError if given with values:."
        option :values, ActiveModel::Type::Value.new,
               doc: "Range mode: [low, high] -> two thumbs, sorted. ArgumentError if given with value:, unsorted, or " \
                    "length != 2."
        option :min, :float, default: 0.0, doc: "The track's lower bound."
        option :max, :float, default: 100.0, doc: "The track's upper bound; must exceed min:."
        option :step, :float, default: 1.0,
                              doc: "Snap increment; decimal steps supported (precision-aware rounding lives in the " \
                                   "controller's math core)."
        option :min_steps_between_thumbs, :integer, default: 0,
                                                    doc: "Range-mode minimum gap in STEPS: high - low >= n*step; " \
                                                         "thumbs can never cross."
        option :orientation, :symbol, default: :horizontal, doc: "The track axis."
        option :inverted, :boolean, default: false,
                                    doc: "Flips the value direction along the axis; composes with RTL (both = ltr " \
                                         "math)."
        option :disabled, :boolean, default: false,
                                    doc: "Renders the control inert; the hidden inputs still submit the server value."
        option :label, ActiveModel::Type::Value.new,
               doc: "Per-thumb accessible names -> aria-label; range REQUIRES two. Alternatively labelled_by " \
                    "(external wiring). Enforced."
        option :labelled_by, :string,
               doc: "aria-labelledby for the thumb(s) - the Field-wrapped single slider derives its name from the " \
                    "field label this way."
        option :value_text, ActiveModel::Type::Value.new,
               doc: "aria-valuetext formatter: a proc (v -> \"$200\") or an i18n key " \
                    "with %{value}; optional - falls back to the bare number." # rubocop:disable Style/FormatStringToken
        option :described_by, :string, doc: "Field hint/error wiring -> aria-describedby on EACH thumb."

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

        # @api private
        def initialize(attributes = {})
          if attributes.values_at(:value, "value").any? && attributes.values_at(:values, "values").any?
            raise ArgumentError, "value: is the single-thumb API and values: the range API - pass one"
          end

          super

          validate_numbers!
          validate_labels!
        end

        # Always an array internally: [v] single, [low, high] range.
        # @api private
        def thumb_values
          @thumb_values ||= if values.present?
                              Array(values).map { |item| numeric(item, "values") }
                            else
                              # No value at all -> ONE thumb at min.
                              [numeric(value.presence || min, "value")]
                            end
        end

        # @api private
        def range?
          thumb_values.length > 1
        end

        # @api private
        def input_name
          range? ? "#{name}[]" : name
        end

        # @api private
        def control_id
          @control_id ||= poetry_instance_id("poetry-slider")
        end

        # @api private
        def thumb_id(index)
          "#{control_id}-thumb-#{index}"
        end

        # The thumb's EFFECTIVE bounds (the high thumb's min is the low
        # thumb's value + the gap) - server-rendered, then rewritten by
        # the controller on every neighbor move.
        # @api private
        def thumb_min(index)
          index.zero? ? number(min) : number(thumb_values[index - 1] + gap)
        end

        # @api private
        def thumb_max(index)
          index == thumb_values.length - 1 ? number(max) : number(thumb_values[index + 1] - gap)
        end

        # @api private
        def thumb_label(index)
          Array(label)[index]
        end

        # @api private
        def thumb_text(index)
          return unless value_text.present?

          value = number(thumb_values[index])
          value_text.respond_to?(:call) ? value_text.call(value) : I18n.t(value_text, value: value)
        end

        # @api private
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

        # @api private
        def track_attributes
          { class: css(:track), "data-slot" => "slider-track", "data-orientation" => orientation }
            .merge(stimulus_attributes_for(:track))
        end

        # @api private
        def range_attributes
          { class: css(:range), "data-slot" => "slider-range", "data-orientation" => orientation }
            .merge(stimulus_attributes_for(:range))
        end

        # @api private
        def anchor_attributes(index)
          anchor = if range? && index.zero? then :anchor_start
                   elsif index == thumb_values.length - 1 then :anchor_end
                   else :anchor_mid
                   end
          attrs = { class: classnames(css(:anchor), css(anchor)), "data-slot" => "slider-anchor",
                    "data-orientation" => orientation }
          attrs[:style] = "--slider-mid: #{number(percent(thumb_values[index]).to_f)}%;" if anchor == :anchor_mid
          attrs
        end

        # @api private
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
        # @api private
        def input_attributes(index)
          { type: "hidden", name: input_name, value: number(thumb_values[index]) }
            .merge(stimulus_attributes_for(:input))
        end

        # Trailing-zero-free rendering: 50.0 -> "50", 0.5 -> "0.5" (aria
        # announcements and params never carry float noise).
        # @api private
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
            raise ArgumentError, "Slider values: must be sorted ascending" unless list.each_cons(2).all? do |a, b|
              a <= b
            end
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

        private :thumb_values, :range?, :input_name, :control_id, :thumb_id, :thumb_min, :thumb_max, :thumb_label
        private :thumb_text, :root_attributes, :track_attributes, :range_attributes, :anchor_attributes
        private :thumb_attributes, :input_attributes, :number
      end
    end
  end
end
