# frozen_string_literal: true

require "json"
require "yaml"

module Poetry
  module Agent
    module A2UI
      # Projects the component registry into an A2UI v1.0 catalog: one
      # JSON Schema component per registry entry (the discriminator
      # `component: { const: Name }`, style axes as enums, options as typed
      # properties, slots as child references, the content block as `text`
      # or `children`, Button's `action`), the catalog's composition
      # instructions, and the `$defs` the envelope schema references. The
      # document obeys the v1.0 catalog rules: the allowed top-level keys
      # only, `$defs` holding exactly `anyComponent` and `anyFunction`,
      # external refs into `common_types.json` only.
      #
      # @example The docs site's catalog
      #   catalog = Poetry::Agent::A2UI::Catalog.from_registry(Poetry::Ui.root)
      #   catalog.to_h["components"].keys.first(3) # => ["Accordion", "ActionBar", "Alert"]
      #   catalog.inline                            # => { "catalogId" => ..., "components" => {...} }
      class Catalog
        # The default catalog id (a versioned, conventionally URI-shaped
        # string identifier - it does not need to resolve).
        DEFAULT_ID = "https://poetryui.com/a2ui/v1_0/catalog.json"

        # Component and property names must be UAX #31 identifiers.
        NAME_PATTERN = /\A[\p{XID_Start}_]\p{XID_Continue}*\z/u

        # Options an agent never sets: styling escape hatches, the envelope's
        # own `id`, and the universal wiring keywords.
        SKIPPED_OPTIONS = %w[class id data aria key webmcp].freeze

        # Option names whose values bind to the data model (`{path}`).
        DYNAMIC_STRINGS = %w[value placeholder label text title description].freeze

        # Option names whose boolean values bind to the data model.
        DYNAMIC_BOOLEANS = %w[checked].freeze

        # The catalog-level guidance every generation reads.
        DEFAULT_INSTRUCTIONS = <<~TEXT.strip
          Poetry components, rendered on the server. Compose a surface as a flat list of components referenced by id:
          exactly one component has the id "root" (a layout or container such as Card, Box, or Stack). Put visible
          text in a component's `text` property; put child components in `children` (an array of component ids) or a
          slot property (one component id). Style axes are enums - pick by intent, never by color. Each component's
          description carries its rules; they are binding.
        TEXT

        # @return [String]
        attr_reader :catalog_id

        # Builds the catalog from a registry root (the directory holding
        # `config/component_registry.yml`), or from the bundled poetry-ui
        # registry when no root is given.
        #
        # Keyword arguments pass through to {#initialize} (`catalog_id:`,
        # `title:`, `description:`, `instructions:`, `exclude:`).
        #
        # @param root [String, Pathname, nil]
        # @return [Catalog]
        # @raise [ArgumentError] when no registry is found
        def self.from_registry(root = nil, **)
          root ||= Gem::Specification.find_all_by_name("poetry-ui").first&.gem_dir
          path = root && File.join(root.to_s, Poetry::Core::Registry::RELATIVE_PATH)
          raise ArgumentError, "no component registry at #{path || "(no root)"}" unless path && File.exist?(path)

          entries = YAML.safe_load_file(path, permitted_classes: [Symbol], aliases: true).fetch("components")
          new(entries: entries, **)
        end

        # @param entries [Hash{String => Hash}] registry entries by path
        # @param catalog_id [String]
        # @param title [String]
        # @param description [String]
        # @param instructions [String] catalog-level guidance for the model
        # @param exclude [Array<String>] registry paths to leave out
        def initialize(entries:, catalog_id: DEFAULT_ID, title: "Poetry UI Catalog",
                       description: "Poetry's component library as an A2UI catalog, projected from its registry.",
                       instructions: DEFAULT_INSTRUCTIONS, exclude: [])
          @entries = entries.except(*exclude)
          @catalog_id = catalog_id
          @title = title
          @description = description
          @instructions = instructions
        end

        # The catalog document (JSON Schema, string keys, components sorted
        # by name).
        #
        # @return [Hash]
        def to_h
          @to_h ||= {
            "$schema" => "https://json-schema.org/draft/2020-12/schema",
            "$id" => @catalog_id,
            "protocolVersion" => PROTOCOL_VERSION,
            "title" => @title,
            "description" => @description,
            "catalogId" => @catalog_id,
            "instructions" => @instructions,
            "components" => components,
            "functions" => {},
            "$defs" => {
              "anyComponent" => {
                "oneOf" => components.keys.map { |name| { "$ref" => "#/components/#{name}" } },
                "discriminator" => { "propertyName" => "component" }
              },
              "anyFunction" => { "not" => {} }
            }
          }
        end

        # The inline form a transport ships to an agent or a middleware
        # fetches at boot.
        #
        # @return [Hash] `{ "catalogId", "components" }`
        def inline
          { "catalogId" => @catalog_id, "components" => components }
        end

        # @return [String] the document as JSON
        def to_json(*)
          JSON.pretty_generate(to_h)
        end

        # The component schemas by name.
        #
        # @return [Hash{String => Hash}]
        def components
          @components ||= @entries.map { |path, entry| [component_name(path), component_schema(path, entry)] }
                                  .sort_by(&:first).to_h
        end

        # The A2UI component name of a registry path (`poetry/ui/alert_dialog`
        # becomes `AlertDialog`).
        #
        # @param path [String]
        # @return [String]
        def component_name(path)
          path.split("/").last.split("_").map(&:capitalize).join
        end

        private

        def component_schema(path, entry)
          properties = { "component" => { "const" => component_name(path) } }
          entry.fetch("styles", []).each { |axis| properties[axis["name"]] = enum_schema(axis) }
          entry.fetch("options", []).each do |option|
            next if skipped_option?(option["name"])

            properties[option["name"]] = option_schema(option)
          end
          entry.fetch("slots", []).each do |slot|
            properties[slot["name"]] =
              slot["many"] ? child_list(slot["description"]) : component_id(slot["description"])
          end
          content = content_bearing?(entry)
          if content
            properties["text"] = dynamic("DynamicString", "The content block as text (Markdown is not interpreted).")
            properties["children"] = child_list("Component ids rendered as the content block, in order.")
          end
          if actionable?(path)
            properties["action"] =
              { "$ref" => "#{COMMON_TYPES}Action", "description" => "What the press does." }
          end

          schema = { "type" => "object", "description" => description_of(entry), "properties" => properties,
                     "required" => ["component"] }
          if content && entry["requires_content"]
            schema["anyOf"] =
              [{ "required" => ["text"] }, { "required" => ["children"] }]
          end
          schema
        end

        def enum_schema(axis)
          schema = { "type" => "string", "enum" => Array(axis["variants"]).map(&:to_s) }
          schema["default"] = axis["default"].to_s if axis.key?("default") && !axis["default"].nil?
          schema["description"] = axis["description"].to_s if axis["description"]
          schema
        end

        def option_schema(option)
          name = option["name"].to_s
          schema =
            if DYNAMIC_STRINGS.include?(name) then dynamic("DynamicString", option["description"])
            elsif DYNAMIC_BOOLEANS.include?(name) then dynamic("DynamicBoolean", option["description"])
            elsif option["variants"] then enum_schema(option)
            else typed(option["type"].to_s, option["description"])
            end
          if option.key?("default") && !option["default"].nil? && !schema.key?("$ref") && !schema.key?("default")
            schema["default"] = option["default"].is_a?(Symbol) ? option["default"].to_s : option["default"]
          end
          schema
        end

        def typed(type, description)
          schema = case type
                   when "boolean" then { "type" => "boolean" }
                   when "integer" then { "type" => "integer" }
                   when "number", "float" then { "type" => "number" }
                   when "list", "array" then { "type" => "array", "items" => { "type" => "string" } }
                   when "hash" then { "type" => "object" }
                   else { "type" => "string" }
                   end
          schema["description"] = description.to_s if description
          schema
        end

        def dynamic(kind, description)
          schema = { "$ref" => "#{COMMON_TYPES}#{kind}" }
          schema["description"] = description.to_s if description
          schema
        end

        def component_id(description)
          { "$ref" => "#{COMMON_TYPES}ComponentId",
            "description" => "The id of the component rendered here. #{description}".strip }
        end

        def child_list(description)
          { "$ref" => "#{COMMON_TYPES}ChildList", "description" => description.to_s }
        end

        def skipped_option?(name)
          name = name.to_s
          SKIPPED_OPTIONS.include?(name) || name.end_with?("_class")
        end

        # A component takes a content block when the registry says one is
        # required, when its requires_any group names content, or when its
        # element roster has a content cell.
        def content_bearing?(entry)
          return true if entry["requires_content"]
          return true if Array(entry["requires_any"]).any? { |group| group["content"] }

          Array(entry["elements"]).include?("content")
        end

        def actionable?(path)
          path.end_with?("/button")
        end

        def description_of(entry)
          rules = Array(entry["agent_rules"])
          text = entry["description"].to_s
          text = "#{text} Rules: #{rules.join(" ")}" if rules.any?
          text.length > 1500 ? "#{text[0, 1497]}..." : text
        end
      end
    end
  end
end
