# frozen_string_literal: true

require "test_helper"

module Poetry
  module Core
    class TokensTest < Minitest::Test
      def setup
        @tokens = Tokens.load
      end

      def test_loads_both_modes
        assert_equal %w[light dark], @tokens.modes
      end

      def test_shadcn_v4_drop_in_var_set_parity
        # The drop-in contract (M1 DoD): poetry defines exactly the shadcn v4
        # distributed var set in BOTH modes, so any shadcn theme block can
        # replace tokens.css wholesale.
        @tokens.modes.each do |mode|
          assert_equal Tokens::SHADCN_V4_COMPAT_VARS.sort, @tokens.color_names(mode).sort,
                       "#{mode} color tokens must match the shadcn v4 var set exactly"
        end
      end

      def test_every_color_token_parses_to_oklch
        @tokens.modes.each do |mode|
          @tokens.color_names(mode).each do |name|
            color = @tokens.color(mode, name)

            assert_kind_of Tokens::Color, color
            assert color.l.between?(0.0, 1.0), "#{mode}/#{name} lightness out of range"
          end
        end
      end

      def test_dark_border_and_input_carry_alpha
        assert_in_delta 0.10, @tokens.color("dark", "border").alpha
        assert_in_delta 0.15, @tokens.color("dark", "input").alpha
        assert_equal "oklch(1 0 0 / 10%)", @tokens.color("dark", "border").css
      end

      def test_radius_css
        assert_equal "0.625rem", @tokens.radius_css
      end

      def test_unknown_token_raises_key_error
        assert_raises(KeyError) { @tokens.color("light", "nope") }
      end
    end
  end
end
