# frozen_string_literal: true

module Poetry
  module Core
    module Concerns
      # The prop-introspection shim: a machine-readable
      # description of a component's public surface - style attributes,
      # options, and slots - derived from the metadata the Styles/Options
      # DSLs and ViewComponent already carry. This is the single source the
      # generated registry, the docs tables, and the MCP prop schema are
      # built from; nothing here is hand-authored.
      module Introspection
        extend ActiveSupport::Concern

        DYNAMIC_DEFAULT = :dynamic

        class_methods do
          # The component's full prop surface.
          #
          # @return [Hash] { styles: [...], options: [...], slots: [...] }
          def prop_definitions
            {
              styles: style_attributes.map { |name| style_definition(name) },
              options: option_attributes.map { |name| option_definition(name) },
              slots: slot_definitions
            }
          end

          private

          def style_definition(name)
            definition = { name: name, type: attribute_types[name.to_s].type }
            variants = respond_to?("#{name}_variants") ? public_send("#{name}_variants") : nil
            definition[:variants] = variants if variants.is_a?(Array)
            definition.merge!(default_definition(name, style_attributes_with_static_defaults,
                                                 style_attributes_with_proc_defaults))
            definition[:required] = true if required_attribute?(name)
            definition
          end

          def option_definition(name)
            definition = { name: name, type: attribute_types[name.to_s].type }
            definition.merge!(default_definition(name, option_attributes_with_static_defaults,
                                                 option_attributes_with_proc_defaults))
            definition[:required] = true if required_attribute?(name)
            definition
          end

          # ViewComponent's registered slots: renders_one -> one, renders_many
          # -> many (ViewComponent registers the plural name with collection).
          def slot_definitions
            registered_slots.map do |slot_name, config|
              { name: slot_name, many: config[:collection] == true }
            end
          end

          # The default, keyed three ways: a static value (from ActiveModel's
          # default attributes, may legitimately be false), :dynamic for proc
          # defaults (value depends on other attributes), or no key at all.
          def default_definition(name, static_names, proc_names)
            if proc_names.include?(name)
              { default: DYNAMIC_DEFAULT }
            elsif static_names.include?(name)
              { default: _default_attributes[name.to_s]&.value_before_type_cast }
            else
              {}
            end
          end

          def required_attribute?(name)
            validators_on(name).any? { |validator| validator.kind == :presence }
          end
        end
      end
    end
  end
end
