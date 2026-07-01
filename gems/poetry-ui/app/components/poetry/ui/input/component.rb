# frozen_string_literal: true

module Poetry
  module Ui
    module Input
      # The text Input - shadcn new-york-v4 parity. Template-less; error
      # state is carried by aria-invalid (set by the Field/FormBuilder from
      # model errors), which the classes style directly - state IS the
      # accessibility attribute, never a parallel class.
      class Component < Poetry::Core::Component
        AGENT_RULES = [
          "Inside a form, never render Input directly - use the FormBuilder's field (it wires ids, errors, and aria).",
          "Error styling comes from aria-invalid, set from model errors - never hand-toggle error classes."
        ].freeze

        option :type, :string, default: "text"
        option :name, :string
        option :value, :string
        option :placeholder, :string
        option :disabled, :boolean, default: false
        option :invalid, :boolean, default: false

        def call
          tag.input(**root_attributes.to_attributes)
        end

        def root_attributes
          attrs = { "type" => type, "data-slot" => "input" }.merge(component_data_attributes)
          attrs["name"] = name if name.present?
          attrs["value"] = value if value.present?
          attrs["placeholder"] = placeholder if placeholder.present?
          attrs["disabled"] = true if disabled
          attrs["aria-invalid"] = true if invalid
          html_attributes.merge_if_not_set(attrs)
        end
      end
    end
  end
end
