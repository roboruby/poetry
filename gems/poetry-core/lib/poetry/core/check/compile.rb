# frozen_string_literal: true

module Poetry
  module Core
    module Check
      # The compile tier for component templates: each one is compiled
      # under Herb the way `bin/rails herb:check` compiles an app's views.
      #
      # Rails renders HTML templates through Herb under its 8.2 framework
      # defaults, and its check task tells an app which views will not
      # compile. That task walks the view paths. A template that sits
      # beside its component lives outside them, so nothing reaches it
      # before the page that renders the component does. Rails checks
      # views, this checks components: the app's own, and the ones the gems
      # in the boot ship.
      #
      # The severity follows the app. One that renders through Herb has the
      # template fail where it is used, which is an error. One that renders
      # through Erubi renders it as it always has, so the finding is a
      # WARNING about the day the app adopts the defaults.
      #
      # @api private
      class Compile
        # The rule the findings carry.
        RULE = "herb-compile"

        # The HTML templates of the components under a root, variants
        # included. Rails compiles no other format through Herb.
        GLOB = "app/components/**/*.html{,+*}.erb"

        # A component's HTML template by convention: a file under
        # `app/components/` in the HTML format, with or without a variant.
        HTML_TEMPLATE = %r{(?:\A|/)app/components/.+\.html(?:\+[\w-]+)?\.erb\z}

        # The path, line and column the engine opens a message with.
        LOCATION = /\A:\d+:\d+(?::| -) /

        class << self
          # Whether a path is a component's HTML template by convention.
          #
          # @param path [String]
          # @return [Boolean]
          def html_template?(path)
            HTML_TEMPLATE.match?(path.to_s)
          end

          # Why the tier cannot run, or nil when it can: the herb gem is
          # missing, or older than the engine the gate is written for.
          #
          # @return [String, nil]
          def unavailable
            TemplateCompile.compile("")
            nil
          rescue Poetry::Core::Error => e
            e.message
          end

          # Whether the booted app compiles its HTML templates with Herb:
          # the handler registered for ERB hands them to the engine, or
          # Rails' own implementation switch names it.
          #
          # @return [Boolean]
          def rendering?
            return false unless defined?(::Herb::Engine) && defined?(::ActionView::Template)

            handler = ::ActionView::Template.handler_for_extension(:erb)
            owner = handler.is_a?(Module) ? handler : handler.class
            return true if defined?(::ReActionView::Template::Handlers::ERB) &&
                           owner <= ::ReActionView::Template::Handlers::ERB

            implementation = owner.erb_implementation if owner.respond_to?(:erb_implementation)
            implementation.is_a?(Class) && implementation <= ::Herb::Engine
          end
        end

        # A compile tier for an app.
        #
        # @param rendering [Boolean] whether the app renders its HTML
        #   templates through Herb, which makes a finding an error
        def initialize(rendering: false)
          @rendering = rendering
        end

        # The finding for one template, when the engine refuses it.
        #
        # @param source [String] the template
        # @param filename [String] its path, which the engine's message opens with
        # @param shipped [Boolean] whether the template ships in a gem
        # @return [Array<Finding>]
        def lint(source, filename:, shipped: false)
          failure = TemplateCompile.failure(source, filename: filename.to_s, posture: :rails)
          return [] unless failure

          [Finding.new(rule: RULE, severity: @rendering ? :error : :warning, line: failure.line,
                       message: message(failure, filename.to_s, shipped))]
        end

        # The findings for the component templates the roots ship, each
        # stamped with its file. A template that cannot be read is skipped:
        # the render that needs it reports that better than a lint can.
        #
        # @param roots [Array<String, Pathname>] gem roots
        # @return [Array<Finding>]
        def scan(roots)
          roots.flat_map do |root|
            Dir.glob(GLOB, base: root.to_s).sort.flat_map do |relative|
              path = File.join(root.to_s, relative)
              lint(File.read(path, encoding: "UTF-8"), filename: path, shipped: true)
                .each { |finding| finding.file = path }
            rescue SystemCallError, IOError, ArgumentError, Encoding::CompatibilityError
              []
            end
          end
        end

        private

        # The finding's sentence: the compiler, the engine's reason
        # without the path it opens with, and what fixes a shipped template.
        def message(failure, filename, shipped)
          compiler = @rendering ? "this app renders with" : "Rails 8.2 renders with by default"
          text = "does not compile under Herb, the compiler #{compiler}: #{reason(failure, filename)}"
          return text unless shipped

          "#{text} - the template ships in a gem: update the gem, or hold herb at the version it was " \
            "checked against (the bundle resolves herb #{Herb::VERSION})"
        end

        # The engine's message on one line, without its location prefix.
        def reason(failure, filename)
          first = failure.message.to_s.each_line.map(&:strip).reject(&:empty?).first.to_s
          first.delete_prefix(filename).sub(LOCATION, "")
        end
      end
    end
  end
end
