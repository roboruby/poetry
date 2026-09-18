# frozen_string_literal: true

module Poetry
  module Core
    module CSS
      # The shared-name contract: poetry's tokens use the widely-distributed
      # v4 names (`--primary`, `--accent`, `--muted`, ...) and its Tailwind
      # theme mapping sets the matching theme keys (`--color-primary`,
      # `--radius-sm`). Both are DEFAULTS: the tokens import into a cascade
      # layer and the mapping is `@theme inline default`, so a host that
      # already declares one of these names keeps its value, and that value
      # now reaches poetry's components too. Precedence makes the install
      # safe; this scan makes the share visible - it lists every host
      # declaration of a poetry name, where it is, and what poetry paints
      # with that role, at the moment the share is created (the installer)
      # and on every later `poetry:check`.
      #
      # Sources are the host's own stylesheets. Poetry's vendored directory
      # and the compiled build are never sources: they declare the names by
      # design.
      #
      # @example
      #   scan = Poetry::Core::CSS::TokenCollisions.scan(root: Rails.root)
      #   scan.ok? || scan.collisions.map(&:to_s)
      #
      # @api private
      class TokenCollisions
        # One host declaration of a poetry name.
        Collision = Struct.new(:name, :path, :line, :kind, :role, keyword_init: true) do
          # The host-facing explanation: where, and what it now paints.
          def to_s
            "#{path}:#{line}: #{name} is yours, so it wins inside poetry's components too - " \
              "poetry #{kind == :theme_key ? "maps" : "uses"} #{name} for #{role}"
          end
        end

        # Same shape as VarCoverage: `--x:` declarations, never Stimulus
        # event tokens or BEM substrings.
        DECLARATION = /(?<![\w-])(--[A-Za-z][\w-]*)\s*:/

        # Host stylesheet roots, relative to the app root.
        SOURCE_GLOBS = ["app/assets/tailwind/**/*.css", "app/assets/stylesheets/**/*.css"].freeze
        # Poetry's own vendored directory and the compiled output declare
        # the names on purpose.
        EXCLUDED_PREFIXES = ["app/assets/tailwind/poetry/", "app/assets/builds/"].freeze

        # What each semantic role paints in poetry's components - the
        # sentence a host reads to decide whether its meaning matches.
        ROLE_USES = {
          "radius" => "the corner radius scale every component derives from (--radius-sm through --radius-4xl)",
          "background" => "the page canvas, dialogs, popovers and every surface that sits on it",
          "foreground" => "body text and icons on the page canvas",
          "card" => "the Card surface and every card-like panel",
          "card-foreground" => "text on Card surfaces",
          "popover" => "the surface of every floating panel (menus, selects, popovers, tooltips)",
          "popover-foreground" => "text inside floating panels",
          "primary" => "the default Button, checked Checkbox and Switch, selected Calendar days, focused Tabs",
          "primary-foreground" => "text and icons on primary surfaces",
          "secondary" => "the secondary Button and Badge surfaces",
          "secondary-foreground" => "text on secondary surfaces",
          "muted" => "quiet surfaces: Tabs lists, Skeleton, table stripes, code panels, disabled fills",
          "muted-foreground" => "secondary text: descriptions, placeholders, captions, inactive tabs",
          "accent" => "hovered and highlighted rows in menus, selects, comboboxes and commands, and ghost Button hover",
          "accent-foreground" => "text on hovered and highlighted rows",
          "destructive" => "the destructive Button, invalid-field rings, error text and Alert",
          "success" => "success Alerts, Badges and status indicators",
          "warning" => "warning Alerts, Badges and status indicators",
          "info" => "info Alerts, Badges and status indicators",
          "border" => "every 1px border: cards, inputs, tables, separators",
          "input" => "the border of text fields, selects and textareas",
          "ring" => "the focus ring on every focusable control",
          "chart-1" => "the first chart series color",
          "chart-2" => "the second chart series color",
          "chart-3" => "the third chart series color",
          "chart-4" => "the fourth chart series color",
          "chart-5" => "the fifth chart series color",
          "sidebar" => "the Sidebar surface",
          "sidebar-foreground" => "text in the Sidebar",
          "sidebar-primary" => "the Sidebar's primary surfaces",
          "sidebar-primary-foreground" => "text on the Sidebar's primary surfaces",
          "sidebar-accent" => "hovered and active Sidebar items",
          "sidebar-accent-foreground" => "text on hovered and active Sidebar items",
          "sidebar-border" => "the Sidebar's borders",
          "sidebar-ring" => "the focus ring inside the Sidebar"
        }.freeze

        class << self
          # Scans a host app's stylesheets.
          #
          # @param root [String, Pathname] the app root
          # @param tokens [Tokens] the poetry token set (the gem's canonical set)
          # @return [TokenCollisions]
          def scan(root:, tokens: Tokens.load)
            root = Pathname.new(root)
            sources = SOURCE_GLOBS.flat_map { |glob| Dir.glob(root.join(glob).to_s) }.sort.uniq.filter_map do |path|
              relative = Pathname.new(path).relative_path_from(root).to_s
              next if EXCLUDED_PREFIXES.any? { |prefix| relative.start_with?(prefix) }

              [relative, File.read(path)]
            end
            new(sources: sources.to_h, tokens: tokens)
          end
        end

        # @param sources [Hash{String => String}] relative path => stylesheet text
        # @param tokens [Tokens] the poetry token set
        def initialize(sources:, tokens: Tokens.load)
          @sources = sources
          @tokens = tokens
        end

        # The bare token names poetry declares (`--radius` + every color role).
        #
        # @return [Array<String>]
        def token_names
          @token_names ||= ["--radius"] + @tokens.color_names("light").map { |name| "--#{name}" }
        end

        # The Tailwind theme keys poetry's mapping sets.
        #
        # @return [Array<String>]
        def theme_keys
          @theme_keys ||= Tokens::Generator::RADIUS_SCALE.keys.map { |step| "--radius-#{step}" } +
                          @tokens.color_names("light").map { |name| "--color-#{name}" }
        end

        # Every host declaration of a poetry name, in file then line order.
        #
        # @return [Array<Collision>]
        def collisions
          @collisions ||= @sources.flat_map do |path, css|
            strip_comments(css).each_line.with_index(1).flat_map do |text, line|
              text.scan(DECLARATION).flatten.filter_map do |name|
                kind = kind_of(name)
                Collision.new(name: name, path: path, line: line, kind: kind, role: role_for(name, kind)) if kind
              end
            end
          end
        end

        def ok?
          collisions.empty?
        end

        # The report a human reads: one line per collision plus the rule.
        #
        # @return [String]
        def to_text
          return "poetry tokens: none of your stylesheets declare a poetry token name" if ok?

          lines = collisions.map(&:to_s)
          lines << ""
          lines << "#{collisions.length} poetry token name(s) are already declared by this app. Poetry's " \
                   "values are defaults (tokens import into layer(theme); the theme mapping is @theme " \
                   "default), so yours win everywhere, poetry's components included. If a name means " \
                   "something else in your app, rename yours, or set poetry's meaning explicitly in " \
                   "app/assets/tailwind/poetry/design-overrides.css. A :root-only value also applies in " \
                   "dark mode; declare a .dark value beside it when the two should differ."
          lines.join("\n")
        end

        private

        def kind_of(name)
          if token_names.include?(name) then :token
          elsif theme_keys.include?(name) then :theme_key
          end
        end

        def role_for(name, kind)
          role = kind == :theme_key ? name.delete_prefix("--color-").delete_prefix("--") : name.delete_prefix("--")
          role = "radius" if role.start_with?("radius-")
          ROLE_USES.fetch(role) { "the #{role} role" }
        end

        # Comments never declare anything (the same discipline as
        # VarCoverage); newlines inside them are kept so line numbers hold.
        def strip_comments(css)
          css.gsub(%r{/\*.*?\*/}m) { |comment| comment.gsub(/[^\n]/, " ") }
        end

        private :theme_keys
      end
    end
  end
end
