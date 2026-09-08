# frozen_string_literal: true

module Poetry
  module Ui
    # A numeric input with steppers and display formatting.
    module NumberField
      # A numeric field with stepper buttons and locale-aware display
      # formatting. The anatomy is a formatted visible <input type=text>
      # (announced as "Number field") beside a visually-hidden
      # <input type=number> that is the form and validation truth: the
      # raw number submits (a currency field showing $1,234.50 submits
      # 1234.5), and native required/min/max validation rides the hidden
      # input.
      #
      # Visuals compose from existing primitives - the group wears
      # InputGroup's chrome and the steppers are ghost icon Buttons - so
      # themes restyle it through those components. The server renders
      # the raw number; the display formats on connect. Typed input
      # parses Latin digits (locale separators and currency/percent
      # symbols are handled).
      #
      # @example
      #   render Poetry::Ui::NumberField::Component.new(
      #     name: "quantity", value: 2, min: 0, label: "Quantity"
      #   )
      class Component < Poetry::Core::Component
        include Poetry::Ui::InputGroupField

        # Projected into the registry, llms.txt, and the agent surface.
        AGENT_RULES = [
          "Use poetry_number_field / form.number_field - never a hand-rolled spinner or a bare " \
          "input type=number.",
          "The server reads params[<name>] as the raw number string - display formatting " \
          "(format:) never changes what submits.",
          "Steppers are mouse/touch affordances (tabindex -1); keyboard users step with " \
          "ArrowUp/Down (Shift = large_step, Alt = small_step) on the input itself.",
          "Pair it with a Label/Field for the accessible name - the component ships none.",
          "format: takes Intl.NumberFormatOptions as a Hash ({ style: \"currency\", " \
          "currency: \"USD\" }); pick locale: to pin parsing separators."
        ].freeze

        use_stimulus do
          on :root do
            controller :number_field do
              register
              value :min, from: :min_number, if: -> { min.present? }
              value :max, from: :max_number, if: -> { max.present? }
              value :step, from: :step_number
              value :large_step, from: :large_step_number
              value :small_step, from: :small_step_number
              value :snap, if: :snap
              value :wheel, if: :wheel
              value :format, from: :format_json, if: -> { format.present? }
              value :locale, if: -> { locale.present? }
            end
          end
          on :input do
            controller :number_field do
              target :input
              action :keydown, on: :keydown
              action :input, on: :input
              action :blur, on: :blur
            end
          end
          # The form/validation truth: the sr-only native number input.
          on :hidden do
            controller :number_field do
              target :hidden
              action :hiddenChanged, on: :change
            end
          end
          # One element per stepper direction, so stepper(direction)
          # forwards stimulus_attributes_for(direction) into Button kwargs.
          %i[increment decrement].each do |direction|
            on direction do
              controller :number_field do
                target direction
                action :press, on: :pointerdown
                action :tap, on: :click
                action :leave, on: :pointerleave
              end
            end
          end
        end

        option :name, :string, required: true, doc: "The submitted field name - rides the hidden number input."
        option :value, ActiveModel::Type::Value.new,
               doc: "Initial value - a number; nil renders empty (null semantics)."
        option :min, :float, doc: "The lower clamp for stepping and native validation."
        option :max, :float, doc: "The upper clamp for stepping and native validation."
        option :step, :float, default: 1.0, doc: "The arrow-key / stepper increment."
        option :large_step, :float, default: 10.0, doc: "The Shift-arrow step size (the coarse jump)."
        option :small_step, :float, default: 0.1, doc: "The Alt-arrow step size (the fine adjustment)."
        option :snap, :boolean, default: false, doc: "Snaps stepped values to step multiples counted from min:."
        option :wheel, :boolean, default: false, doc: "Opt-in wheel stepping while the input is focused."
        option :format, ActiveModel::Type::Value.new,
               doc: "Intl.NumberFormatOptions for the DISPLAY (submission stays raw)."
        option :locale, :string,
               doc: "Locale tag pinning the display and parsing separators; the page locale otherwise."
        option :placeholder, :string, doc: "Placeholder text for the empty input."
        option :disabled, :boolean, default: false, doc: "Disables both inputs and the steppers; the group chrome dims."
        option :readonly, :boolean, default: false,
                                    doc: "Makes the visible input read-only (steppers and typing inert)."
        option :required, :boolean, default: false, doc: "Requires a value - native validation rides the hidden input."
        option :invalid, :boolean, default: false,
                                   doc: "Marks the field invalid (aria-invalid on the visible input; the group wears " \
                                        "the destructive ring)."
        option :id, :string, doc: "The visible input's dom id - the seam a Label's for_id: points at."
        option :label, :string,
               doc: "Standalone accessible name -> aria-label on the visible input. Inside a form, the Field label " \
                    "wires ids instead - pass neither and pair with poetry_label/form."
        option :described_by, :string, doc: "aria-describedby wiring for Field hint/error pairing."

        validates :step, numericality: { greater_than: 0 }

        part "number-field", "Root wrapper - the controller, disabled/invalid/filled state, " \
                             "and the two-input pair ride here",
             states: {
               "data-disabled" => "disabled: is set (steppers disable, the group chrome dims)",
               "data-invalid" => "invalid: is set (the group wears the destructive ring via " \
                                 "the control's aria-invalid)",
               "data-filled" => "the value is non-null (the controller keeps it live)"
             }
        part "number-field-group", "The bordered field surface - wears InputGroup's chrome " \
                                   "(cn-input-group), focus ring keyed on the control inside"
        part "input-group-addon", "The two stepper cells - InputGroup's addon vocabulary, " \
                                  "reused so the group paddings compose",
             states: {
               "data-align" => { condition: "always - inline-start holds the decrement, " \
                                            "inline-end the increment",
                                 values: %w[inline-start inline-end] }
             }
        part "input-group-control", "The visible formatted <input type=text> - InputGroup's " \
                                    "control slot (the themes' focus-ring hook); " \
                                    "aria-roledescription \"Number field\", never a spinbutton"
        # The steppers render as composed ghost Buttons and carry
        # data-slot=number-field-increment/-decrement on Button's root -
        # ownership attributes them to Button (the date-picker-trigger
        # pattern), so they are documented here in prose only.

        # Rejects a non-numeric value: early.
        # @api private
        def initialize(attributes = {})
          super
          return unless value.present? && !numeric?(value)

          raise ArgumentError, "value: must be a number (got #{value.inspect})"
        end

        # Enforces the format: Hash contract.
        # @api private
        def before_render
          return unless format.present? && !format.is_a?(Hash)

          raise ArgumentError, "format: takes an Intl.NumberFormatOptions Hash"
        end

        # @api private
        def root_attributes
          attrs = {
            "data-slot" => "number-field",
            "class" => css
          }.merge(component_data_attributes)
          attrs["data-disabled"] = "" if disabled
          attrs["data-invalid"] = "" if invalid
          attrs["data-filled"] = "" if value.present?
          html_attributes.merge_if_not_set(attrs.merge(stimulus_attributes_for(:root)))
        end

        # @api private
        def input_attributes
          attrs = Poetry::Core::HTML::Attributes.new(
            "type" => "text",
            "id" => control_id,
            "data-slot" => "input-group-control",
            "class" => Input::Style.css(class: InputGroup::Style.css(:control_input)),
            "inputmode" => inputmode,
            "autocomplete" => "off",
            "autocorrect" => "off",
            "spellcheck" => "false",
            "aria-roledescription" => t("poetry.number_field.roledescription")
          )
          attrs["placeholder"] = placeholder if placeholder.present?
          attrs["value"] = number(value) if value.present?
          attrs["aria-label"] = label if label.present?
          attrs["aria-invalid"] = "true" if invalid && !disabled
          attrs["aria-describedby"] = described_by if described_by.present?
          attrs["disabled"] = "" if disabled
          attrs["readonly"] = "" if readonly
          attrs["required"] = "" if required
          attrs.merge!(stimulus_attributes_for(:input))
          attrs
        end

        # The form/validation truth: raw number out, native constraint
        # validation on. Focus never lands here (tabindex -1, aria-hidden).
        # @api private
        def hidden_attributes
          attrs = Poetry::Core::HTML::Attributes.new(
            "type" => "number",
            "name" => name,
            "class" => "sr-only",
            "tabindex" => "-1",
            "aria-hidden" => "true"
          )
          attrs["value"] = number(value) if value.present?
          attrs["min"] = number(min) if min.present?
          attrs["max"] = number(max) if max.present?
          attrs["step"] = number(step)
          attrs["disabled"] = "" if disabled
          attrs["required"] = "" if required
          attrs.merge!(stimulus_attributes_for(:hidden))
          attrs
        end

        # The stepper Buttons (ghost, icon-xs, InputGroup's tiny-button
        # chrome): tabindex -1 keeps them off the Tab order - keyboard
        # users step on the input. aria-hidden is deliberately NOT applied,
        # so touch screen readers can still activate them.
        # @api private
        def stepper(direction)
          group_tool_button(slot: "number-field-#{direction}",
                            label: t("poetry.number_field.#{direction}"),
                            wiring: stimulus_attributes_for(direction))
        end

        # @api private
        def stepper_icon(direction)
          direction == :increment ? :plus : :minus
        end

        private

        def numeric?(candidate)
          candidate.is_a?(Numeric) || candidate.to_s.match?(/\A-?\d+(\.\d+)?\z/)
        end

        # Integer ranges starting at zero take the digit keyboard; decimals
        # or open/negative ranges need the full layout.
        def inputmode
          whole = step == step.to_i && (!min.present? || min == min.to_i)
          min.present? && min >= 0 && whole && format.blank? ? "numeric" : "decimal"
        end

        # Trailing-zero-free numeric strings (5.0 -> "5"), the slider idiom.
        def number(numeric)
          float = Float(numeric)
          float == float.to_i ? float.to_i.to_s : float.to_s
        end

        def min_number = number(min)
        def max_number = number(max)
        def step_number = number(step)
        def large_step_number = number(large_step)
        def small_step_number = number(small_step)
        def format_json = format.to_json

        private :root_attributes, :input_attributes, :hidden_attributes, :stepper, :stepper_icon
      end
    end
  end
end
