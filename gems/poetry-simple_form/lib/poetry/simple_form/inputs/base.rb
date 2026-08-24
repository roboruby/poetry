# frozen_string_literal: true

module Poetry
  module SimpleForm
    # The input classes the bridge maps simple_form's types onto.
    module Inputs
      # The shim's shared floor: every input renders through a
      # Poetry::Ui::FormBuilder bound to the SAME object/template, so the
      # poetry Field quartet (label/hint/error/aria) is byte-identical to
      # the native-builder path - no duplicated derivation.
      class Base < ::SimpleForm::Inputs::Base
        # Render the attribute as a whole poetry Field through the bound
        # Poetry::Ui::FormBuilder; the subclass's `poetry_as` pins the
        # control type (nil lets poetry infer it).
        #
        # @param wrapper_options [Hash, nil] unused - the Field owns its chrome
        # @return [String] the rendered Field HTML
        def input(wrapper_options = nil)
          poetry_builder.input(attribute_name, as: poetry_as, **poetry_options)
        rescue ArgumentError => e
          # poetry refuses :datetime (no composite control) - fall back to
          # simple_form's stock select trio rather than raising
          # mid-migration (the DateTimeInput doctrine, reachable here when
          # a column-less datetime resolves through the string path).
          raise unless e.message.include?(":datetime")

          ::SimpleForm::Inputs::DateTimeInput
            .new(@builder, attribute_name, column, :datetime, options).input(wrapper_options)
        end

        private

        # Subclasses answer the poetry `as:` value (nil lets poetry infer).
        def poetry_as = nil

        def poetry_builder
          Poetry::Ui::FormBuilder.new(object_name, object, template, {})
        end

        # simple_form option vocabulary -> poetry's: label/hint/placeholder
        # pass through (false stays false-y as an omission), required:
        # explicit override wins, input_html lands on the control minus the
        # class string (poetry components own their classes; append via
        # input_html: { class: } consciously with poetry_class:).
        def poetry_options
          opts = input_html_options.except(:class, :id)
          opts[:hint] = options[:hint] if options[:hint].is_a?(String)
          opts[:label] = options[:label] if options[:label].is_a?(String)
          placeholder = options[:placeholder] || input_html_options[:placeholder]
          opts[:placeholder] = placeholder if placeholder.is_a?(String)
          opts
        end
      end
    end
  end
end
