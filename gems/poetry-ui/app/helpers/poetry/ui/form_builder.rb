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
      # One field entrypoint for field-shaped controls: as: :input (the
      # default, with type:) or as: :textarea (rows: passes through) -
      # Own-line controls slot in as as: values; group-shaped
      # controls get dedicated methods (radio_group, slider, otp_field).
      def field(method, as: :input, hint: nil, **input_options)
        field_component = field_for(method, hint: hint)
        control_options = {
          name: field_name(method),
          value: object.public_send(method).presence&.to_s,
          **input_options,
          **field_component.control_attributes.transform_keys(&:to_sym)
        }
        @template.render(field_component) do
          @template.render(
            if as == :textarea
              Textarea::Component.new(**control_options)
            else
              Input::Component.new(**control_options)
            end
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

      # The collection_radio_buttons-equivalent (the exclusive-choice
      # story): a Field wrapping a RadioGroup, items from the collection
      # ([[value, label], ...] pairs or bare values), value/label/error/
      # required derived from the object. Serialization is byte-identical
      # to collection_radio_buttons (one hidden native radio per item,
      # shared name; nothing submits when none is checked).
      def radio_group(method, collection, hint: nil, **options)
        field_component = field_for(method, hint: hint)
        @template.render(field_component) do
          @template.render RadioGroup::Component.new(
            name: field_name(method),
            value: object.public_send(method).presence&.to_s,
            required: required?(method),
            invalid: field_component.invalid?,
            # The group name doubles the visible Field label (aria-label -
            # the Field's label element carries no id to point
            # aria-labelledby at).
            label: field_component.label_text,
            **group_control_attributes(field_component),
            **options.transform_keys(&:to_sym)
          ) do |group|
            collection.each do |item|
              value, label = item.is_a?(Array) ? item : [item, item.to_s.humanize]
              group.with_item(value: value, label: label)
            end
          end
        end
      end

      # The bounded-numeric story: form.slider(:volume) single (label from
      # human_attribute_name), form.slider(:price_range, range: true,
      # label: [...]) reads an Array[2] and submits name[] (params:
      # ["200", "800"] - Rails' own array convention). Field wraps for
      # hint/error; the describedby lands on each THUMB.
      def slider(method, range: false, hint: nil, **options)
        field_component = field_for(method, hint: hint)
        value = object.public_send(method)
        slider_options = {
          name: field_name(method),
          label: options.delete(:label) || (range ? nil : field_component.label_text),
          **group_control_attributes(field_component),
          **options.transform_keys(&:to_sym)
        }
        describedby = slider_options.delete(:"aria-describedby")
        slider_options[:described_by] = describedby if describedby
        if range
          slider_options[:values] = Array(value).presence ||
                                    [slider_options.fetch(:min, 0), slider_options.fetch(:max, 100)]
        else
          slider_options[:value] = value
        end
        @template.render(field_component) do
          @template.render Slider::Component.new(**slider_options)
        end
      end

      # The verification-code story: form.otp_field(:code, length: 6) - a
      # Field wrapping an InputOTP, label/error/required from the object.
      # The value is deliberately NEVER round-tripped (a rejected code is
      # dead; re-rendering it invites resubmit-the-same-wrong-code loops)
      # - pass value: explicitly to override.
      def otp_field(method, length: 6, hint: nil, **options)
        field_component = field_for(method, hint: hint)
        @template.render(field_component) do
          @template.render InputOtp::Component.new(
            name: field_name(method),
            length: length,
            required: required?(method),
            invalid: field_component.invalid?,
            **field_component.control_attributes.slice("id", "aria-describedby").transform_keys(&:to_sym),
            **options.transform_keys(&:to_sym)
          )
        end
      end

      private

      # Group-shaped controls take the id (item ids derive from it) and
      # the describedby wiring from the Field; invalid/required ride the
      # component's own options (aria-invalid belongs on the ITEMS, not
      # the root).
      def group_control_attributes(field_component)
        field_component.control_attributes.slice("id", "aria-describedby").transform_keys(&:to_sym)
      end

      def field_for(method, hint: nil)
        Field::Component.new(
          id: field_id(method),
          label_text: object.class.human_attribute_name(method),
          hint: hint,
          error: error_for(method),
          required: required?(method)
        )
      end

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
