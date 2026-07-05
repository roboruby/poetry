# frozen_string_literal: true

require "test_helper"

module Poetry
  module Charts
    # The config contract: shadcn's ChartConfig shape (label/icon + color
    # XOR theme), with the poetry addition that every key and color is
    # validated CSS-safe at wrap time - the config feeds a <style> element.
    class ConfigTest < ActiveSupport::TestCase
      def test_wraps_a_hash_and_resolves_entries
        config = Config.wrap(desktop: { label: "Desktop", color: "var(--chart-1)" })

        assert_equal %w[desktop], config.keys
        assert_equal "Desktop", config[:desktop].label
        assert_equal "var(--chart-1)", config[:desktop].color
      end

      def test_wrap_passes_a_config_through
        config = Config.wrap(desktop: { color: "var(--chart-1)" })

        assert_same config, Config.wrap(config)
      end

      def test_color_entries_skips_label_only_series
        config = Config.wrap(
          desktop: { label: "Desktop", color: "var(--chart-1)" },
          other: { label: "Other" }
        )

        assert_equal %w[desktop], config.color_entries.map(&:key)
      end

      def test_theme_entries_resolve_per_mode
        config = Config.wrap(revenue: { theme: { light: "#0ea5e9", dark: "#38bdf8" } })

        assert_equal "#0ea5e9", config[:revenue].color_for(:light)
        assert_equal "#38bdf8", config[:revenue].color_for(:dark)
        assert_predicate config[:revenue], :colored?
      end

      def test_label_for_falls_back_key_then_given
        config = Config.wrap(desktop: { label: "Desktop" })

        assert_equal "Desktop", config.label_for(:desktop)
        assert_equal "mobile", config.label_for(:mobile)
        assert_equal "Phones", config.label_for(:mobile, "Phones")
      end

      def test_rejects_css_unsafe_colors
        error = assert_raises(ArgumentError) do
          Config.wrap(evil: { color: "red;} body{display:none" })
        end

        assert_match(/not CSS-safe/, error.message)
      end

      def test_rejects_css_unsafe_keys
        assert_raises(ArgumentError) { Config.wrap("bad key}" => { color: "red" }) }
      end

      def test_rejects_color_and_theme_together
        assert_raises(ArgumentError) do
          Config.wrap(x: { color: "red", theme: { light: "red", dark: "pink" } })
        end
      end

      def test_rejects_unknown_theme_modes
        assert_raises(ArgumentError) { Config.wrap(x: { theme: { sepia: "tan" } }) }
      end
    end
  end
end
