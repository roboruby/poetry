# frozen_string_literal: true

module Poetry
  module Ui
    module SensitiveInput
      # The SensitiveInput (the kumo contract): a secret field -
      # API keys, tokens, credentials - in a three-state machine carried by
      # data-state on the root: masked (value hidden, the MASK OVERLAY is
      # the reveal affordance - role=button, label, sr hint - while the
      # real input stays rendered for layout but goes inert), revealed
      # (type=text, editable, the eye re-masks), empty (a plain password
      # input; the first character typed auto-reveals so composition
      # happens visibly). Re-mask: Escape (focus returns to the group),
      # leaving the component, or the eye. copy: mounts the clipboard-text
      # engine alongside - copy WITHOUT revealing is the point. The no-JS
      # story is a plain password input that still submits.
      class Component < Poetry::Core::Component
        CONTROLLER = %i[poetry core sensitive_input].freeze
        COPY_CONTROLLER = %i[poetry core clipboard_text].freeze

        AGENT_RULES = [
          "Secrets shown-on-demand are a SensitiveInput (poetry_sensitive_input) - never a bare " \
          "password Input with a hand-rolled eye; the masked-container contract (role=button, " \
          "focus discipline, blur re-mask) rides the controller.",
          "label: feeds the masked announcement (\"{label}, masked.\") - pair with a Label/Field " \
          "for the visible caption.",
          "copy: true adds copy-without-revealing; leave it off for password-change forms.",
          "Values re-mask on blur BY DESIGN - do not fight it with reveal-state persistence."
        ].freeze

        option :name, :string, required: true
        option :value, :string
        option :id, :string
        option :label, :string
        option :placeholder, :string
        option :described_by, :string
        option :copy, :boolean, default: false
        option :disabled, :boolean, default: false
        option :readonly, :boolean, default: false
        option :required, :boolean, default: false
        option :invalid, :boolean, default: false

        part "sensitive-input", "Root - the state machine rides here",
             states: {
               "data-state" => { condition: "always - masked (value hidden, group is the reveal " \
                                            "button), revealed, or empty",
                                 values: %w[masked revealed empty] },
               "data-copied" => "copy: only - stamped for a beat after a successful copy " \
                                "(the clipboard-text engine)",
               "data-disabled" => "disabled: - the masked group loses its tab stop and pointer " \
                                  "affordances"
             }
        part "sensitive-input-group", "The bordered field surface (InputGroup's chrome) - " \
                                      "clicks anywhere on it reveal; wears the focus ring when " \
                                      "the mask button inside holds focus"
        part "input-group-control", "The real input - rendered in every state for layout " \
                                    "stability; inert while masked (aria-hidden, tabindex -1, " \
                                    "readonly, transparent); type=password unless revealed"
        part "sensitive-input-mask", "The overlay painting the masked state - while masked it " \
                                     "IS the reveal button (role=button, tabindex 0, " \
                                     "\"{label}, masked.\", described by the sr hint; only text " \
                                     "spans inside, so no nested-interactive); bullet dots swap " \
                                     "to the reveal hint on hover/focus with no layout shift"
        part "input-group-addon", "The trailing cell holding the eye (and copy: affordance)",
             states: {
               "data-align" => { condition: "always - inline-end holds the actions",
                                 values: %w[inline-end] }
             }
        # The eye and copy affordances render as composed ghost Buttons
        # carrying data-slot=sensitive-input-toggle / clipboard-text-copy on
        # Button's root - ownership attributes them to Button (the
        # NumberField stepper precedent), prose only: the eye exists ONLY
        # while revealed (hidden otherwise; the masked group is the reveal
        # path), re-masks and hands focus back to the group; copy is a real
        # tab stop wired to the clipboard-text engine.

        def control_id
          @control_id ||= id.presence || "poetry-sensitive-input-#{SecureRandom.hex(4)}"
        end

        def hint_id
          "#{control_id}-hint"
        end

        def state
          value.present? ? "masked" : "empty"
        end

        def masked?
          state == "masked"
        end

        def root_attributes
          attrs = {
            "data-slot" => "sensitive-input",
            "data-state" => state,
            "class" => css
          }.merge(component_data_attributes)
          attrs["data-disabled"] = "" if disabled
          html_attributes.merge_if_not_set(attrs.merge(root_stimulus_attributes))
        end

        def group_attributes
          attrs = Poetry::Core::HTML::Attributes.new(
            "data-slot" => "sensitive-input-group",
            "class" => InputGroup::Style.css(class: css(:group))
          )
          attrs.merge!(group_stimulus_attributes)
          attrs
        end

        def addon_attributes
          {
            "data-slot" => "input-group-addon",
            "data-align" => "inline-end",
            "class" => InputGroup::Style.css(:addon, class: InputGroup::Style.css(:addon_inline_end))
          }
        end

        # The mask overlay IS the reveal button while masked (never the
        # group: a role=button ancestor around the inert input trips axe
        # nested-interactive - the catch kumo, with no axe walk, ships).
        # Display:none in every other state keeps it out of the a11y tree.
        def mask_attributes
          attrs = Poetry::Core::HTML::Attributes.new(
            "data-slot" => "sensitive-input-mask",
            "class" => css(:mask)
          )
          if masked?
            attrs["role"] = "button"
            attrs["tabindex"] = disabled ? "-1" : "0"
            attrs["aria-label"] = masked_label
            attrs["aria-describedby"] = hint_id
          end
          attrs.merge!(mask_stimulus_attributes)
          attrs
        end

        def input_attributes
          attrs = Poetry::Core::HTML::Attributes.new(
            "type" => "password",
            "name" => name,
            "id" => control_id,
            "data-slot" => "input-group-control",
            "class" => "#{Input::Style.css(class: InputGroup::Style.css(:control_input))} #{css(:input)}",
            "autocomplete" => "off",
            "spellcheck" => "false"
          )
          attrs["value"] = value if value.present?
          attrs["placeholder"] = placeholder if placeholder.present?
          attrs["aria-label"] = label if label.present?
          attrs["aria-invalid"] = "true" if invalid && !disabled
          attrs["aria-describedby"] = described_by if described_by.present?
          attrs["disabled"] = "" if disabled
          attrs["required"] = "" if required
          if masked?
            attrs["aria-hidden"] = "true"
            attrs["tabindex"] = "-1"
            attrs["readonly"] = ""
          elsif readonly
            attrs["readonly"] = ""
          end
          attrs.merge!(input_stimulus_attributes)
          attrs
        end

        # The eye: exists only while revealed (the masked group is the
        # reveal path), so the server always renders it hidden.
        def toggle_button
          Button::Component.new({
            variant: :ghost, size: :"icon-xs", disabled: disabled,
            label: t("poetry.sensitive_input.hide"),
            class: InputGroup::Style.css(:button, class: InputGroup::Style.css(:button_icon_xs)),
            "data-slot" => "sensitive-input-toggle",
            "hidden" => "",
            "aria-controls" => control_id
          }.merge(toggle_stimulus_attributes))
        end

        def copy_button
          Button::Component.new({
            variant: :ghost, size: :"icon-xs", disabled: disabled,
            label: t("poetry.clipboard_text.copy"),
            class: InputGroup::Style.css(:button, class: InputGroup::Style.css(:button_icon_xs)),
            "data-slot" => "clipboard-text-copy",
            "aria-controls" => control_id
          }.merge(copy_stimulus_attributes))
        end

        def masked_label
          if label.present?
            t("poetry.sensitive_input.masked_label", label: label)
          else
            t("poetry.sensitive_input.masked_fallback")
          end
        end

        # The sr hint the masked group is described by (always rendered;
        # only referenced while masked).
        def hint_attributes
          attrs = Poetry::Core::HTML::Attributes.new("id" => hint_id, "class" => "sr-only")
          Poetry::Core::Stimulus::Builder.new(CONTROLLER, attrs).with_target(:hint)
          attrs
        end

        private

        # Both engines ride ONE attribute build (the TagGroup lesson: a
        # plain hash merge clobbers the first data-controller token).
        def root_stimulus_attributes
          attrs = Poetry::Core::HTML::Attributes.new
          field = Poetry::Core::Stimulus::Builder.new(CONTROLLER, attrs)
          field.register_controller
          field.with_value(:masked_label, masked_label)
          field.with_value(:hidden_message, t("poetry.sensitive_input.hidden"))
          field.with_value(:read_only, "true") if readonly
          field.with_action(:blurred, on: :focusout)
          if copy
            clip = Poetry::Core::Stimulus::Builder.new(COPY_CONTROLLER, attrs)
            clip.register_controller
            clip.with_value(:message, t("poetry.clipboard_text.copied"))
          end
          attrs.to_attributes
        end

        # Clicks anywhere on the bordered surface reveal (the mask's own
        # clicks bubble here); Enter/Space ride the mask button.
        def group_stimulus_attributes
          stimulus_attributes do |field|
            field.with_action(:reveal, on: :click)
          end
        end

        def mask_stimulus_attributes
          stimulus_attributes do |field|
            field.with_target(:mask)
            field.with_action(:maskKeydown, on: :keydown)
          end
        end

        def input_stimulus_attributes
          attrs = Poetry::Core::HTML::Attributes.new
          field = Poetry::Core::Stimulus::Builder.new(CONTROLLER, attrs)
          field.with_target(:input)
          field.with_action(:changed, on: :input)
          field.with_action(:inputKeydown, on: :keydown)
          Poetry::Core::Stimulus::Builder.new(COPY_CONTROLLER, attrs).with_target(:input) if copy
          attrs.to_attributes
        end

        def toggle_stimulus_attributes
          stimulus_attributes do |field|
            field.with_target(:toggle)
            field.with_action(:toggle, on: :click)
          end
        end

        def copy_stimulus_attributes
          attrs = Poetry::Core::HTML::Attributes.new
          Poetry::Core::Stimulus::Builder.new(COPY_CONTROLLER, attrs).with_action(:copy, on: :click)
          attrs.to_attributes
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
