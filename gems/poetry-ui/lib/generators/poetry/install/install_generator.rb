# frozen_string_literal: true

require "rails/generators"
require_relative "../agents_section"
require_relative "../skills_section"

module Poetry
  # `rails g poetry:install` - wires poetry into a host app:
  #
  #   app/assets/tailwind/poetry/tokens.css   the design tokens (:root + .dark),
  #                                           imported into layer(theme)
  #   app/assets/tailwind/poetry/theme.css    the Tailwind v4 @theme mapping
  #   app/assets/tailwind/poetry/animate.css  the vendored animation
  #                                           utility layer (Rails hosts
  #                                           have no npm)
  #   app/assets/tailwind/poetry/safelist.txt every dictionary + template class
  #                                           (so the host build never purges
  #                                           classes resolved in Ruby)
  #   config/initializers/poetry.rb           commented configuration
  #   config/poetry_components.yml            the copy-in manifest (empty)
  #
  # plus idempotent @import/@source injection into the host's Tailwind entry
  # (append-unless-present - re-running install is always safe; a line an
  # earlier version wrote in a superseded form is rewritten in place).
  #
  # Poetry's token names are the widely-distributed v4 names, and a host may
  # already own some of them. The install never takes a name over: the
  # tokens import into a cascade layer and the theme mapping is `@theme
  # default`, so a host declaration wins from either side of the import,
  # inside poetry's components too. The first step reports every such
  # name, so the share is a visible decision, not a surprise.
  #
  # `--charts` additionally wires poetry-charts (the gem must already be in
  # the bundle - its engine merges the @poetry/charts importmap pins and the
  # safelist pass picks the chart dictionaries up on its own; what a host
  # still needs by hand is the motion stylesheet in the Tailwind entry and
  # the Stimulus registration, and that is exactly what the flag does).
  #
  # @example
  #   bin/rails g poetry:install --theme vega
  class InstallGenerator < Rails::Generators::Base
    include Generators::AgentsSection
    include Generators::SkillsSection

    # The host's Tailwind entry stylesheet (import/@source injection).
    TAILWIND_ENTRY = "app/assets/tailwind/application.css"
    # The reset floor, vendored only for hosts that opted out of preflight.
    RESET_FILE = "app/assets/tailwind/poetry/reset.css"
    RESET_LINE = %(@import "./poetry/reset.css" layer(base);)
    # The theme slot: --theme swaps its CONTENT, the filename stays put.
    STYLE_SLOT = "app/assets/tailwind/poetry/style-default.css"
    # Every shipped fragment opens with `/* poetry <name> theme` - the sniff
    # reads the slot's first line back so a plain re-run keeps the theme.
    THEME_HEADER = %r{\A/\* poetry ([a-z0-9-]+) theme\b}

    class_option :charts, type: :boolean, default: false,
                          desc: %(Also wire poetry-charts (requires gem "poetry-charts" in the bundle))
    class_option :skip_bundle, type: :boolean, default: false,
                               desc: "Skip `bundle install` after adding the herb gem (poetry:check's parser)"
    # --no-preflight: the host imports Tailwind without preflight (its own
    # reset). Poetry's components lean on a handful of preflight's
    # normalizations, so the install vendors the reset floor - preflight at
    # zero specificity (lib/poetry/ui/reset_floor.rb) - and imports it
    # into layer(base) ahead of the theme; on a fresh entry it writes the
    # split no-preflight import. Remembered like the theme: a re-run keeps
    # vendoring the floor while reset.css is present.
    class_option :preflight, type: :boolean, default: true,
                             desc: "Pass --no-preflight when your Tailwind entry omits preflight: vendors poetry's " \
                                   "reset floor (poetry/reset.css) so the components keep their normalizations"

    # A Gemfile line declaring herb, in any quoting, at any indentation
    # (a `group :development do` block included).
    HERB_GEM_LINE = /^\s*gem\s+["']herb["']/

    # Install-time theme selection. Every themes/<name>.css fragment is
    # a complete visual theme; the chosen one fills the style-default.css
    # slot (the SLOT filename never changes - that keeps ENTRY_LINES
    # idempotent and makes switching themes a re-run with a different
    # --theme, overwriting in place). One theme per build; the multi-theme
    # .style-<name> wrapper arrives with the docs switcher, not here.
    #
    # The upgrade-path contract: the default is nil, not "default" -
    # a plain re-run sniffs the theme already in the slot and keeps it, so
    # upgrading (bundle update + re-run) never swaps an app's design. An
    # explicit --theme always wins; only a first install falls to "default".
    class_option :theme, type: :string, default: nil,
                         desc: "Visual theme fragment to install (a themes/<name>.css shipped by poetry-ui); " \
                               "defaults to the theme already installed, or \"default\" on a first install"

    # Injected line by line (not as one block) so a re-run after an upgrade
    # appends any line a previous poetry version didn't know about.
    ENTRY_LINES = [
      # layer(theme): any unlayered token the host declares beats poetry's,
      # whatever the order in the entry (the appended import used to land
      # after the host's own :root and take its brand colors over).
      %(@import "./poetry/tokens.css" layer(theme);),
      %(@import "./poetry/theme.css";),
      %(@import "./poetry/animate.css";),
      %(@import "./poetry/utilities.css";),
      %(@import "./poetry/aliases.css";),
      %(@import "./poetry/style-default.css" layer(base);),
      %(@import "./poetry/base.css";),
      %(@import "./poetry/typeset.css";),
      %(@source "./poetry/safelist.txt";)
    ].freeze

    # Entry lines earlier versions wrote, keyed to their current form: a
    # re-run rewrites them in place instead of appending a second import
    # (two tokens imports would let the old unlayered one win again).
    SUPERSEDED_ENTRY_LINES = {
      %(@import "./poetry/tokens.css";) => %(@import "./poetry/tokens.css" layer(theme);)
    }.freeze

    # The base layer (upstream's init writes the same defaults into the
    # host stylesheet):
    # without it body/border/outline don't ride the tokens and dark mode
    # only flips the components. Seeded once,
    # user-owned - re-install never overwrites.
    BASE_CSS = <<~CSS
      /* poetry base layer (source-parity defaults) - yours to edit. */
      @layer base {
        * {
          border-color: var(--border);
          outline-color: color-mix(in oklab, var(--ring) 50%, transparent);
        }
        body {
          background-color: var(--background);
          color: var(--foreground);
        }
      }
    CSS

    desc "Install poetry: tokens, Tailwind theme, safelist, initializer, and the component manifest"

    # Step: reports every poetry token name and theme key the host's own
    # stylesheets already declare. Never blocks - precedence (layer(theme)
    # + @theme default) makes the install safe - but the host reads, at
    # the moment the share is created, which of its values now reach
    # poetry's components and what those roles paint. Runs first, on the
    # host's files only (poetry's vendored directory is excluded), so a
    # re-run reports the same set. `bin/rails poetry:check` repeats it.
    # @api private
    def report_token_collisions
      scan = Poetry::Core::CSS::TokenCollisions.scan(root: destination_root)
      return if scan.ok?

      scan.collisions.each { |collision| say_status :token, collision.to_s, :yellow }
      say_status :note, scan.to_text.lines.last.strip, :yellow
    end

    # Step: a Tailwind entry that imports neither preflight nor the reset
    # floor is a host that removed preflight after installing, or before
    # installing without saying so - the components lose the
    # normalizations they lean on. Says so; never blocks (poetry:check
    # repeats it).
    # @api private
    def report_preflight
      return if floor?

      path = File.join(destination_root, TAILWIND_ENTRY)
      return unless File.exist?(path) && Poetry::Ui::ResetFloor.entry_state(File.read(path)) == :none

      say_status :preflight, "#{TAILWIND_ENTRY} imports Tailwind without preflight and without poetry's reset " \
                             "floor - re-run with --no-preflight to vendor the floor (the components lean on " \
                             "preflight's normalizations)", :yellow
    end

    # Fails fast BEFORE any file lands: --charts against a bundle without
    # the gem would otherwise half-install (css copied, dead registration).
    # @api private
    def verify_charts_gem
      return if !options[:charts] || charts_available?

      raise Thor::Error, "--charts needs poetry-charts in the bundle - add " \
                         '`gem "poetry-charts"` to the Gemfile, bundle, and re-run'
    end

    # Same fail-fast for --theme: an unknown name (or one poetry-charts
    # doesn't ship when --charts is on) must not half-install.
    # @api private
    def verify_theme_choice
      unless ui_theme_path.exist?
        available = Dir[Poetry::Ui.root.join("themes/*.css").to_s].map { |f| File.basename(f, ".css") }.sort
        raise Thor::Error, "unknown poetry theme #{resolved_theme.inspect} - poetry-ui ships: #{available.join(", ")}"
      end

      return if !options[:charts] || !charts_available? || charts_theme_path.exist?

      raise Thor::Error, "poetry-charts does not ship theme #{resolved_theme.inspect} - " \
                         "every installed poetry gem must provide themes/#{resolved_theme}.css"
    end

    # Step: copies tokens, the Tailwind theme mapping, the vendored css,
    # and the theme slot.
    # @api private
    def copy_tokens_and_theme
      create_file "app/assets/tailwind/poetry/tokens.css",
                  Poetry::Core.root.join("tokens/tokens.css").read, force: true
      create_file "app/assets/tailwind/poetry/theme.css",
                  Poetry::Core.root.join("tokens/tailwind-theme.css").read, force: true
      create_file "app/assets/tailwind/poetry/animate.css",
                  Poetry::Core.root.join("vendor/tw-animate-css/tw-animate.css").read, force: true
      # The upstream first-party utility layer (shimmer / scroll-fade
      # families + the chat-set keyframes), vendored verbatim at a pinned
      # SHA - provenance in THIRD_PARTY_NOTICES.md (host filename stays
      # utilities.css).
      create_file "app/assets/tailwind/poetry/utilities.css",
                  Poetry::Core.root.join("vendor/shadcn-tailwind/tailwind.css").read, force: true
      create_file "app/assets/tailwind/poetry/aliases.css",
                  Poetry::Core.root.join("tokens/aliases.css").read, force: true
      # The cn-* theme layer: the named-class design source, imported
      # layer(base) so host utilities always win. Vendored like tokens
      # (force) - a host restyles by overriding .cn-* rules in its OWN css
      # (any utilities-layer or unlayered rule beats layer(base)), never by
      # editing this file, so theme updates keep flowing on re-install.
      # --theme swaps the CONTENT; the slot filename stays put.
      create_file "app/assets/tailwind/poetry/style-default.css",
                  ui_theme_path.read, force: true
      # The reset floor: preflight at zero specificity, for hosts without
      # preflight (--no-preflight, remembered while the file is present).
      create_file RESET_FILE, Poetry::Ui.root.join(Poetry::Ui::ResetFloor::RELATIVE_PATH).read, force: true if floor?
      create_file "app/assets/tailwind/poetry/base.css", BASE_CSS, skip: true
      # poetry/typeset (the vendored prose-styling port - provenance in
      # THIRD_PARTY_NOTICES.md): prose styling for
      # rendered markdown. App-OWNED like base.css (skip, never force) -
      # the whole point of the artifact is that the file is yours to tune.
      create_file "app/assets/tailwind/poetry/typeset.css",
                  Poetry::Ui.root.join("typeset/typeset.css").read, skip: true
    end

    # Step: writes the dictionary + template-class safelist.
    # @api private
    def generate_safelist
      # Style.descendants is empty until the component classes load - under
      # `rails g` nothing has autoloaded them (the fresh-app proof caught
      # this; the dummy suite masked it by eager-loading first).
      Rails.application.eager_load!
      styles = Poetry::Core::Style.descendants.select(&:name)
      # Template-static classes (sr-only, animate-spin) come from the
      # COMMITTED list - herb-extracted and drift-gated in poetry's CI,
      # never required in a host (the browser pass caught the live-scan
      # skip purging them).
      safelist = Poetry::Core::CSS::Safelist.new(style_classes: styles,
                                                 template_classes: Poetry::Ui.template_classes)
      create_file "app/assets/tailwind/poetry/safelist.txt", safelist.text, force: true
    end

    # Step: injects the poetry @import/@source lines into the host's
    # Tailwind entry.
    # @api private
    def wire_tailwind_entry
      unless File.exist?(File.join(destination_root, TAILWIND_ENTRY))
        create_file TAILWIND_ENTRY, floor? ? Poetry::Ui::ResetFloor::NO_PREFLIGHT_ENTRY : %(@import "tailwindcss";\n)
      end
      SUPERSEDED_ENTRY_LINES.each { |old, current| replace_line(TAILWIND_ENTRY, old, current) }
      ENTRY_LINES.each { |line| inject_unless_present(TAILWIND_ENTRY, line) }
      # The floor imports into layer(base) AHEAD of the theme: its few
      # pseudo-element rules cannot be :where()-wrapped, and earlier in the
      # same layer loses a tie to the theme, as preflight would.
      inject_line_before(TAILWIND_ENTRY, RESET_LINE, %(@import "./poetry/style-default.css" layer(base);)) if floor?
    end

    # Step: writes the commented configuration initializer.
    # @api private
    def create_initializer
      create_file "config/initializers/poetry.rb", <<~RUBY, skip: true
        # frozen_string_literal: true

        # poetry configuration. Defaults shown commented.
        #
        # Poetry::Core::Config.current.css_mode = :tailwind   # or :bem (bring your own CSS)
        # Poetry::Core::Config.current.icon_library = :lucide
      RUBY
    end

    # Step: writes the empty copy-in manifest.
    # @api private
    def create_manifest
      create_file "config/poetry_components.yml", "components: {}\n", skip: true
    end

    # Pins alone don't register controllers: without this call every poetry
    # controller is dead JS (the browser pass caught the dialog trigger
    # doing nothing in a fresh host).
    # @api private
    def register_controllers
      index = "app/javascript/controllers/index.js"
      unless File.exist?(File.join(destination_root, index))
        say_status :note, "no #{index} - register poetry's controllers yourself: " \
                          "registerPoetryControllers(application) from \"@poetry/controllers\" " \
                          "(and registerPoetryAgent(application) from \"@poetry/agent\" " \
                          "when poetry-agent is bundled)", :yellow
        return
      end

      inject_unless_present(index, <<~JS.strip)
        import { registerPoetryControllers } from "@poetry/controllers"
        registerPoetryControllers(application)
      JS
      register_agent_runtime(index)
    end

    # --charts: the two host-side wires the charts engine cannot do itself.
    # The motion stylesheet is COPIED (tailwindcss-rails compiles standalone;
    # a gem-path @import would not resolve) - vendored artifact, force like
    # tokens; the entry @import and the Stimulus registration ride the same
    # idempotent primitives as the core wiring.
    # @api private
    def wire_charts
      return unless options[:charts]

      create_file "app/assets/tailwind/poetry/charts.css",
                  Poetry::Charts.root.join("app/assets/stylesheets/poetry-charts.css").read,
                  force: true
      inject_unless_present(TAILWIND_ENTRY, %(@import "./poetry/charts.css";))
      # The charts cn-* theme fragment - vendored like style-default,
      # same --theme selection.
      create_file "app/assets/tailwind/poetry/style-charts.css",
                  charts_theme_path.read, force: true
      inject_unless_present(TAILWIND_ENTRY, %(@import "./poetry/style-charts.css" layer(base);))

      index = "app/javascript/controllers/index.js"
      unless File.exist?(File.join(destination_root, index))
        say_status :note, "no #{index} - register the chart controllers yourself: " \
                          "registerPoetryChartsControllers(application) from \"@poetry/charts\"", :yellow
        return
      end

      inject_unless_present(index, <<~JS.strip)
        import { registerPoetryChartsControllers } from "@poetry/charts"
        registerPoetryChartsControllers(application)
      JS
    end

    # poetry:check parses ERB with herb, which stays out of poetry's runtime
    # dependencies on purpose (hosts never need it to render), so the
    # install adds it to the development group - once, and never when the
    # Gemfile already declares it anywhere. Then `bundle install`, unless
    # --skip-bundle (the note says what is left to do).
    # @api private
    def add_herb_gem
      gemfile = File.join(destination_root, "Gemfile")
      return unless File.exist?(gemfile)

      if gemfile_sources(gemfile).any? { |source| source.match?(HERB_GEM_LINE) }
        say_status :skip, "herb is already in the Gemfile (poetry:check's parser)", :cyan
        return
      end

      gem "herb", group: :development, comment: "poetry:check parses ERB with herb (development only)"
      if options[:skip_bundle]
        say_status :note, "run `bundle install` to fetch herb before `bin/rails poetry:check`", :cyan
      else
        in_root { Bundler.with_unbundled_env { run "bundle install" } }
      end
    end

    # The llms.txt / llms-full.txt agent docs are engine routes - without
    # the mount they are unreachable (the fresh-app proof caught this).
    # @api private
    def mount_engine
      routes = File.join(destination_root, "config/routes.rb")
      return unless File.exist?(routes)
      return if File.read(routes).include?("Poetry::Ui::Engine")

      route %(mount Poetry::Ui::Engine => "/poetry" # llms.txt + llms-full.txt (agent-facing docs))
    end

    # The AGENTS.md pointer section - marker-bounded so a re-run
    # refreshes it in place. Standalone refresh: `rails g poetry:agents`.
    # @api private
    def write_agents_md
      apply_agents_section
    end

    # The Claude Code skills - part of the standard
    # install surface, like AGENTS.md. Standalone refresh:
    # `rails g poetry:skill` (re-run after updating poetry gems).
    # @api private
    def write_skills
      apply_poetry_skills
    end

    # Dark mode is one layout line, but nothing else in the install touches
    # the layout - without the pointer the theme never applies before first
    # paint and hosts rediscover the flash-of-light-mode pothole.
    # @api private
    def announce_color_scheme
      say_status :note, "dark mode: render <%= poetry_color_scheme_script %> in your layout <head> " \
                        "(the Theming guide, \"Color scheme\")", :cyan
    end

    # poetry_optimistic_form reconciles failures via a Turbo refresh, which
    # must MORPH to be seamless - two layout metas the install cannot add
    # for the host (the redirect trap and server contract live in
    # the doc).
    # @api private
    def announce_optimistic_form
      say_status :note, "optimistic forms: add <meta name=\"turbo-refresh-method\" content=\"morph\"> " \
                        "+ <meta name=\"turbo-refresh-scroll\" content=\"preserve\"> to your layout " \
                        "<head> before using poetry_optimistic_form (the Optimistic Forms guide)", :cyan
    end

    private

    # Whether this install vendors the reset floor: asked for now, or
    # installed by an earlier run (the file is present).
    def floor?
      options[:preflight] == false || File.exist?(File.join(destination_root, RESET_FILE))
    end

    def resolved_theme
      @resolved_theme ||= options[:theme] || installed_theme || "default"
    end

    # Which theme fills the slot right now. Unreadable header (a
    # hand-edited file, or an install predating theme selection) falls back
    # to "default" WITH a warning - never silently.
    def installed_theme
      path = File.join(destination_root, STYLE_SLOT)
      return nil unless File.exist?(path)

      name = File.foreach(path).first.to_s[THEME_HEADER, 1]
      if name.nil?
        say_status :theme, "could not identify the installed theme from #{STYLE_SLOT} - " \
                           "installing \"default\" (pass --theme <name> to keep yours)", :yellow
      elsif name != "default"
        say_status :theme, "keeping installed theme #{name.inspect} (pass --theme to switch)", :cyan
      end
      name
    end

    def charts_available?
      defined?(Poetry::Charts::Engine) ? true : false
    end

    def agent_available?
      defined?(Poetry::Agent::Engine) ? true : false
    end

    # poetry-agent's WebMCP runtime registers beside the controllers when
    # the gem is bundled (the engine already pins @poetry/agent); without
    # it, `webmcp:` opt-ins have nothing to register with. Private: Thor
    # would otherwise expose an argument-taking method as a command.
    def register_agent_runtime(index)
      return unless agent_available?

      inject_unless_present(index, <<~JS.strip)
        import { registerPoetryAgent } from "@poetry/agent"
        registerPoetryAgent(application)
      JS
    end

    # The Gemfile's text plus every file it pulls in with eval_gemfile (a
    # shared Gemfile.shared, a family Gemfile) - a gem declared there is
    # declared, and the install must not add it a second time.
    def gemfile_sources(gemfile)
      text = File.read(gemfile)
      pattern = /^\s*eval_gemfile\s+(?:File\.expand_path\()?["']([^"']+)["']/
      evaluated = text.scan(pattern).flatten.filter_map do |relative|
        path = File.expand_path(relative, File.dirname(gemfile))
        File.read(path) if File.exist?(path)
      end
      [text] + evaluated
    end

    def ui_theme_path
      Poetry::Ui.root.join("themes/#{resolved_theme}.css")
    end

    def charts_theme_path
      Poetry::Charts.root.join("themes/#{resolved_theme}.css")
    end

    # The idempotency lives in the file-mutation primitive, not the
    # generator: appending is a no-op when
    # the line is already present.
    def inject_unless_present(relative, line)
      path = File.join(destination_root, relative)
      return if File.exist?(path) && File.read(path).include?(line)

      append_to_file relative, "#{line}\n"
    end

    # Injects a line before an anchor line (appends when the anchor is
    # absent); a no-op when the line is already present.
    def inject_line_before(relative, line, anchor)
      path = File.join(destination_root, relative)
      return if File.exist?(path) && File.read(path).include?(line)

      if File.exist?(path) && File.read(path).include?(anchor)
        inject_into_file relative, "#{line}\n", before: anchor
      else
        append_to_file relative, "#{line}\n"
      end
    end

    # Rewrites one superseded entry line in place (whole line, so the
    # current form - which contains the old one's prefix - is never touched).
    def replace_line(relative, old, current)
      path = File.join(destination_root, relative)
      return unless File.exist?(path)

      pattern = /^#{Regexp.escape(old)}[ \t]*$/
      return unless File.read(path).match?(pattern)

      gsub_file relative, pattern, current
    end
  end
end
