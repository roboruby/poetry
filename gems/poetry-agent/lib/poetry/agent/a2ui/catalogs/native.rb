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

          # The catalog id this binding answers to.
          # @return [String]
          attr_reader :id
          # The protocol version the catalog is built for.
          # @return [Dialect]
          attr_reader :dialect

          # A native binding over registry entries, answering to a catalog id.
          # @param entries [Hash{String => Hash}, nil] registry entries by path
          #   (the poetry-ui registry when nil)
          # @param id [String] the catalog id this binding answers to
          # @param dialect [Dialect] the protocol version the catalog is built for
          def initialize(entries: nil, id: Catalog::DEFAULT_ID, dialect: Dialect::V1_0)
            @entries = entries
            @id = id
            @dialect = dialect
          end

          # The function set Poetry's catalog declares: the basic one.
          # @return [Functions] the function set Poetry's catalog declares (the basic one)
          def functions
            Functions.basic
          end

          # The catalog document the binding renders, Poetry's catalog in the
          # binding's version (strict validation reads it).
          # @return [Hash]
          def document
            @document ||= Catalog.new(entries: entries, catalog_id: id, v0_9_id: id).to_h(version: dialect.version)
          end

          # The registry entries by path, loaded on first use.
          # @return [Hash{String => Hash}] registry entries by path
          def entries
            @entries ||= Catalog.load_entries
          end

          # The path and entry of every component, by component name.
          # @return [Hash{String => Array(String, Hash)}] `[path, entry]` by component name
          def by_name
            @by_name ||= entries.to_h { |path, entry| [Catalog.component_name(path), [path, entry]] }
          end

          # The child references: `child`, `children`, and every slot property.
          #
          # @param component [Hash]
          # @return [Array<Object>]
          def references(component)
            reference_fields(component).map(&:last)
          end

          # The child references with the field each sits in, for what names a reference in a message.
          # @param component [Hash]
          # @return [Array<Array(String, Object)>]
          def reference_fields(component)
            _path, entry = lookup(component)
            names = %w[child children] + Array(entry && entry["slots"]).map { |slot| slot["name"] }
            names.filter_map { |name| [name, component[name]] unless component[name].nil? }
          end

          # The bound inputs of a component: each bound option's path with its kind.
          # @param component [Hash]
          # @param scope [String, nil]
          # @param dialect [Dialect] the surface's protocol version
          # @return [Array<Hash>] `{ path:, kind: }` for each bound option
          def inputs(component, scope, dialect)
            _path, entry = lookup(component)
            return [] unless entry

            BOUND_OPTIONS.filter_map do |name|
              path = dialect.path(component[name]) or next

              option = Array(entry["options"]).find { |candidate| candidate["name"] == name }
              next unless option

              { path: Pointer.absolute(path, scope), kind: KINDS.fetch(option["type"].to_s, :string) }
            end
          end

          # Renders a native component through its Poetry class, filling its slots and content.
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

          # A component's path and registry entry, or a nil pair.
          def lookup(component)
            by_name[component["component"].to_s] || [nil, nil]
          end

          # Whether an entry marks an option required.
          def option_required?(entry, name)
            Array(entry["options"]).any? { |option| option["name"] == name && option["required"] }
          end

          # The component's Poetry attributes: its styles as symbols, its resolved options, and any action.
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
            # An id the component requires (Field: the control its label
            # names) is not the agent's to set, so the render-stable key
            # stands in and the component builds instead of vanishing.
            attributes[:id] = renderer.stable_key if option_required?(entry, "id") && !attributes.key?(:id)
            bound = BOUND_OPTIONS.find { |name| renderer.surface.binding?(component[name]) }
            if bound && option_names.include?("name") && !component.key?("name")
              attributes[:name] = renderer.input_name(renderer.surface.binding_path(component[bound]), scope)
            end
            aria = renderer.aria(component, scope)
            attributes[:aria] = aria if aria.any?
            attributes.merge!(action_attributes(component, scope, renderer)) if component["action"].is_a?(Hash)
            if bound || component["action"]
              attributes[:data] = (attributes[:data] || {}).merge(a2ui_key: renderer.current_key)
            end
            attributes
          end

          # The attributes for a component's action: a submit, a link for openUrl, or nothing.
          def action_attributes(component, scope, renderer)
            action = component["action"]
            if renderer.surface.event_of(component)
              if renderer.surface.shorthand?(action)
                renderer.warn("#{component["component"]} #{component["id"].inspect}: an action without `event` " \
                              "(the v0.9 docs' shorthand) is read as one")
              end
              return renderer.submit_attributes(component, scope)
            end

            call = action["functionCall"]
            if renderer.surface.dialect.call_name(call) == "openUrl"
              url = renderer.link_target(call, scope)
              return { href: url } if url
            else
              renderer.warn("#{component["component"]} #{component["id"].inspect}: unsupported local action")
            end
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

          # A component's content: its text, its children, or its child.
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
