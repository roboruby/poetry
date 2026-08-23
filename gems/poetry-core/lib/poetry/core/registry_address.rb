# frozen_string_literal: true

require "uri"

module Poetry
  module Core
    # The uniform registry address scheme - the shadcn
    # CLI lesson applied verbatim: no --from flag, ONE classifier for every
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
    # naming, and shadcn's.
    #
    # @example
    #   Poetry::Core::RegistryAddress.parse("@acme/fancy-chart").kind # => :namespace
    class RegistryAddress
      NAMESPACED = %r{\A(@[a-z0-9][a-z0-9_-]*)/([A-Za-z0-9_-]+)\z}
      BARE = /\A[A-Za-z0-9_-]+\z/

      attr_reader :kind, :raw, :namespace, :name, :location

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

      def self.parse_namespaced(raw)
        match = NAMESPACED.match(raw)
        raise ArgumentError, "malformed namespaced address #{raw.inspect} (expected @registry/item-name)" unless match

        new(kind: :namespace, raw: raw, namespace: match[1], name: normalize(match[2]))
      end

      # CamelCase / snake_case / kebab-case all land on the kebab item name.
      def self.normalize(name)
        name.gsub(/([a-z\d])([A-Z])/, '\1_\2').downcase.tr("_", "-")
      end

      def initialize(kind:, raw:, namespace: nil, name: nil, location: nil)
        @kind = kind
        @raw = raw
        @namespace = namespace
        @name = name
        @location = location
        freeze
      end

      def remote?
        kind != :bare
      end

      # The address of a bare dependency named inside a parent item - the
      # sibling convention: an @acme item's bare deps are @acme items; a
      # url/file item's bare deps sit next to it.
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
