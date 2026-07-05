# frozen_string_literal: true

module Poetry
  module Charts
    # The chart config - poetry's port of shadcn's ChartConfig contract:
    # series key -> { label:, icon:, color: } or { label:, icon:, theme:
    # { light:, dark: } }. The config is the SINGLE place series get their
    # human labels and colors; the container's <style> emission, the tooltip
    # chrome, and the legend chrome all resolve through it.
    #
    # Values land inside a <style> element and inline style attributes, so
    # every color (and key) is validated against a conservative character
    # set at wrap time - a config can never smuggle CSS out of its block.
    class Config
      # A series key becomes a --color-<key> custom property.
      KEY = /\A[a-zA-Z][a-zA-Z0-9_-]*\z/
      # Any CSS color form (var(--chart-1), #hex, oklch(...), named...) minus
      # everything that could terminate a declaration or escape the block.
      COLOR = /\A[^{};<>&"']+\z/

      THEMES = %i[light dark].freeze

      Entry = Data.define(:key, :label, :icon, :color, :theme) do
        # The per-theme color: the flat color, or the theme map's value.
        def color_for(theme_name)
          theme ? theme[theme_name] : color
        end

        def colored?
          !!(color || theme)
        end
      end

      class << self
        # Accepts a Config (pass-through) or a Hash keyed by series name.
        def wrap(source)
          source.is_a?(Config) ? source : new(source || {})
        end
      end

      attr_reader :entries

      def initialize(hash)
        raise ArgumentError, "chart config must be a Hash, got #{hash.class}" unless hash.is_a?(Hash)

        @entries = hash.map { |key, value| build_entry(key, value || {}) }
      end

      def [](key)
        key = key.to_s
        entries.find { |entry| entry.key == key }
      end

      def keys
        entries.map(&:key)
      end

      # The entries that carry a color (flat or themed) - the set the
      # container's <style> emission covers, in config order.
      def color_entries
        entries.select(&:colored?)
      end

      # The label for a series key, falling back to the key itself - the
      # tooltip/legend resolution rule (shadcn: config[key]?.label ?? name).
      def label_for(key, fallback = nil)
        self[key]&.label || fallback || key.to_s
      end

      def to_h
        entries.to_h do |entry|
          value = { label: entry.label }.compact
          value[:color] = entry.color if entry.color
          value[:theme] = entry.theme if entry.theme
          [entry.key, value]
        end
      end

      private

      def build_entry(key, value)
        key = key.to_s
        raise ArgumentError, "chart config key #{key.inspect} is not CSS-safe" unless key.match?(KEY)

        value = value.symbolize_keys
        color = validate_color!(key, value[:color])
        theme = validate_theme!(key, value[:theme])
        raise ArgumentError, "chart config #{key.inspect} sets both color: and theme:" if color && theme

        Entry.new(key:, label: value[:label], icon: value[:icon], color:, theme:)
      end

      def validate_color!(key, color)
        return nil if color.nil?

        color = color.to_s
        unless color.match?(COLOR)
          raise ArgumentError,
                "chart config #{key.inspect} color #{color.inspect} is not CSS-safe"
        end

        color
      end

      def validate_theme!(key, theme)
        return nil if theme.nil?
        raise ArgumentError, "chart config #{key.inspect} theme must be a Hash" unless theme.is_a?(Hash)

        theme = theme.symbolize_keys
        unknown = theme.keys - THEMES
        raise ArgumentError, "chart config #{key.inspect} theme has unknown modes #{unknown.inspect}" if unknown.any?

        theme.to_h { |mode, color| [mode, validate_color!(key, color)] }
      end
    end
  end
end
