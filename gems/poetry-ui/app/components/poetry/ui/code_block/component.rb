# frozen_string_literal: true

module Poetry
  module Ui
    # CodeBlock family: highlighted, copyable code.
    module CodeBlock
      # A block of code on upstream's code-block anatomy (shadcn@4.23.0),
      # highlighted on the server: rouge when the host bundles it, the plain
      # escaped text otherwise - the markup is identical either way. Every
      # source line renders as its own line part, so line numbers (CSS
      # counters, never in copied text), highlighted lines and diff lines
      # are per-line variants the theme tints. An optional header carries a
      # title and actions; without one the copy button floats in the corner,
      # shown on hover or focus.
      #
      # @example
      #   render Poetry::Ui::CodeBlock::Component.new(code: snippet, language: "ruby", line_numbers: true)
      #
      # @example A header and a diff
      #   render Poetry::Ui::CodeBlock::Component.new(code: patch, language: "ruby", diff: true) do |block|
      #     block.with_title { "app/models/user.rb" }
      #   end
      class Component < Poetry::Core::Component
        # Projected into the registry, llms.txt, and the agent surface.
        AGENT_RULES = [
          "Blocks of code are a CodeBlock (poetry_code_block) - never a hand-rolled pre/code " \
          "with utility classes; the syntax palette, line counters, and copy affordance ride it.",
          "Highlighting needs `gem \"rouge\"` in the host Gemfile - without it the block renders " \
          "plain (same markup, no colors). Inline code stays plain <code> typography.",
          "highlight_lines: takes 1-based line positions; line numbers are CSS counters and never " \
          "pollute copied text.",
          "diff: true reads a unified diff: a leading + or - marks the line added or removed (the theme " \
          "draws the marker), and the rest of the line highlights in language:.",
          "with_title { \"path/to/file.rb\" } opens a header; the copy button moves into it."
        ].freeze

        # The closed vocabularies.
        VARIANTS = %i[default destructive].freeze
        SIZES = %i[default sm].freeze

        # The per-line variants (the theme's line tints).
        LINE_VARIANTS = %i[default added removed highlighted].freeze

        use_stimulus do
          on :root, if: :copy do
            controller :clipboard_text do
              register
              value :message, from: :copied_message_text
              value :text, from: :copy_text
            end
          end
          on :source, if: :copy do
            controller(:clipboard_text) { target :source }
          end
          on :copy_button do
            controller(:clipboard_text) { action :copy, on: :click }
          end
        end

        renders_one :title, doc: "The header's title - a file name or a label; opens the header, and the copy " \
                                 "button moves into it."
        renders_one :actions, doc: "More actions beside the copy button (in the header, or floating in the corner)."
        renders_one :footer, doc: "A row below the code - a caption, a status, a link."

        style :variant, default: :default, required: true, variants: VARIANTS,
                        doc: "The intent axis; :destructive frames an error's output."

        option :code, :string, required: true, doc: "The source text to highlight - required."
        option :language, :string, default: "text",
                                   doc: "The lexer name (\"ruby\", \"js\", ...); unknown languages fall back to " \
                                        "plain text."
        option :label, :string,
               doc: "The scroll region's accessible name; defaults to the title when there is one, else the " \
                    "localized \"Code\" (a focusable scrollable region must be named - axe)."
        option :size, :symbol, default: :default, doc: "The density axis; :sm tightens the padding and the type."
        option :line_numbers, :boolean, default: false,
                                        doc: "Renders CSS-counter line numbers - never part of selection or copied " \
                                             "text."
        option :start_line, :integer, default: 1, doc: "The first line's number when line_numbers: is on."
        option :highlight_lines, ActiveModel::Type::Value.new,
               doc: "1-based line positions to tint via the theme's highlighted line."
        option :diff, :boolean, default: false,
                                doc: "Reads the code as a unified diff: + and - lines render added and removed, " \
                                     "their marker drawn by the theme; copy keeps the markers."
        option :wrap, :boolean, default: false, doc: "Wraps long lines instead of scrolling sideways."
        option :copy, :boolean, default: true, doc: "Renders the copy button."

        validates :size, inclusion: { in: SIZES }
        validates :start_line, numericality: { only_integer: true, greater_than_or_equal_to: 1 }

        part "code-block", "Root - the panel (cn-code-block plus its variant)",
             states: {
               "data-variant" => { condition: "always - the resolved variant", values: VARIANTS.map(&:to_s) },
               "data-size" => { condition: "always - the resolved size", values: SIZES.map(&:to_s) },
               "data-language" => "always - the lexer name, a styling/tooling hook",
               "data-copied" => "copy: only - stamped for a beat after a successful copy " \
                                "(the clipboard-text engine)"
             }
        part "code-block-header", "The header row - the title, then the actions (rendered with a title)"
        part "code-block-title", "The header's title (with_title)"
        part "code-block-actions", "The actions - in the header row, or floating in the corner without one"
        part "code-block-copy-button", "The copy button (copy:) - a ghost Button over the clipboard-text engine",
             states: {
               "data-variant" => "always - the composed Button's variant axis",
               "data-size" => "always - the composed Button's size axis"
             }
        part "code-block-content", "The scroll container (a pre) - tabindex 0 + role region + its name " \
                                   "(a scrollable region must be keyboard-reachable and named)",
             states: {
               "data-wrap" => "wrap: - long lines wrap instead of scrolling",
               "data-numbered" => "line_numbers: - each line shows its CSS-counter number"
             }
        part "code-block-code", "The code element - the token map reads the theme's seven --syntax-* vars; " \
                                "the copy affordance reads ITS textContent"
        part "code-block-line", "One source line - the numbered row and the tint",
             states: {
               "data-variant" => { condition: "always - the line's variant", values: LINE_VARIANTS.map(&:to_s) }
             }
        part "code-block-line-content", "The line's text"
        part "code-block-footer", "The row below the code (with_footer)"

        # Attributes for the root.
        # @api private
        def root_attributes
          super({ "data-variant" => variant, "data-size" => size, "data-language" => language, "class" => css })
        end

        # Attributes for the scroll container.
        # @api private
        def content_attributes
          attrs = { "tabindex" => "0", "role" => "region", "dir" => "ltr" }
          attrs.merge!(region_name)
          attrs["data-wrap"] = "" if wrap
          attrs["data-numbered"] = "" if line_numbers
          attrs["style"] = "counter-reset: line #{start_line - 1}" if line_numbers && start_line != 1
          element_attributes(:content, attrs)
        end

        # Attributes for the code element.
        # @api private
        def code_attributes
          element_attributes(:code, {}, stimulus: :source)
        end

        # The rendered lines: [variant, html] per source line.
        # @api private
        def lines
          @lines ||= begin
            fragments = CodeBlockHighlighter.highlight_lines(display_lines, language: language)
            fragments.each_with_index.map { |html, index| [line_variant(index), html] }
          end
        end

        # The code element's lines, one span per source line joined by
        # newlines: the grid renders no whitespace between its items, and
        # the copy affordance's textContent keeps the real line breaks.
        # @api private
        def code_markup
          spans = lines.map do |variant, html|
            content = tag.span(html, **element_attributes(:line_content))
            attrs = { "data-variant" => variant, "class" => line_class(variant) }
            tag.span(content, **element_attributes(:line, attrs))
          end
          safe_join(spans, "\n") + (code.to_s.end_with?("\n") ? "\n" : "")
        end

        # The class list for one line of the given variant.
        # @api private
        def line_class(variant)
          [css(:line), css(:"line_#{variant}")].compact_blank.join(" ")
        end

        # Whether the header renders: a title opens it.
        # @api private
        def header?
          title?
        end

        # Whether any action renders (the copy button or the caller's).
        # @api private
        def actions_any?
          copy || actions?
        end

        # The title's id - the region's name when there is no label.
        # @api private
        def title_id
          @title_id ||= "#{poetry_instance_id("poetry-code-block")}-title"
        end

        # The copy button - a ghost icon Button carrying the engine's action.
        # @api private
        def copy_button
          Button::Component.new({
            variant: :ghost, size: :"icon-xs",
            label: t("poetry.clipboard_text.copy"),
            class: "cn-code-block-copy-button",
            "data-slot" => "code-block-copy-button"
          }.merge(stimulus_attributes_for(:copy_button)))
        end

        private

        # The lines as they render: a diff's first column is its marker.
        def display_lines
          raw = CodeBlockHighlighter.source_lines(code)
          diff ? raw.map { |line| line[1..].to_s } : raw
        end

        def line_variant(index)
          if diff
            marker = CodeBlockHighlighter.source_lines(code)[index].to_s[0]
            return :added if marker == "+"
            return :removed if marker == "-"
          end
          highlighted_positions.include?(index + 1) ? :highlighted : :default
        end

        def highlighted_positions
          @highlighted_positions ||= Array(highlight_lines).map(&:to_i)
        end

        def region_name
          return { "aria-label" => label } if label.present?
          return { "aria-labelledby" => title_id } if title?

          { "aria-label" => t("poetry.code_block.label") }
        end

        # A diff's markers never reach the DOM text (the theme draws them),
        # so the copy text is the source itself; otherwise the engine reads
        # the code element.
        def copy_text = diff ? code.to_s : ""

        def copied_message_text = t("poetry.clipboard_text.copied")

        private :content_attributes, :code_attributes, :lines, :code_markup, :line_class, :header?,
                :actions_any?, :title_id, :copy_button
      end
    end
  end
end
