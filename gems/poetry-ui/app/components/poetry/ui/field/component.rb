# frozen_string_literal: true

module Poetry
  module Ui
    module Field
      # The Field wrapper - the error quartet (label / control / hint /
      # error) with the aria wiring every reviewed form library leaves
      # manual: the control (the content block) receives its id from the
      # field, and control_attributes carries aria-invalid +
      # aria-describedby pointing at the hint and error ids. The
      # FormBuilder composes this from model truth; Field itself is
      # model-agnostic.
      class Component < Poetry::Core::Component
        AGENT_RULES = [
          "Wire the control with field.control_attributes - never hand-write aria-describedby.",
          "Error text arrives via error: (from model errors upstream) - never a bare red <p>.",
          "orientation: :horizontal is the boolean-control layout (checkbox/switch left, " \
          "label + hint stacked right) - text inputs and groups stay vertical.",
          "orientation: :responsive stacks by default and flips label-left / control-right " \
          "once its poetry_field_group container passes the md mark - the settings-page " \
          "recipe (it needs that FieldGroup ancestor to measure against)."
        ].freeze

        ORIENTATIONS = %i[vertical horizontal setting responsive].freeze

        # Upstream fieldVariants' orientation axis. Horizontal is the
        # boolean-control pattern: the control lands in the first grid
        # column, label + hint/error stack in the second, the control
        # row-centers against the label line (upstream approximates the
        # same with items-start + mt-px).
        style :orientation, default: :vertical, required: true, variants: ORIENTATIONS

        option :id, :string, required: true
        option :label_text, :string
        option :hint, :string
        option :error, :string
        option :required, :boolean, default: false
        # group: the control is a role-bearing <div> (RadioGroup, Slider) -
        # label[for] would be inert (Chrome flags it), so the label drops
        # for=, carries label_id, and control_attributes names the group
        # via aria-labelledby (the visible label, i18n-proof).
        option :group, :boolean, default: false

        part "field", "The quartet's grid root - label, control, hint, and error stack inside",
             states: {
               "data-invalid" => { condition: "always - true when error: is present, else false",
                                   values: %w[true false] },
               "data-orientation" => { condition: "always - the resolved orientation " \
                                                  "(horizontal is the boolean-control layout)",
                                       values: ORIENTATIONS.map(&:to_s) }
             }
        part "field-hint", "The hint <p> - its id lands in the control's aria-describedby"
        part "field-error", "The error <p> - present only when error: is set; its id leads " \
                            "the control's aria-describedby"
        part "checkbox-input", "A nested Checkbox's hidden native input - the toggle renders " \
                               "as a wrapper-free fragment, so its sibling form store sits " \
                               "directly in the field's DOM (the horizontal boolean-control " \
                               "layout)"
        part "switch-input", "A nested Switch's hidden native input - the same wrapper-free " \
                             "fragment escape as checkbox-input (the setting-row layout)"

        def hint_id = "#{id}-hint"
        def error_id = "#{id}-error"
        def label_id = "#{id}-label"

        def invalid? = error.present?

        # Everything the control inside the field must carry - merged by
        # the FormBuilder (or the caller) into the control's attributes.
        def control_attributes
          attrs = { "id" => id }
          attrs["aria-labelledby"] = label_id if group && label_text.present?
          describedby = []
          describedby << error_id if invalid?
          describedby << hint_id if hint.present?
          attrs["aria-describedby"] = describedby.join(" ") if describedby.any?
          attrs["aria-invalid"] = true if invalid?
          # The aria-required-only rule (an external generator): never the native
          # required attribute - no native bubbles, no double announcement.
          attrs["aria-required"] = true if required
          attrs
        end

        def root_attributes
          html_attributes.merge_if_not_set(
            { "data-slot" => "field", "data-invalid" => invalid?,
              "data-orientation" => orientation }.merge(component_data_attributes)
          )
        end
      end
    end
  end
end
