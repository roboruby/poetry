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
        # @param _wrapper_options [Hash, nil] unused - the Field owns its chrome
        # @return [String] the rendered Field HTML
        def input(_wrapper_options = nil)
          poetry_builder.input(attribute_name, as: poetry_as, **poetry_options)
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
        # input_html: { class: } consciously with poetry_class:). A `poetry:`
        # hash is the first-class channel for poetry-only options (switch:,
        # length:, orientation:, ...) - merged last, so it wins.
        def poetry_options
          opts = input_html_options.except(:class, :id)
          opts[:hint] = options[:hint] if options[:hint].is_a?(String)
          label = options[:label].is_a?(String) ? options[:label] : translate_from_namespace(:labels)
          opts[:label] = label if label.is_a?(String) # simple_form.labels.* keys, its own lookup chain
          placeholder = options[:placeholder] || input_html_options[:placeholder]
          opts[:placeholder] = placeholder if placeholder.is_a?(String)
          opts[:required] = options[:required] if options.key?(:required) # explicit beats inference
          opts.merge!(options[:poetry].to_h.transform_keys(&:to_sym)) if options[:poetry]
          opts
        end
      end
    end
  end
end
