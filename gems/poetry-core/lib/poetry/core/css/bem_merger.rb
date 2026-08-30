# frozen_string_literal: true

module Poetry
  module Core
    module CSS
      # The BEM-mode classname merger: the classname_merger a host pairs
      # with `css_mode = :bem`. Same contract as {TailwindMerger}
      # (flatten, stringify, drop blanks, nil for empty input) with
      # exactly two behaviors on top: order-preserving token dedupe and
      # a space join - no Tailwind conflict semantics applied to a BEM
      # host's classes.
      #
      # Deliberately NO modifier-axis conflict resolution: the BEM
      # modifier grammar is dictionary-dependent at the string level
      # (values carry dashes - `--align-inline-start` - and names carry
      # underscores), so a string merger guessing axes would be wrong.
      # Style axes are driven through component options; conflicts
      # between raw caller classes belong to the host stylesheet's
      # cascade.
      #
      # @example Pairing with BEM mode (config/initializers/poetry.rb)
      #   Poetry::Core::Config.current.css_mode = :bem
      #   Poetry::Core::Config.current.classname_merger =
      #     Poetry::Core::CSS::BemMerger.new
      #
      # @example Dedupe without Tailwind semantics
      #   Poetry::Core::CSS::BemMerger.new.merge("pill pill--variant-danger", "pill", "p-4 p-2")
      #   # => "pill pill--variant-danger p-4 p-2"
      class BemMerger
        # Merges class lists BEM-style: normalize, dedupe at the token
        # level (first occurrence keeps its position), join.
        #
        # @param classes [Array<String, Symbol, Array, nil>] class names,
        #   arrays of class names, or nils
        # @return [String, nil] the merged classes, or nil when empty
        def merge(*classes)
          normalized = classes.flatten.compact_blank.map(&:to_s)
          return nil if normalized.empty?

          normalized.flat_map(&:split).uniq.join(" ")
        end
      end
    end
  end
end
