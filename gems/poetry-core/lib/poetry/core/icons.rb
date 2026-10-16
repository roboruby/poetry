# frozen_string_literal: true

module Poetry
  module Core
    # The pluggable icon-set registry (Lucide default, per-set
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
      # The <svg> wrapper attributes a set draws with when it names none:
      # Lucide's 24-unit stroke style, the family's default. A set whose
      # icons are filled, thinner or on another grid passes its own
      # `svg_attributes:`; the Icon component lays them under the caller's.
      DEFAULT_SVG_ATTRIBUTES = {
        "width" => "24",
        "height" => "24",
        "viewBox" => "0 0 24 24",
        "fill" => "none",
        "stroke" => "currentColor",
        "stroke-width" => "2",
        "stroke-linecap" => "round",
        "stroke-linejoin" => "round"
      }.freeze

      # The kebab-case shape every icon name must match before it touches
      # the filesystem.
      NAME_FORMAT = /\A[a-z0-9][a-z0-9-]*\z/

      # A directory of vendored, pre-sanitized icon files - one
      # `<name>.svg` per icon holding the INNER markup (the component owns
      # the <svg> wrapper). Reads are memory-cached; names are validated
      # against a strict format before touching the filesystem (icon names
      # can carry user input - no path traversal).
      class FileSet
        # The kebab-case shape every icon name must match (kept here too:
        # `poetry check` reads it as FileSet::NAME_FORMAT).
        NAME_FORMAT = Icons::NAME_FORMAT

        # The directory the set reads from.
        #
        # @return [Pathname]
        attr_reader :dir

        # The attributes the <svg> wrapper draws this set with.
        #
        # @return [Hash{String => String}]
        attr_reader :svg_attributes

        # Old names the upstream renamed, each to the name it renders as.
        #
        # @return [Hash{String => String}]
        attr_reader :aliases

        # A set over one directory of sanitized SVG files, one file per
        # icon name (`circle-alert.svg`); each icon is read once and cached.
        #
        # @param dir [String, Pathname] the directory holding the SVGs
        # @param svg_attributes [Hash{String => String}] the <svg> wrapper's
        #   drawing attributes (viewBox, fill, stroke)
        # @param aliases [Hash{String => String}] old name => current name;
        #   an old name still renders, and `poetry check` warns with the rename
        def initialize(dir:, svg_attributes: DEFAULT_SVG_ATTRIBUTES, aliases: {})
          @dir = Pathname.new(dir)
          @svg_attributes = svg_attributes.freeze
          @aliases = aliases.to_h { |old, current| [old.to_s, current.to_s] }.freeze
          @cache = {}
          @mutex = Mutex.new
        end

        # Whether the set has an icon of this name, or an alias for one: the
        # name must be well-formed and its SVG present on disk.
        #
        # @param name [Symbol, String] the icon name
        # @return [Boolean]
        def include?(name)
          valid_name?(name) && path_for(resolve(name)).exist?
        end

        # The inner SVG markup of one icon, read once and cached.
        #
        # @param name [Symbol, String] the icon name
        # @return [String] the icon's inner SVG markup
        # @raise [Poetry::Core::IconNotFound] for a malformed name, or an
        #   unknown one (the message carries a did-you-mean suggestion when
        #   one exists; the error's #name and #suggestion carry the parts)
        def fetch(name)
          raise IconNotFound.new("invalid icon name #{name.inspect}", name: name) unless valid_name?(name)

          current = resolve(name)
          raise Icons.not_found(name, names) unless path_for(current).exist?

          @mutex.synchronize do
            @cache[current.to_sym] ||= path_for(current).read.strip
          end
        end

        # Every current icon name in the set, sorted (aliases are not names).
        #
        # @return [Array<Symbol>]
        def names
          @names ||= @dir.glob("*.svg").map { |path| path.basename(".svg").to_s.to_sym }.sort
        end

        private

        # The name an alias renders as, else the name itself.
        def resolve(name)
          @aliases.fetch(name.to_s, name.to_s)
        end

        # Whether the name has the icon-file shape.
        def valid_name?(name)
          name.to_s.match?(NAME_FORMAT)
        end

        # The SVG file for a name under the set's directory.
        def path_for(name)
          @dir.join("#{name}.svg")
        end
      end

      # One file holding a whole vendored set, one icon per line:
      # `<name>\t<inner markup>\n`, sorted by name. A large set ships as a
      # handful of files instead of thousands. The first read indexes the
      # names and their byte offsets; each icon's markup is read once, by
      # offset, and cached. Same contract and errors as {FileSet}.
      class PackedSet
        # The packed file the set reads from.
        #
        # @return [Pathname]
        attr_reader :path

        # The attributes the <svg> wrapper draws this set with.
        #
        # @return [Hash{String => String}]
        attr_reader :svg_attributes

        # Old names the upstream renamed, each to the name it renders as.
        #
        # @return [Hash{String => String}]
        attr_reader :aliases

        # A set over one packed file of sanitized inner markup.
        #
        # @param path [String, Pathname] the packed file
        # @param svg_attributes [Hash{String => String}] the <svg> wrapper's
        #   drawing attributes (viewBox, fill, stroke)
        # @param aliases [Hash{String => String}] old name => current name
        def initialize(path:, svg_attributes: DEFAULT_SVG_ATTRIBUTES, aliases: {})
          @path = Pathname.new(path)
          @svg_attributes = svg_attributes.freeze
          @aliases = aliases.to_h { |old, current| [old.to_s, current.to_s] }.freeze
          @cache = {}
          @mutex = Mutex.new
        end

        # Whether the set has an icon of this name, or an alias for one.
        #
        # @param name [Symbol, String] the icon name
        # @return [Boolean]
        def include?(name)
          name.to_s.match?(NAME_FORMAT) && index.key?(@aliases.fetch(name.to_s, name.to_s))
        end

        # The inner SVG markup of one icon, read once and cached.
        #
        # @param name [Symbol, String] the icon name
        # @return [String] the icon's inner SVG markup
        # @raise [Poetry::Core::IconNotFound] for a malformed or unknown name
        def fetch(name)
          raise IconNotFound.new("invalid icon name #{name.inspect}", name: name) unless name.to_s.match?(NAME_FORMAT)

          current = @aliases.fetch(name.to_s, name.to_s)
          offset, length = index[current]
          raise Icons.not_found(name, names) unless offset

          @mutex.synchronize do
            @cache[current.to_sym] ||= File.open(@path, "rb") do |file|
              file.seek(offset)
              file.read(length).force_encoding(Encoding::UTF_8)
            end
          end
        end

        # Every icon name in the set, sorted.
        #
        # @return [Array<Symbol>]
        def names
          @names ||= index.keys.map(&:to_sym).sort
        end

        private

        # name => [byte offset of the markup, byte length], built once.
        def index
          @index || @mutex.synchronize do
            @index ||= begin
              entries = {}
              position = 0
              File.open(@path, "rb") do |file|
                file.each_line do |line|
                  tab = line.index("\t")
                  if tab
                    markup = line.byteslice(tab + 1, line.bytesize - tab - 1).chomp
                    entries[line.byteslice(0, tab).force_encoding(Encoding::UTF_8)] =
                      [position + tab + 1, markup.bytesize]
                  end
                  position += line.bytesize
                end
              end
              entries.freeze
            end
          end
        end
      end

      class << self
        # The error for a well-formed name a set does not have, with a
        # did-you-mean when one is close.
        #
        # @param name [Symbol, String] the unknown name
        # @param names [Enumerable] every name the set serves, to suggest from
        # @return [Poetry::Core::IconNotFound]
        def not_found(name, names)
          suggestion = suggest(name, names)
          hint = suggestion ? " - did you mean #{suggestion.to_sym.inspect}?" : ""
          IconNotFound.new("unknown icon #{name.inspect} (not in this set)#{hint}", name: name, suggestion: suggestion)
        end

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

        # The registered icon sets, library key => set object. Icon gems
        # add themselves here on require.
        #
        # @return [Hash{Symbol => Object}]
        def registry
          @registry ||= {}
        end

        # Registers an icon set under a library key - the extension point
        # an icon gem calls on require. A set is any object responding to
        # `#include?(name)`, `#fetch(name)` (returning inner SVG markup),
        # and `#names`. The set contract: `#fetch` raises
        # {Poetry::Core::IconNotFound} for any name it cannot serve - the
        # Icon component's missing-icon policy rescues exactly that class.
        # See the SECURITY note above for the pre-sanitization requirement
        # on custom sets.
        #
        # @param key [Symbol, String] the library key `config.icon_library`
        #   selects the set by
        # @param set [Object] the icon set (a {FileSet} over a directory of
        #   vendored SVGs, or any object honoring the same contract)
        # @return [Object] the set, now registered
        # @example Register a vendored set and select it
        #   Poetry::Core::Icons.register(:my_icons,
        #     Poetry::Core::Icons::FileSet.new(dir: root.join("icons")))
        #   # config/initializers/poetry.rb: config.icon_library = :my_icons
        def register(key, set)
          registry[key.to_sym] = set
        end

        # The set for the given library key, defaulting to
        # config.icon_library. Raises with the fix when unregistered.
        #
        # @param library [Symbol, String, nil] the library key; nil reads
        #   `Poetry::Core::Config.current.icon_library`
        # @return [Object] the registered set
        # @raise [Poetry::Core::Error] when no set is registered under the key
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
