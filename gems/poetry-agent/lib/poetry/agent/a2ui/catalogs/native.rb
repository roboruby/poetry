# frozen_string_literal: true

require_relative "../pointer"
require_relative "../catalog"

module Poetry
  module Agent
    module A2UI
      module Catalogs
        # Poetry's own catalog (the {Catalog} projection) rendered back
        # through the registry: a component name resolves to its registry
        # entry, style axes and options become constructor keywords, slot
        # properties drive the generated slot setters, `text` is the
        # content block, `children` and `child` nest, and a bound `value`
        # names the control for the surface form. The registry is the one
        # source: whatever it declares renders, nothing is hand-mapped.
        class Native
          # The bound options an input component may carry.
          BOUND_OPTIONS = %w[value checked values].freeze
          # Registry option types by bound kind.
          KINDS = { "boolean" => :boolean, "checked_state" => :boolean, "integer" => :number, "number" => :number,
                    "float" => :number, "list" => :string_list }.freeze

          # @return [String]
          attr_reader :id

          # @param entries [Hash{String => Hash}, nil] registry entries by path
          #   (the poetry-ui registry when nil)
          # @param id [String] the catalog id this binding answers to
          def initialize(entries: nil, id: Catalog::DEFAULT_ID)
            @entries = entries
            @id = id
          end

          # @return [Hash{String => Hash}] registry entries by path
          def entries
            @entries ||= Catalog.load_entries
          end

          # @return [Hash{String => Array(String, Hash)}] `[path, entry]` by component name
          def by_name
            @by_name ||= entries.to_h { |path, entry| [Catalog.component_name(path), [path, entry]] }
          end

          # The child references: `child`, `children`, and every slot property.
          #
          # @param component [Hash]
          # @return [Array<Object>]
          def references(component)
            _path, entry = lookup(component)
            references = [component["child"], component["children"]]
            Array(entry && entry["slots"]).each { |slot| references << component[slot["name"]] }
            references.compact
          end

          # @param component [Hash]
          # @param scope [String, nil]
          # @return [Array<Hash>] `{ path:, kind: }` for each bound option
          def inputs(component, scope)
            _path, entry = lookup(component)
            return [] unless entry

            BOUND_OPTIONS.filter_map do |name|
              value = component[name]
              next unless value.is_a?(Hash) && value["path"].is_a?(String)

              option = Array(entry["options"]).find { |candidate| candidate["name"] == name }
              next unless option

              { path: Pointer.absolute(value["path"], scope), kind: KINDS.fetch(option["type"].to_s, :string) }
            end
          end

          # @param component [Hash]
          # @param scope [String, nil]
          # @param renderer [Renderer]
          # @return [String] HTML
          def render(component, scope, renderer)
            _path, entry = lookup(component)
            return renderer.warn("unknown component #{component["component"].inspect}") unless entry

            klass = Object.const_get(entry["class_name"])
            renderer.component(klass, attributes(component, entry, scope, renderer)) do |instance|
              fill_slots(instance, component, entry, scope, renderer)
              content(component, scope, renderer)
            end
          end

          private

          def lookup(component)
            by_name[component["component"].to_s] || [nil, nil]
          end

          def attributes(component, entry, scope, renderer)
            attributes = {}
            Array(entry["styles"]).each do |axis|
              value = component[axis["name"]]
              attributes[axis["name"].to_sym] = value.to_sym if value.is_a?(String)
            end
            option_names = Array(entry["options"]).map { |option| option["name"] }
            option_names.each do |name|
              next if Catalog.skipped_option?(name) || !component.key?(name)

              attributes[name.to_sym] = renderer.resolve(component[name], scope)
            end
            bound = BOUND_OPTIONS.find { |name| renderer.surface.binding?(component[name]) }
            if bound && option_names.include?("name") && !component.key?("name")
              attributes[:name] = renderer.input_name(component[bound]["path"], scope)
            end
            label = renderer.aria_label(component, scope)
            attributes[:aria] = { label: label } if label
            attributes.merge!(action_attributes(component, scope, renderer)) if component["action"].is_a?(Hash)
            attributes
          end

          def action_attributes(component, scope, renderer)
            action = component["action"]
            return renderer.submit_attributes(component, scope) if action["event"].is_a?(Hash)

            call = action["functionCall"]
            url = call.is_a?(Hash) && call["call"] == "openUrl" ? renderer.text(call.dig("args", "url"), scope) : ""
            return { href: url } if url.match?(%r{\Ahttps?://}) && !url.include?("${")

            renderer.warn("#{component["component"]} #{component["id"].inspect}: unsupported local action")
            { type: :button, disabled: true }
          end

          # A slot property holds one id (renders_one) or ids (renders_many).
          # A positional setter (Tabs' `with_tab(title, value:)`) takes the
          # child's `text` as its title and the child's children as its panel.
          def fill_slots(instance, component, entry, scope, renderer)
            Array(entry["slots"]).each do |slot|
              target = component[slot["name"]]
              next if target.nil?

              setter = slot["many"] ? "with_#{slot["name"].singularize}" : "with_#{slot["name"]}"
              positional = slot["setter_args"].is_a?(Hash) ? slot["setter_args"].values.first.to_i : 0
              renderer.surface.expand(target, scope).each do |child_id, child_scope|
                if positional.positive?
                  child = renderer.surface.component(child_id) || {}
                  title = renderer.text(child["text"], child_scope)
                  instance.public_send(setter, title, value: child_id) do
                    renderer.render_children(child["children"] || child["child"], child_scope)
                  end
                else
                  instance.public_send(setter) { renderer.render_component(child_id, child_scope) }
                end
              end
            end
          end

          def content(component, scope, renderer)
            if component.key?("text")
              renderer.view.safe_join([renderer.text(component["text"], scope)])
            elsif component.key?("children")
              renderer.render_children(component["children"], scope)
            elsif component.key?("child")
              renderer.render_children(component["child"], scope)
            end
          end
        end
      end
    end
  end
end
