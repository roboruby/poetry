# frozen_string_literal: true

module Poetry
  module Core
    # The pluggable icon-set registry (: Lucide default, per-set
    # adapters). An icon set is anything responding to #include?(name),
    # #fetch(name) -> inner SVG markup, and #names. Sets register themselves
    # on require (poetry-lucide does); the active set is selected by
    # `config.icon_library` and can be overridden per render.
    module Icons
      # A directory of vendored, pre-sanitized icon files - one
      # `<name>.svg` per icon holding the INNER markup (the component owns
      # the <svg> wrapper). Reads are memory-cached; names are validated
      # against a strict format before touching the filesystem (icon names
      # can carry user input - no path traversal).
      class FileSet
        NAME_FORMAT = /\A[a-z0-9][a-z0-9-]*\z/

        attr_reader :dir

        def initialize(dir:)
          @dir = Pathname.new(dir)
          @cache = {}
          @mutex = Mutex.new
        end

        def include?(name)
          valid_name?(name) && path_for(name).exist?
        end

        def fetch(name)
          raise ArgumentError, "invalid icon name #{name.inspect}" unless valid_name?(name)
          raise ArgumentError, "unknown icon #{name.inspect} (not in this set)" unless path_for(name).exist?

          @mutex.synchronize do
            @cache[name.to_sym] ||= path_for(name).read.strip
          end
        end

        def names
          @names ||= @dir.glob("*.svg").map { |path| path.basename(".svg").to_s.to_sym }.sort
        end

        private

        def valid_name?(name)
          name.to_s.match?(NAME_FORMAT)
        end

        def path_for(name)
          @dir.join("#{name}.svg")
        end
      end

      class << self
        def registry
          @registry ||= {}
        end

        def register(key, set)
          registry[key.to_sym] = set
        end

        # The set for the given library key, defaulting to
        # config.icon_library. Raises with the fix when unregistered.
        def set(library = nil)
          key = (library || Poetry::Core::Config.current.icon_library).to_sym
          registry.fetch(key) do
            raise Poetry::Core::Error,
                  "no icon set registered as #{key.inspect} - require its gem (e.g. poetry-lucide) " \
                  "or set config.icon_library to one of: #{registry.keys.inspect}"
          end
        end
      end
    end
  end
end
