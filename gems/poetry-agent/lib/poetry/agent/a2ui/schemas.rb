# frozen_string_literal: true

require "json"
require_relative "dialect"
require_relative "pointer"
require_relative "schema"

module Poetry
  module Agent
    module A2UI
      # The schema half of strict validation: the A2UI specification's own
      # schemas (each protocol version's message schema, its common types and
      # its basic catalog, shipped unmodified under `schemas/` with their
      # Apache-2.0 LICENSE) with a surface's catalogs plugged in where the
      # message schema says `catalog.json`.
      #
      # A catalog plugs in as the specification's own test runner plugs one:
      # its `$id` moves beside the common types so its relative references
      # resolve, a `#/$defs/X` it does not define points at the common types,
      # and the `anyComponent` and `anyFunction` unions are built from its
      # `components` and `functions` when it states none. A catalog entry
      # closed with `additionalProperties: false` is opened to the envelope
      # keys (`id`, `component`, `catalogId`, ...), which the SDKs strip before
      # they apply an entry. On v1.0, where a component or call may name its
      # own catalog, `catalog.json` dispatches on `catalogId`: none is the
      # surface's default, a held catalog is that catalog, and one the
      # session does not hold passes here and is refused as a catalog error.
      module Schemas
        # Where the shipped schemas live, in the specification's layout.
        ROOT = File.expand_path("schemas", __dir__)

        # Per protocol version: its schemas' directory, the URI they live
        # under, its incoming message schema and its basic catalog.
        SPECS = {
          "v0.9" => { dir: "specification/v0_9/json", base: "https://a2ui.org/specification/v0_9/",
                      message: "server_to_client.json", basic: "specification/v0_9/catalogs/basic/catalog.json" },
          "v0.9.1" => { dir: "specification/v0_9_1/json", base: "https://a2ui.org/specification/v0_9/",
                        message: "server_to_client.json", basic: "specification/v0_9_1/catalogs/basic/catalog.json" },
          "1.0" => { dir: "specification/v1_0/json", base: "https://a2ui.org/specification/v1_0/",
                     message: "agent_to_renderer.json", basic: "catalogs/basic/v1/catalog.json" }
        }.freeze

        # What a catalog that has no document, or a catalog id the session
        # does not hold, admits: any object, every property evaluated.
        OPEN = { "type" => "object", "additionalProperties" => true }.freeze

        # The same for a function call, leaving `@index` to the system function's own schema.
        OPEN_FUNCTION = OPEN.merge("not" => { "properties" => { "@call" => { "const" => "@index" } },
                                              "required" => ["@call"] }).freeze

        # The keys a component's envelope carries beside its catalog entry's
        # own, per version (the common types' `ComponentCommon`, and `component`).
        COMPONENT_ENVELOPE = { false => %w[id component accessibility],
                               true => %w[id component catalogId accessibility metadata] }.freeze

        # The keys a function call's envelope carries beside its catalog entry's own.
        FUNCTION_ENVELOPE = { false => %w[call returnType], true => %w[@call catalogId] }.freeze

        # Keywords whose values are data, never schemas to walk.
        DATA_KEYWORDS = %w[const enum default examples].freeze

        module_function

        # The specification's documents for a version, by URI: its message
        # schema and its common types.
        # @param dialect [Dialect]
        # @return [Hash{String => Hash}]
        def documents(dialect)
          (@documents ||= {})[dialect.version] ||= begin
            spec = SPECS.fetch(dialect.version)
            [spec[:message], "common_types.json"].to_h do |file|
              document = load(File.join(spec[:dir], file))
              [document["$id"] || "#{spec[:base]}#{file}", document]
            end.freeze
          end
        end

        # The basic catalog's document for a version, as the specification publishes it.
        # @param dialect [Dialect]
        # @return [Hash]
        def basic_catalog(dialect)
          (@basic ||= {})[dialect.version] ||= load(SPECS.fetch(dialect.version)[:basic])
        end

        # A catalog document as the message schema consumes it, under a new URI.
        # @param document [Hash] the catalog as published
        # @param dialect [Dialect]
        # @param uri [String] where it is registered, beside the common types
        # @return [Hash] a plugged copy (the document is not changed)
        def plug(document, dialect, uri)
          catalog = JSON.parse(JSON.generate(document))
          catalog["$id"] = uri
          defs = (catalog["$defs"] = catalog["$defs"].is_a?(Hash) ? catalog["$defs"] : {})
          common = documents(dialect).values.find { |doc| doc["$id"].to_s.end_with?("common_types.json") }
          retarget(catalog, defs.keys, common.fetch("$defs", {}).keys)
          components = catalog["components"].is_a?(Hash) ? catalog["components"] : {}
          functions = catalog["functions"].is_a?(Hash) ? catalog["functions"] : {}
          components.each_value { |entry| open_entry(entry, COMPONENT_ENVELOPE.fetch(dialect.v1?)) }
          functions.each_value { |entry| open_entry(entry, FUNCTION_ENVELOPE.fetch(dialect.v1?)) }
          defs["anyComponent"] ||= union(components, "components", "component")
          defs["anyFunction"] ||= union(functions, "functions", dialect.call_key)
          defs["theme"] ||= catalog.delete("theme") || OPEN unless dialect.v1?
          catalog
        end

        # The `catalog.json` a v1.0 surface's messages validate against: each
        # union dispatches on `catalogId` to the catalog it names.
        # @param base [String] the URI the version's schemas live under
        # @param default [String, nil] the URI of the surface's default catalog
        # @param named [Hash{String => String, nil}] catalog id => its URI (nil: no document)
        # @return [Hash]
        def dispatcher(base, default, named)
          defs = { "anyComponent" => OPEN, "anyFunction" => OPEN_FUNCTION }.to_h do |name, open|
            chain = named.reverse_each.reduce(open) do |rest, (id, uri)|
              { "if" => { "properties" => { "catalogId" => { "const" => id } } },
                "then" => uri ? { "$ref" => "#{uri}#/$defs/#{name}" } : open, "else" => rest }
            end
            [name, { "if" => { "required" => ["catalogId"] }, "then" => chain,
                     "else" => default ? { "$ref" => "#{default}#/$defs/#{name}" } : open }]
          end
          { "$schema" => Schema::DIALECT, "$id" => "#{base}catalog.json", "$defs" => defs }
        end

        # A shipped document, parsed and frozen.
        # @api private
        def load(path)
          deep_freeze(JSON.parse(File.read(File.join(ROOT, path))))
        end

        # Points each `#/$defs/X` a catalog does not define at the common types.
        # @api private
        def retarget(node, own, common)
          case node
          when Hash
            ref = node["$ref"]
            name = ref.is_a?(String) ? ref[%r{\A#/\$defs/([^/]+)\z}, 1] : nil
            node["$ref"] = "common_types.json#/$defs/#{name}" if name && !own.include?(name) && common.include?(name)
            node.each { |key, value| retarget(value, own, common) unless DATA_KEYWORDS.include?(key) }
          when Array then node.each { |value| retarget(value, own, common) }
          end
        end

        # Lets a closed entry, or a closed part of its `allOf`, admit the envelope keys.
        # @api private
        def open_entry(entry, keys)
          return unless entry.is_a?(Hash)

          [entry, *Array(entry["allOf"])].grep(Hash).each do |part|
            next unless part["additionalProperties"] == false

            properties = (part["properties"] ||= {})
            keys.each { |key| properties[key] ||= true }
          end
        end

        # A union of a catalog's entries, each branch pinned to its name as the SDKs pin them.
        # @api private
        def union(entries, section, key)
          return { "not" => {} } if entries.empty?

          { "oneOf" => entries.keys.map do |name|
            { "allOf" => [{ "$ref" => "##{Pointer.build([section, name])}" },
                          { "properties" => { key => { "const" => name } }, "required" => [key] }] }
          end }
        end

        # Freezes a parsed document all the way down.
        # @api private
        def deep_freeze(value)
          case value
          when Hash then value.each_value { |item| deep_freeze(item) }
          when Array then value.each { |item| deep_freeze(item) }
          end
          value.freeze
        end

        private_class_method :load, :retarget, :open_entry, :union, :deep_freeze

        # A version's message schema with one surface's catalogs plugged in,
        # compiled once and shared by every message on surfaces like it.
        class Validator
          # Keywords whose failure only says no branch matched; the branch's own problems say why.
          UNIONS = %w[oneOf anyOf].freeze
          # How many of a component's problems one message names.
          MAX_DETAILS = 3

          # A validator for a version, a default catalog and the other catalogs of the version.
          # @param dialect [Dialect]
          # @param default [String, nil] the surface's default catalog id
          # @param catalogs [Hash{String => Hash, nil}] catalog id => its document (nil when it has none)
          def initialize(dialect, default:, catalogs:)
            @dialect = dialect
            spec = SPECS.fetch(dialect.version)
            documents = Schemas.documents(dialect).dup
            if dialect.v1?
              named = catalogs.each_with_index.to_h do |(id, document), index|
                uri = document && "#{spec[:base]}plugged_catalog_#{index}.json"
                documents[uri] = Schemas.plug(document, dialect, uri) if uri
                [id, uri]
              end
              documents["#{spec[:base]}catalog.json"] = Schemas.dispatcher(spec[:base], named[default], named)
            else
              uri = "#{spec[:base]}catalog.json"
              document = catalogs[default]
              documents[uri] = document ? Schemas.plug(document, dialect, uri) : open_catalog(uri)
            end
            @schema = Schema.compile(documents).schema("#{spec[:base]}#{spec[:message]}")
          end

          # The first schema problem of an incoming message, worded as the
          # spec's processors word it, or nil when it is valid.
          # @param message [Hash] the whole message, its version included
          # @param outside [String, nil] a pointer whose items are judged
          #   elsewhere (a message's components, which the update checks)
          # @return [Hash, nil] `{ code:, path:, message: }`
          def problem(message, outside: nil)
            instance = @dialect.v1? ? message.merge("version" => @dialect.version) : message
            problems = @schema.errors(instance)
            return if problems.empty?

            leaves = problems.reject { |found| UNIONS.include?(found.keyword) }
            candidates = leaves.empty? ? [problems.reverse.max_by { |union| union.pointer.count("/") }] : leaves
            candidates = candidates.reject { |candidate| candidate.pointer.start_with?("#{outside}/") } if outside
            found = candidates.first or return
            { code: "VALIDATION_FAILED", path: found.pointer, message: describe(found, leaves, message) }
          rescue Schema::LimitError => e
            { code: "RECURSION_ERROR", path: nil, message: "Validation failed: #{e.message}" }
          end

          private

          # A catalog with no document: any component, any call, any theme.
          def open_catalog(uri)
            { "$schema" => Schema::DIALECT, "$id" => uri,
              "$defs" => { "anyComponent" => OPEN, "anyFunction" => OPEN_FUNCTION, "theme" => OPEN } }
          end

          # The problem named by what it belongs to (a component, a theme, or the
          # message), with the component's next few problems beside it.
          def describe(found, leaves, message)
            key, *rest = found.pointer.delete_prefix("/").split("/")
            body = key && message[key].is_a?(Hash) ? message[key] : {}
            if rest[0] == "components" && rest[1]&.match?(/\A\d+\z/) && body["components"].is_a?(Array)
              prefix = "/#{key}/components/#{rest[1]}"
              component = body["components"][rest[1].to_i]
              component = {} unless component.is_a?(Hash)
              within = ([found] + leaves).uniq.select do |leaf|
                leaf.pointer == prefix || leaf.pointer.start_with?("#{prefix}/")
              end
              details = within.first(MAX_DETAILS).map do |leaf|
                Schema::Problem.new(pointer: leaf.pointer.delete_prefix(prefix), keyword: leaf.keyword,
                                    detail: leaf.detail)
              end
              return "Validation failed for component '#{component["component"]}' (#{component["id"]}): " \
                     "#{details.join("; ")}"
            end
            return "Validation failed for theme on surface '#{body["surfaceId"]}': #{found}" if rest[0] == "theme"

            "Validation failed for message: #{found}"
          end
        end
      end
    end
  end
end
