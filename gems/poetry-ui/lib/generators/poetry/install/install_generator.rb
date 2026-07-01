# frozen_string_literal: true

require "rails/generators"

module Poetry
  # `rails g poetry:install` - wires poetry into a host app (M8):
  #
  #   app/assets/tailwind/poetry/tokens.css   the design tokens (:root + .dark)
  #   app/assets/tailwind/poetry/theme.css    the Tailwind v4 @theme mapping
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

    desc "Install poetry: tokens, Tailwind theme, safelist, initializer, and the component manifest"

    def copy_tokens_and_theme
      create_file "app/assets/tailwind/poetry/tokens.css",
                  Poetry::Core.root.join("tokens/tokens.css").read, force: true
      create_file "app/assets/tailwind/poetry/theme.css",
                  Poetry::Core.root.join("tokens/tailwind-theme.css").read, force: true
    end

    def generate_safelist
      styles = Poetry::Core::Style.descendants.select(&:name)
      safelist = Poetry::Core::CSS::Safelist.new(style_classes: styles)
      create_file "app/assets/tailwind/poetry/safelist.txt", safelist.text, force: true
    end

    def wire_tailwind_entry
      unless File.exist?(File.join(destination_root, TAILWIND_ENTRY))
        create_file TAILWIND_ENTRY, %(@import "tailwindcss";\n)
      end
      inject_unless_present(TAILWIND_ENTRY, <<~CSS)
        @import "./poetry/tokens.css";
        @import "./poetry/theme.css";
        @source "./poetry/safelist.txt";
      CSS
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

    private

    # The idempotency lives in the file-mutation primitive, not the
    # generator (the vite_ruby review lesson): appending is a no-op when
    # the block is already present.
    def inject_unless_present(relative, block)
      path = File.join(destination_root, relative)
      return if File.exist?(path) && File.read(path).include?(block.lines.first.strip)

      append_to_file relative, "\n#{block}"
    end
  end
end
