# frozen_string_literal: true

module Poetry
  module Ui
    module NumberField
      # The NumberField: Base UI's number-field contract on
      # poetry's InputGroup visual language. Base UI dropped the spinbutton
      # ARIA pattern - the anatomy is a formatted visible <input type=text>
      # (aria-roledescription "Number field") beside a visually-hidden
      # <input type=number> that is the form/validation truth: the raw JS
      # number submits (a currency field showing $1,234.50 submits 1234.5),
      # and native required/min/max validation rides the hidden input.
      #
      # Visuals compose from existing primitives:
      # the group wears InputGroup's chrome (the input keeps data-slot=
      # input-group-control - the themes' focus-ring hook), the steppers
      # are ghost icon Buttons in addon cells. Zero new theme CSS.
      #
      # Documented divergences from Base UI: no scrub area (unscheduled),
      # Latin-digit parsing only (locale separators and currency/percent
      # symbols ARE handled via Intl.formatToParts), and the server renders
      # the raw number - the display formats on connect.
      #
      # @example
      #   render Poetry::Ui::NumberField::Component.new(
      #     name: "quantity", value: 2, min: 0, label: "Quantity"
      #   )
      class Component < Poetry::Core::Component
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
              action :focus, on: :focus
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

        option :name, :string, required: true
        # Initial value - a number; nil renders empty (null semantics).
        option :value, ActiveModel::Type::Value.new
        option :min, :float
        option :max, :float
        option :step, :float, default: 1.0
        # Shift-arrow / Alt-arrow step sizes (Base UI largeStep/smallStep).
        option :large_step, :float, default: 10.0
        option :small_step, :float, default: 0.1
        # Snap stepped values to step multiples from min (Base UI snapOnStep).
        option :snap, :boolean, default: false
        # Opt-in wheel stepping while the input is focused.
        option :wheel, :boolean, default: false
        # Intl.NumberFormatOptions for the DISPLAY (submission stays raw).
        option :format, ActiveModel::Type::Value.new
        option :locale, :string
        option :placeholder, :string
        option :disabled, :boolean, default: false
        option :readonly, :boolean, default: false
        option :required, :boolean, default: false
        option :invalid, :boolean, default: false
        option :id, :string
        # Standalone accessible name -> aria-label on the visible input
        # (the slider precedent). Inside a form, the Field label wires ids
        # instead - pass neither and pair with poetry_label/form.
        option :label, :string
        # aria-describedby wiring for Field hint/error pairing.
        option :described_by, :string

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

        def initialize(attributes = {})
          super
          return unless value.present? && !numeric?(value)

          raise ArgumentError, "value: must be a number (got #{value.inspect})"
        end

        def before_render
          return unless format.present? && !format.is_a?(Hash)

          raise ArgumentError, "format: takes an Intl.NumberFormatOptions Hash"
        end

        def control_id
          @control_id ||= id.presence || poetry_instance_id("poetry-number-field")
        end

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

        def group_attributes
          {
            "role" => "group",
            "data-slot" => "number-field-group",
            "class" => InputGroup::Style.css
          }
        end

        def addon_attributes(align)
          {
            "data-slot" => "input-group-addon",
            "data-align" => "inline-#{align}",
            "class" => InputGroup::Style.css(:addon, class: InputGroup::Style.css(:"addon_inline_#{align}"))
          }
        end

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
        # users step on the input (Base UI; aria-hidden deliberately NOT
        # applied so touch screen readers can still activate them).
        def stepper(direction)
          Button::Component.new({
            variant: :ghost, size: :"icon-xs", disabled: disabled,
            label: t("poetry.number_field.#{direction}"),
            class: InputGroup::Style.css(:button, class: InputGroup::Style.css(:button_icon_xs)),
            "data-slot" => "number-field-#{direction}",
            "tabindex" => "-1",
            "aria-controls" => control_id
          }.merge(stimulus_attributes_for(direction)))
        end

        def stepper_icon(direction)
          direction == :increment ? :plus : :minus
        end

        private

        def numeric?(candidate)
          candidate.is_a?(Numeric) || candidate.to_s.match?(/\A-?\d+(\.\d+)?\z/)
        end

        # Integer ranges starting at zero take the digit keyboard; decimals
        # or open/negative ranges need the full layout (Base UI's iOS rule,
        # collapsed to one axis).
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
      end
    end
  end
end
