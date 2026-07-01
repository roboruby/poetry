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

      private

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
