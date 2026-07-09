# frozen_string_literal: true

require "json"

module Poetry
  module Core
    # The canonical design-token model (M1). Loads tokens/tokens.dtcg.json -
    # the single source of truth - and exposes the semantic color roles per
    # mode plus the radius dimension. Everything else (tokens.css,
    # tailwind-theme.css, the DESIGN.md front matter) is generated from an
    # instance of this class; the AAA-contrast gate asserts against it.
    class Tokens
      DEFAULT_RELATIVE_PATH = "tokens/tokens.dtcg.json"

      # The exact CSS custom-property set of the shadcn/ui v4 distributed
      # theme (cssVarsV4, plus --radius). This is the drop-in contract: any
      # shadcn v4 theme block defines exactly these names, so it can replace
      # poetry's tokens.css wholesale (DoD: "a shadcn theme drops in").
      SHADCN_V4_COMPAT_VARS = %w[
        background foreground
        card card-foreground
        popover popover-foreground
        primary primary-foreground
        secondary secondary-foreground
        muted muted-foreground
        accent accent-foreground
        destructive
        border input ring
        chart-1 chart-2 chart-3 chart-4 chart-5
        sidebar sidebar-foreground
        sidebar-primary sidebar-primary-foreground
        sidebar-accent sidebar-accent-foreground
        sidebar-border sidebar-ring
      ].freeze

      # Poetry-original extensions BEYOND the shadcn v4 set (Blocks v1.1,
      #): the soft status vocabulary the benchmark measured as
      # missing. Kept separate so the drop-in contract stays sharp: a
      # shadcn theme block replaces the compat set wholesale, and these
      # keep their poetry defaults unless the theme chooses to override.
      POETRY_STATUS_VARS = %w[success warning info].freeze

      class << self
        def default_path
          Poetry::Core.root.join(DEFAULT_RELATIVE_PATH)
        end

        def load(path = default_path)
          new(JSON.parse(File.read(path)))
        end
      end

      attr_reader :data

      def initialize(data)
        @data = data
        @colors = {}
      end

      # Mode names ("light", "dark"), skipping DTCG $-metadata keys.
      def modes
        data.fetch("color").keys.reject { |k| k.start_with?("$") }
      end

      def color_names(mode)
        data.fetch("color").fetch(mode).keys.reject { |k| k.start_with?("$") }
      end

      def color(mode, name)
        @colors[[mode, name]] ||= begin
          token = data.fetch("color").fetch(mode).fetch(name) do
            raise KeyError, "no #{mode} color token #{name.inspect}"
          end
          Color.from_dtcg(token.fetch("$value"))
        end
      end

      # The radius dimension as CSS ("0.625rem").
      def radius_css
        value = data.fetch("dimension").fetch("radius").fetch("$value")
        "#{format("%g", value.fetch("value"))}#{value.fetch("unit")}"
      end
    end
  end
end
