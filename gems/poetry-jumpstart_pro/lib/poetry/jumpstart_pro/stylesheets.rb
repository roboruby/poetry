# frozen_string_literal: true

require_relative "css_scanner"

module Poetry
  module JumpstartPro
    # The stylesheet reconciliation the installer runs on a Jumpstart Pro
    # host. Jumpstart's own CSS declares a few things globally - the forms
    # plugin's base rules, a primary color mapping, a page background token,
    # and bare a/ul/ol and heading rules in layer(components) - that would
    # otherwise win over Poetry's tokens and component styles. Each edit here is a pure
    # String -> String function: a second run returns its input unchanged,
    # and the tests exercise it without a host app.
    #
    # @example Reconcile the Tailwind entry
    #   css = File.read("app/assets/tailwind/application.css")
    #   Poetry::JumpstartPro::Stylesheets.tailwind_entry(css)
    module Stylesheets
      # The files the installer reconciles, relative to the host root, and
      # the edit each one gets.
      FILES = {
        "app/assets/tailwind/application.css" => :tailwind_entry,
        "app/assets/tailwind/themes/light.css" => :theme,
        "app/assets/tailwind/themes/dark.css" => :theme,
        "app/assets/tailwind/components/base.css" => :base,
        "app/assets/tailwind/components/typography.css" => :typography
      }.freeze

      # The forms plugin loaded with its default strategy, which restyles
      # every input through base rules.
      FORMS_PLUGIN = %r{^@plugin\s+"@tailwindcss/forms"\s*;[ \t]*$}

      # The class-strategy replacement: Jumpstart's own form classes keep
      # working, and Poetry's inputs keep their own focus ring and chevron.
      FORMS_PLUGIN_CLASS_STRATEGY = <<~CSS.chomp
        /* Class strategy only (poetry-jumpstart_pro): the plugin's base rules would
           restyle every input under Poetry's own. Jumpstart's form classes keep working. */
        @plugin "@tailwindcss/forms" {
          strategy: class;
        }
      CSS

      # Jumpstart's theme maps --color-primary onto its own --bg-primary; a
      # host declaration wins over Poetry's tokens, so it would recolor every
      # Poetry primary surface.
      PRIMARY_MAPPING = /^([ \t]*)--color-primary:\s*var\(--bg-primary\)\s*;[ \t]*$/

      # Jumpstart's themes declare --background, Poetry's page canvas token.
      BACKGROUND_TOKEN = /^([ \t]*)--background:\s*[^;\n]+;[ \t]*$/

      # Bare element selectors in Jumpstart's base.css that outrank Poetry's
      # base-layer component styles from layer(components): underlined,
      # recolored links and bulleted lists inside menus and navigation.
      GLOBAL_SELECTORS = %w[a ul ol].freeze

      # The bare elements Jumpstart's typography styles that Poetry's
      # components render too: headings, code and kbd.
      TYPOGRAPHY_ELEMENTS = /\A(?:h[1-6]|code|kbd)\z/

      # Excludes Poetry's components, whose parts all carry data-slot.
      UNSLOTTED = ":not([data-slot])"

      # Prepended to base.css once its global rules are gone.
      BASE_NOTE = "/* poetry-jumpstart_pro removed the bare a, ul and ol rules here: links and\n   " \
                  "lists keep preflight's neutral defaults so Poetry's components render as designed. */\n\n"

      module_function

      # The Tailwind entry: the forms plugin moves to the class strategy and
      # the --color-primary mapping becomes a comment.
      #
      # @param css [String] the contents of app/assets/tailwind/application.css
      # @return [String] the reconciled stylesheet
      def tailwind_entry(css)
        css = css.sub(FORMS_PLUGIN, FORMS_PLUGIN_CLASS_STRATEGY)
        css.sub(PRIMARY_MAPPING) do
          "#{Regexp.last_match(1)}/* --color-primary comes from Poetry's tokens (poetry/tokens.css). */"
        end
      end

      # A Jumpstart theme file: its --background declaration becomes a comment.
      #
      # @param css [String] the contents of a themes/*.css file
      # @return [String] the reconciled stylesheet
      def theme(css)
        css.sub(BACKGROUND_TOKEN) do
          "#{Regexp.last_match(1)}/* --background comes from Poetry's tokens (poetry/tokens.css). */"
        end
      end

      # Jumpstart's base.css: drops the top-level a, ul and ol rules, and any
      # supports block that holds nothing but those rules. Everything else -
      # the body frame, main's gutter, tables, hr - stays.
      #
      # @param css [String] the contents of components/base.css
      # @return [String] the reconciled stylesheet
      def base(css)
        kept = +""
        dropped = false
        CssScanner.each_statement(css) do |text, prelude, body|
          if global_rule?(prelude, body)
            dropped = true
          else
            kept << text
          end
        end
        return css unless dropped

        kept = kept.gsub(/\n{3,}/, "\n\n").sub(/\A\s+/, "")
        kept.start_with?(BASE_NOTE) ? kept : BASE_NOTE + kept
      end

      # Jumpstart's typography.css: its bare h1-h6, code and kbd rules sit
      # in layer(components), above Poetry's base-layer component styles, so
      # a card or dialog title would take a page heading's size and a code
      # block's code an inline chip. Each selector ending in one of those
      # elements skips elements that carry data-slot; the .h1-.h6 classes
      # and the host's own markup keep Jumpstart's styles.
      #
      # @param css [String] the contents of components/typography.css
      # @return [String] the reconciled stylesheet
      def typography(css)
        out = +""
        CssScanner.each_statement(css) do |text, prelude, _body|
          next out << text if prelude.nil? || prelude.start_with?("@")

          parts = prelude.split(",").map(&:strip)
          scoped = parts.map do |part|
            part.split(/[\s>+~]+/).last.match?(TYPOGRAPHY_ELEMENTS) ? "#{part}#{UNSLOTTED}" : part
          end
          out << (scoped == parts ? text : text.sub(prelude, scoped.join(", ")))
        end
        out
      end

      # Whether a top-level statement is one of the global rules to drop.
      # @api private
      def global_rule?(prelude, body)
        return false if prelude.nil?
        return GLOBAL_SELECTORS.include?(normalize(prelude)) unless prelude.start_with?("@supports")

        inner = []
        CssScanner.each_statement(body) { |_, inner_prelude, inner_body| inner << [inner_prelude, inner_body] }
        rules = inner.reject { |inner_prelude, _| inner_prelude.nil? }
        rules.any? && rules.all? { |inner_prelude, _| GLOBAL_SELECTORS.include?(normalize(inner_prelude)) }
      end

      # A selector with its whitespace collapsed.
      # @api private
      def normalize(prelude)
        prelude.gsub(/\s+/, " ").strip
      end
    end
  end
end
