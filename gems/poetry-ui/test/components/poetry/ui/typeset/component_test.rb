# frozen_string_literal: true

require "test_helper"

module Poetry
  module Ui
    module Typeset
      class ComponentTest < ViewComponent::TestCase
        def test_renders_the_prose_container_with_the_switch_class
          fragment = render_inline(Component.new) { "<p>prose</p>".html_safe }
          root = fragment.css('[data-slot="typeset"]').first

          assert root
          assert_includes root["class"], "typeset"
          assert_equal "prose", root.css("p").first.text
        end

        def test_preset_appends_its_class_and_caller_classes_survive
          fragment = render_inline(Component.new(preset: "docs", class: "max-w-xl")) { "x" }
          root = fragment.css('[data-slot="typeset"]').first

          assert_includes root["class"], "typeset"
          assert_includes root["class"], "typeset-docs"
          assert_includes root["class"], "max-w-xl"
        end

        def test_without_content_it_raises
          assert_raises(ArgumentError) { render_inline(Component.new) }
        end
      end

      # The upstream streaming-invariant contract (shadcn 3cdaa6eb,
      # packages/tests/src/tests/typeset.test.ts), ported against the gem's
      # shipped file: appending a block must never restyle the blocks
      # already on screen, so the stylesheet bans forward-looking selectors
      # and backward-facing spacing. Runs on the SOURCE file the installer
      # copies - a drifted edit fails here before any app inherits it.
      class StylesheetInvariantsTest < ActiveSupport::TestCase
        CSS = Poetry::Ui.root.join("typeset/typeset.css").read
        # Selectors only: the prose comments legitimately NAME the banned
        # selectors ("not tr:last-child: append-safe").
        RULES = CSS.gsub(%r{/\*.*?\*/}m, "").freeze

        def test_keeps_the_three_rhythm_knobs
          assert_includes CSS, "--typeset-size:"
          assert_includes CSS, "--typeset-leading:"
          assert_includes CSS, "--typeset-flow:"
        end

        def test_only_spaces_forward
          offenders = CSS.scan(/margin-block-end:\s*([^;]+);/).map(&:first).reject { |v| v.strip == "0" }

          assert_empty offenders, "margin-block-end must always be 0 - spacing flows forward only"
        end

        def test_never_uses_the_margin_shorthand
          assert_no_match(/^\s*margin:\s/, CSS, "the margin shorthand hides a block-end value")
        end

        def test_bans_forward_looking_selectors
          %w[:last-child :has( :empty].each do |selector|
            refute_includes RULES, selector, "#{selector} matches can change as content streams in"
          end
        end

        def test_separates_table_rows_on_cells_not_rows
          assert_includes RULES, "border-block-start: 1px solid"
          refute_includes RULES, "tr:first-child"
        end

        def test_guards_element_rules_with_the_escape_hatch
          assert_includes CSS, ".not-typeset"
          assert_includes CSS, "[data-not-typeset]"
        end
      end
    end
  end
end
