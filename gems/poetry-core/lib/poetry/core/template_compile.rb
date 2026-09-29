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
        # @return [String, nil]
        def compile(source, filename: "template.html.erb")
          herb!

          begin
            Herb::Engine.new(source, filename: filename, validate_ruby: true, visitors: validators)
            nil
          rescue StandardError, SyntaxError => e
            # The engine raises its compile and parse errors as syntax
            # errors, which a bare rescue would let through.
            e.message
          end
        end

        # Compiles every template under root matching the globs.
        #
        # @return [Result] compiled (Integer, templates that compiled) + errors (Array<CompileError>)
        def check(root:, globs: DEFAULT_GLOBS)
          errors = []
          paths = globs.flat_map { |glob| Dir.glob(glob, base: root.to_s) }.uniq.sort
          paths.each do |relative|
            message = compile(File.read(File.join(root, relative)), filename: relative)
            errors << CompileError.new(relative, message) if message
          end
          Result.new(paths.size - errors.size, errors)
        end

        private

        # Every validator the engine ships, each one fatal. Built per
        # compile, since a validator keeps what it found.
        def validators
          Herb::Engine::Validators::ALL.values.map { |validator| validator.new(fatal: true) }
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
