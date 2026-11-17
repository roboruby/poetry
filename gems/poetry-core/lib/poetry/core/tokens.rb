# frozen_string_literal: true

require "json"

module Poetry
  module Core
    # The canonical design-token model. Loads tokens/tokens.dtcg.json -
    # the single source of truth - and exposes the semantic color roles per
    # mode plus the radius dimension. Everything else (tokens.css,
    # tailwind-theme.css, the DESIGN.md front matter) is generated from an
    # instance of this class; the AAA-contrast gate asserts against it.
    #
    # @example
    #   tokens = Poetry::Core::Tokens.load
    #   tokens.color("light", "primary").css # => "oklch(0.205 0 0)"
    #   tokens.radius_css                    # => "0.625rem"
    class Tokens
      # Where the canonical DTCG token file lives, relative to the gem root.
      DEFAULT_RELATIVE_PATH = "tokens/tokens.dtcg.json"

      # The exact CSS custom-property set of the widely-distributed v4
      # theme convention (cssVarsV4, plus --radius). This is the drop-in
      # contract: any theme block written to that convention defines exactly
      # these names, so it can replace poetry's tokens.css wholesale.
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

      # Poetry-original extensions BEYOND the compat set: the soft
      # status vocabulary that set lacks. Kept separate so the
      # drop-in contract stays sharp: a drop-in theme block replaces the
      # compat set wholesale, and these keep their poetry defaults unless
      # the theme chooses to override.
      POETRY_STATUS_VARS = %w[success warning info].freeze

      # A status role is a fill and a tint. As text it is too light in
      # light mode (success is 3.67:1 on white), so each role has a
      # text-safe companion, --<role>-strong: the role at
      # {STRONG_LIGHTNESS} of its lightness in light mode, and the role
      # itself in dark, where it already reads. The text-<role> utilities
      # read the companion; the other utilities (bg-, border-, ring-) keep
      # the role. This is the companion's suffix.
      STRONG_SUFFIX = "-strong"

      # The share of a status role's lightness its text-safe companion
      # keeps in light mode: the largest at which success clears AA on its
      # own 10% tint, and the share the themes' own status rules have
      # always written out.
      STRONG_LIGHTNESS = 0.85

      class << self
        # The gem's canonical token file path ({DEFAULT_RELATIVE_PATH}
        # under the gem root).
        #
        # @return [Pathname]
        def default_path
          Poetry::Core.root.join(DEFAULT_RELATIVE_PATH)
        end

        # Loads a DTCG token file into a Tokens instance.
        #
        # @param path [String, Pathname] a DTCG JSON file; defaults to the
        #   gem's canonical tokens
        # @return [Tokens]
        def load(path = default_path)
          new(JSON.parse(File.read(path)))
        end
      end

      attr_reader :data

      # Wraps one parsed DTCG document; {.load} is the file-backed form.
      #
      # @param data [Hash] the parsed DTCG JSON
      def initialize(data)
        @data = data
        @colors = {}
      end

      # Mode names ("light", "dark"), skipping DTCG $-metadata keys.
      #
      # @return [Array<String>]
      def modes
        data.fetch("color").keys.reject { |k| k.start_with?("$") }
      end

      # The semantic color-role names of one mode, in file order.
      #
      # @param mode [String] "light" or "dark"
      # @return [Array<String>] role names ("primary", "muted-foreground", ...)
      def color_names(mode)
        data.fetch("color").fetch(mode).keys.reject { |k| k.start_with?("$") }
      end

      # The names of the status roles' text-safe companions.
      #
      # @return [Array<String>] ("success-strong", "warning-strong", ...)
      def strong_names
        POETRY_STATUS_VARS.map { |role| "#{role}#{STRONG_SUFFIX}" }
      end

      # The color of one semantic role in one mode. A status role's
      # companion ("success-strong") is not in the file: it is worked out
      # from its role, {STRONG_LIGHTNESS} of its lightness in light mode
      # and the role itself in dark.
      #
      # @param mode [String] "light" or "dark"
      # @param name [String] the role name ("primary", "destructive", ...)
      # @return [Color]
      # @raise [KeyError] when the mode has no such role
      def color(mode, name)
        @colors[[mode, name]] ||=
          if strong_names.include?(name)
            role = color(mode, name.delete_suffix(STRONG_SUFFIX))
            mode == "light" ? role.with(l: role.l * STRONG_LIGHTNESS) : role
          else
            token = data.fetch("color").fetch(mode).fetch(name) do
              raise KeyError, "no #{mode} color token #{name.inspect}"
            end
            Color.from_dtcg(token.fetch("$value"))
          end
      end

      # The radius dimension as CSS ("0.625rem").
      #
      # @return [String]
      def radius_css
        value = data.fetch("dimension").fetch("radius").fetch("$value")
        "#{format("%g", value.fetch("value"))}#{value.fetch("unit")}"
      end
    end
  end
end
