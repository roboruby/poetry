# frozen_string_literal: true

module Poetry
  module Ui
    # A secret field that stays masked until deliberately revealed.
    module SensitiveInput
      # A secret field - API keys, tokens, credentials - shown masked
      # until deliberately revealed. Three states ride data-state on the
      # root: masked (the value hidden behind an overlay that IS the
      # reveal button, while the real input stays rendered for layout but
      # goes inert), revealed (type=text, editable, the eye re-masks), and
      # empty (a plain password input; the first character typed
      # auto-reveals so composition happens visibly). Re-mask via Escape
      # (focus returns to the group), leaving the component, or the eye.
      # copy: adds a copy button - a real keyboard tab stop - that copies
      # the value WITHOUT revealing it. The no-JS story is a plain
      # password input that still submits.
      #
      # @example An API key with copy-without-reveal
      #   render Poetry::Ui::SensitiveInput::Component.new(name: "api_key", label: "API key",
      #                                                    value: token, copy: true)
      class Component < Poetry::Core::Component
        include Poetry::Ui::InputGroupField
        # Projected into the registry, llms.txt, and the agent surface.
        AGENT_RULES = [
          "Secrets shown-on-demand are a SensitiveInput (poetry_sensitive_input) - never a bare " \
          "password Input with a hand-rolled eye; the masked-container contract (role=button, " \
          "focus discipline, blur re-mask) rides the controller.",
          "label: feeds the masked announcement (\"{label}, masked.\") - pair with a Label/Field " \
          "for the visible caption.",
          "copy: true adds copy-without-revealing; leave it off for password-change forms.",
          "Values re-mask on blur BY DESIGN - do not fight it with reveal-state persistence."
        ].freeze

        # Both engines declare on the root; the clipboard-text controller
        # rides along only when copy: is set.
        use_stimulus do
          on :root do
            controller :sensitive_input do
              register
              value :masked_label
              value :hidden_message, from: :hidden_message_text
              value :read_only, "true", if: :readonly
              action :blurred, on: :focusout
            end
            controller :clipboard_text, if: :copy do
              register
              value :message, from: :copied_message_text
            end
          end
          # Clicks anywhere on the bordered surface reveal (the mask's own
          # clicks bubble here); Enter/Space ride the mask button.
          on :group do
            controller(:sensitive_input) { action :reveal, on: :click }
          end
          on :mask do
            controller :sensitive_input do
              target :mask
              action :maskKeydown, on: :keydown
            end
          end
          on :input do
            controller :sensitive_input do
              target :input
              action :changed, on: :input
              action :inputKeydown, on: :keydown
            end
            controller(:clipboard_text, if: :copy) { target :input }
          end
          on :toggle do
            controller :sensitive_input do
              target :toggle
              action :toggle, on: :click
            end
          end
          on :copy_button do
            controller(:clipboard_text) { action :copy, on: :click }
          end
          # The sr hint the masked group is described by.
          on :hint do
            controller(:sensitive_input) { target :hint }
          end
        end

        # The form field name on the real input.
        option :name, :string, required: true
        # The secret's current value; present = first paint is masked,
        # blank = the empty state.
        option :value, :string
        # The input's DOM id - what a Field label's for: must reference.
        option :id, :string
        # The accessible name - feeds the input's aria-label and the
        # masked announcement ("{label}, masked."); pair with a visible
        # Label/Field caption.
        option :label, :string
        # Hint text shown while the field is empty.
        option :placeholder, :string
        # aria-describedby on the input - Field hint/error wiring.
        option :described_by, :string
        # Adds the copy-without-revealing button in the trailing cell.
        option :copy, :boolean, default: false
        # Disables the input and drops the masked group's tab stop.
        option :disabled, :boolean, default: false
        # The value can be revealed and copied but not edited.
        option :readonly, :boolean, default: false
        # Marks the real input required.
        option :required, :boolean, default: false
        # aria-invalid on the input - set by Field/FormBuilder from model
        # errors.
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
        # carrying data-slot=sensitive-input-toggle / clipboard-text-copy
        # on Button's root - part ownership attributes them to Button. The
        # eye exists ONLY while revealed (hidden otherwise; the masked
        # group is the reveal path), re-masks and hands focus back to the
        # group; copy is a real tab stop wired to the clipboard-text
        # engine.

        # @api private
        def hint_id
          "#{control_id}-hint"
        end

        # @api private
        def state
          value.present? ? "masked" : "empty"
        end

        # @api private
        def masked?
          state == "masked"
        end

        # @api private
        def root_attributes
          attrs = {
            "data-slot" => "sensitive-input",
            "data-state" => state,
            "class" => css
          }.merge(component_data_attributes)
          attrs["data-disabled"] = "" if disabled
          html_attributes.merge_if_not_set(attrs.merge(stimulus_attributes_for(:root)))
        end

        # @api private
        def group_attributes
          attrs = Poetry::Core::HTML::Attributes.new(
            "data-slot" => "sensitive-input-group",
            "class" => InputGroup::Style.css(class: css(:group))
          )
          attrs.merge!(stimulus_attributes_for(:group))
          attrs
        end

        # Fixed inline-end - the reveal/copy cell.
        # @api private
        def addon_attributes
          super(:end)
        end

        # The mask overlay IS the reveal button while masked (never the
        # group: a role=button ancestor around the inert input trips axe
        # nested-interactive). Display:none in every other state keeps it
        # out of the a11y tree.
        # @api private
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
          attrs.merge!(stimulus_attributes_for(:mask))
          attrs
        end

        # @api private
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
          attrs.merge!(stimulus_attributes_for(:input))
          attrs
        end

        # The eye: exists only while revealed (the masked group is the
        # reveal path), so the server always renders it hidden.
        # @api private
        def toggle_button
          group_tool_button(slot: "sensitive-input-toggle",
                            label: t("poetry.sensitive_input.hide"),
                            tabindex: nil, extra: { "hidden" => "" },
                            wiring: stimulus_attributes_for(:toggle))
        end

        # A REAL tab stop (no tabindex -1): copy must be keyboard-reachable.
        # @api private
        def copy_button
          group_tool_button(slot: "clipboard-text-copy",
                            label: t("poetry.clipboard_text.copy"),
                            tabindex: nil,
                            wiring: stimulus_attributes_for(:copy_button))
        end

        # @api private
        def masked_label
          if label.present?
            t("poetry.sensitive_input.masked_label", label: label)
          else
            t("poetry.sensitive_input.masked_fallback")
          end
        end

        # The sr hint the masked group is described by (always rendered;
        # only referenced while masked).
        # @api private
        def hint_attributes
          attrs = Poetry::Core::HTML::Attributes.new("id" => hint_id, "class" => "sr-only")
          attrs.merge!(stimulus_attributes_for(:hint))
          attrs
        end

        private

        def hidden_message_text = t("poetry.sensitive_input.hidden")
        def copied_message_text = t("poetry.clipboard_text.copied")
      end
    end
  end
end
