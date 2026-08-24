# frozen_string_literal: true

module Poetry
  module SimpleForm
    module Inputs
      # The collection floor: pairs from options[:collection] (both
      # f.input(collection:) and f.association arrive here - association
      # fetches the records first), label/value methods resolved with
      # simple_form's own detection chain.
      class CollectionBase < Base
        private

        def label_value_pairs
          collection = Array(options[:collection])
          return [] if collection.empty?

          sample = collection.first
          if sample.is_a?(Array) || !sample.respond_to?(:id)
            collection.map { |item| item.is_a?(Array) ? item : [item.to_s, item] }
          else
            label = ::SimpleForm.collection_label_methods.find { |m| sample.respond_to?(m) }
            value = ::SimpleForm.collection_value_methods.find { |m| sample.respond_to?(m) }
            collection.map { |item| [item.public_send(label), item.public_send(value)] }
          end
        end
      end

      # Serves `as: :select` (and f.association's default): a poetry Field
      # wrapping the Select component; the hidden native <select> stays the
      # serialization truth.
      class CollectionSelectInput < CollectionBase
        # Render the collection as a Field-wrapped Select;
        # include_blank/prompt becomes the placeholder option.
        #
        # @return [String] the rendered Field HTML
        def input(_wrapper_options = nil)
          poetry_builder.poetry_select(attribute_name, label_value_pairs,
                                       include_blank: options[:include_blank] || options[:prompt],
                                       **poetry_options)
        end
      end

      # Serves `as: :radio_buttons`: a poetry Field wrapping the
      # RadioGroup component, one row per collection item.
      class CollectionRadioButtonsInput < CollectionBase
        # Render the collection as a Field-wrapped RadioGroup.
        #
        # @return [String] the rendered Field HTML
        def input(_wrapper_options = nil)
          pairs = label_value_pairs.map { |label, value| [value, label] }
          poetry_builder.radio_group(attribute_name, pairs, **poetry_options)
        end
      end

      # Serves `as: :check_boxes`: a poetry Field wrapping the checkbox
      # group - one Checkbox row per collection item, posting an array.
      class CollectionCheckBoxesInput < CollectionBase
        # Render the collection as a Field-wrapped checkbox group.
        #
        # @return [String] the rendered Field HTML
        def input(_wrapper_options = nil)
          pairs = label_value_pairs.map { |label, value| [value, label] }
          poetry_builder.checkbox_group(attribute_name, pairs, **poetry_options)
        end
      end
    end
  end
end
