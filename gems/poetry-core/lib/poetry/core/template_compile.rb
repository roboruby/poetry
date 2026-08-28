# frozen_string_literal: true

module Poetry
  module Core
    # The Herb COMPILE gate: every ERB template is fed through
    # `Herb::Engine` - the same compiler Rails routes templates through when
    # a host opts into the Herb ERB implementation - so a template that
    # parses but refuses to compile (ERB output in an attribute name, bare
    # output in attribute position, an element nested where the validators
    # forbid it) fails poetry's CI instead of the host's first request.
    #
    # Parsing clean (see CSS::TemplateClasses, the parse gate) and
    # compiling clean are different contracts: the engine runs validators
    # the parser does not.
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

      CompileError = Struct.new(:path, :message) do
        def to_s
          "#{path}: #{message}"
        end
      end

      Result = Struct.new(:compiled, :errors)

      class << self
        # Compiles one ERB source string, returning the engine's error
        # message or nil when it compiles.
        #
        # @return [String, nil]
        def compile(source, filename: "template.html.erb")
          herb!
          Herb::Engine.new(source, filename: filename)
          nil
        rescue StandardError => e
          e.message
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

        def herb!
          require "herb"
        rescue LoadError
          raise Poetry::Core::Error,
                "the herb gem is required for the template compile gate - add `gem \"herb\"` to your Gemfile"
        end
      end
    end
  end
end
