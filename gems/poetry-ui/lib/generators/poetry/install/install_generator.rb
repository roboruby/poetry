# frozen_string_literal: true

require "rails/generators"

module Poetry
  # `rails g poetry:install` - wires poetry into a host app (M8):
  #
  #   app/assets/tailwind/poetry/tokens.css   the design tokens (:root + .dark)
  #   app/assets/tailwind/poetry/theme.css    the Tailwind v4 @theme mapping
  #   app/assets/tailwind/poetry/animate.css  vendored tw-animate-css (the
  #                                           shadcn v4 animation layer -
  #                                           Rails hosts have no npm)
  #   app/assets/tailwind/poetry/safelist.txt every dictionary + template class
  #                                           (so the host build never purges
  #                                           classes resolved in Ruby)
  #   config/initializers/poetry.rb           commented configuration
  #   config/poetry_components.yml            the copy-in manifest (empty)
  #
  # plus idempotent @import/@source injection into the host's Tailwind entry
  # (append-unless-present - re-running install is always safe).
  class InstallGenerator < Rails::Generators::Base
    TAILWIND_ENTRY = "app/assets/tailwind/application.css"

    # Injected line by line (not as one block) so a re-run after an upgrade
    # appends any line a previous poetry version didn't know about.
    ENTRY_LINES = [
      %(@import "./poetry/tokens.css";),
      %(@import "./poetry/theme.css";),
      %(@import "./poetry/animate.css";),
      %(@import "./poetry/utilities.css";),
      %(@import "./poetry/aliases.css";),
      %(@import "./poetry/base.css";),
      %(@source "./poetry/safelist.txt";)
    ].freeze

    # The shadcn base layer (its init writes the same into globals.css):
    # without it body/border/outline don't ride the tokens and dark mode
    # only flips the components (2026-07-01 browser pass). Seeded once,
    # user-owned - re-install never overwrites.
    BASE_CSS = <<~CSS
      /* poetry base layer (shadcn-parity defaults) - yours to edit. */
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

    def copy_tokens_and_theme
      create_file "app/assets/tailwind/poetry/tokens.css",
                  Poetry::Core.root.join("tokens/tokens.css").read, force: true
      create_file "app/assets/tailwind/poetry/theme.css",
                  Poetry::Core.root.join("tokens/tailwind-theme.css").read, force: true
      create_file "app/assets/tailwind/poetry/animate.css",
                  Poetry::Core.root.join("vendor/tw-animate-css/tw-animate.css").read, force: true
      # shadcn's first-party utility layer (shimmer / scroll-fade families +
      # the chat-set keyframes), vendored verbatim at a pinned SHA (N1).
      # N6: vendored source moved to shadcn/tailwind.css @ d0fae528 (host filename stays utilities.css).
      create_file "app/assets/tailwind/poetry/utilities.css",
                  Poetry::Core.root.join("vendor/shadcn-tailwind/tailwind.css").read, force: true
      create_file "app/assets/tailwind/poetry/aliases.css",
                  Poetry::Core.root.join("tokens/aliases.css").read, force: true
      create_file "app/assets/tailwind/poetry/base.css", BASE_CSS, skip: true
    end

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

    def wire_tailwind_entry
      unless File.exist?(File.join(destination_root, TAILWIND_ENTRY))
        create_file TAILWIND_ENTRY, %(@import "tailwindcss";\n)
      end
      ENTRY_LINES.each { |line| inject_unless_present(TAILWIND_ENTRY, line) }
    end

    def create_initializer
      create_file "config/initializers/poetry.rb", <<~RUBY, skip: true
        # frozen_string_literal: true

        # poetry configuration. Defaults shown commented.
        #
        # Poetry::Core::Config.current.css_mode = :tailwind   # or :bem (bring your own CSS)
        # Poetry::Core::Config.current.icon_library = :lucide
      RUBY
    end

    def create_manifest
      create_file "config/poetry_components.yml", "components: {}\n", skip: true
    end

    # Pins alone don't register controllers: without this call every poetry
    # controller is dead JS (the browser pass caught the dialog trigger
    # doing nothing in a fresh host).
    def register_controllers
      index = "app/javascript/controllers/index.js"
      unless File.exist?(File.join(destination_root, index))
        say_status :note, "no #{index} - register poetry's controllers yourself: " \
                          "registerPoetryControllers(application) from \"@poetry/controllers\"", :yellow
        return
      end

      inject_unless_present(index, <<~JS.strip)
        import { registerPoetryControllers } from "@poetry/controllers"
        registerPoetryControllers(application)
      JS
    end

    # The llms.txt / llms-full.txt agent docs are engine routes - without
    # the mount they are unreachable (the fresh-app proof caught this).
    def mount_engine
      routes = File.join(destination_root, "config/routes.rb")
      return unless File.exist?(routes)
      return if File.read(routes).include?("Poetry::Ui::Engine")

      route %(mount Poetry::Ui::Engine => "/poetry" # llms.txt + llms-full.txt (agent-facing docs))
    end

    private

    # The idempotency lives in the file-mutation primitive, not the
    # generator (the vite_ruby review lesson): appending is a no-op when
    # the line is already present.
    def inject_unless_present(relative, line)
      path = File.join(destination_root, relative)
      return if File.exist?(path) && File.read(path).include?(line)

      append_to_file relative, "#{line}\n"
    end
  end
end
