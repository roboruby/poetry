# frozen_string_literal: true

module Poetry
  module Core
    class Tokens
      # An OKLCH color value (with optional alpha) plus the conversion and
      # contrast math the AAA-contrast gate is built on:
      #
      #   OKLCH -> OKLab -> linear sRGB -> gamma sRGB   (Björn Ottosson's matrices)
      #   WCAG 2.x relative luminance + contrast ratio
      #   browser-style alpha compositing (gamma-encoded sRGB blend)
      #
      # Pure Ruby, no dependencies - cheap enough to run on every CI build.
      #
      # @example
      #   color = Poetry::Core::Tokens::Color.parse("#1A1C1E")
      #   color.css # => "oklch(0.225 0.005 248.047)"
      #   color.contrast_ratio(Poetry::Core::Tokens::Color::WHITE) # => 17.09...
      class Color
        # WCAG 2.x contrast shared by Color and Blend: relative luminance is
        # computed from gamma-encoded sRGB (the value a browser actually paints).
        module Contrast
          def luminance
            r, g, b = srgb.map { |v| v <= 0.04045 ? v / 12.92 : ((v + 0.055) / 1.055)**2.4 }
            (0.2126 * r) + (0.7152 * g) + (0.0722 * b)
          end

          def contrast_ratio(other)
            pair = [luminance, other.luminance].sort
            (pair[1] + 0.05) / (pair[0] + 0.05)
          end
        end

        # The result of alpha-compositing one color over another: a plain
        # gamma-encoded sRGB triplet that still knows how to measure contrast.
        Blend = Struct.new(:srgb) do
          include Contrast
        end

        include Contrast

        attr_reader :l, :c, :h, :alpha

        def initialize(l:, c: 0.0, h: 0.0, alpha: 1.0)
          @l = l.to_f
          @c = c.to_f
          @h = h.to_f
          @alpha = alpha.to_f
        end

        # Build from a DTCG color $value: {"colorSpace" => "oklch",
        # "components" => [l, c, h], "alpha" => 0.1 (optional)}.
        def self.from_dtcg(value)
          color_space = value["colorSpace"]
          unless color_space == "oklch"
            raise ArgumentError, "unsupported colorSpace #{color_space.inspect} (only oklch)"
          end

          l, c, h = value.fetch("components")
          new(l: l, c: c, h: h, alpha: value.fetch("alpha", 1.0))
        end

        WHITE = new(l: 1.0)
        BLACK = new(l: 0.0)

        # The CSS color spellings DESIGN.md files carry across the design-skill
        # ecosystem: poetry emits oklch; foreign-authored files arrive in
        # hex or rgb().
        OKLCH_CSS = %r{\Aoklch\(\s*([\d.]+)(%?)\s+([\d.]+)\s+([\d.]+)(?:\s*/\s*([\d.]+)(%?))?\s*\)\z}i
        HEX_CSS = /\A#(\h{3}|\h{4}|\h{6}|\h{8})\z/
        RGB_CSS = %r{\Argba?\(\s*(\d{1,3})\s*[,\s]\s*(\d{1,3})\s*[,\s]\s*(\d{1,3})(?:\s*[,/]\s*([\d.]+)(%?))?\s*\)\z}i

        class << self
          # Parse a CSS color string into a Color, or nil for anything else
          # (named colors, var() refs, gradients) - the DESIGN.md importer
          # DROPS what it cannot parse, never guesses. oklch input keeps its
          # components verbatim so poetry-authored values round-trip
          # byte-exact through parse -> css.
          def parse(css)
            value = css.to_s.strip
            if (match = value.match(OKLCH_CSS))
              lightness = match[2] == "%" ? match[1].to_f / 100.0 : match[1].to_f
              new(l: lightness, c: match[3].to_f, h: match[4].to_f, alpha: parse_alpha(match[5], match[6]))
            elsif (match = value.match(HEX_CSS))
              from_hex(match[1])
            elsif (match = value.match(RGB_CSS))
              channels = [match[1], match[2], match[3]].map { |channel| channel.to_i / 255.0 }
              from_srgb(channels, alpha: parse_alpha(match[4], match[5]))
            end
          end

          # Gamma-encoded sRGB [0,1] triplet -> Color, via Ottosson's inverse
          # path (linear sRGB -> LMS -> OKLab -> LCH). Components round to the
          # 3-decimal precision shadcn themes publish.
          def from_srgb(srgb, alpha: 1.0)
            r, g, b = srgb.map { |v| v <= 0.04045 ? v / 12.92 : ((v + 0.055) / 1.055)**2.4 }

            l_ = Math.cbrt((0.4122214708 * r) + (0.5363325363 * g) + (0.0514459929 * b))
            m_ = Math.cbrt((0.2119034982 * r) + (0.6806995451 * g) + (0.1073969566 * b))
            s_ = Math.cbrt((0.0883024619 * r) + (0.2817188376 * g) + (0.6299787005 * b))

            lab_l = (0.2104542553 * l_) + (0.7936177850 * m_) - (0.0040720468 * s_)
            lab_a = (1.9779984951 * l_) - (2.4285922050 * m_) + (0.4505937099 * s_)
            lab_b = (0.0259040371 * l_) + (0.7827717662 * m_) - (0.8086757660 * s_)

            chroma = Math.sqrt((lab_a**2) + (lab_b**2))
            hue = chroma < 1e-4 ? 0.0 : ((Math.atan2(lab_b, lab_a) * 180.0 / Math::PI) % 360.0)
            new(l: lab_l.clamp(0.0, 1.0).round(3), c: chroma.round(3), h: hue.round(3), alpha: alpha)
          end

          private

          def from_hex(digits)
            digits = digits.chars.map { |d| d * 2 }.join if digits.length <= 4
            channels = digits.scan(/\h{2}/).map { |pair| pair.to_i(16) / 255.0 }
            from_srgb(channels.first(3), alpha: channels.fetch(3, 1.0))
          end

          def parse_alpha(raw, percent)
            return 1.0 if raw.nil?

            percent == "%" ? raw.to_f / 100.0 : raw.to_f
          end
        end

        # A copy with any component replaced. The import AA-walk moves L in
        # fixed steps while chroma holds - deterministic.
        def with(l: self.l, c: self.c, h: self.h, alpha: self.alpha)
          self.class.new(l: l, c: c, h: h, alpha: alpha)
        end

        # The CSS serialization, matching shadcn's formatting:
        # "oklch(0.577 0.245 27.325)" / "oklch(1 0 0 / 10%)".
        def css
          base = [l, c, h].map { |v| format("%g", v) }.join(" ")
          alpha < 1.0 ? "oklch(#{base} / #{format("%g", alpha * 100)}%)" : "oklch(#{base})"
        end

        # Gamma-encoded sRGB components, each clamped to [0, 1].
        def srgb
          @srgb ||= linear_srgb.map { |v| v <= 0.0031308 ? 12.92 * v : (1.055 * (v**(1.0 / 2.4))) - 0.055 }
        end

        # Alpha-composite this color over an opaque background, the way a
        # browser blends (per-channel, gamma-encoded). Returns a Blend.
        def composite_over(background)
          blended = srgb.zip(background.srgb).map { |fg, bg| (alpha * fg) + ((1.0 - alpha) * bg) }
          Blend.new(blended)
        end

        private

        # OKLCH -> OKLab -> linear sRGB (Ottosson's OKLab matrices), clamped to
        # gamut. Clamping matches how out-of-gamut CSS colors rasterize.
        def linear_srgb
          a = c * Math.cos(h * Math::PI / 180.0)
          b = c * Math.sin(h * Math::PI / 180.0)

          l_ = (l + (0.3963377774 * a) + (0.2158037573 * b))**3
          m_ = (l - (0.1055613458 * a) - (0.0638541728 * b))**3
          s_ = (l - (0.0894841775 * a) - (1.2914855480 * b))**3

          [
            (+4.0767416621 * l_) - (3.3077115913 * m_) + (0.2309699292 * s_),
            (-1.2684380046 * l_) + (2.6097574011 * m_) - (0.3413193965 * s_),
            (-0.0041960863 * l_) - (0.7034186147 * m_) + (1.7076147010 * s_)
          ].map { |v| v.clamp(0.0, 1.0) }
        end
      end
    end
  end
end
