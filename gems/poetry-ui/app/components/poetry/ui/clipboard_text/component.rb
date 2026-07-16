# frozen_string_literal: true

module Poetry
  module Ui
    module ClipboardText
      # The ClipboardText (the kumo contract): a read-only value with
      # one copy affordance - API keys, install commands, resource IDs. The
      # value rides a readonly mono input on InputGroup's chrome (selectable,
      # never editable), the trailing ghost Button copies, and the controller
      # stamps data-copied on the root for a beat - the stacked copy/check
      # glyphs swap off it in CSS. The announcement goes through the
      # live-region singleton; the execCommand fallback restores the user's
      # own selection and focus (poetry--core--clipboard-text).
      class Component < Poetry::Core::Component
        CONTROLLER = %i[poetry core clipboard_text].freeze

        AGENT_RULES = [
          "A read-only value with one copy affordance (poetry_clipboard_text) - API keys, install " \
          "commands, IDs. Editable text is an Input; a secret that needs masking is a SensitiveInput.",
          "value: is what SHOWS; text_to_copy: overrides what lands on the clipboard when the " \
          "display truncates - never truncate the copied text itself.",
          "Give it label: (or compose under a Field/Label) - the readonly input still needs its " \
          "accessible name."
        ].freeze

        option :value, :string, required: true
        # Copy override when the displayed value truncates (kumo's
        # textToCopy): display short, copy full.
        option :text_to_copy, :string
        option :id, :string
        option :label, :string
        option :described_by, :string
        option :disabled, :boolean, default: false

        part "clipboard-text", "Root - the controller rides here",
             states: {
               "data-copied" => "stamped for a beat after a successful copy (the stacked " \
                                "copy/check glyphs swap off it)"
             }
        part "clipboard-text-group", "The bordered field surface - InputGroup's chrome"
        part "input-group-control", "The readonly mono <input> showing the value - selectable, " \
                                    "never editable; InputGroup's control slot"
        part "input-group-addon", "The trailing cell holding the copy affordance - InputGroup's " \
                                  "addon vocabulary",
             states: {
               "data-align" => { condition: "always - inline-end holds the copy button",
                                 values: %w[inline-end] }
             }
        # The copy affordance renders as a composed ghost Button carrying
        # data-slot=clipboard-text-copy on Button's root - ownership
        # attributes it to Button (the NumberField stepper precedent), so it
        # is documented here in prose only: a REAL tab stop (copying is the
        # component's primary action), aria-controls to the input, stacked
        # copy/check glyphs inside.

        def control_id
          @control_id ||= id.presence || "poetry-clipboard-text-#{SecureRandom.hex(4)}"
        end

        def root_attributes
          attrs = {
            "data-slot" => "clipboard-text",
            "class" => css
          }.merge(component_data_attributes)
          html_attributes.merge_if_not_set(attrs.merge(root_stimulus_attributes))
        end

        def group_attributes
          {
            "role" => "group",
            "data-slot" => "clipboard-text-group",
            "class" => InputGroup::Style.css
          }
        end

        def addon_attributes
          {
            "data-slot" => "input-group-addon",
            "data-align" => "inline-end",
            "class" => InputGroup::Style.css(:addon, class: InputGroup::Style.css(:addon_inline_end))
          }
        end

        def input_attributes
          attrs = Poetry::Core::HTML::Attributes.new(
            "type" => "text",
            "readonly" => "",
            "id" => control_id,
            "value" => value,
            "data-slot" => "input-group-control",
            "class" => "#{Input::Style.css(class: InputGroup::Style.css(:control_input))} #{css(:input)}",
            "autocomplete" => "off",
            "spellcheck" => "false"
          )
          attrs["aria-label"] = label if label.present?
          attrs["aria-describedby"] = described_by if described_by.present?
          attrs["disabled"] = "" if disabled
          attrs.merge!(input_stimulus_attributes)
          attrs
        end

        # The copy affordance: a ghost icon Button, a real tab stop (it IS
        # the component's action).
        def copy_button
          Button::Component.new({
            variant: :ghost, size: :"icon-xs", disabled: disabled,
            label: t("poetry.clipboard_text.copy"),
            class: InputGroup::Style.css(:button, class: InputGroup::Style.css(:button_icon_xs)),
            "data-slot" => "clipboard-text-copy",
            "aria-controls" => control_id
          }.compact.merge(copy_stimulus_attributes))
        end

        private

        def root_stimulus_attributes
          attrs = Poetry::Core::HTML::Attributes.new
          text = Poetry::Core::Stimulus::Builder.new(CONTROLLER, attrs)
          text.register_controller
          text.with_value(:message, t("poetry.clipboard_text.copied"))
          text.with_value(:text, text_to_copy) if text_to_copy.present?
          attrs.to_attributes
        end

        def input_stimulus_attributes
          stimulus_attributes { |text| text.with_target(:input) }
        end

        def copy_stimulus_attributes
          stimulus_attributes { |text| text.with_action(:copy, on: :click) }
        end

        def stimulus_attributes
          attrs = Poetry::Core::HTML::Attributes.new
          yield Poetry::Core::Stimulus::Builder.new(CONTROLLER, attrs)
          attrs.to_attributes
        end
      end
    end
  end
end
