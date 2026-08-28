# frozen_string_literal: true

require "test_helper"

module Poetry
  module Ui
    # Two command-list facts the transcription-fidelity gate cannot see,
    # held per theme:
    #
    # 1. The active command row is data-highlighted (the engine's
    #    twin-write with aria-activedescendant); data-selected is the
    #    committed VALUE on select/combobox options. The source's palette
    #    marks its active row data-selected=true, so a transcribed theme
    #    rule that keeps data-selected styles the wrong state - the
    #    highlight goes invisible while the committed row lights up.
    # 2. The source's palette never renders items outside a group (the
    #    group carries the inset), but poetry's list takes loose items -
    #    the list must carry the inset itself when it holds direct items,
    #    or the first row sits flush under the search well. Lyra's groups
    #    are unpadded, so lyra deliberately carries nothing.
    class ThemeCommandRulesTest < ActiveSupport::TestCase
      THEMES = Dir[File.expand_path("../../../themes/*.css", __dir__)]

      def rule(css, selector)
        css[/^#{Regexp.escape(selector)} \{\n  @apply ([^\n]*);\n\}/, 1] or flunk "#{selector} missing"
      end

      test "the theme roster is present" do
        assert_equal 9, THEMES.size
      end

      THEMES.each do |path|
        theme = File.basename(path, ".css")

        test "#{theme}: .cn-command-item styles data-highlighted, never data-selected" do
          body = rule(File.read(path), ".cn-command-item")

          assert_match(/(^|\s)data-\[?highlighted\]?:/, body,
                       "#{theme}: the highlighted row has no rule - keyboard navigation is invisible")
          refute_match(/(^|\s)data-selected:/, body,
                       "#{theme}: data-selected is the committed value, not the highlight")
        end

        test "#{theme}: .cn-command-shortcut re-colors on the highlighted row" do
          body = rule(File.read(path), ".cn-command-shortcut")

          refute_includes body, "group-data-selected/command-item:",
                          "#{theme}: the shortcut keys on the committed value instead of the highlight"
        end

        test "#{theme}: .cn-command-list carries the loose-item inset" do
          body = rule(File.read(path), ".cn-command-list")

          if theme == "lyra"
            refute_includes body, "has-[>[data-slot=command-item]]",
                            "lyra's groups are unpadded - loose rows are flush by design"
          else
            assert_match(/has-\[>\[data-slot=command-item\]\]:p-1(\.5)?(\s|$)/, body,
                         "#{theme}: a list holding loose items must carry the inset")
            assert_includes body, "has-[>[data-slot=command-item]]:*:data-[slot=command-group]:px-0",
                            "#{theme}: groups in a loose-item list must drop their horizontal padding"
          end
        end

        test "#{theme}: the classic h-12 palette chain rides .cn-command-dialog only in default" do
          body = rule(File.read(path), ".cn-command-dialog")

          if theme == "default"
            assert_includes body, "**:data-[slot=command-input-wrapper]:h-12"
            assert_includes body, "[&_[data-slot=command-item]]:py-3"
          else
            refute_match(/h-12|py-3/, body, "#{theme}: the styled source sizes the dialog palette like the theme")
          end
        end

        test "#{theme}: the combobox list carries its own inset rule" do
          css = File.read(path)

          assert_match(/^\.cn-combobox-list \{/, css, "#{theme}: no .cn-combobox-list rule")
          assert_match(/^\.cn-combobox-label \{/, css, "#{theme}: no .cn-combobox-label rule")
        end
      end
    end
  end
end
