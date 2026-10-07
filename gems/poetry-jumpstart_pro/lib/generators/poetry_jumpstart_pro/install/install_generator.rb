# frozen_string_literal: true

require "rails/generators"
require "poetry/jumpstart_pro"

module PoetryJumpstartPro
  # `rails g poetry_jumpstart_pro:install [categories...]`
  #
  # Re-skins a Jumpstart Pro app with Poetry. It copies Poetry recreations of
  # Jumpstart's views into the host's app/views/, where Rails resolves them
  # ahead of the Jumpstart engine's originals, then wires what those views
  # lean on:
  #
  #   - the stylesheet reconciliation (Poetry::JumpstartPro::Stylesheets),
  #     so Jumpstart's global CSS stops overriding Poetry's components
  #   - Poetry itself (`poetry:install`) when the app does not have it yet
  #   - app/helpers/poetry_jumpstart_pro_helper.rb, the pagination and toast
  #     adapters
  #   - Poetry's styles on the Madmin pages, with the madmin category
  #   - the selectors of Jumpstart's own tests that assert on the replaced
  #     markup (Poetry::JumpstartPro::TestEdits)
  #
  # Views are verbatim copies (copy_file, never template), so the ERB is the
  # exact runtime view. In development Jumpstart copies a few default views
  # into app/views on boot (the layout, _head, the left and right nav, the
  # dashboard, the landing and about pages, the agreements); a copy still
  # identical to the engine's view is replaced without asking, and one the
  # app has edited prompts like any Rails generator conflict. Every step is
  # idempotent, so re-running after an upgrade is safe.
  #
  # @example Install every category
  #   rails g poetry_jumpstart_pro:install
  # @example Install the sign in screens and the app shell only
  #   rails g poetry_jumpstart_pro:install auth shell
  class InstallGenerator < Rails::Generators::Base
    source_root File.expand_path("templates", __dir__)

    # The host helper the views call, copied once and then the host's own.
    HELPER = File.expand_path("files/poetry_jumpstart_pro_helper.rb", __dir__)

    # The file whose presence means `poetry:install` has run.
    POETRY_TOKENS = "app/assets/tailwind/poetry/tokens.css"
    # The Tailwind entry, which imports the tokens once the install finished.
    TAILWIND_ENTRY = "app/assets/tailwind/application.css"
    # Where a Jumpstart Pro app keeps the engine's own views.
    ENGINE_VIEWS = "lib/jumpstart/app/views"

    # Madmin's initializer and the line that adds the app stylesheet to it.
    MADMIN_INITIALIZER = "config/initializers/madmin.rb"
    # Appended to the Madmin initializer for the madmin category.
    MADMIN_STYLESHEET = %(Madmin.stylesheets << "tailwind")

    argument :categories, type: :array, default: Poetry::JumpstartPro::CATEGORIES,
                          banner: "category ..."

    class_option :theme, type: :string, default: nil,
                         desc: "The Poetry theme for `poetry:install` when Poetry is not installed yet"
    class_option :skip_poetry_install, type: :boolean, default: false,
                                       desc: "Do not run `poetry:install`, even when Poetry is missing"
    class_option :skip_stylesheets, type: :boolean, default: false,
                                    desc: "Leave Jumpstart's stylesheets untouched"
    class_option :skip_tests, type: :boolean, default: false,
                              desc: "Leave the selectors in Jumpstart's own tests untouched"

    desc "Re-skin a Jumpstart Pro app's views with Poetry components"

    # Step: reconciles Jumpstart's stylesheets with Poetry's, before
    # `poetry:install` so its token report starts from the reconciled files
    # (Thor task).
    # @api private
    def reconcile_stylesheets
      return if installed.empty? || options[:skip_stylesheets]

      Poetry::JumpstartPro::Stylesheets::FILES.each do |relative, edit|
        path = File.join(destination_root, relative)
        next say_status(:missing, relative, :yellow) unless File.exist?(path)

        before = File.read(path)
        after = Poetry::JumpstartPro::Stylesheets.public_send(edit, before)
        next say_status(:identical, relative, :blue) if after == before

        File.write(path, after) unless options[:pretend]
        say_status :reconcile, relative, :green
      end
    end

    # Step: runs `poetry:install` when the app has no Poetry yet (Thor task).
    # @api private
    def install_poetry
      return if poetry_installed?

      theme = options[:theme] ? ["--theme", options[:theme]] : []
      return generate("poetry:install", *theme) unless options[:skip_poetry_install]

      say_status :poetry, "not installed - run `bin/rails g poetry:install` before using these views", :yellow
    end

    # Step: copies each requested category's view overrides (Thor task).
    # @api private
    def install_categories
      categories.each do |category|
        unless Poetry::JumpstartPro::CATEGORIES.include?(category)
          say_status :skip, "unknown category #{category.inspect} " \
                            "(available: #{Poetry::JumpstartPro::CATEGORIES.join(", ")})", :yellow
          next
        end
        copy_category(category)
      end
    end

    # Step: copies the pagination and toast adapters the views call (Thor task).
    # @api private
    def install_helper
      return if installed.empty?

      copy_file HELPER, "app/helpers/poetry_jumpstart_pro_helper.rb"
    end

    # Step: adds the app stylesheet to Madmin's pages, for the madmin
    # category (Thor task).
    # @api private
    def style_madmin
      return unless installed.include?("madmin")

      path = File.join(destination_root, MADMIN_INITIALIZER)
      return say_status(:missing, MADMIN_INITIALIZER, :yellow) unless File.exist?(path)
      return say_status(:identical, MADMIN_INITIALIZER, :blue) if File.read(path).include?(MADMIN_STYLESHEET)

      append_to_file MADMIN_INITIALIZER,
                     "\n# Poetry's styles on the admin pages poetry-jumpstart_pro re-skinned.\n#{MADMIN_STYLESHEET}\n"
    end

    # Step: updates the selectors in Jumpstart's own tests that assert on the
    # markup the installed views replace (Thor task).
    # @api private
    def update_tests
      return if options[:skip_tests]

      Poetry::JumpstartPro::TestEdits.for(installed).each do |edit|
        path = File.join(destination_root, edit.file)
        next unless File.exist?(path) && edit.applies_to?(File.read(path))

        gsub_file edit.file, edit.pattern, edit.replacement
      end
    end

    # Step: prints the post-install checklist (Thor task).
    # @api private
    def next_steps
      return if installed.empty?

      say ""
      say "poetry-jumpstart_pro installed #{installed.join(", ")} as overrides in app/views/.", :green
      say "  1. Rebuild the CSS:  bin/rails tailwindcss:build"
      say "  2. Check the views:  bin/rails poetry:check"
      say "  3. Run your tests:   bin/rails test && bin/rails test:system"
      say "Every installed file is yours to edit. Delete an override to fall back to Jumpstart's view."
    end

    private

    # The requested categories this gem knows.
    def installed
      categories & Poetry::JumpstartPro::CATEGORIES
    end

    # Whether `poetry:install` has run to the end in the host: the tokens
    # are vendored and the Tailwind entry imports them.
    def poetry_installed?
      entry = File.join(destination_root, TAILWIND_ENTRY)
      File.exist?(File.join(destination_root, POETRY_TOKENS)) &&
        File.exist?(entry) && File.read(entry).include?("poetry/tokens.css")
    end

    # Whether the host's copy of a view is Jumpstart's default, unedited: the
    # file the engine copies in on a development boot.
    def jumpstart_default?(view)
      host = File.join(destination_root, view)
      original = File.join(destination_root, ENGINE_VIEWS, view.delete_prefix("app/views/"))
      File.exist?(host) && File.exist?(original) && File.binread(host) == File.binread(original)
    end

    # Mirror templates/<category>/**/* onto app/views/**/*, stripping the
    # category prefix (the template tree already mirrors the view tree).
    def copy_category(category)
      base = File.join(self.class.source_root, category)
      Dir.glob("#{base}/**/*").select { |path| File.file?(path) }.sort.each do |source|
        relative = source.delete_prefix("#{base}/")
        view = File.join("app/views", relative)
        # Only ever force: an explicit false would override a --force given
        # on the command line, since Thor merges this over the options.
        copy_file File.join(category, relative), view, **(jumpstart_default?(view) ? { force: true } : {})
      end
    end
  end
end
