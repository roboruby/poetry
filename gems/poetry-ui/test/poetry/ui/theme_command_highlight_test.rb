# frozen_string_literal: true

require "test_helper"

module Poetry
  module Ui
    # The active command row is data-highlighted (the engine's twin-write
    # with aria-activedescendant); data-selected is the committed VALUE
    # on select/combobox options. The source's palette marks its active
    # row data-selected=true, so a transcribed theme rule that keeps
    # data-selected styles the wrong state - the highlight goes invisible
    # while the committed row lights up. Every theme must style the
    # highlight, in the item and in its shortcut re-color.
    class ThemeCommandHighlightTest < ActiveSupport::TestCase
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

        test "#{theme}: the combobox list carries its own inset rule" do
          css = File.read(path)

          assert_match(/^\.cn-combobox-list \{/, css, "#{theme}: no .cn-combobox-list rule")
          assert_match(/^\.cn-combobox-label \{/, css, "#{theme}: no .cn-combobox-label rule")
        end
      end
    end
  end
end
