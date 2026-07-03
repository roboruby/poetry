# frozen_string_literal: true

module Poetry
  module Ui
    module Checkbox
      # First of the toggle family (Checkbox) - the one
      # that carries tri-state and the family's form-integration
      # architecture. Poetry INVERTS Radix's hidden-input model: the hidden
      # native <input type=checkbox> IS the form participant and the store
      # (server-rendered name/value/checked, Rails "1"/"0" plus the
      # unchecked-hidden pair), while the visual button[role=checkbox] only
      # REFLECTS it via aria-checked + data-state. The shared
      # poetry--core--checked controller (reused verbatim by Switch) flips
      # the input, lets the REAL change event bubble, and re-syncs from the
      # input on native form reset.
      #
      # No wrapper element: button + inputs render as SIBLINGS (fragment) -
      # the source's `peer` class contract for peer-* label styling breaks
      # if poetry wraps.
      class Component < Poetry::Core::Component
        CHECKED = %i[poetry core checked].freeze
        STATES = [true, false, :indeterminate].freeze

        AGENT_RULES = [
          "Use poetry_checkbox (or f.check_box) - never a raw input[type=checkbox] with hand-written " \
          "Tailwind, and never a hand-rolled button[role=checkbox].",
          "Always give it a name: in forms - a checkbox without one submits nothing (visual-only mode " \
          "is for controlled UI like DataTable row selection ONLY).",
          "Every checkbox needs an accessible name: a Label/Field for= association (preferred) or label:.",
          "Indeterminate is set programmatically/server-side only - no user gesture produces it; use it " \
          "for select-all parents.",
          "Instant-effect settings use Switch; pressed UI tools use Toggle; one-of-N uses RadioGroup.",
          "NEVER write data-state without aria-checked and the input's checked property (the controller " \
          "writes all three; agents patching DOM must too).",
          "Don't suppress unchecked_value unless using the array idiom - an unchecked box that submits " \
          "nothing silently keeps the old server value."
        ].freeze

        # The tri-valued checked: type (mirrors Radix CheckedState): casts to
        # exactly true | false | :indeterminate - one option, one source of
        # truth, no separate indeterminate: flag.
        class CheckedState < ActiveModel::Type::Value
          def type
            :checked_state
          end

          def cast(value)
            return :indeterminate if value.to_s == "indeterminate"

            ActiveModel::Type::Boolean.new.cast(value) || false
          end
        end

        # checked: is ONE tri-valued option ([true, false, :indeterminate]) -
        # not a separate indeterminate: flag (mirrors Radix CheckedState).
        option :checked, CheckedState.new, default: false
        # PRESENCE gates the hidden native input pair - poetry's server-side
        # answer to Radix's runtime closest('form') isFormControl check.
        option :name, :string
        # Rails check_box parity ("1", not Radix's "on").
        option :value, :string, default: "1"
        # The paired hidden's value submitted when unchecked (FormBuilder
        # parity); nil suppresses the pair (the array idiom).
        option :unchecked_value, :string, default: "0"
        option :disabled, :boolean, default: false
        # aria-required ONLY, never native required (the Field lock).
        option :required, :boolean, default: false
        # aria-label fallback when no <label for>/Field association exists.
        option :label, :string

        def indeterminate?
          checked == :indeterminate
        end

        def checked?
          checked == true
        end

        def state
          return "indeterminate" if indeterminate?

          checked? ? "checked" : "unchecked"
        end

        def aria_checked
          indeterminate? ? "mixed" : checked?.to_s
        end

        # The label-for target (Field-issued or auto) - server-stable so the
        # sibling input resolves structurally by id, wrapper-free.
        def control_id
          @control_id ||= html_attributes["id"].presence || "poetry-checkbox-#{SecureRandom.hex(4)}"
        end

        def input_id
          "#{control_id}-input"
        end

        def form_participant?
          name.present?
        end

        def root_attributes
          attrs = {
            "type" => "button", "role" => "checkbox", "id" => control_id,
            "aria-checked" => aria_checked, "data-state" => state,
            "data-slot" => "checkbox", "disabled" => disabled
          }
          attrs["aria-required"] = true if required
          attrs["aria-label"] = label if label.present?
          html_attributes.merge_if_not_set(
            attrs.merge(root_stimulus_attributes).merge(component_data_attributes)
          )
        end

        private

        def root_stimulus_attributes
          attrs = Poetry::Core::HTML::Attributes.new
          builder = Poetry::Core::Stimulus::Builder.new(CHECKED, attrs)
          builder.register_controller
          # No input-id value -> pure visual mode: state lives on the
          # button's data-state alone (discouraged; see AGENT_RULES).
          builder.with_value(:input_id, input_id) if form_participant?
          builder.with_action(:toggle, on: :click)
          attrs.to_attributes
        end
      end
    end
  end
end
