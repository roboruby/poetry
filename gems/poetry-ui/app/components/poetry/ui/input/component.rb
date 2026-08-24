# frozen_string_literal: true

module Poetry
  module Ui
    # The Input family - the single-line native text control.
    module Input
      # The text Input - the styled native <input>. Template-less; error
      # state is carried by aria-invalid (set by the Field/FormBuilder from
      # model errors), which the classes style directly - state IS the
      # accessibility attribute, never a parallel class.
      #
      # @example An email field
      #   render Poetry::Ui::Input::Component.new(type: "email", name: "email",
      #                                           placeholder: "you@example.com")
      class Component < Poetry::Core::Component
        # The mask controller identifier: masking is an Input OPTION,
        # not a separate component.
        MASK = %i[poetry core mask].freeze

        # Projected into the registry, llms.txt, and the agent surface.
        AGENT_RULES = [
          "Inside a form, never render Input directly - use the FormBuilder's field (it wires ids, errors, and aria).",
          "Error styling comes from aria-invalid, set from model errors - never hand-toggle error classes.",
          "mask: formats as the user types ('(999) 999-9999'; 9=digit, a=letter, A=upper, " \
          "*=alnum, #=sign/digit, \\\\ escapes, ? makes the rest optional) - the MASKED text " \
          "submits; read data-raw for the bare value."
        ].freeze

        # The native type attribute (text, email, password, file, ...).
        option :type, :string, default: "text"
        # The submitted param name.
        option :name, :string
        # The current value.
        option :value, :string
        # Native placeholder text - not a substitute for a Label.
        option :placeholder, :string
        # Disables the native input.
        option :disabled, :boolean, default: false
        # Marks the input aria-invalid - the error skin keys on the attribute.
        option :invalid, :boolean, default: false
        # Format-as-you-type mask descriptor ('(999) 999-9999'). Extra
        # knobs (slot char, always-show, auto-clear) ride Stimulus values
        # via data: - one declarative option covers the common case.
        option :mask, :string

        part "input", "The <input> element itself - no inner anatomy; error state is " \
                      "aria-invalid (set by Field/FormBuilder), never a parallel class",
             states: {
               "data-raw" => "mask: is set - the unmasked value, kept live by the mask " \
                             "controller (the masked text is what submits)"
             }

        # Renders the <input> element.
        # @api private
        def call
          tag.input(**root_attributes.to_attributes)
        end

        # The <input> element's attributes.
        # @api private
        def root_attributes
          attrs = { "type" => type, "data-slot" => "input" }.merge(component_data_attributes)
          attrs["name"] = name if name.present?
          attrs["value"] = value if value.present?
          attrs["placeholder"] = placeholder if placeholder.present?
          attrs["disabled"] = true if disabled
          attrs["aria-invalid"] = true if invalid
          attrs.merge!(mask_attributes) if mask.present?
          html_attributes.merge_if_not_set(attrs)
        end

        private

        def mask_attributes
          attrs = Poetry::Core::HTML::Attributes.new
          masked = Poetry::Core::Stimulus::Builder.new(MASK, attrs)
          masked.register_controller
          masked.with_value(:mask, mask)
          attrs.to_attributes
        end
      end
    end
  end
end
