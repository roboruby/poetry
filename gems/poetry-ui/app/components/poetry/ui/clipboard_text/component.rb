# frozen_string_literal: true

module Poetry
  module Ui
    # ClipboardText family: a read-only value with one copy affordance.
    module ClipboardText
      # A read-only value with one copy affordance - API keys, install
      # commands, resource IDs. The value renders in a readonly monospace
      # input (selectable, never editable) with a trailing copy button.
      # A successful copy stamps data-copied on the root for a moment, so
      # the stacked copy/check glyphs swap in CSS, and announces itself
      # to screen readers; the fallback copy path restores the user's own
      # selection and focus.
      #
      # @example An install command with a copy button
      #   render Poetry::Ui::ClipboardText::Component.new(value: "gem install poetry-ui",
      #                                                   label: "Install command")
      class Component < Poetry::Core::Component
        # Projected into the registry, llms.txt, and the agent surface.
        AGENT_RULES = [
          "A read-only value with one copy affordance (poetry_clipboard_text) - API keys, install " \
          "commands, IDs. Editable text is an Input; a secret that needs masking is a SensitiveInput.",
          "value: is what SHOWS; text_to_copy: overrides what lands on the clipboard when the " \
          "display truncates - never truncate the copied text itself.",
          "Give it label: (or compose under a Field/Label) - the readonly input still needs its " \
          "accessible name."
        ].freeze

        use_stimulus do
          on :root do
            controller :clipboard_text do
              register
              value :message, from: :copied_message_text
              value :text, from: :text_to_copy, if: -> { text_to_copy.present? }
            end
          end
          on :input do
            controller(:clipboard_text) { target :input }
          end
          on :copy_button do
            controller(:clipboard_text) { action :copy, on: :click }
          end
        end

        option :value, :string, required: true,
                                doc: "The displayed text - also what copies, unless text_to_copy: overrides it."
        option :text_to_copy, :string,
               doc: "Overrides what lands on the clipboard when the displayed value truncates: display short, copy " \
                    "full."
        option :id, :string,
               doc: "The readonly input's DOM id (auto-generated when omitted) - the Field/Label for= target."
        option :label, :string, doc: "The readonly input's accessible name when no Label/Field association exists."
        option :described_by, :string, doc: "Ids for the input's aria-describedby (hint or error text)."
        option :disabled, :boolean, default: false, doc: "Disables the input and the copy button together."

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

        # The readonly input's id (given or auto-generated).
        # @api private
        def control_id
          @control_id ||= id.presence || poetry_instance_id("poetry-clipboard-text")
        end

        # Attributes for the root wrapper.
        # @api private
        def root_attributes
          attrs = {
            "data-slot" => "clipboard-text",
            "class" => css
          }.merge(component_data_attributes)
          html_attributes.merge_if_not_set(attrs.merge(stimulus_attributes_for(:root)))
        end

        # Attributes for the bordered field surface.
        # @api private
        def group_attributes
          {
            "role" => "group",
            "data-slot" => "clipboard-text-group",
            "class" => InputGroup::Style.css
          }
        end

        # Attributes for the trailing addon cell.
        # @api private
        def addon_attributes
          {
            "data-slot" => "input-group-addon",
            "data-align" => "inline-end",
            "class" => InputGroup::Style.css(:addon, class: InputGroup::Style.css(:addon_inline_end))
          }
        end

        # Attributes for the readonly value input.
        # @api private
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
          attrs.merge!(stimulus_attributes_for(:input))
          attrs
        end

        # The copy affordance: a ghost icon Button, a real tab stop (it IS
        # the component's action).
        # @api private
        def copy_button
          Button::Component.new({
            variant: :ghost, size: :"icon-xs", disabled: disabled,
            label: t("poetry.clipboard_text.copy"),
            class: InputGroup::Style.css(:button, class: InputGroup::Style.css(:button_icon_xs)),
            "data-slot" => "clipboard-text-copy",
            "aria-controls" => control_id
          }.compact.merge(stimulus_attributes_for(:copy_button)))
        end

        private

        def copied_message_text = t("poetry.clipboard_text.copied")

        private :control_id, :root_attributes, :group_attributes, :addon_attributes, :input_attributes, :copy_button
      end
    end
  end
end
