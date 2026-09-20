# frozen_string_literal: true

require "test_helper"

module Poetry
  module Extract
    # The derived mode keeps a primary that already sits on the right side
    # of its canvas: a light primary stays light in the dark mode, a dark
    # one stays dark in the light mode (only a sinking color is pulled
    # toward the canvas).
    class DeriveTokensPaletteTest < Minitest::Test
      def test_a_light_primary_is_left_alone_in_the_derived_dark_mode
        css = DeriveTokens.derive_css_variables("example.com", nil, light_styleguide("#eeeeee"))

        assert_includes root_block(css), "--primary: #eeeeee;"
        assert_includes dark_block(css), "--primary: #eeeeee;"
      end

      def test_a_dark_primary_is_left_alone_in_the_derived_light_mode
        css = DeriveTokens.derive_css_variables("example.com", nil, dark_styleguide("#111111"))

        assert_includes dark_block(css), "--primary: #111111;"
        assert_includes root_block(css), "--primary: #111111;"
      end

      private

      def light_styleguide(primary)
        { "mode" => "light", "colors" => { "background" => "#ffffff", "text" => "#0a0a0a" },
          "components" => { "button" => { "primary" => { "backgroundColor" => primary, "color" => "#0a0a0a" } } } }
      end

      def dark_styleguide(primary)
        { "mode" => "dark", "colors" => { "background" => "#171715", "text" => "#f5f5f4" },
          "components" => { "button" => { "primary" => { "backgroundColor" => primary, "color" => "#f5f5f4" } } } }
      end

      def root_block(css) = css[/:root \{.*?\n\}/m]

      def dark_block(css) = css[/\.dark \{.*?\n\}/m]
    end
  end
end
