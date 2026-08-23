# frozen_string_literal: true

module Poetry
  module Ui
    module Checkbox
      # First of the toggle family - the one that carries tri-state and
      # the family's form-integration architecture. Poetry INVERTS Radix's hidden-input model: the hidden
      # native <input type=checkbox> IS the form participant and the store
      # (server-rendered name/value/checked, Rails "1"/"0" plus the
      # unchecked-hidden pair), while the visual button[role=checkbox] only
      # REFLECTS it via aria-checked + the checked pair (data-checked /
      # data-unchecked / data-indeterminate, Base UI vocabulary). The shared
      # poetry--core--checked controller (reused verbatim by Switch) flips
      # the input, lets the REAL change event bubble, and re-syncs from the
      # input on native form reset.
      #
      # No wrapper element: button + inputs render as SIBLINGS (fragment) -
      # the source's `peer` class contract for peer-* label styling breaks
      # if poetry wraps.
      #
      # @example A form checkbox
      #   render Poetry::Ui::Checkbox::Component.new(name: "terms", label: "Accept terms")
      class Component < Poetry::Core::Component
        STATES = [true, false, :indeterminate].freeze

        AGENT_RULES = [
          "A select-all run rides poetry_checkbox_group (wrapper) + poetry_checkbox_group_all " \
          "(the mixed-state parent) + poetry_checkbox_group_item per member - toggles fan out " \
          "and re-derive automatically.",
          "Use poetry_checkbox (or f.check_box) - never a raw input[type=checkbox] with hand-written " \
          "Tailwind, and never a hand-rolled button[role=checkbox].",
          "Always give it a name: in forms - a checkbox without one submits nothing (visual-only mode " \
          "is for controlled UI like DataTable row selection ONLY).",
          "Every checkbox needs an accessible name: a Label/Field for= association (preferred) or label:.",
          "Indeterminate is set programmatically/server-side only - no user gesture produces it; use it " \
          "for select-all parents.",
          "Select-all recipe: wrap parent + rows in data-controller=\"poetry--core--checkbox-group\" with " \
          "data-action=\"poetry:checkbox:change->poetry--core--checkbox-group#changed\"; mark the parent " \
          "box data: {\"poetry--core--checkbox-group-target\": \"all\"} and each row box target \"item\" - " \
          "the parent fans out, rows re-derive checked/unchecked/indeterminate (DataTable's selectable: " \
          "already does this for its own rows).",
          "Instant-effect settings use Switch; pressed UI tools use Toggle; one-of-N uses RadioGroup.",
          "NEVER write the checked attributes (data-checked/data-unchecked/data-indeterminate) without " \
          "aria-checked and the input's checked property (the controller writes all three; agents " \
          "patching DOM must too).",
          "Don't suppress unchecked_value unless using the array idiom - an unchecked box that submits " \
          "nothing silently keeps the old server value."
        ].freeze

        use_stimulus do
          on :root do
            controller :checked do
              register
              # No input-id value -> pure visual mode: state lives on the
              # button's checked attributes alone (discouraged; see AGENT_RULES).
              value :input_id, if: :form_participant?
              action :toggle, on: :click
            end
          end
        end

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
        # aria-required ONLY, never native required - native required on the
        # hidden input would make an unfocusable control invalid.
        option :required, :boolean, default: false
        # aria-label fallback when no <label for>/Field association exists.
        option :label, :string

        part "checkbox", "The visual button[role=checkbox] - reflects the hidden input via " \
                         "aria-checked plus the checked triple",
             states: {
               "data-checked" => "checked (the controller reflects every toggle here, " \
                                 "aria-checked in step)",
               "data-unchecked" => "unchecked - the indicator goes invisible",
               "data-indeterminate" => "checked: :indeterminate (server/programmatic only; " \
                                       "the first toggle resolves it to checked)"
             }
        part "checkbox-indicator", "Centering span around the check glyph (minus when " \
                                   "indeterminate) - CSS-hidden while unchecked, never unmounted",
             states: {
               "data-checked" => "mirrors the control (the controller reflects state on " \
                                 "every part wearing the triple)",
               "data-unchecked" => "mirrors the control - the indicator is invisible",
               "data-indeterminate" => "mirrors the control - the glyph swaps to minus"
             }

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
          @control_id ||= poetry_instance_id("poetry-checkbox")
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
            "aria-checked" => aria_checked, "data-#{state}" => "",
            "data-slot" => "checkbox", "disabled" => disabled
          }
          attrs["aria-required"] = true if required
          attrs["aria-label"] = label if label.present?
          html_attributes.merge_if_not_set(
            attrs.merge(stimulus_attributes_for(:root)).merge(component_data_attributes)
          )
        end
      end
    end
  end
end
