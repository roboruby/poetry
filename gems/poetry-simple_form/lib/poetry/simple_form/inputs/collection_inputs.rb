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

        def label_value_pairs(collection = Array(options[:collection]))
          return [] if collection.empty?

          sample = collection.first
          label = options[:label_method]
          value = options[:value_method]
          if (sample.is_a?(Array) || !sample.respond_to?(:id)) && !(label || value)
            collection.map { |item| item.is_a?(Array) ? item : [item.to_s, item] }
          else
            # simple_form's label_method:/value_method: (symbols or callables)
            # win; otherwise its detection chain (name, title, to_s / id, to_s).
            label ||= ::SimpleForm.collection_label_methods.find { |m| sample.respond_to?(m) }
            value ||= ::SimpleForm.collection_value_methods.find { |m| sample.respond_to?(m) }
            collection.map { |item| [read(item, label), read(item, value)] }
          end
        end

        def read(item, method)
          method.respond_to?(:call) ? method.call(item) : item.public_send(method)
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

      # Serves `as: :native_select`: a poetry Field wrapping the styled
      # native <select> (the no-JS picker).
      class NativeSelectInput < CollectionBase
        # @return [String] the rendered Field HTML
        def input(_wrapper_options = nil)
          poetry_builder.native_select(attribute_name, label_value_pairs,
                                       include_blank: options[:include_blank] || options[:prompt],
                                       **poetry_options)
        end
      end

      # Serves `as: :combobox`: a poetry Field wrapping the filterable Combobox.
      class ComboboxInput < CollectionBase
        # @return [String] the rendered Field HTML
        def input(_wrapper_options = nil)
          poetry_builder.poetry_combobox(attribute_name, label_value_pairs,
                                         include_blank: options[:include_blank] || options[:prompt],
                                         **poetry_options)
        end
      end

      # Serves `as: :autocomplete`: a poetry Field wrapping the Autocomplete;
      # the collection becomes its suggestions.
      class AutocompleteInput < CollectionBase
        # @return [String] the rendered Field HTML
        def input(_wrapper_options = nil)
          poetry_builder.autocomplete(attribute_name, label_value_pairs, **poetry_options)
        end
      end

      # Serves `as: :grouped_select`: simple_form's group_method /
      # group_label_method resolve the groups, poetry's Select renders them
      # as labelled groups.
      class GroupedCollectionSelectInput < CollectionBase
        # @return [String] the rendered Field HTML
        def input(_wrapper_options = nil)
          poetry_builder.poetry_select(attribute_name, grouped_pairs,
                                       include_blank: options[:include_blank] || options[:prompt],
                                       **poetry_options)
        end

        private

        # { "Group label" => [[label, value], ...] } in collection order.
        def grouped_pairs
          groups = options[:collection]
          groups = groups.call if groups.respond_to?(:call)
          group_method = options.fetch(:group_method)
          Array(groups).to_h do |group|
            [group_label_for(group).to_s, label_value_pairs(Array(group.public_send(group_method)))]
          end
        end

        def group_label_for(group)
          method = options[:group_label_method] ||
                   ::SimpleForm.collection_label_methods.find { |m| group.respond_to?(m) }
          method ? group.public_send(method) : group
        end
      end

      # Serves `as: :time_zone`: every ActiveSupport::TimeZone in a poetry
      # Select, the priority zones (priority: or SimpleForm.time_zone_priority)
      # listed first.
      class TimeZoneInput < CollectionBase
        # @return [String] the rendered Field HTML
        def input(_wrapper_options = nil)
          poetry_builder.poetry_select(attribute_name, zone_pairs,
                                       include_blank: options[:include_blank] || options[:prompt],
                                       **poetry_options)
        end

        private

        def zone_pairs
          zones = ActiveSupport::TimeZone.all
          priority = Array(options[:priority] || ::SimpleForm.time_zone_priority)
          first = priority.map { |zone| zone.is_a?(ActiveSupport::TimeZone) ? zone : ActiveSupport::TimeZone[zone] }.compact
          (first + (zones - first)).map { |zone| [zone.to_s, zone.name] }
        end
      end
    end
  end
end
