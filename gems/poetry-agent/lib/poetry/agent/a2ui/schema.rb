# frozen_string_literal: true

require "date"
require "uri"

module Poetry
  module Agent
    module A2UI
      # JSON Schema 2020-12 validation for the subset the A2UI specification's
      # message schemas, common types and catalogs use, with nothing beyond
      # the standard library. It is the strict tier's schema half: the
      # message envelope, each component against its catalog entry, each
      # function call against its catalog function.
      #
      # Documents are given by URI ({.compile} indexes them); a root and
      # everything it reaches compile once, at construction, so a schema the
      # interpreter cannot honour raises there ({Unsupported}, {UnknownRef})
      # and never halfway through a message. Validation only reads the
      # compiled nodes, so one {Schema} serves every instance, from any
      # thread. Several roots over the same documents share one {Compiler}
      # ({.compile}, then {Compiler#schema}).
      #
      # A node evaluates an instance in one pass and answers with the
      # property names it evaluated, which flow through `$ref`, `allOf`, the
      # passing `anyOf`/`oneOf` branches and `if`/`then`/`else` to the
      # `unevaluatedProperties` that closes an object. {#valid?} stops at
      # the first failing keyword; {#errors} walks on, and explains a failed
      # `oneOf` or `anyOf` through the branch the instance most likely meant.
      #
      # Two shortcuts keep the walk linear on A2UI's nested function calls:
      # a `oneOf` whose branches all require one property with distinct
      # string constants evaluates only the branch the instance names (the
      # catalog unions, `FunctionCall`), and a branch whose `type` excludes
      # the instance's JSON type is skipped as failed. Detection falls back
      # to evaluating every branch whenever it cannot prove the shortcut.
      #
      # Unknown keywords are annotations, as 2020-12 requires; a 2020-12
      # keyword the interpreter does not implement, another draft, an
      # embedded `$id` resource or a pattern whose meaning would differ from
      # ECMA-262 is refused at compile time. A walk nested deeper than
      # {MAX_DEPTH} raises {LimitError} instead of exhausting the stack.
      #
      # @example
      #   uri = "https://a2ui.org/specification/v1_0/agent_to_renderer.json"
      #   schema = Poetry::Agent::A2UI::Schema.new(documents: { uri => doc, ... }, root: uri)
      #   schema.valid?(message) # => true or false
      #   schema.errors(message) # => [] or [Schema::Problem, ...]
      #
      #   compiler = Poetry::Agent::A2UI::Schema.compile(documents) # several roots, one compilation
      #   component = compiler.schema("#{uri}#/$defs/Component")
      class Schema
        # Anything this validator refuses.
        class Error < StandardError; end

        # A schema outside the supported subset: another draft, an
        # unimplemented keyword, an embedded `$id`, a malformed keyword value,
        # or a pattern that would not mean what ECMA-262 says it means.
        class Unsupported < Error; end

        # A `$ref`, `$dynamicRef` or root that no document resolves.
        class UnknownRef < Error; end

        # A walk nested deeper than {MAX_DEPTH}.
        class LimitError < Error; end

        # One reason an instance fails: the JSON Pointer to the value, the
        # keyword that failed and what it expected.
        #
        # @example
        #   problem.to_s # => "/components/0/variant enum: expected one of \"h1\", \"h2\""
        Problem = Data.define(:pointer, :keyword, :detail) do
          # The problem as one line, "(root)" standing for the empty pointer.
          # @return [String]
          def to_s = "#{pointer.empty? ? "(root)" : pointer} #{keyword}: #{detail}"
        end

        # The draft every document and schema must be written in.
        DIALECT = "https://json-schema.org/draft/2020-12/schema"

        # How deep a walk may nest, counting every subschema it enters.
        MAX_DEPTH = 128

        # How long one pattern match may run, in seconds; a match that runs out fails.
        PATTERN_TIMEOUT = 0.05

        # 2020-12 (or older) keywords the interpreter does not implement: a schema using one is refused.
        UNSUPPORTED = %w[unevaluatedItems $recursiveRef $recursiveAnchor dependencies].freeze

        # The JSON types each `type` name accepts ("integer" is a whole number, so "number" takes it too).
        TYPES = {
          "object" => %w[object], "array" => %w[array], "string" => %w[string], "boolean" => %w[boolean],
          "null" => %w[null], "integer" => %w[integer], "number" => %w[integer number]
        }.freeze

        # The Unicode properties a pattern may name: the identifier classes A2UI's schemas use.
        PROPERTIES = %w[XID_Start XID_Continue].freeze

        # ECMA-262's white space and line terminators (its `\s`), as the body of a character class.
        SPACE = '\t\n\v\f\r\uFEFF\u2028\u2029\p{Zs}'

        # The value shape each keyword requires; a schema breaking one is refused.
        SHAPES = {
          "type" => ->(v) { v.is_a?(String) || (v.is_a?(Array) && v.all?(String)) },
          "required" => ->(v) { v.is_a?(Array) && v.all?(String) },
          "enum" => ->(v) { v.is_a?(Array) },
          "properties" => ->(v) { v.is_a?(Hash) },
          "patternProperties" => ->(v) { v.is_a?(Hash) },
          "dependentSchemas" => ->(v) { v.is_a?(Hash) },
          "dependentRequired" => ->(v) { v.is_a?(Hash) && v.each_value.all? { |n| n.is_a?(Array) && n.all?(String) } },
          "uniqueItems" => ->(v) { [true, false].include?(v) },
          "multipleOf" => ->(v) { v.is_a?(Numeric) && v.positive? },
          **%w[allOf anyOf oneOf prefixItems].to_h { |k| [k, ->(v) { v.is_a?(Array) && !v.empty? }] },
          **%w[$ref $dynamicRef pattern format].to_h { |k| [k, ->(v) { v.is_a?(String) }] },
          **%w[minimum maximum exclusiveMinimum exclusiveMaximum].to_h { |k| [k, ->(v) { v.is_a?(Numeric) }] },
          **%w[minLength maxLength minItems maxItems minProperties maxProperties minContains maxContains].to_h do |k|
            [k, ->(v) { v.is_a?(Numeric) && !v.negative? && (v % 1).zero? }]
          end
        }.freeze

        # Nothing evaluated (a frozen empty list, compared by identity).
        NONE = [].freeze
        # Every property evaluated (after an `unevaluatedProperties`).
        ALL = :all
        private_constant :NONE, :ALL

        # The documents indexed for compiling, shared by every root compiled from them.
        #
        # @param documents [Hash{String => Hash, Boolean}] parsed JSON documents by absolute URI; a
        #   document's own `$id` wins over its key, which still finds it
        # @return [Compiler]
        # @raise [Unsupported] for a document in another draft or holding an embedded `$id`
        def self.compile(documents) = Compiler.new(Registry.new(documents))

        # The JSON type of a parsed value ("integer" for a whole number, 1.0 included).
        # @param value [Object]
        # @return [String]
        # @api private
        def self.json_type(value)
          case value
          when Hash then "object"
          when Array then "array"
          when String then "string"
          when Integer then "integer"
          when Float then value.finite? && (value % 1).zero? ? "integer" : "number"
          when true, false then "boolean"
          when nil then "null"
          else raise ArgumentError, "not a JSON value: #{value.class}"
          end
        end

        # JSON equality: 1 equals 1.0, key order does not count, true is not 1.
        # @param left [Object]
        # @param right [Object]
        # @return [Boolean]
        # @api private
        def self.same?(left, right)
          case left
          when Hash
            right.is_a?(Hash) && left.size == right.size && left.all? { |k, v| right.key?(k) && same?(v, right[k]) }
          when Array
            right.is_a?(Array) && left.size == right.size && left.each_index.all? { |i| same?(left[i], right[i]) }
          when Integer, Float then right.is_a?(Numeric) && left == right
          else left == right
          end
        end

        # An ECMA-262 pattern as Ruby regexp source. `^` and `$` outside a
        # class become input anchors, `.` stops at every ECMA line terminator,
        # `\s` and `\S` take ECMA's white space, `\b` and `\B` ECMA's ASCII
        # word boundary. Anything that is not ECMA-262, or whose meaning
        # differs between the two (lookbehind, other Unicode properties, the
        # `v` flag's class syntax, `\cX`), is refused; `lenient` lets the
        # second kind through, for the `regex` format, which asks only whether
        # a string is a pattern.
        #
        # @param source [String]
        # @param lenient [Boolean]
        # @return [String]
        # @raise [Unsupported] naming the construct refused
        # @api private
        def self.translate(source, lenient: false) = Translation.new(source, lenient).run

        # Whether a string is an ECMA-262 pattern (the `regex` format).
        # @param string [String]
        # @return [Boolean]
        # @api private
        def self.regex?(string)
          Regexp.new(translate(string, lenient: true))
          true
        rescue Unsupported, RegexpError
          false
        end

        # A URI reference split into its RFC 3986 parts, or nil when it is not
        # one; white space in the opaque part or the query, which the split
        # lets through, makes it not one.
        # @param string [String]
        # @return [Array<String, nil>, nil]
        # @api private
        def self.uri_parts(string)
          parts = URI::RFC3986_PARSER.split(string)
          parts unless parts[6].to_s.match?(/\s/) || parts[7].to_s.match?(/\s/)
        rescue URI::InvalidURIError
          nil
        end

        # Whether a string is an absolute URI (one with a scheme).
        # @param string [String]
        # @return [Boolean]
        # @api private
        def self.uri?(string) = !uri_parts(string)&.first.nil?

        # Whether a string is a URI reference, relative or absolute.
        # @param string [String]
        # @return [Boolean]
        # @api private
        def self.uri_reference?(string) = !uri_parts(string).nil?

        # RFC 3339's date-time, its syntax first.
        DATE_TIME = /\A\d{4}-\d{2}-\d{2}[Tt\s]\d{2}:\d{2}:\d{2}(\.\d+)?([Zz]|[+-]\d{2}:\d{2})\z/

        # Whether a string is an RFC 3339 date-time; a leap second only at 23:59:60 UTC.
        # @param string [String]
        # @return [Boolean]
        # @api private
        def self.date_time?(string)
          return false unless DATE_TIME.match?(string) && !string.match?(/[Tt\s]24:/)

          parsed = DateTime.rfc3339(string.sub(/\A(.{10})[t\s]/, '\1T'))
          !string.match?(/[Tt\s]\d{2}:\d{2}:6/) || parsed.new_offset.strftime("%H:%M") == "23:59"
        rescue ArgumentError
          false
        end

        # The formats asserted, the ones A2UI's schemas and the meta-schemas
        # use; any other format is an annotation.
        FORMATS = {
          "uri" => method(:uri?), "uri-reference" => method(:uri_reference?), "date-time" => method(:date_time?),
          "date" => ->(s) { date_time?("#{s}T04:05:06.123456789+07:00") },
          "time" => ->(s) { date_time?("2001-02-03T#{s}") },
          "regex" => method(:regex?)
        }.freeze

        # The root URI this schema validates against, fragment included.
        # @return [String]
        attr_reader :root

        # A schema compiled from its root: everything the root reaches is
        # compiled now, so an unsupported keyword or an unresolvable reference
        # raises here.
        #
        # @param documents [Hash{String => Hash, Boolean}, Compiler] parsed JSON documents by absolute URI (see
        #   {.compile}), or a {Compiler} already holding them
        # @param root [String] an absolute URI, with or without a fragment (`...#/$defs/Component`)
        # @raise [Unsupported] for a schema outside the subset
        # @raise [UnknownRef] for a root or reference no document resolves
        def initialize(documents:, root:)
          @root = root.to_s
          @node = (documents.is_a?(Compiler) ? documents : Schema.compile(documents)).root(@root)
        end

        # Whether an instance validates.
        # @param instance [Object] a parsed JSON value
        # @return [Boolean]
        # @raise [LimitError] when the walk nests deeper than {MAX_DEPTH}
        def valid?(instance) = !@node.evaluate(instance, nil, nil, [@node.resource], 0).nil?

        # Why an instance fails, in walk order; empty exactly when it validates.
        # @param instance [Object] a parsed JSON value
        # @return [Array<Problem>]
        # @raise [LimitError] when the walk nests deeper than {MAX_DEPTH}
        def errors(instance)
          problems = []
          @node.evaluate(instance, problems, "", [@node.resource], 0)
          problems
        end

        # Documents by URI, their anchors and dynamic anchors, and how
        # references resolve against them.
        # @api private
        class Registry
          # Keywords holding one subschema.
          SUBSCHEMA = %w[not if then else items contains additionalProperties propertyNames unevaluatedProperties
                         contentSchema].freeze
          # Keywords holding subschemas by name.
          SUBSCHEMA_MAP = %w[$defs definitions properties patternProperties dependentSchemas].freeze
          # Keywords holding a list of subschemas.
          SUBSCHEMA_LIST = %w[allOf anyOf oneOf prefixItems].freeze
          # A catalog document's root maps of schemas, which its JSON Pointer refs reach.
          CATALOG_MAPS = %w[components functions].freeze

          # Every document indexed under its URI.
          # @param documents [Hash{String => Hash, Boolean}]
          # @raise [ArgumentError] for a document with no absolute URI, or two claiming one
          # @raise [Unsupported] for another draft or an embedded `$id`
          def initialize(documents)
            raise ArgumentError, "documents must be a Hash of URI => document" unless documents.is_a?(Hash)

            @docs = {}
            @anchors = {}
            @dynamic = {}
            @aliases = {}
            @joins = {}
            documents.each { |key, doc| add(key.to_s, doc) }
            @aliases.delete_if { |key, _| @docs.key?(key) } # a document's own URI wins over another's key
          end

          # The document at a URI (an alias resolved), or nil.
          # @param uri [String]
          # @return [Hash, Boolean, nil]
          def document(uri) = @docs[uri]

          # The schema a reference names against a base, and the URI of the resource holding it.
          # @param base [String]
          # @param ref [String]
          # @return [Array(Object, String)]
          # @raise [UnknownRef] when no document, pointer or anchor resolves it
          def resolve(base, ref)
            absolute = join(base, ref)
            uri, fragment = absolute.split("#", 2)
            uri = @aliases.fetch(uri, uri)
            doc = @docs.fetch(uri) { raise UnknownRef, "no document at #{uri} (resolving #{ref.inspect})" }
            fragment = fragment.to_s
            target =
              if fragment.empty? then doc
              elsif fragment.start_with?("/") then pointer(doc, fragment, absolute)
              else @anchors[uri].fetch(fragment) { raise UnknownRef, "no anchor #{fragment.inspect} in #{uri}" }
              end
            [target, uri]
          end

          # The schema a resource marks with a `$dynamicAnchor`, or nil.
          # @param uri [String]
          # @param name [String]
          # @return [Object, nil]
          def dynamic_anchor(uri, name) = @dynamic.fetch(uri)[name]

          # Every resource marking a schema with this `$dynamicAnchor`, and that schema.
          # @param name [String]
          # @yieldparam uri [String]
          # @yieldparam schema [Hash]
          # @return [void]
          def each_dynamic_anchor(name)
            @dynamic.each { |uri, anchors| yield uri, anchors[name] if anchors.key?(name) }
          end

          private

          # Indexes one document under its `$id` (resolved against its key) or its key.
          def add(key, doc)
            base = key.sub(/#.*\z/m, "")
            id = doc.is_a?(Hash) ? doc["$id"] : nil
            uri = (id.is_a?(String) ? join(base, id) : base).sub(/#.*\z/m, "")
            raise ArgumentError, "a document needs an absolute URI, got #{uri.inspect}" unless absolute?(uri)
            raise ArgumentError, "two documents claim #{uri}" if @docs.key?(uri)

            dialect = doc.is_a?(Hash) ? doc["$schema"] : nil
            if dialect && dialect.to_s.delete_suffix("#") != DIALECT
              raise Unsupported, "#{uri} is written in #{dialect}; only #{DIALECT} is supported"
            end

            @docs[uri] = doc
            @anchors[uri] = {}
            @dynamic[uri] = {}
            @aliases[base] = uri unless base == uri
            index(doc, uri)
          end

          # Whether a URI is absolute.
          def absolute?(uri)
            URI.parse(uri).absolute?
          rescue URI::Error
            false
          end

          # A reference made absolute against a base, memoized.
          def join(base, ref)
            @joins[[base, ref]] ||= ref.start_with?("#") ? "#{base}#{ref}" : URI.join(base, ref).to_s
          rescue URI::Error, ArgumentError => e
            raise UnknownRef, "cannot resolve #{ref.inspect} against #{base.inspect}: #{e.message}"
          end

          # The value a JSON Pointer fragment names in a document.
          def pointer(doc, fragment, absolute)
            fragment[1..].split("/", -1).reduce(doc) do |node, token|
              token = token.gsub(/(?:%\h\h)+/) { |m| [m.delete("%")].pack("H*").force_encoding(Encoding::UTF_8) }
              token = token.gsub("~1", "/").gsub("~0", "~")
              missing = -> { raise UnknownRef, "#{absolute} names nothing" }
              case node
              when Hash then node.fetch(token) { missing.call }
              when Array then node.fetch(Integer(token, 10, exception: false) || node.size) { missing.call }
              else missing.call
              end
            end
          end

          # Indexes `$anchor` and `$dynamicAnchor`, walking schema positions
          # only (a property named `$id` is data); an embedded `$id`, a
          # resource inside a resource, is refused.
          def index(doc, uri)
            queue = [[doc, true]]
            until queue.empty?
              node, root = queue.pop
              next unless node.is_a?(Hash)
              raise Unsupported, "embedded $id #{node["$id"].inspect} in #{uri}" if !root && node.key?("$id")

              @anchors[uri][node["$anchor"]] = node if node["$anchor"].is_a?(String)
              if node["$dynamicAnchor"].is_a?(String)
                @anchors[uri][node["$dynamicAnchor"]] = node
                @dynamic[uri][node["$dynamicAnchor"]] = node
              end
              node.each do |key, value|
                if SUBSCHEMA.include?(key) then queue << [value, false]
                elsif SUBSCHEMA_LIST.include?(key) && value.is_a?(Array) then value.each { |v| queue << [v, false] }
                elsif (SUBSCHEMA_MAP.include?(key) || (root && CATALOG_MAPS.include?(key))) && value.is_a?(Hash)
                  value.each_value { |v| queue << [v, false] }
                end
              end
            end
          end
        end

        # Compiles schemas into nodes, one per (schema object, resource), and
        # hands out {Schema}s by root. Compiling a root links everything it
        # reaches before the schema is returned; a root that fails to compile
        # leaves nothing behind. Safe to share between threads.
        class Compiler
          # The indexed documents.
          # @return [Registry]
          # @api private
          attr_reader :registry

          # A compiler over indexed documents ({Schema.compile} builds one).
          # @param registry [Registry]
          # @api private
          def initialize(registry)
            @registry = registry
            @nodes = {}.compare_by_identity
            @schemas = {}
            @pending = []
            @created = []
            @lock = Mutex.new
          end

          # The schema for a root URI, compiled on first request and memoized.
          # @param root [String] an absolute URI, with or without a fragment
          # @return [Schema]
          # @raise [Unsupported] for a schema outside the subset
          # @raise [UnknownRef] for a root or reference no document resolves
          def schema(root)
            @schemas.fetch(root) do
              built = Schema.new(documents: self, root: root)
              @lock.synchronize { @schemas[root] ||= built }
            end
          end

          # The node a root URI names, with everything it reaches compiled and linked.
          # @param uri [String]
          # @return [Node]
          # @api private
          def root(uri)
            @lock.synchronize do
              base, fragment = uri.split("#", 2)
              target, resource = @registry.resolve(base, "##{fragment}")
              node = node(target, resource)
              drain
              node
            rescue StandardError
              @created.each { |n| @nodes[n.schema].delete(n.resource) }
              raise
            ensure
              @pending.clear
              @created.clear
            end
          end

          # The node for a schema in a resource, created and queued for linking on first sight.
          # @param schema [Hash, Boolean]
          # @param resource [String]
          # @return [Node]
          # @api private
          def node(schema, resource)
            by_resource = (@nodes[schema] ||= {})
            by_resource.fetch(resource) do
              built = Node.new(self, schema, resource)
              @pending << built
              @created << built
              by_resource[resource] = built
            end
          end

          # A node compiled earlier, for the walk's `$dynamicRef` lookups (which never compile).
          # @param schema [Hash, Boolean]
          # @param resource [String]
          # @return [Node]
          # @api private
          def lookup(schema, resource) = @nodes.fetch(schema).fetch(resource)

          # Queues every schema marked with this `$dynamicAnchor`, whichever
          # resource the walk's dynamic scope turns out to start from.
          # @param name [String]
          # @return [void]
          # @api private
          def dynamic(name)
            @registry.each_dynamic_anchor(name) { |uri, schema| node(schema, uri) }
          end

          private

          # Links queued nodes until none is left, then precomputes what the walk consults.
          def drain
            while (n = @pending.shift)
              n.link
            end
            @created.each(&:prepare)
          end
        end

        # One compiled schema object in one resource.
        # @api private
        class Node
          # The resource (document URI) the schema sits in.
          # @return [String]
          attr_reader :resource

          # The schema object itself.
          # @return [Hash, Boolean]
          attr_reader :schema

          # A node with the schema's own keywords read; subschemas wait for {#link}.
          # @param compiler [Compiler]
          # @param schema [Hash, Boolean]
          # @param resource [String]
          # @raise [Unsupported] for a schema outside the subset
          def initialize(compiler, schema, resource)
            @compiler = compiler
            @resource = resource
            @schema = schema
            if [true, false].include?(schema)
              @boolean = schema
              return
            end
            unless schema.is_a?(Hash)
              raise Unsupported, "a schema must be an object or a boolean, got #{schema.inspect[0, 60]}"
            end

            check(schema)
            @types = Array(schema["type"]).flat_map { |t| TYPES.fetch(t) }.uniq if schema.key?("type")
            @type_label = Array(schema["type"]).join("|")
            @has_const = schema.key?("const")
            @const = schema["const"]
            @enum = schema["enum"]
            @required = schema["required"]
            @dependent_required = schema["dependentRequired"]
            @unique = schema["uniqueItems"] == true
            @min_length = schema["minLength"]&.to_i
            @max_length = schema["maxLength"]&.to_i
            @min_items = schema["minItems"]&.to_i
            @max_items = schema["maxItems"]&.to_i
            @min_properties = schema["minProperties"]&.to_i
            @max_properties = schema["maxProperties"]&.to_i
            @min_contains = schema["minContains"]&.to_i
            @max_contains = schema["maxContains"]&.to_i
            @numeric = %w[minimum maximum exclusiveMinimum exclusiveMaximum multipleOf]
                       .filter_map { |k| [k, schema[k]] if schema.key?(k) }
            @pattern = Pattern.new(schema["pattern"]) if schema.key?("pattern")
            @format_name = schema["format"]
            @format = FORMATS[@format_name] if schema.key?("format")
          end

          # Compiles the subschemas and resolves the references, queueing new nodes with the compiler.
          # @return [void]
          # @raise [UnknownRef] for a reference no document resolves
          # @raise [Unsupported] for a pattern outside the subset
          def link
            return unless @boolean.nil?

            s = @schema
            @ref = target(s["$ref"]) if s.key?("$ref")
            link_dynamic(s["$dynamicRef"]) if s.key?("$dynamicRef")
            @properties = s["properties"]&.transform_values { |sub| child(sub) }
            @pattern_properties = s["patternProperties"]&.map { |source, sub| [Pattern.new(source), child(sub)] }
            @additional = child(s["additionalProperties"]) if s.key?("additionalProperties")
            @property_names = child(s["propertyNames"]) if s.key?("propertyNames")
            @dependent_schemas = s["dependentSchemas"]&.transform_values { |sub| child(sub) }
            @unevaluated = child(s["unevaluatedProperties"]) if s.key?("unevaluatedProperties")
            @prefix_items = s["prefixItems"]&.map { |sub| child(sub) }
            @items = child(s["items"]) if s.key?("items")
            @contains = child(s["contains"]) if s.key?("contains")
            @all_of = s["allOf"]&.map { |sub| child(sub) }
            @any_of = s["anyOf"]&.map { |sub| child(sub) }
            @one_of = s["oneOf"]&.map { |sub| child(sub) }
            @not = child(s["not"]) if s.key?("not")
            return unless s.key?("if")

            @if = child(s["if"])
            @then = child(s["then"]) if s.key?("then")
            @else = child(s["else"]) if s.key?("else")
          end

          # Precomputes the type gate, the discriminator and the tags, so the walk only reads.
          # @return [void]
          def prepare
            gate
            tag_info
            discriminator if @one_of
          end

          # The JSON types this node can accept (nil for any), through `$ref`
          # and `allOf`: a `oneOf`/`anyOf` branch excluding the instance's type
          # is skipped as failed.
          # @return [Array<String>, nil]
          def gate
            return @gate if defined?(@gate)

            @gate = nil # a cycle reads as "any type"
            return @gate = [] if @boolean == false
            return @gate if @boolean

            gate = @types
            gate = intersect(gate, @ref.gate) if @ref
            @all_of&.each { |n| gate = intersect(gate, n.gate) }
            @gate = gate
          end

          # A `oneOf`'s discriminator: a property every branch requires with
          # distinct string constants in unconditional positions, as
          # [name, {value => branch}], or nil when that cannot be shown. Sound
          # because a branch fails whenever the value is not one of its own.
          # @return [Array(String, Hash{String => Node}), nil]
          def discriminator
            return @discriminator if defined?(@discriminator)

            @discriminator = nil
            tags = @one_of.map(&:tags)
            return if tags.any?(&:nil?)

            tags.map(&:keys).reduce(:&).each do |name|
              map = {}
              clash = false
              @one_of.each_with_index do |branch, i|
                tags[i][name].each do |value|
                  clash ||= map.key?(value)
                  map[value] = branch
                end
              end
              return @discriminator = [name, map].freeze unless clash
            end
            nil
          end

          # The required properties with string constants, {name => [values]}, or nil.
          # @return [Hash{String => Array<String>}, nil]
          def tags
            consts, required = tag_info
            found = consts.slice(*required)
            found.empty? ? nil : found
          end

          # String constants under `properties`, and required names, gathered
          # through `$ref` and `allOf` (unconditional positions only) and a
          # discriminated `oneOf`.
          # @return [Array(Hash{String => Array<String>}, Set<String>)]
          def tag_info
            return @tag_info if @tag_info

            @tag_info = [{}, Set.new] # a cycle reads as nothing known
            return @tag_info unless @boolean.nil?

            consts = {}
            required = Set.new(@required || [])
            add = ->(name, values) { consts[name] = consts.key?(name) ? (consts[name] & values) : values }
            (@schema["properties"] || {}).each do |name, sub|
              add.call(name, [sub["const"]]) if sub.is_a?(Hash) && sub["const"].is_a?(String)
            end
            [*@ref, *@all_of].each do |n|
              c, r = n.tag_info
              c.each { |name, values| add.call(name, values) }
              required.merge(r)
            end
            if @one_of && (d = discriminator)
              add.call(d[0], d[1].keys)
              required << d[0]
            end
            @tag_info = [consts.freeze, required.freeze].freeze
          end

          # Evaluates an instance: the property names evaluated (NONE, ALL or
          # an Array), or nil when it fails. `errs` collects Problems (nil:
          # stop at the first failure); `ptr` is the instance's JSON Pointer
          # (nil when not collecting); `scope` the dynamic scope's resources,
          # outermost first; `depth` the subschemas entered so far.
          # @param inst [Object]
          # @param errs [Array<Problem>, nil]
          # @param ptr [String, nil]
          # @param scope [Array<String>]
          # @param depth [Integer]
          # @return [Array<String>, Symbol, nil]
          # @raise [LimitError] past {MAX_DEPTH}
          def evaluate(inst, errs, ptr, scope, depth)
            raise LimitError, "Schema walk nested deeper than #{MAX_DEPTH}#{" at '#{ptr}'" if ptr}" if depth > MAX_DEPTH

            unless @boolean.nil?
              return NONE if @boolean

              problem(errs, ptr, "false", "no value is allowed here")
              return nil
            end

            ok = true
            seen = NONE
            type = Schema.json_type(inst)
            depth += 1
            if @ref
              r = descend(@ref, inst, errs, ptr, scope, depth)
              return nil if r.nil? && errs.nil?

              r.nil? ? ok = false : seen = merge(seen, r)
            end
            if @dynamic_ref
              r = descend(dynamic_target(scope), inst, errs, ptr, scope, depth)
              return nil if r.nil? && errs.nil?

              r.nil? ? ok = false : seen = merge(seen, r)
            end

            if @types && !@types.include?(type)
              problem(errs, ptr, "type", "expected #{@type_label}, received #{type}")
              return nil # nothing below means much for a mistyped value
            end
            if @has_const && !Schema.same?(inst, @const)
              return nil unless errs

              ok = problem(errs, ptr, "const", "expected #{@const.inspect}")
            end
            if @enum&.none? { |v| Schema.same?(inst, v) }
              return nil unless errs

              ok = problem(errs, ptr, "enum", "expected one of #{@enum.map(&:inspect).join(", ")}")
            end

            case type
            when "integer", "number" then ok = numeric(inst, errs, ptr) && ok
            when "string" then ok = string(inst, errs, ptr) && ok
            when "array" then ok = array(inst, errs, ptr, scope, depth) && ok
            when "object"
              r = object(inst, errs, ptr, scope, depth)
              r.nil? ? ok = false : seen = merge(seen, r)
            end
            return nil if !ok && errs.nil?

            r = applicators(inst, errs, ptr, scope, depth, type)
            return nil if r.nil? && errs.nil?

            r.nil? ? ok = false : seen = merge(seen, r)
            # Once something failed, the names a failed branch evaluated are
            # lost; closing the object then would only repeat the failure.
            return nil unless ok
            return seen unless @unevaluated && type == "object"

            unevaluated(inst, errs, ptr, scope, depth, seen)
          end

          private

          # The node a reference names, compiled with the compiler.
          def target(ref)
            schema, resource = @compiler.registry.resolve(@resource, ref)
            @compiler.node(schema, resource)
          end

          # A `$dynamicRef`: its static target, and the anchor name when that
          # target is a `$dynamicAnchor` (the only case where scope matters).
          def link_dynamic(ref)
            @dynamic_ref = target(ref)
            name = ref.split("#", 2)[1]
            return unless name && !name.empty? && !name.start_with?("/")
            return unless @compiler.registry.dynamic_anchor(@dynamic_ref.resource, name)

            @dynamic_name = name
            @compiler.dynamic(name)
          end

          # A subschema in this node's resource.
          def child(schema) = @compiler.node(schema, @resource)

          # Refuses a keyword the interpreter does not implement, another draft, or a malformed value.
          def check(schema)
            bad = schema.keys & UNSUPPORTED
            raise Unsupported, "unsupported keyword #{bad.join(", ")} in #{@resource}" unless bad.empty?
            if schema.key?("$schema") && schema["$schema"].to_s.delete_suffix("#") != DIALECT
              raise Unsupported, "only #{DIALECT} is supported, not #{schema["$schema"]}"
            end
            if schema.key?("$id") && !schema.equal?(@compiler.registry.document(@resource))
              raise Unsupported, "embedded $id #{schema["$id"].inspect} in #{@resource}"
            end

            malformed = SHAPES.find { |keyword, shape| schema.key?(keyword) && !shape.call(schema[keyword]) }
            raise Unsupported, "malformed #{malformed[0]}: #{schema[malformed[0]].inspect[0, 60]}" if malformed

            unknown = Array(schema["type"]) - TYPES.keys
            raise Unsupported, "unknown type #{unknown.join(", ")}" unless unknown.empty?
          end

          # The narrower of two type gates (nil is any type).
          def intersect(left, right)
            return right if left.nil?
            return left if right.nil?

            left & right
          end

          # The rest of an object closed by `unevaluatedProperties`: ALL, or nil when a property fails.
          def unevaluated(hash, errs, ptr, scope, depth, seen)
            return ALL if seen.equal?(ALL)

            names = seen.size > 16 ? seen.to_set : seen
            ok = true
            hash.each do |key, value|
              next if names.include?(key)

              if @unevaluated.schema == false
                return nil unless errs

                ok = problem(errs, "#{ptr}/#{escape(key)}", "unevaluatedProperties", "property not allowed")
                next
              end
              next unless @unevaluated.evaluate(value, errs, ptr && "#{ptr}/#{escape(key)}", scope, depth).nil?
              return nil unless errs

              ok = false
            end
            ok ? ALL : nil
          end

          # A property name as a JSON Pointer token.
          def escape(key) = key.to_s.gsub("~", "~0").gsub("/", "~1")

          # Records a problem when collecting; nil either way, the failed verdict, for `ok = problem(...)`.
          def problem(errs, ptr, keyword, detail)
            errs&.<<(Problem.new(pointer: ptr.to_s, keyword: keyword, detail: detail))
            nil
          end

          # The union of two sets of evaluated names.
          def merge(left, right)
            return left if right.equal?(NONE) || right.empty?
            return right if left.equal?(NONE) || left.empty?
            return ALL if left.equal?(ALL) || right.equal?(ALL)

            left | right
          end

          # Follows a reference, entering its resource in the dynamic scope.
          def descend(node, inst, errs, ptr, scope, depth)
            return node.evaluate(inst, errs, ptr, scope, depth) if node.resource == @resource

            scope.push(node.resource)
            begin
              node.evaluate(inst, errs, ptr, scope, depth)
            ensure
              scope.pop
            end
          end

          # A `$dynamicRef`'s target: the outermost resource in scope marking
          # its anchor wins, when the static target is itself that anchor.
          def dynamic_target(scope)
            return @dynamic_ref unless @dynamic_name

            registry = @compiler.registry
            outer = scope.find { |uri| registry.dynamic_anchor(uri, @dynamic_name) }
            outer ? @compiler.lookup(registry.dynamic_anchor(outer, @dynamic_name), outer) : @dynamic_ref
          end

          # The numeric keywords; true when they pass.
          def numeric(number, errs, ptr)
            ok = true
            @numeric.each do |keyword, bound|
              pass = case keyword
                     when "minimum" then number >= bound
                     when "maximum" then number <= bound
                     when "exclusiveMinimum" then number > bound
                     when "exclusiveMaximum" then number < bound
                     else (number.to_r / bound.to_r).denominator == 1
                     end
              next if pass
              return nil unless errs

              ok = problem(errs, ptr, keyword, "#{number} violates #{keyword} #{bound}")
            end
            ok
          end

          # The string keywords; true when they pass. A pattern that runs out of time fails.
          def string(text, errs, ptr)
            ok = true
            if @min_length && text.length < @min_length
              return nil unless errs

              ok = problem(errs, ptr, "minLength", "shorter than #{@min_length}")
            end
            if @max_length && text.length > @max_length
              return nil unless errs

              ok = problem(errs, ptr, "maxLength", "longer than #{@max_length}")
            end
            if @pattern && !(matched = @pattern.test(text))
              return nil unless errs

              detail = matched.nil? ? "timed out matching #{@pattern.source}" : "does not match #{@pattern.source}"
              ok = problem(errs, ptr, "pattern", detail)
            end
            if @format && !@format.call(text)
              return nil unless errs

              ok = problem(errs, ptr, "format", "not a valid #{@format_name}")
            end
            ok
          end

          # The array keywords; true when they pass.
          def array(list, errs, ptr, scope, depth)
            ok = true
            if @min_items && list.size < @min_items
              return nil unless errs

              ok = problem(errs, ptr, "minItems", "fewer than #{@min_items} items")
            end
            if @max_items && list.size > @max_items
              return nil unless errs

              ok = problem(errs, ptr, "maxItems", "more than #{@max_items} items")
            end
            if @unique && list.each_index.any? { |i| (0...i).any? { |j| Schema.same?(list[i], list[j]) } }
              return nil unless errs

              ok = problem(errs, ptr, "uniqueItems", "items are not unique")
            end
            @prefix_items&.each_with_index do |n, i|
              break if i >= list.size
              next unless n.evaluate(list[i], errs, ptr && "#{ptr}/#{i}", scope, depth).nil?
              return nil unless errs

              ok = false
            end
            if @items
              ((@prefix_items&.size || 0)...list.size).each do |i|
                next unless @items.evaluate(list[i], errs, ptr && "#{ptr}/#{i}", scope, depth).nil?
                return nil unless errs

                ok = false
              end
            end
            if @contains
              count = list.count { |item| !@contains.evaluate(item, nil, nil, scope, depth).nil? }
              min = @min_contains || 1
              if count < min || (@max_contains && count > @max_contains)
                return nil unless errs

                ok = problem(errs, ptr, "contains", "#{count} items match contains (min #{min})")
              end
            end
            ok
          end

          # The object keywords: the names they evaluated, or nil when one fails.
          def object(hash, errs, ptr, scope, depth)
            ok = true
            seen = nil
            @required&.each do |name|
              next if hash.key?(name)
              return nil unless errs

              ok = problem(errs, ptr, "required", "missing required '#{name}'")
            end
            if @min_properties && hash.size < @min_properties
              return nil unless errs

              ok = problem(errs, ptr, "minProperties", "fewer than #{@min_properties} properties")
            end
            if @max_properties && hash.size > @max_properties
              return nil unless errs

              ok = problem(errs, ptr, "maxProperties", "more than #{@max_properties} properties")
            end
            @dependent_required&.each do |name, needs|
              next unless hash.key?(name)

              needs.each do |other|
                next if hash.key?(other)
                return nil unless errs

                ok = problem(errs, ptr, "dependentRequired", "'#{name}' needs '#{other}'")
              end
            end
            if @properties
              hash.each do |key, value|
                n = @properties[key] or next
                (seen ||= []) << key
                next unless n.evaluate(value, errs, ptr && "#{ptr}/#{escape(key)}", scope, depth).nil?
                return nil unless errs

                ok = false
              end
            end
            @pattern_properties&.each do |pattern, n|
              hash.each do |key, value|
                matched = pattern.test(key)
                if matched.nil?
                  return nil unless errs

                  ok = problem(errs, "#{ptr}/#{escape(key)}", "patternProperties",
                               "timed out matching #{pattern.source}")
                  next
                end
                next unless matched

                (seen ||= []) << key
                next unless n.evaluate(value, errs, ptr && "#{ptr}/#{escape(key)}", scope, depth).nil?
                return nil unless errs

                ok = false
              end
            end
            if @additional
              hash.each do |key, value|
                next if @properties&.key?(key)
                next if @pattern_properties&.any? { |pattern, _| pattern.test(key) }

                (seen ||= []) << key
                if @additional.schema == false
                  return nil unless errs

                  ok = problem(errs, "#{ptr}/#{escape(key)}", "additionalProperties", "property not allowed")
                  next
                end
                next unless @additional.evaluate(value, errs, ptr && "#{ptr}/#{escape(key)}", scope, depth).nil?
                return nil unless errs

                ok = false
              end
            end
            if @property_names
              hash.each_key do |key|
                next unless @property_names.evaluate(key, nil, nil, scope, depth).nil?
                return nil unless errs

                ok = problem(errs, "#{ptr}/#{escape(key)}", "propertyNames",
                             "property name #{key.inspect} is not allowed")
              end
            end
            @dependent_schemas&.each do |name, n|
              next unless hash.key?(name)

              r = n.evaluate(hash, errs, ptr, scope, depth)
              return nil if r.nil? && errs.nil?

              r.nil? ? ok = false : seen = merge(seen || NONE, r)
            end
            ok ? (seen || NONE) : nil
          end

          # The in-place applicators: the names they evaluated, or nil when one fails.
          def applicators(inst, errs, ptr, scope, depth, type)
            ok = true
            seen = NONE
            @all_of&.each do |n|
              r = n.evaluate(inst, errs, ptr, scope, depth)
              return nil if r.nil? && errs.nil?

              r.nil? ? ok = false : seen = merge(seen, r)
            end
            if @any_of
              hit = false
              @any_of.each do |n|
                next if n.gate && !n.gate.include?(type)

                r = n.evaluate(inst, nil, nil, scope, depth)
                next if r.nil?

                hit = true
                seen = merge(seen, r)
              end
              unless hit
                return nil unless errs

                problem(errs, ptr, "anyOf", "matches none of the anyOf schemas")
                ok = explain(@any_of, inst, errs, ptr, scope, depth)
              end
            end
            if @one_of
              r = one_of(inst, errs, ptr, scope, depth, type)
              return nil if r.nil? && errs.nil?

              r.nil? ? ok = false : seen = merge(seen, r)
            end
            if @not && !@not.evaluate(inst, nil, nil, scope, depth).nil?
              return nil unless errs

              ok = problem(errs, ptr, "not", "matches a schema it must not match")
            end
            if @if
              r = @if.evaluate(inst, nil, nil, scope, depth)
              seen = merge(seen, r) unless r.nil?
              branch = r.nil? ? @else : @then
              if branch
                b = branch.evaluate(inst, errs, ptr, scope, depth)
                return nil if b.nil? && errs.nil?

                b.nil? ? ok = false : seen = merge(seen, b)
              end
            end
            ok ? seen : nil
          end

          # `oneOf`: through the discriminator when there is one, else every
          # branch the instance's type admits, exactly one passing.
          def one_of(inst, errs, ptr, scope, depth, type)
            if type == "object" && (d = discriminator)
              name, map = d
              n = inst[name].is_a?(String) ? map[inst[name]] : nil
              return n.evaluate(inst, errs, ptr, scope, depth) if n

              detail = inst.key?(name) ? "#{inst[name].inspect} names no oneOf schema" : "is missing"
              problem(errs, ptr, "oneOf", "'#{name}' #{detail}")
              return nil
            end
            found = nil
            @one_of.each do |n|
              next if n.gate && !n.gate.include?(type)

              r = n.evaluate(inst, nil, nil, scope, depth)
              next if r.nil?

              if found
                problem(errs, ptr, "oneOf", "matches more than one oneOf schema")
                return nil
              end
              found = r
            end
            return found if found
            return nil unless errs

            problem(errs, ptr, "oneOf", "matches none of the oneOf schemas")
            explain(@one_of, inst, errs, ptr, scope, depth)
          end

          # Why no branch matched, after the problem saying so: the problems of
          # the branch whose required keys the instance has (the kind it
          # meant), then of the one with the fewest; when no branch takes the
          # instance's type at all, the types they take. Nil, the failed verdict.
          def explain(branches, inst, errs, ptr, scope, depth)
            type = Schema.json_type(inst)
            best = nil
            best_score = nil
            branches.each do |n|
              next if n.gate && !n.gate.include?(type)

              found = []
              n.evaluate(inst, found, ptr, scope, depth)
              missing = type == "object" ? n.tag_info[1].count { |name| !inst.key?(name) } : 0
              score = [missing, found.size]
              if best_score.nil? || (score <=> best_score).negative?
                best = found
                best_score = score
              end
            end
            if best
              errs.concat(best)
              return nil
            end

            types = branches.flat_map(&:gate).uniq
            problem(errs, ptr, "type", "expected #{types.empty? ? "nothing" : types.join("|")}, received #{type}")
          end
        end

        # One ECMA-262 pattern read left to right into Ruby regexp source (see {Schema.translate}).
        # @api private
        class Translation
          # Escapes ECMA-262 gives the same meaning in both, besides the ones translated.
          SAME_ESCAPES = %w[d D w W f n r t v x u k].freeze
          # What `^`, `$` and `.` mean outside a class: input anchors, and anything but a line terminator.
          OUTSIDE = { "^" => "\\A", "$" => "\\z", "." => '[^\n\r\u2028\u2029]' }.freeze
          # The characters that may follow `(?` in ECMA-262: a non-capturing group, a lookahead, a named group.
          GROUPS = %w[: = ! <].freeze
          # The characters after `(?<` that make a lookbehind rather than a named group.
          LOOKBEHIND = %w[= !].freeze
          # An interval quantifier: {n}, {n,}, {n,m}, or Ruby's {,m}.
          INTERVAL = /\A\{(?:\d+(?:,\d*)?|,\d*)\}/

          # A scan of one pattern.
          # @param source [String]
          # @param lenient [Boolean] whether constructs ECMA-262 has but means differently pass through
          def initialize(source, lenient)
            @source = source
            @lenient = lenient
            @out = +""
            @at = 0
            @in_class = false
          end

          # The Ruby regexp source.
          # @return [String]
          # @raise [Unsupported] naming the construct refused
          def run
            while @at < @source.length
              char = @source[@at]
              if char == "\\" then escape
              elsif @in_class then class_char(char)
              else outside(char)
              end
            end
            @out
          end

          private

          # The character so many places ahead.
          def peek(offset = 1) = @source[@at + offset]

          # A construct ECMA-262 has with another meaning: refused, unless lenient (then `text` stands).
          def differs(what, text)
            return text if @lenient

            raise Unsupported,
                  "pattern #{@source.inspect} uses #{what}, which this validator cannot match as ECMA-262 does"
          end

          # A construct ECMA-262 does not have: always refused.
          def not_ecma(what) = raise(Unsupported, "pattern #{@source.inspect} uses #{what}, which is not ECMA-262")

          # An escape: ECMA's classes in its own terms, an escape it does not have refused.
          def escape
            letter = peek
            @out << case letter
                    when nil then "\\" # a trailing backslash, which then fails to compile
                    when "s" then @in_class ? SPACE : "[#{SPACE}]"
                    when "S" then "[^#{SPACE}]"
                    when "b" then @in_class ? "\\b" : "(?a:\\b)"
                    when "B" then @in_class ? not_ecma("\\B in a class") : "(?a:\\B)"
                    when "c" then differs("\\c", "\\c")
                    when "p", "P" then property(letter)
                    when /[A-Za-z]/ then SAME_ESCAPES.include?(letter) ? "\\#{letter}" : not_ecma("\\#{letter}")
                    else "\\#{letter}" # a digit, or punctuation escaped
                    end
            @at += 2
          end

          # `\p{...}` or `\P{...}`: the identifier classes pass, any other property differs.
          def property(letter)
            close = @source.index("}", @at + 3)
            name = peek(2) == "{" && close ? @source[(@at + 3)...close] : nil
            PROPERTIES.include?(name) ? "\\#{letter}" : differs("\\#{letter}{#{name}}", "\\#{letter}")
          end

          # A character inside a class; a nested class and the `v` flag's operators differ.
          def class_char(char)
            if char == "]" then @in_class = false
            elsif char == "[" then differs("[ inside a class", nil)
            elsif %w[& -].include?(char) && peek == char then differs("#{char}#{char} inside a class", nil)
            end
            @out << char
            @at += 1
          end

          # A character outside a class.
          def outside(char)
            case char
            when "[" then open_class
            when "(" then group
            when "*", "+", "?" then quantifier(char)
            when "{"
              interval = @source[@at..][INTERVAL]
              interval ? quantifier(interval) : literal(char)
            else literal(OUTSIDE.fetch(char, char))
            end
          end

          # Text written as is, for one source character.
          def literal(text)
            @out << text
            @at += 1
          end

          # A class opening; ECMA's `[]` matches nothing and `[^]` anything.
          def open_class
            if peek == "]"
              @out << "(?!)"
              @at += 2
            elsif @source[@at + 1, 2] == "^]"
              @out << "(?m:.)"
              @at += 3
            else
              @in_class = true
              @out << (peek == "^" ? "[^" : "[")
              @at += peek == "^" ? 2 : 1
            end
          end

          # A group opening; Ruby's own group kinds are refused, lookbehind differs.
          def group
            if peek == "?"
              kind = peek(2)
              if kind == "<" && LOOKBEHIND.include?(peek(3)) then differs("lookbehind", nil)
              elsif !GROUPS.include?(kind) then not_ecma("(?#{kind}")
              end
            end
            @out << (peek == "?" ? "(?" : "(")
            @at += peek == "?" ? 2 : 1
          end

          # A quantifier, then its lazy `?`; `{,m}` and a possessive `+` are Ruby's alone.
          def quantifier(text)
            not_ecma(text) if text.start_with?("{,")
            @out << text
            @at += text.length
            if @source[@at] == "?"
              @out << "?"
              @at += 1
            end
            not_ecma("a possessive quantifier") if @source[@at] == "+"
          end
        end

        # An ECMA-262 pattern compiled once, matched with a timeout.
        # @api private
        class Pattern
          # The pattern as the schema wrote it.
          # @return [String]
          attr_reader :source

          # A pattern compiled from its ECMA-262 source.
          # @param source [String]
          # @raise [Unsupported] for a pattern outside the subset, or one that does not compile
          def initialize(source)
            @source = source
            @regexp = Regexp.new(Schema.translate(source), timeout: PATTERN_TIMEOUT)
          rescue RegexpError => e
            raise Unsupported, "pattern #{source.inspect} does not compile: #{e.message}"
          end

          # Whether a string matches: true, false, or nil when the match ran out of time.
          # @param string [String]
          # @return [Boolean, nil]
          def test(string)
            @regexp.match?(string)
          rescue Regexp::TimeoutError
            nil
          end
        end
      end
    end
  end
end
