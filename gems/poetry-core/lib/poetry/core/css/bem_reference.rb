# frozen_string_literal: true

module Poetry
  module Core
    module CSS
      # Generates the reference stylesheet for `css_mode = :bem` from a Style
      # dictionary: every BEM class the component emits, as a documented CSS
      # selector skeleton the consumer fills with their own rules. Each
      # selector carries a `tailwind-equivalent` comment - the utilities the
      # default (Tailwind) theme resolves that token to - so the reference
      # doubles as the class contract's documentation.
      #
      # The header embeds the dictionary's capsule digest as a leak-guard:
      # CSS written against an older dictionary is detectable by digest
      # mismatch instead of silently drifting on upgrade.
      #
      # @example
      #   Poetry::Core::CSS::BemReference.new(MyApp::Button::Style).css
      #   # => "/* poetry BEM reference for `.button` - capsule 1a2b3c... */\n.button { ... }"
      #
      # @api private
      class BemReference
        # The BEM reference for a Style class's dictionary under its block name.
        def initialize(style_class, block: style_class.bem_block)
          raise ArgumentError, "#{style_class} has no derivable BEM block" unless block

          @resolver = style_class.resolver
          @block = block
        end

        # The reference stylesheet text.
        def css
          [header, root_rule, element_rules, variant_rules, compound_rules]
            .flatten.compact.join("\n")
        end

        private

        # The comment heading the reference.
        def header
          <<~CSS
            /* poetry BEM reference for `.#{@block}` - capsule #{@resolver.digest}
               Generated from the Style dictionary; consumers on css_mode = :bem
               style these selectors with their own CSS. The tailwind-equivalent
               comments show what the default (Tailwind) theme resolves each
               token to. */
          CSS
        end

        # The block's own rule.
        def root_rule
          rule(".#{@block}", @resolver.bases.join(" "))
        end

        # One rule per element.
        def element_rules
          @resolver.elements.map do |name, classes|
            rule(".#{@block}__#{name}", classes.join(" "))
          end
        end

        # One rule per variant value.
        def variant_rules
          @resolver.variants.flat_map do |attr, mapping|
            mapping.map { |value, classes| rule(modifier_selector(attr, value), classes) }
          end.compact
        end

        # One rule per compound, its modifiers chained.
        def compound_rules
          @resolver.compounds.map do |compound|
            selector = compound.criteria.map { |attr, value| modifier_selector(attr, value) }.join
            rule(selector, compound.classes)
          end
        end

        # Boolean modifiers are presence classes (`block--attr`); `false` has
        # no class and produces no rule.
        def modifier_selector(attr, value)
          return nil if value == false

          value == true ? ".#{@block}--#{attr}" : ".#{@block}--#{attr}-#{value}"
        end

        # A rule whose body names the tailwind-equivalent classes, or nil for no selector.
        def rule(selector, classes)
          return nil if selector.nil?

          body = classes.to_s.strip.empty? ? "/* (no default styles) */" : "/* tailwind-equivalent: #{classes} */"
          "#{selector} { #{body} }"
        end
      end
    end
  end
end
