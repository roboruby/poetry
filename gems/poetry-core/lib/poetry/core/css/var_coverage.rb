# frozen_string_literal: true

module Poetry
  module Core
    module CSS
      # The custom-property contract: every `var(--x)` READ in a
      # compiled build must resolve to a DEFINITION - a declaration or a
      # CSS `@property` registration in the compiled CSS, or a runtime assignment
      # (JS setProperty, inline style attributes) that the caller passes in,
      # since runtime assignments never appear in the build output.
      #
      # Derivation over maintenance: the definition set is read from the
      # artifacts that already exist (the compiled build + the actual JS and
      # template sources), never a hand-maintained list - so a token rename
      # or deletion reddens every stale read the moment it lands. A read
      # WITH a fallback still counts: `var(--x, 4px)` where --x is defined
      # nowhere is a dead read whose intent lives only in the fallback -
      # drift by construction, not a feature.
      #
      # Dynamic runtime names (`--drawer-swipe-movement-${axis}`) enter as
      # PREFIXES: a read resolves if it starts with a registered prefix.
      #
      # @example
      #   coverage = Poetry::Core::CSS::VarCoverage.new(
      #     compiled_css: File.read("app/assets/builds/tailwind.css"),
      #     extra_definitions: ["--anchor-width"] # assigned from JS at runtime
      #   )
      #   coverage.ok? || coverage.dead_reads # => ["--never-defined"]
      #
      # @api private
      class VarCoverage
        # `--x:` declarations; the lookbehind keeps Stimulus event tokens
        # (`poetry--core--calendar:change`) and BEM-ish substrings out.
        DECLARATION = /(?<![\w-])(--[A-Za-z][\w-]*)\s*:/
        PROPERTY_RULE = /@property\s+(--[A-Za-z][\w-]*)/
        READ = /var\(\s*(--[A-Za-z][\w-]*)/

        def initialize(compiled_css:, extra_definitions: [], definition_prefixes: [], extra_reads: [])
          @compiled_css = strip_comments(compiled_css)
          @extra_definitions = extra_definitions.map(&:to_s)
          @definition_prefixes = definition_prefixes.map(&:to_s)
          @extra_reads = extra_reads.map(&:to_s)
        end

        def definitions
          @definitions ||= (@compiled_css.scan(DECLARATION).flatten +
                            @compiled_css.scan(PROPERTY_RULE).flatten +
                            @extra_definitions).to_set
        end

        def reads
          @reads ||= (@compiled_css.scan(READ).flatten + @extra_reads).uniq.sort
        end

        # Reads that resolve to nothing: not declared in the build, not
        # registered via CSS `@property`, not runtime-assigned. Each one is a rule
        # silently falling back (or to nothing at all) - a class of bug
        # once dug out by hand as a dozen dead reads of renamed vars.
        def dead_reads
          reads.reject do |name|
            definitions.include?(name) || @definition_prefixes.any? { |prefix| name.start_with?(prefix) }
          end
        end

        def ok? = dead_reads.empty?

        private

        def strip_comments(css)
          css.gsub(%r{/\*.*?\*/}m, "")
        end
      end
    end
  end
end
