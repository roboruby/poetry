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
              slots: slot_definitions,
              slot_extras: slot_extras
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
            format = option_format(name)
            definition[:format] = format if format
            definition
          end

          # ViewComponent's registered slots: renders_one -> one, renders_many
          # -> many (ViewComponent registers the plural name with collection).
          # A typed slot (renders_one :icon, Icon::Component) also carries the
          # slot component's registry path - the machine-readable form of "this
          # slot takes that component's props, not a render block" (the W2
          # alert crash class: an agent can only honor a contract a surface
          # states).
          def slot_definitions
            registered_slots.map do |slot_name, config|
              definition = { name: slot_name, many: config[:collection] == true }
              renderable = config[:renderable]
              definition[:component] = renderable.component_path if renderable.respond_to?(:component_path)
              # Polymorphic slots (renders_many :items, types: {...}) accept
              # one with_<type> setter per type - the consumer-facing call
              # surface, which poetry check and the docs must know.
              definition[:types] = config[:renderable_hash].keys if config[:renderable_hash]
              definition
            end
          end

          # Hand-rolled with_* conveniences (NavigationMenu#with_link) are
          # part of the consumer call surface even though they are not
          # registered slots: every own with_* method that is neither a
          # slot-generated setter (with_<name>/<singular>/<type> and their
          # _content twins) nor inherited.
          def slot_extras
            generated = slot_definitions.flat_map do |slot|
              names = [slot[:name].to_s]
              names << slot[:name].to_s.delete_suffix("s") if slot[:many]
              names.concat((slot[:types] || []).map(&:to_s))
              names
            end
            public_instance_methods(false).map(&:to_s)
                                          .select { |method| method.start_with?("with_") }
                                          .reject { |method| method.end_with?("_content") }
                                          .map { |method| method.delete_prefix("with_") }
                                          .sort - generated
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
