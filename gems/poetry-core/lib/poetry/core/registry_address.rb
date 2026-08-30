# frozen_string_literal: true

require "uri"

module Poetry
  module Core
    # The uniform registry address scheme:
    # no --from flag, ONE classifier for every
    # generator argument and every registryDependencies entry. An address is
    # exactly one of:
    #
    #   https://acme.dev/r/fancy-chart.json   :url        any endpoint
    #   ./registry/fancy-chart.json           :file       a local item file
    #   @acme/fancy-chart                     :namespace  a configured registry
    #   button / Button / input_group         :bare       the installed gems
    #
    # Item names normalize to kebab-case everywhere (InputGroup and
    # input_group are both input-group) - the block catalog's existing
    # naming, and the wider registry ecosystem's.
    #
    # @example
    #   Poetry::Core::RegistryAddress.parse("@acme/fancy-chart").kind # => :namespace
    class RegistryAddress
      # The `@namespace/item-name` address shape (`@acme/fancy-chart`): a
      # registry namespace, a slash, an item name.
      NAMESPACED = %r{\A(@[a-z0-9][a-z0-9_-]*)/([A-Za-z0-9_-]+)\z}
      # The bare item-name address shape (the installed gems).
      BARE = /\A[A-Za-z0-9_-]+\z/

      attr_reader :kind, :raw, :namespace, :name, :location

      # Parses one address into its kind: `http(s)://` is a :url, `@x/y` a
      # :namespace, a `.json` path or a `./`, `../`, `/`, `~` prefix a
      # :file, and a plain item name a :bare address.
      #
      # @param raw [String, #to_s] the address as typed
      # @return [RegistryAddress]
      # @raise [ArgumentError] for an empty or unrecognized address
      def self.parse(raw)
        raw = raw.to_s.strip
        raise ArgumentError, "empty registry address" if raw.empty?

        if raw.match?(%r{\Ahttps?://}) then new(kind: :url, raw: raw, location: raw)
        elsif raw.start_with?("@") then parse_namespaced(raw)
        elsif raw.end_with?(".json") || raw.start_with?("./", "../", "/", "~")
          new(kind: :file, raw: raw, location: raw)
        elsif raw.match?(BARE)
          new(kind: :bare, raw: raw, name: normalize(raw))
        else
          raise ArgumentError, "unrecognized registry address #{raw.inspect}"
        end
      end

      # Parses an `@namespace/item-name` address.
      #
      # @param raw [String] the address, already known to start with `@`
      # @return [RegistryAddress] a :namespace address
      # @raise [ArgumentError] when the shape is not `@registry/item-name`
      def self.parse_namespaced(raw)
        match = NAMESPACED.match(raw)
        raise ArgumentError, "malformed namespaced address #{raw.inspect} (expected @registry/item-name)" unless match

        new(kind: :namespace, raw: raw, namespace: match[1], name: normalize(match[2]))
      end

      # CamelCase / snake_case / kebab-case all land on the kebab item name.
      #
      # @param name [String] an item name in any of the three spellings
      # @return [String] the kebab-case item name
      def self.normalize(name)
        name.gsub(/([a-z\d])([A-Z])/, '\1_\2').downcase.tr("_", "-")
      end

      # Builds a frozen address; {.parse} is the usual entry point.
      #
      # @param kind [Symbol] :bare, :namespace, :url, or :file
      # @param raw [String] the address as typed
      # @param namespace [String, nil] the `@registry` part of a :namespace address
      # @param name [String, nil] the normalized item name (:bare, :namespace)
      # @param location [String, nil] the URL or path (:url, :file)
      def initialize(kind:, raw:, namespace: nil, name: nil, location: nil)
        @kind = kind
        @raw = raw
        @namespace = namespace
        @name = name
        @location = location
        freeze
      end

      # Whether the item has to be fetched rather than found among the
      # installed gems - every kind but :bare.
      #
      # @return [Boolean]
      def remote?
        kind != :bare
      end

      # The address of a bare dependency named inside a parent item - the
      # sibling convention: an @acme item's bare deps are @acme items; a
      # url/file item's bare deps sit next to it.
      #
      # @param dep_name [String] the dependency's bare item name
      # @return [RegistryAddress]
      # @raise [ArgumentError] for a :bare address, which has no siblings
      def sibling(dep_name)
        case kind
        when :namespace then self.class.parse("#{namespace}/#{dep_name}")
        when :url then self.class.parse(URI.join(location, "#{dep_name}.json").to_s)
        when :file then self.class.parse(File.join(File.dirname(location), "#{dep_name}.json"))
        else raise ArgumentError, "a #{kind} address has no siblings"
        end
      end
    end
  end
end
