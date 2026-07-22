# frozen_string_literal: true

module Poetry
  module Core
    # The pluggable icon-set registry (: Lucide default, per-set
    # adapters). An icon set is anything responding to #include?(name),
    # #fetch(name) -> inner SVG markup, and #names. Sets register themselves
    # on require (poetry-lucide does); the active set is selected by
    # `config.icon_library` and can be overridden per render.
    #
    # SECURITY: #fetch's return value is rendered `html_safe` by the Icon
    # component. The shipped sets vendor SVGs sanitized AT VENDOR TIME
    # (poetry-lucide's fetch script strips <script>/<foreignObject>/handlers
    # /external-href <use>/<image>), so render never parses untrusted markup.
    # A custom set registered by a host MUST pre-sanitize its SVGs the same
    # way - the vendored pipeline is the reference; a set that serves raw,
    # attacker-influenced SVG is an XSS sink.
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

          unless path_for(name).exist?
            suggestion = Icons.suggest(name, names)
            hint = suggestion ? " - did you mean #{suggestion.to_sym.inspect}?" : ""
            raise ArgumentError, "unknown icon #{name.inspect} (not in this set)#{hint}"
          end

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
        # Did-you-mean for icon names. The reversed-compound form is
        # checked before edit distance: Lucide v1 swapped modifier and noun
        # (alert-circle -> circle-alert, x-circle -> circle-x), a rename class
        # DidYouMean's checker misses every time - the reversal IS the fix.
        #
        # @param name [Symbol, String] the unknown name (underscores tolerated)
        # @param names [Enumerable] the valid names to suggest from
        # @return [String, nil] the closest valid name, or nil
        def suggest(name, names)
          name = name.to_s.tr("_", "-")
          candidates = names.map(&:to_s)
          reversed = name.split("-").reverse.join("-")
          return reversed if reversed != name && candidates.include?(reversed)

          require "did_you_mean"
          DidYouMean::SpellChecker.new(dictionary: candidates).correct(name).first
        end

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
