# frozen_string_literal: true

module Poetry
  module Agent
    module A2UI
      # How one A2UI protocol version spells a surface's messages and dynamic
      # values. v0.9 (and its v0.9.1 revision) bind data with `{ "path" }`
      # and call functions with `{ "call" }`. v1.0 binds with `{ "@path" }`
      # and calls with `{ "@call" }`, so a plain object's `path` and `call`
      # keys are literal data there; it reserves every other key with a
      # single leading `@`, and a literal key that starts with `@` is escaped
      # by doubling the prefix (`"@@type"` reads as `"@type"`). A ChildList
      # template is `{ "componentId", "path" }` in both.
      #
      # @example
      #   Dialect.for("1.0").binding?({ "@path" => "/name" })  # => true
      #   Dialect.for("v0.9").binding?({ "@path" => "/name" }) # => false
      class Dialect
        # The single-`@` keys v1.0 defines; any other is reserved.
        DIRECTIVES = %w[@path @call].freeze

        # The version this dialect stamps on what the renderer sends.
        # @return [String] `"v0.9"`, `"v0.9.1"` or `"1.0"`
        attr_reader :version
        # The key a data binding carries its pointer under.
        # @return [String] `"path"` or `"@path"`
        attr_reader :path_key
        # The key a function call carries its name under.
        # @return [String] `"call"` or `"@call"`
        attr_reader :call_key

        # A dialect for a version.
        # @param version [String]
        # @param path_key [String]
        # @param call_key [String]
        def initialize(version:, path_key:, call_key:)
          @version = version
          @path_key = path_key
          @call_key = call_key
          freeze
        end

        # v0.9.
        V0_9 = new(version: "v0.9", path_key: "path", call_key: "call")
        # v0.9.1, v0.9's revision: the same messages and values.
        V0_9_1 = new(version: "v0.9.1", path_key: "path", call_key: "call")
        # v1.0.
        V1_0 = new(version: "1.0", path_key: "@path", call_key: "@call")

        # The wire versions a renderer accepts. `"v1.0"` is v1.0's spelling
        # before the bare `"1.0"`, which the published agent SDKs still send;
        # it is accepted on input only.
        VERSIONS = { "v0.9" => V0_9, "v0.9.1" => V0_9_1, "1.0" => V1_0, "v1.0" => V1_0 }.freeze

        # The dialect of a wire version, or nil for one Poetry does not speak.
        # @param version [String, nil]
        # @return [Dialect, nil]
        def self.for(version)
          VERSIONS[version]
        end

        # Whether this is v1.0, with its reserved `@` keys and its validation results.
        # @return [Boolean]
        def v1?
          path_key == "@path"
        end

        # Whether another dialect speaks the same messages (v0.9 and v0.9.1 do).
        # @param other [Dialect]
        # @return [Boolean]
        def compatible?(other)
          other.v1? == v1?
        end

        # Whether a value is a data binding: a string pointer under the
        # binding key, and no `componentId` (that is a template).
        # @param value [Object]
        # @return [Boolean]
        def binding?(value)
          value.is_a?(Hash) && value[path_key].is_a?(String) && !value.key?("componentId")
        end

        # Whether a value is a function call: a string name under the call key.
        # @param value [Object]
        # @return [Boolean]
        def call?(value)
          value.is_a?(Hash) && value[call_key].is_a?(String)
        end

        # A binding's pointer, or nil when the value is not a binding.
        # @param value [Object]
        # @return [String, nil]
        def path(value)
          value[path_key] if binding?(value)
        end

        # A call's function name, or nil when the value is not a call.
        # @param value [Object]
        # @return [String, nil]
        def call_name(value)
          value[call_key] if call?(value)
        end

        # The keys of a plain object v1.0 reserves (a single leading `@`,
        # not one of its directives); none in v0.9.
        # @param object [Hash]
        # @return [Array<String>]
        def reserved_keys(object)
          return [] unless v1?

          object.keys.select { |key| key.start_with?("@") && !key.start_with?("@@") && !DIRECTIVES.include?(key) }
        end

        # A plain object's key as data: v1.0 drops the doubled prefix's first `@`.
        # @param key [String]
        # @return [String]
        def unescape(key)
          v1? && key.start_with?("@@") ? key[1..] : key
        end
      end
    end
  end
end
