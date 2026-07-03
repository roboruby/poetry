# frozen_string_literal: true

module Poetry
  module Ui
    # The poetry FormBuilder - the model-truth end of the error
    # quartet: `form.field(:email)` renders a Field wrapping an Input with
    # everything derived from the object, never hand-wired:
    #
    #   label    from human_attribute_name (Rails i18n)
    #   value    from the object
    # error from object.errors (auto-flow)
    #   required from the model's presence validators (-> aria-required
    # only - the external generator rule; never the native attribute)
    #   ids/aria field_id + aria-describedby via Field#control_attributes
    #
    # Usage: form_with(model:, builder: Poetry::Ui::FormBuilder).
    class FormBuilder < ActionView::Helpers::FormBuilder
      def field(method, type: "text", hint: nil, placeholder: nil, **input_options)
        field_component = Field::Component.new(
          id: field_id(method),
          label_text: object.class.human_attribute_name(method),
          hint: hint,
          error: error_for(method),
          required: required?(method)
        )
        @template.render(field_component) do
          @template.render Input::Component.new(
            type: type,
            name: field_name(method),
            value: object.public_send(method).presence&.to_s,
            placeholder: placeholder,
            **input_options,
            **field_component.control_attributes.transform_keys(&:to_sym)
          )
        end
      end

      # The f.check_box-equivalent (the toggle family's form story): name/id
      # derived, checked: from the object's attribute truthiness, "1"/"0"
      # plus the unchecked-hidden pair (ActionView::Helpers::Tags::CheckBox
      # parity incl. hidden-input-first ordering - the Checkbox component
      # renders the pair). A BARE control mapping: compose with a Field
      # (control_attributes) for the label/hint/error quartet.
      def check_box(method, options = {}, checked_value = "1", unchecked_value = "0")
        @template.render Checkbox::Component.new(**toggle_options(method, options, checked_value, unchecked_value))
      end

      # The same mapping wearing switch semantics (Rails has NO native
      # switch builder): role=switch announces on/off; use it for
      # instant-effect settings, check_box for values staged for submit.
      def switch(method, options = {}, checked_value = "1", unchecked_value = "0")
        @template.render Switch::Component.new(**toggle_options(method, options, checked_value, unchecked_value))
      end

      private

      # Shared derivation for the toggle-family builder methods: everything
      # from the object, never hand-wired. required maps to aria-required
      # only (the lock - the components never render native required).
      def toggle_options(method, options, checked_value, unchecked_value)
        {
          name: field_name(method),
          id: field_id(method),
          checked: ActiveModel::Type::Boolean.new.cast(object.public_send(method)) || false,
          value: checked_value,
          unchecked_value: unchecked_value,
          required: required?(method),
          **options.transform_keys(&:to_sym)
        }
      end

      def error_for(method)
        object.errors.full_messages_for(method).first if object.respond_to?(:errors)
      end

      def required?(method)
        object.class.respond_to?(:validators_on) &&
          object.class.validators_on(method).any? { |validator| validator.kind == :presence }
      end
    end
  end
end
