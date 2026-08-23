# frozen_string_literal: true

module Poetry
  module Core
    module CSS
      # The theme-layer coverage gate: bidirectional agreement between
      # the cn-* names Style dictionaries emit and the rules a theme
      # fragment defines.
      #
      #   missing - dictionary cn names with no theme rule (the component
      #             would render undesigned; css:verify_compiled reddens
      #             too - this names the culprit precisely)
      #   orphans - theme cn tokens no dictionary emits (a dead rule, or a
      #             rename the theme didn't follow). Consumer-facing utility
      #             classes a theme defines on purpose (cn-font-heading)
      #             ride the allowlist.
      #
      # The parser is deliberately narrow: cn tokens are read from top-level
      # selectors only (lines that open a rule), never from @apply bodies -
      # theme fragments are flat by convention (see themes/default.css).
      #
      # @example
      #   coverage = Poetry::Core::CSS::ThemeCoverage.new(
      #     theme_css: File.read("themes/default.css"),
      #     style_classes: [MyApp::Button::Style]
      #   )
      #   coverage.ok? || [coverage.missing, coverage.orphans]
      class ThemeCoverage
        SELECTOR_LINE = /^[^@\s{}][^{]*\{/
        CN_TOKEN = /\.(cn-[a-z0-9-]+)/

        def initialize(theme_css:, style_classes:, allowlist: [])
          @theme_css = theme_css
          @style_classes = style_classes
          @allowlist = allowlist.map(&:to_s)
        end

        # Every cn-* class any dictionary emits (bases, elements, variants,
        # compounds), deduplicated across dictionaries.
        def dictionary_names
          @dictionary_names ||= @style_classes
                                .flat_map { |style| style.resolver.all_classes }
                                .select { |cls| cls.start_with?("cn-") }
                                .uniq.sort
        end

        # Every cn-* token appearing in a theme selector (a combined
        # compound selector like `.cn-x-a.cn-x-b` contributes both).
        def theme_names
          @theme_names ||= @theme_css.each_line
                                     .grep(SELECTOR_LINE)
                                     .flat_map { |line| line[0...line.index("{")].scan(CN_TOKEN) }
                                     .flatten.uniq.sort
        end

        def missing
          dictionary_names - theme_names
        end

        def orphans
          theme_names - dictionary_names - @allowlist
        end

        def ok?
          missing.empty? && orphans.empty?
        end
      end
    end
  end
end
