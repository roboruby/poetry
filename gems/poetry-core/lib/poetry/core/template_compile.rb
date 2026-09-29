# frozen_string_literal: true

module Poetry
  module Core
    # The Herb COMPILE gate: every ERB template is fed through
    # `Herb::Engine` - the compiler Rails routes HTML templates through
    # under its 8.2 framework defaults - so a template that parses but
    # refuses to compile (ERB output in an attribute name, bare output in
    # attribute position, an element nested where the validators forbid it)
    # fails poetry's CI instead of the host's first request.
    #
    # The posture is the strictest one a host can run. The engine validates
    # nothing unless it is handed validators, so the gate hands it every
    # validator it ships, each one fatal, and has the compiled Ruby checked
    # for syntax. Rails compiles without validators and its `herb:check`
    # task adds the security one; a host that compiles gem templates with
    # every validator raising is the far end. A template that passes here
    # passes all of them. The validators are named in code, never read from
    # `.herb.yml`, so no configuration can hollow the gate.
    #
    # A second posture, `:rails`, is the one `bin/rails herb:check` holds an
    # app's views to: the security validator alone. `poetry:check` compiles
    # component templates in it, since that task walks the view paths and
    # never reaches them.
    #
    # Parsing clean (see CSS::TemplateClasses, the parse gate) and
    # compiling clean are different contracts: the validators refuse shapes
    # the parser accepts.
    #
    # Herb is loaded lazily: it is a build/CI-time tool, not a runtime
    # dependency of the gem.
    #
    # @example
    #   result = Poetry::Core::TemplateCompile.check(root: Poetry::Core.root)
    #   result.errors # => [] when every template compiles
    #
    # @api private
    class TemplateCompile
      # The templates a gem ships: its components + the generator templates
      # copied verbatim into hosts. Rails renders both through the engine.
      DEFAULT_GLOBS = ["app/**/*.erb", "lib/generators/**/templates/**/*.erb"].freeze

      # The oldest Herb the gate runs on: from this version the engine takes
      # its validators as visitors and raises compile errors as syntax errors.
      MINIMUM_HERB = "0.11.0"

      # The validators of each posture, by their names in the engine.
      POSTURES = {
        strict: %i[security nesting accessibility render generator_template],
        rails: %i[security]
      }.freeze

      # A template the engine refused: its message, and the line the engine
      # points at when it names one.
      Failure = Struct.new(:message, :line)

      # A template Herb's engine could not compile, with its message.
      CompileError = Struct.new(:path, :message) do
        # The path and the message.
        def to_s
          "#{path}: #{message}"
        end
      end

      # The compiled count and the errors met.
      Result = Struct.new(:compiled, :errors)

      class << self
        # Compiles one ERB source string, returning the engine's error
        # message or nil when it compiles. A missing or outdated herb gem
        # raises instead: that is a broken setup, not a finding about the
        # template.
        #
        # @param source [String] the template
        # @param filename [String] the path the engine opens its message with
        # @param posture [Symbol] :strict or :rails
        # @return [String, nil]
        def compile(source, filename: "template.html.erb", posture: :strict)
          failure(source, filename: filename, posture: posture)&.message
        end

        # Compiles one ERB source string, returning what the engine refused
        # it for, or nil when it compiles.
        #
        # @param source [String] the template
        # @param filename [String] the path the engine opens its message with
        # @param posture [Symbol] :strict or :rails
        # @return [Failure, nil]
        def failure(source, filename: "template.html.erb", posture: :strict)
          herb!
          visitors = validators(posture)

          begin
            Herb::Engine.new(source, filename: filename, validate_ruby: true, visitors: visitors)
            nil
          rescue StandardError, SyntaxError => e
            # The engine raises its compile and parse errors as syntax
            # errors, which a bare rescue would let through.
            Failure.new(e.message, line_of(e))
          end
        end

        # Compiles every template under root matching the globs.
        #
        # @param root [String, Pathname] the directory the globs are read under
        # @param globs [Array<String>] the templates to compile
        # @param posture [Symbol] :strict or :rails
        # @return [Result] compiled (Integer, templates that compiled) + errors (Array<CompileError>)
        def check(root:, globs: DEFAULT_GLOBS, posture: :strict)
          errors = []
          paths = globs.flat_map { |glob| Dir.glob(glob, base: root.to_s) }.uniq.sort
          paths.each do |relative|
            message = compile(File.read(File.join(root, relative)), filename: relative, posture: posture)
            errors << CompileError.new(relative, message) if message
          end
          Result.new(paths.size - errors.size, errors)
        end

        private

        # The validators of a posture, each one fatal. Built per compile,
        # since a validator keeps what it found. The strict posture is every
        # validator the engine ships, so one a later release adds joins it.
        def validators(posture = :strict)
          names = POSTURES.fetch(posture) do
            raise ArgumentError, "unknown posture #{posture.inspect} - one of #{POSTURES.keys.join(", ")}"
          end
          shipped = Herb::Engine::Validators::ALL
          chosen = posture == :strict ? shipped.values : shipped.values_at(*names)
          chosen.map { |validator| validator.new(fatal: true) }
        end

        # The line an engine error points at: a validator's error carries
        # it, a parse error carries it on its first diagnostic.
        def line_of(error)
          return error.line if error.respond_to?(:line) && error.line
          return unless error.respond_to?(:diagnostics)

          location = error.diagnostics.first&.location
          location&.start&.line
        end

        # Requires the herb gem with its engine and validators, raising a
        # clear error when the gem is missing or too old for the gate.
        def herb!
          begin
            require "herb"
          rescue LoadError
            raise Poetry::Core::Error,
                  "the herb gem is required for the template compile gate - add `gem \"herb\"` to your Gemfile"
          end

          unless supported?(Herb::VERSION)
            raise Poetry::Core::Error,
                  "the template compile gate needs herb #{MINIMUM_HERB} or newer, found #{Herb::VERSION} - " \
                  "run `bundle update herb`"
          end

          require "herb/engine"
          require "herb/engine/validators"
        end

        # Whether a herb version carries the engine the gate is written for.
        def supported?(version)
          Gem::Version.new(version) >= Gem::Version.new(MINIMUM_HERB)
        end
      end
    end
  end
end
