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
      end
    end
  end
end
