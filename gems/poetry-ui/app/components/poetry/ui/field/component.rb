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
          "Error text arrives via error: (from model errors upstream) - never a bare red <p>."
        ].freeze

        option :id, :string, required: true
        option :label_text, :string
        option :hint, :string
        option :error, :string
        option :required, :boolean, default: false

        def hint_id = "#{id}-hint"
        def error_id = "#{id}-error"

        def invalid? = error.present?

        # Everything the control inside the field must carry - merged by
        # the FormBuilder (or the caller) into the control's attributes.
        def control_attributes
          attrs = { "id" => id }
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
            { "data-slot" => "field", "data-invalid" => invalid? }.merge(component_data_attributes)
          )
        end
      end
    end
  end
end
