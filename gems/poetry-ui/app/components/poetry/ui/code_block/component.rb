# frozen_string_literal: true

module Poetry
  module Ui
    module CodeBlock
      # The CodeBlock (the kumo CodeHighlighted port - server-side):
      # a highlighted code panel rendered entirely at request time via rouge
      # (kumo needed a server.tsx escape hatch; poetry's whole model IS the
      # escape hatch). Rouge is a SOFT dependency - without it the same
      # markup ships with plain escaped code. Line numbers are CSS counters
      # in ::before, so they are excluded from selection and from the copy
      # affordance's text by construction; highlight_lines: tints via the
      # theme's .hll hook; the syntax palette is seven --syntax-* vars each
      # theme owns (GitHub light/dark is the shared v1 baseline). copy:
      # rides the clipboard-text engine reading the rendered code itself.
      class Component < Poetry::Core::Component
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

        AGENT_RULES = [
          "Blocks of code are a CodeBlock (poetry_code_block) - never a hand-rolled pre/code " \
          "with utility classes; the syntax palette, line counters, and copy affordance ride it.",
          "Highlighting needs `gem \"rouge\"` in the host Gemfile - without it the block renders " \
          "plain (same markup, no colors). Inline code stays plain <code> typography.",
          "highlight_lines: takes 1-based line numbers; line numbers are CSS counters and never " \
          "pollute copied text."
        ].freeze

        option :code, :string, required: true
        option :language, :string, default: "text"
        # The scroll region's accessible name; defaults to the localized
        # "Code" (a focusable scrollable region must be named - axe).
        option :label, :string
        option :line_numbers, :boolean, default: false
        option :highlight_lines, ActiveModel::Type::Value.new
        option :copy, :boolean, default: true

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

        def highlighted
          @highlighted ||= CodeBlockHighlighter.highlight(
            code, language: language, highlight_lines: highlight_lines || []
          )
        end

        def root_attributes
          attrs = {
            "data-slot" => "code-block",
            "data-language" => language,
            "class" => css
          }.merge(component_data_attributes)
          attrs["data-line-numbers"] = "" if line_numbers
          html_attributes.merge_if_not_set(attrs.merge(stimulus_attributes_for(:root)))
        end

        def pre_attributes
          {
            "data-slot" => "code-block-pre",
            "tabindex" => "0",
            "role" => "region",
            "aria-label" => label.presence || t("poetry.code_block.label"),
            "class" => css(:pre)
          }
        end

        def code_attributes
          attrs = Poetry::Core::HTML::Attributes.new(
            "data-slot" => "code-block-code",
            "class" => css(:code)
          )
          attrs.merge!(stimulus_attributes_for(:source))
          attrs
        end

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
      end
    end
  end
end
