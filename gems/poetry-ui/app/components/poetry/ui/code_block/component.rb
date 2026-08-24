# frozen_string_literal: true

module Poetry
  module Ui
    # CodeBlock family: the server-highlighted code panel.
    module CodeBlock
      # A highlighted code panel rendered entirely at request time via
      # the rouge gem. Rouge is a SOFT dependency - without it the same
      # markup ships with plain escaped code. Line numbers are CSS
      # counters, so they are excluded from selection and from copied
      # text by construction; highlight_lines: tints rows via the
      # theme's highlight hook; the syntax palette is seven --syntax-*
      # vars each theme owns. copy: adds a copy button reading the
      # rendered code itself.
      #
      # @example
      #   render Poetry::Ui::CodeBlock::Component.new(
      #     code: "puts \"hello\"", language: "ruby"
      #   )
      class Component < Poetry::Core::Component
        # Projected into the registry, llms.txt, and the agent surface.
        AGENT_RULES = [
          "Blocks of code are a CodeBlock (poetry_code_block) - never a hand-rolled pre/code " \
          "with utility classes; the syntax palette, line counters, and copy affordance ride it.",
          "Highlighting needs `gem \"rouge\"` in the host Gemfile - without it the block renders " \
          "plain (same markup, no colors). Inline code stays plain <code> typography.",
          "highlight_lines: takes 1-based line numbers; line numbers are CSS counters and never " \
          "pollute copied text."
        ].freeze

        # The whole copy surface is copy:-gated - element conditions keep
        # the wiring out of copy: false renders entirely.
        use_stimulus do
          on :root, if: :copy do
            controller :clipboard_text do
              register
              value :message, from: :copied_message_text
            end
          end
          on :source, if: :copy do
            controller(:clipboard_text) { target :source }
          end
          on :copy_button do
            controller(:clipboard_text) { action :copy, on: :click }
          end
        end

        option :code, :string, required: true, doc: "The source text to highlight - required."
        option :language, :string, default: "text",
                                   doc: "The lexer name (\"ruby\", \"js\", ...); unknown languages fall back to " \
                                        "plain text."
        option :label, :string,
               doc: "The scroll region's accessible name; defaults to the localized \"Code\" (a focusable scrollable " \
                    "region must be named - axe)."
        option :line_numbers, :boolean, default: false,
                                        doc: "Renders CSS-counter line numbers - never part of selection or copied " \
                                             "text."
        option :highlight_lines, ActiveModel::Type::Value.new,
               doc: "1-based line numbers to tint via the theme's highlight hook."
        option :copy, :boolean, default: true, doc: "Renders the copy button in the panel's corner."

        part "code-block", "Root - the syntax-palette surface (cn-code-block)",
             states: {
               "data-language" => "always - the lexer name, a styling/tooling hook",
               "data-line-numbers" => "line_numbers: - turns on the ::before CSS counters",
               "data-copied" => "copy: only - stamped for a beat after a successful copy " \
                                "(the clipboard-text engine)"
             }
        part "code-block-pre", "The scroll container - tabindex 0 + role region + label " \
                               "(a scrollable region must be keyboard-reachable and named)"
        part "code-block-code", "The code element - rouge's .line/.hll spans and the seven " \
                                "--syntax-* token maps live under it; the copy affordance " \
                                "reads ITS textContent"
        # The copy affordance renders as a composed ghost Button carrying
        # data-slot=clipboard-text-copy on Button's root (the ClipboardText
        # anatomy, prose not part): top-right of the panel, a real tab stop,
        # stacked copy/check glyphs swapping on data-copied.

        # The rouge-rendered (or plain-escaped) markup.
        # @api private
        def highlighted
          @highlighted ||= CodeBlockHighlighter.highlight(
            code, language: language, highlight_lines: highlight_lines || []
          )
        end

        # Attributes for the panel root.
        # @api private
        def root_attributes
          attrs = {
            "data-slot" => "code-block",
            "data-language" => language,
            "class" => css
          }.merge(component_data_attributes)
          attrs["data-line-numbers"] = "" if line_numbers
          html_attributes.merge_if_not_set(attrs.merge(stimulus_attributes_for(:root)))
        end

        # Attributes for the scrollable <pre> region.
        # @api private
        def pre_attributes
          {
            "data-slot" => "code-block-pre",
            "tabindex" => "0",
            "role" => "region",
            "aria-label" => label.presence || t("poetry.code_block.label"),
            "class" => css(:pre)
          }
        end

        # Attributes for the <code> element.
        # @api private
        def code_attributes
          attrs = Poetry::Core::HTML::Attributes.new(
            "data-slot" => "code-block-code",
            "class" => css(:code)
          )
          attrs.merge!(stimulus_attributes_for(:source))
          attrs
        end

        # The corner copy affordance: a ghost icon Button.
        # @api private
        def copy_button
          Button::Component.new({
            variant: :ghost, size: :"icon-xs",
            label: t("poetry.clipboard_text.copy"),
            class: css(:copy),
            "data-slot" => "clipboard-text-copy"
          }.merge(stimulus_attributes_for(:copy_button)))
        end

        private

        def copied_message_text = t("poetry.clipboard_text.copied")

        private :highlighted, :root_attributes, :pre_attributes, :code_attributes, :copy_button
      end
    end
  end
end
