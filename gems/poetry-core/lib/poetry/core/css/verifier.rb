# frozen_string_literal: true

require "did_you_mean/levenshtein"

module Poetry
  module Core
    module CSS
      # The class Verifier: validates that every class a Style
      # dictionary emits actually exists in the COMPILED Tailwind stylesheet -
      # catching typos and LLM-hallucinated classes before they ship as
      # silently-unstyled markup.
      #
      # A pure function over (classes, compiled CSS): no Tailwind toolchain
      # required at verify time, just the build output. Built as a reusable
      # library on purpose - CI, the agent checks, the editor LSP, and the
      # host-app `poetry:verify` task all consume this one
      # implementation.
      class Verifier
        Unknown = Struct.new(:class_name, :suggestion) do
          def to_s
            suggestion ? "#{class_name} (did you mean #{suggestion.inspect}?)" : class_name
          end
        end

        # Maximum Levenshtein distance for a did-you-mean suggestion.
        SUGGESTION_DISTANCE = 2

        # Named group/peer MARKER classes (`group/menu-item`, `peer/menu-button`).
        # Tailwind emits no CSS for the bare marker by design - it only ever
        # appears inside the selectors of utilities that CONSUME it
        # (`group-focus/menu-item:*`), so its presence in compiled CSS depends
        # on which theme is active. A marker is valid markup regardless (N12:
        # the vega port stamps markers whose consumers live in the vega
        # fragment only), so verification skips them instead of rewarding the
        # coincidence of a same-theme consumer.
        MARKER_CLASS = %r{\A(?:group|peer)/[a-z0-9-]+\z}

        # Extracts the set of class names defined by a compiled CSS text.
        # Selectors are the text runs preceding `{` (which also covers rules
        # nested in @media etc.); Tailwind's escaping (`\:` `\/` `\[` ...) is
        # unescaped so names compare in their authored form. Tokens starting
        # with a digit are rejected (artifacts of dimensions like `.5rem` in
        # at-rule params - real leading-digit classes are escaped by Tailwind
        # and survive unescaping).
        def self.known_classes(compiled_css)
          selectors = compiled_css.gsub(%r{/\*.*?\*/}m, "").scan(/[^{}]+(?=\{)/)
          selectors.each_with_object(Set.new) do |selector, known|
            selector.scan(/\.((?:\\.|[-\w])+)/) do |(token)|
              name = token.gsub(/\\(.)/, '\1')
              known << name unless name.match?(/\A\d/)
            end
          end
        end

        attr_reader :known

        def initialize(compiled_css:)
          @known = self.class.known_classes(compiled_css)
        end

        # The classes (of those given) that do NOT exist in the compiled CSS,
        # each with a nearest-known-class suggestion when one is close enough.
        #
        # @param classes [Enumerable<String>]
        # @return [Array<Unknown>]
        def unknown(classes)
          classes.uniq.reject { |name| @known.include?(name) || name.match?(MARKER_CLASS) }.map do |name|
            Unknown.new(name, suggestion_for(name))
          end
        end

        # Verifies every class in a Style dictionary (bases, elements,
        # variants, compounds).
        #
        # @param style_class [Class] a Poetry::Core::Style subclass
        # @return [Array<Unknown>]
        def verify_style(style_class)
          unknown(style_class.resolver.all_classes)
        end

        private

        def suggestion_for(name)
          best = nil
          best_distance = SUGGESTION_DISTANCE + 1
          @known.each do |candidate|
            next if (candidate.length - name.length).abs > SUGGESTION_DISTANCE

            distance = DidYouMean::Levenshtein.distance(name, candidate)
            if distance < best_distance
              best = candidate
              best_distance = distance
            end
          end
          best
        end
      end
    end
  end
end
