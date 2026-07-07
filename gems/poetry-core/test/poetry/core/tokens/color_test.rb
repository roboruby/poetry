# frozen_string_literal: true

require "test_helper"

module Poetry
  module Core
    class Tokens
      class ColorTest < Minitest::Test
        def test_white_and_black_luminance_bounds
          assert_in_delta 1.0, Color::WHITE.luminance, 0.0001
          assert_in_delta 0.0, Color::BLACK.luminance, 0.0001
        end

        def test_white_on_black_is_maximum_contrast
          assert_in_delta 21.0, Color::WHITE.contrast_ratio(Color::BLACK), 0.01
        end

        def test_contrast_ratio_is_symmetric
          a = Color.new(l: 0.97)
          b = Color.new(l: 0.205)

          assert_in_delta a.contrast_ratio(b), b.contrast_ratio(a), 0.0001
        end

        def test_known_shadcn_pair_ratio
          # primary-foreground (0.985) on primary (0.205), the shipped light pair.
          ratio = Color.new(l: 0.985).contrast_ratio(Color.new(l: 0.205))

          assert_in_delta 17.16, ratio, 0.05
        end

        def test_chromatic_conversion_destructive_red
          # shadcn light destructive: white text measures ~4.76:1 on it (the
          # red is slightly out of sRGB gamut; channels clamp before encoding).
          destructive = Color.new(l: 0.577, c: 0.245, h: 27.325)

          assert_in_delta 4.76, Color::WHITE.contrast_ratio(destructive), 0.05
        end

        def test_css_serialization_matches_shadcn_formatting
          assert_equal "oklch(1 0 0)", Color.new(l: 1).css
          assert_equal "oklch(0.577 0.245 27.325)", Color.new(l: 0.577, c: 0.245, h: 27.325).css
          assert_equal "oklch(1 0 0 / 10%)", Color.new(l: 1, alpha: 0.1).css
        end

        def test_from_dtcg_reads_components_and_alpha
          color = Color.from_dtcg("colorSpace" => "oklch", "components" => [0.97, 0, 0], "alpha" => 0.5)

          assert_in_delta 0.97, color.l
          assert_in_delta 0.5, color.alpha
        end

        def test_from_dtcg_rejects_other_color_spaces
          assert_raises(ArgumentError) do
            Color.from_dtcg("colorSpace" => "srgb", "components" => [1, 1, 1])
          end
        end

        def test_composite_over_blends_toward_background
          # 60% white over black = mid gray in gamma space: luminance well
          # between the two, closer to the composite weighting.
          blend = Color.new(l: 1, alpha: 0.6).composite_over(Color::BLACK)

          assert_in_delta 0.6, blend.srgb[0], 0.0001
          assert blend.luminance.between?(0.2, 0.4)
        end

        def test_fully_opaque_composite_equals_the_color
          red = Color.new(l: 0.577, c: 0.245, h: 27.325)
          blend = red.composite_over(Color::WHITE)

          assert_in_delta red.luminance, blend.luminance, 0.0001
        end

        def test_parse_oklch_keeps_components_verbatim
          # poetry-authored values round-trip byte-exact through parse -> css.
          ["oklch(1 0 0)", "oklch(0.577 0.245 27.325)", "oklch(1 0 0 / 10%)"].each do |css|
            assert_equal css, Color.parse(css).css
          end
        end

        def test_parse_oklch_percent_lightness_and_bare_alpha
          color = Color.parse("oklch(57.7% 0.245 27.325 / 0.5)")

          assert_in_delta 0.577, color.l
          assert_in_delta 0.5, color.alpha
        end

        def test_parse_hex_extremes_land_on_the_neutral_axis
          assert_equal "oklch(1 0 0)", Color.parse("#ffffff").css
          assert_equal "oklch(0 0 0)", Color.parse("#000").css
        end

        def test_parse_hex_red_matches_the_published_oklch
          # sRGB pure red is oklch(0.628 0.258 29.234) in every reference
          # implementation - the inverse matrices are only right if this is.
          color = Color.parse("#ff0000")

          assert_in_delta 0.628, color.l, 0.001
          assert_in_delta 0.258, color.c, 0.001
          assert_in_delta 29.234, color.h, 0.01
        end

        def test_parse_inverse_agrees_with_the_forward_conversion
          # hex -> Color -> srgb must land back on the original channels.
          color = Color.parse("#1a1c1e")

          assert_equal([0x1a, 0x1c, 0x1e], color.srgb.map { |v| (v * 255).round })
        end

        def test_parse_rgb_forms_and_hex_alpha
          assert_equal "oklch(1 0 0)", Color.parse("rgb(255, 255, 255)").css
          assert_in_delta 0.5, Color.parse("rgba(255, 255, 255, 0.5)").alpha
          assert_in_delta 0x80 / 255.0, Color.parse("#ffffff80").alpha, 0.01
        end

        def test_parse_drops_what_it_cannot_read
          [nil, "", "bisque", "var(--primary)", "linear-gradient(red, blue)", "hsl(0 0% 0%)"].each do |value|
            assert_nil Color.parse(value), "#{value.inspect} must parse to nil, never a guess"
          end
        end

        def test_with_replaces_only_the_named_component
          color = Color.new(l: 0.5, c: 0.2, h: 120.0, alpha: 0.9)
          walked = color.with(l: 0.4)

          assert_in_delta 0.4, walked.l
          assert_in_delta 0.2, walked.c
          assert_in_delta 120.0, walked.h
          assert_in_delta 0.9, walked.alpha
        end
      end
    end
  end
end
