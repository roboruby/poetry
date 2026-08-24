# frozen_string_literal: true

require "bigdecimal/util"

module Poetry
  module Extract
    # Deterministic token derivation - a function-for-function Ruby port of
    # an MIT-licensed token deriver (source and license in
    # THIRD_PARTY_NOTICES.md). Inputs are the context.dev styleguide
    # and brand payloads as string-keyed hashes (parsed JSON); outputs are
    # the Tailwind v4 theme stylesheet and the vanilla CSS :root variables.
    #
    # Parity doctrine: the ported source is the ORACLE - test/fixtures/oracle
    # runs it on canned inputs and this port must reproduce its outputs
    # byte-for-byte, so behavior must match it bit-for-bit. The source's JS
    # semantics are mirrored deliberately (parseFloat leniency via js_float,
    # toFixed formatting via format_number); do not "clean up" behavior here
    # without regenerating the fixtures oracle-first.
    #
    # Every helper in here is that parity-port math; the gem's public
    # surface is Runner.run!.
    # @api private
    module DeriveTokens
      WHITE = { r: 255.0, g: 255.0, b: 255.0 }.freeze
      BLACK = { r: 0.0, g: 0.0, b: 0.0 }.freeze

      SANS_FALLBACKS = %w[ui-sans-serif system-ui sans-serif].freeze
      SERIF_FALLBACKS = %w[ui-serif Georgia serif].freeze
      MONO_FALLBACKS = %w[ui-monospace SFMono-Regular Menlo monospace].freeze

      MIN_SPACING_PX = 3.5
      DEFAULT_SPACING_PX = 4
      MAX_SPACING_PX = 5

      module_function

      # --- Public API ------------------------------------------------------

      def derive_tailwind_theme(_domain, brand = nil, styleguide = nil)
        root_body, dark_body = bodies(brand, styleguide)
        [
          %(@import "tailwindcss";), "",
          "@custom-variant dark (&:is(.dark *));", "",
          ":root {", indent(root_body), "}", "",
          ".dark {", indent(dark_body), "}", "",
          theme_inline_block, "",
          layer_base, ""
        ].join("\n")
      end

      def derive_css_variables(domain, brand = nil, styleguide = nil)
        root_body, dark_body = bodies(brand, styleguide)
        [
          "/* #{domain} — design tokens (vanilla CSS) */",
          ":root {", indent(root_body), "}", "",
          ".dark {", indent(dark_body), "}", ""
        ].join("\n")
      end

      def bodies(brand, styleguide)
        light = build_palette(brand, styleguide, "light")
        dark = build_palette(brand, styleguide, "dark")
        fonts = pick_fonts(styleguide)
        radius = pick_radius(styleguide)
        light_shadows = pick_shadows(styleguide, light, "light")
        dark_shadows = pick_shadows(styleguide, dark, "dark")
        spacing = pick_spacing(styleguide)
        tracking = pick_tracking_normal(styleguide)

        [palette_lines(light) + non_color_lines(fonts, radius, light_shadows, tracking, spacing),
         palette_lines(dark) + non_color_lines(fonts, radius, dark_shadows)]
      end

      # --- Color utilities -------------------------------------------------

      def parse_hex(hex)
        return nil unless hex

        clean = hex.strip.delete_prefix("#")
        return nil unless /\A(?:[0-9a-f]{3}|[0-9a-f]{6}|[0-9a-f]{8})\z/i.match?(clean)

        if clean.length == 3
          { r: Integer(clean[0] * 2, 16).to_f, g: Integer(clean[1] * 2, 16).to_f,
            b: Integer(clean[2] * 2, 16).to_f }
        else
          { r: Integer(clean[0, 2], 16).to_f, g: Integer(clean[2, 2], 16).to_f,
            b: Integer(clean[4, 2], 16).to_f }
        end
      end

      def to_hex(color)
        hx = ->(n) { format("%02x", n.round.clamp(0, 255)) }
        "##{hx.call(color[:r])}#{hx.call(color[:g])}#{hx.call(color[:b])}"
      end

      def mix(from, to, amount)
        { r: from[:r] + ((to[:r] - from[:r]) * amount),
          g: from[:g] + ((to[:g] - from[:g]) * amount),
          b: from[:b] + ((to[:b] - from[:b]) * amount) }
      end

      def luminance(color)
        f = lambda do |c|
          s = c / 255.0
          s <= 0.03928 ? s / 12.92 : ((s + 0.055) / 1.055)**2.4
        end
        (0.2126 * f.call(color[:r])) + (0.7152 * f.call(color[:g])) + (0.0722 * f.call(color[:b]))
      end

      def dark?(color) = luminance(color) < 0.5

      def readable(background) = dark?(background) ? "#ffffff" : "#0a0a0a"

      def clamp(number, min, max) = number.clamp(min, max)

      # JS parseFloat: leading number or nil - "5.9%" => 5.9, "abc" => nil.
      def js_float(value)
        m = value.to_s.strip.match(/\A[+-]?(?:\d+\.?\d*|\.\d+)(?:e[+-]?\d+)?/i)
        m && Float(m[0])
      end

      # JS Number#toFixed: ties on the exact binary value round HALF AWAY
      # FROM ZERO (V8: (-0.03125).toFixed(4) => "-0.0313"), where C sprintf
      # rounds half to even ("-0.0312") - BigDecimal over the float's exact
      # expansion mirrors JS. The parity fixtures caught this.
      def js_to_fixed(number, decimals)
        format("%.#{decimals}f", number.to_f.to_d.round(decimals, half: :up))
      end

      # JS toFixed + trailing-zero strip: 12.0 => "12", 0.18 => "0.18".
      def format_number(number, decimals = 4)
        js_to_fixed(number, decimals).sub(/\.?0+\z/, "")
      end

      def rgb_to_hsl_token(color)
        rr = color[:r] / 255.0
        gg = color[:g] / 255.0
        bb = color[:b] / 255.0
        max = [rr, gg, bb].max
        min = [rr, gg, bb].min
        delta = max - min

        h = 0.0
        if delta != 0
          h = if max == rr then ((gg - bb) / delta) % 6
              elsif max == gg then ((bb - rr) / delta) + 2
              else ((rr - gg) / delta) + 4
              end
          h *= 60
          h += 360 if h.negative?
        end

        l = (max + min) / 2
        s = delta.zero? ? 0.0 : delta / (1 - ((2 * l) - 1).abs)

        "hsl(#{format_number(h, 1)} #{format_number(s * 100, 1)}% #{format_number(l * 100, 1)}%)"
      end

      def normalize_css_color(raw)
        return nil unless raw

        value = raw.strip
        hex = parse_hex(value)
        return { color: rgb_to_hsl_token(hex) } if hex

        normalize_hsl(value) || normalize_rgb(value)
      end

      def normalize_hsl(value)
        m = value.match(/\Ahsla?\((.+)\)\z/i)
        return nil unless m

        channels, alpha_part = split_channels(m[1].strip)
        parts = channels.split(/[,\s]+/).map(&:strip).reject(&:empty?)
        return nil if parts.length < 3

        h, s, l = parts[0, 3].map { |part| js_float(part) }
        alpha = alpha_part ? js_float(alpha_part) : (parts[3] && js_float(parts[3]))
        return nil unless [h, s, l].all?

        { color: "hsl(#{format_number(h, 1)} #{format_number(s, 1)}% #{format_number(l, 1)}%)",
          opacity: alpha && clamp(alpha, 0, 1) }.compact
      end

      def normalize_rgb(value)
        m = value.match(/\Argba?\((.+)\)\z/i)
        return nil unless m

        channels, alpha_part = split_channels(m[1].strip)
        parts = channels.split(/[,\s]+/).map(&:strip).reject(&:empty?)
        return nil if parts.length < 3

        to_channel = ->(part) { (n = js_float(part)) && (part.end_with?("%") ? n / 100 * 255 : n) }
        r, g, b = parts[0, 3].map { |part| to_channel.call(part) }
        alpha = alpha_part ? js_float(alpha_part) : (parts[3] && js_float(parts[3]))
        return nil unless [r, g, b].all?

        { color: rgb_to_hsl_token({ r: r, g: g, b: b }),
          opacity: alpha && clamp(alpha, 0, 1) }.compact
      end

      def split_channels(body)
        body.include?("/") ? body.split("/", 2) : [body, nil]
      end

      # --- Length utilities ------------------------------------------------

      def to_px(value)
        return nil unless value

        m = value.to_s.strip.match(/\A(-?\d*\.?\d+)\s*(px|rem|em)?\z/i)
        return nil unless m

        n = Float(m[1])
        unit = (m[2] || "px").downcase
        %w[rem em].include?(unit) ? n * 16 : n
      end

      def to_px_list(value)
        return [] unless value

        value.to_s.strip.split(/\s+/).filter_map { |part| to_px(part) }.select(&:positive?)
      end

      def px_to_rem(pixels)
        "#{js_to_fixed(pixels / 16.0, 4).sub(/\.?0+\z/, "")}rem"
      end

      # --- Font utilities --------------------------------------------------

      def quote_if_needed(name)
        trimmed = name.strip.gsub(/\A["']|["']\z/, "")
        return trimmed if trimmed.empty?
        return %("#{trimmed}") if /[^a-zA-Z0-9_-]/.match?(trimmed) && !/\A[a-z-]+\z/.match?(trimmed)

        trimmed
      end

      def build_font_stack(primary, fallbacks, generic)
        seen = {}
        stack = []
        push = lambda do |name|
          next unless name

          trimmed = name.strip.gsub(/\A["']|["']\z/, "")
          next if trimmed.empty?
          next if seen[trimmed.downcase]

          seen[trimmed.downcase] = true
          stack << quote_if_needed(trimmed)
        end
        push.call(primary)
        (fallbacks || []).each(&push)
        generic.each(&push)
        stack.join(", ")
      end

      def classify_family(family, font_links)
        return "unknown" unless family

        first = family.split(",")[0]&.strip&.gsub(/\A["']|["']\z/, "")
        category = first && font_links&.dig(first, "category")
        if category
          cat = category.downcase
          return "mono" if cat.include?("mono")
          return "serif" if cat.include?("serif") && !cat.include?("sans")
          return "sans" if cat.include?("sans") || cat.include?("display") || cat.include?("hand")
        end
        stripped = family.downcase.gsub("sans-serif", "")
        return "mono" if /\b(monospace|mono)\b/.match?(family.downcase)
        return "serif" if /\bserif\b/.match?(stripped)
        return "sans" if family.downcase.include?("sans-serif")

        "unknown"
      end

      def find_mono_family(font_links)
        font_links&.each do |name, link|
          return name if link["category"]&.downcase&.include?("mono")
        end
        nil
      end

      def find_serif_family(font_links, exclude)
        font_links&.each do |name, link|
          next if exclude.include?(name.downcase)

          cat = link["category"]&.downcase || ""
          return name if cat.include?("serif") && !cat.include?("sans")
        end
        nil
      end

      def pick_fonts(styleguide)
        body = styleguide&.dig("typography", "p")
        h1 = styleguide&.dig("typography", "headings", "h1")
        links = styleguide&.dig("fontLinks")

        sans_family = body&.dig("fontFamily") || h1&.dig("fontFamily")
        sans_fallbacks = body&.dig("fontFallbacks") || h1&.dig("fontFallbacks")
        sans = build_font_stack(sans_family, sans_fallbacks, SANS_FALLBACKS)

        used = {}
        used[sans_family.downcase] = true if sans_family

        serif = nil
        [h1, styleguide&.dig("typography", "headings", "h2"),
         styleguide&.dig("typography", "headings", "h3")].each do |head|
          fam = head&.dig("fontFamily")
          next if !fam || used[fam.downcase]
          next unless classify_family(fam, links) == "serif"

          serif = build_font_stack(fam, head["fontFallbacks"], SERIF_FALLBACKS)
          break
        end
        if serif.nil? && (from_links = find_serif_family(links, used.keys))
          serif = build_font_stack(from_links, nil, SERIF_FALLBACKS)
        end

        mono = build_font_stack(find_mono_family(links), nil, MONO_FALLBACKS)

        { sans: sans, serif: serif || build_font_stack(nil, nil, SERIF_FALLBACKS), mono: mono }
      end

      # --- Radius / shadows / spacing --------------------------------------

      def pick_radius(styleguide)
        card_radius = to_px(styleguide&.dig("components", "card", "borderRadius"))
        button_radius = to_px(styleguide&.dig("components", "button", "primary", "borderRadius"))
        px = card_radius || button_radius
        return "0.5rem" if px.nil?

        px_to_rem(px.clamp(2, 16))
      end

      def normalize_px_token(value, fallback)
        px = to_px(value)
        px.nil? ? fallback : "#{format_number(px, 2)}px"
      end

      def split_shadow_layers(value)
        layers = []
        depth = 0
        start = 0
        value.each_char.with_index do |ch, i|
          depth += 1 if ch == "("
          depth = [0, depth - 1].max if ch == ")"
          if ch == "," && depth.zero?
            layers << value[start...i].strip
            start = i + 1
          end
        end
        layers << value[start..].strip
        layers.reject(&:empty?)
      end

      def find_color_snippet(layer)
        layer[/\b(?:rgba?|hsla?)\([^)]+\)/i] || layer[/#[0-9a-f]{3,8}\b/i]
      end

      def parse_box_shadow(value)
        return nil if !value || value.strip.downcase == "none"

        layer = split_shadow_layers(value)[0]
        return nil if layer.nil? || layer.empty?

        color_snippet = find_color_snippet(layer)
        color = normalize_css_color(color_snippet)
        without_color = color_snippet ? layer.sub(color_snippet, " ") : layer
        lengths = without_color.gsub(/\binset\b/i, " ").split(/\s+/)
                               .map(&:strip).select { |part| to_px(part) }
        return nil if lengths.length < 2

        { x: normalize_px_token(lengths[0], "0px"),
          y: normalize_px_token(lengths[1], "2px"),
          blur: normalize_px_token(lengths[2], "3px"),
          spread: normalize_px_token(lengths[3], "0px"),
          color: color && color[:color],
          opacity: color && color[:opacity] }
      end

      def color_with_opacity(color, opacity)
        alpha = format_number(clamp(opacity, 0, 1), 4)
        if (m = color.match(/\Ahsl\((.+)\)\z/i))
          "hsl(#{m[1]} / #{alpha})"
        elsif (m = color.match(/\Argb\((.+)\)\z/i))
          "rgb(#{m[1]} / #{alpha})"
        else
          color
        end
      end

      def fallback_shadow_color(palette, mode)
        bg = parse_hex(palette[:background])
        fg = parse_hex(palette[:foreground])
        return "hsl(0 0% 5%)" if mode == "dark"
        return rgb_to_hsl_token(mix(fg, bg, 0.15)) if bg && fg

        fg ? rgb_to_hsl_token(fg) : "hsl(0 0% 5%)"
      end

      def build_shadow_tokens(base)
        half = base[:opacity] * 0.5
        heavy = [base[:opacity] * 2.5, 0.75].min
        main = color_with_opacity(base[:color], base[:opacity])
        quiet = color_with_opacity(base[:color], half)
        loud = color_with_opacity(base[:color], heavy)
        first = "#{base[:x]} #{base[:y]} #{base[:blur]} #{base[:spread]}"
        second = ->(y, blur, spread) { "#{base[:x]} #{y} #{blur} #{spread}" }

        { x: base[:x], y: base[:y], blur: base[:blur], spread: base[:spread],
          opacity: format_number(base[:opacity], 4), color: base[:color],
          shadow2xs: "#{first} #{quiet}",
          xs: "#{first} #{quiet}",
          sm: "#{first} #{main}, #{second.call("1px", "2px", "-1px")} #{main}",
          base: "#{first} #{main}, #{second.call("1px", "2px", "-1px")} #{main}",
          md: "#{first} #{main}, #{second.call("2px", "4px", "-1px")} #{main}",
          lg: "#{first} #{main}, #{second.call("4px", "6px", "-1px")} #{main}",
          xl: "#{first} #{main}, #{second.call("8px", "10px", "-1px")} #{main}",
          shadow2xl: "#{first} #{loud}" }
      end

      def pick_shadows(styleguide, palette, mode)
        s = styleguide&.dig("shadows")
        candidates = [
          s&.dig("md"),
          styleguide&.dig("components", "card", "boxShadow"),
          styleguide&.dig("components", "button", "primary", "boxShadow"),
          s&.dig("sm"), s&.dig("lg"), s&.dig("xl")
        ]
        parsed = candidates.lazy.map { |candidate| parse_box_shadow(candidate) }.find(&:itself)

        build_shadow_tokens(
          x: parsed&.dig(:x) || "0px",
          y: parsed&.dig(:y) || "2px",
          blur: parsed&.dig(:blur) || "3px",
          spread: parsed&.dig(:spread) || "0px",
          color: parsed&.dig(:color) || fallback_shadow_color(palette, mode),
          opacity: parsed&.dig(:opacity) || 0.18
        )
      end

      def median(values)
        return nil if values.empty?

        sorted = values.sort
        mid = sorted.length / 2
        return sorted[mid] if sorted.length.odd?

        (sorted[mid - 1] + sorted[mid]) / 2.0
      end

      def pick_spacing(styleguide)
        sp = styleguide&.dig("elementSpacing")
        divided = lambda do |value, divisor|
          px = to_px(value)
          px && !px.zero? ? px / divisor : nil
        end
        scale_candidates = [
          to_px(sp&.dig("xs")),
          divided.call(sp&.dig("sm"), 2), divided.call(sp&.dig("md"), 4),
          divided.call(sp&.dig("lg"), 6), divided.call(sp&.dig("xl"), 8)
        ].compact.select(&:positive?)

        component_padding = [
          styleguide&.dig("components", "button", "primary", "padding"),
          styleguide&.dig("components", "button", "secondary", "padding"),
          styleguide&.dig("components", "card", "padding")
        ].flat_map { |value| to_px_list(value) }
        padding_candidates = component_padding.map { |value| value / 4.0 }

        picked = median(scale_candidates + padding_candidates) || DEFAULT_SPACING_PX
        safe_unit = clamp((picked * 2).round / 2.0, MIN_SPACING_PX, MAX_SPACING_PX)
        px_to_rem(safe_unit)
      end

      def pick_tracking_normal(styleguide)
        values = [styleguide&.dig("typography", "p", "letterSpacing"),
                  styleguide&.dig("typography", "headings", "h1", "letterSpacing")]
        value = values.find { |v| v && v.strip.downcase != "normal" }
        return "0em" unless value

        trimmed = value.strip
        m = trimmed.match(/\A(-?\d*\.?\d+)\s*(px|rem|em)?\z/i)
        return trimmed unless m

        n = Float(m[1])
        unit = (m[2] || "em").downcase
        unit == "px" ? "#{format_number(n / 16, 4)}em" : "#{format_number(n, 4)}em"
      end

      # --- Palette ---------------------------------------------------------

      def build_palette(brand, styleguide, mode)
        sg_mode = styleguide&.dig("mode")
        source_is_light = sg_mode != "dark"
        direct = mode == (source_is_light ? "light" : "dark")

        brand_colors = (brand&.dig("colors") || []).filter_map { |c| parse_hex(c["hex"]) }
        named_brand_accent = parse_hex(
          (brand&.dig("colors") || []).find do |c|
            /accent|secondary|highlight|support/i.match?(c["name"] || "")
          end&.dig("hex")
        )

        sg_bg = parse_hex(styleguide&.dig("colors", "background"))
        sg_fg = parse_hex(styleguide&.dig("colors", "text"))
        sg_accent = parse_hex(styleguide&.dig("colors", "accent"))

        btn_primary = styleguide&.dig("components", "button", "primary")
        btn_secondary = styleguide&.dig("components", "button", "secondary")
        btn_link = styleguide&.dig("components", "button", "link")
        card = styleguide&.dig("components", "card")

        sg_primary_bg = parse_hex(btn_primary&.dig("backgroundColor"))
        sg_primary_fg = parse_hex(btn_primary&.dig("color"))
        sg_secondary_bg = parse_hex(btn_secondary&.dig("backgroundColor"))
        sg_secondary_fg = parse_hex(btn_secondary&.dig("color"))
        sg_link_accent = parse_hex(btn_link&.dig("backgroundColor") || btn_link&.dig("color"))
        sg_card_bg = parse_hex(card&.dig("backgroundColor"))
        sg_card_fg = parse_hex(card&.dig("textColor"))
        sg_card_border = parse_hex(card&.dig("borderColor"))
        sg_btn_border = parse_hex(btn_secondary&.dig("borderColor") || btn_primary&.dig("borderColor"))
        source_accent = sg_accent || sg_link_accent || named_brand_accent || brand_colors[1]

        if direct
          background = sg_bg || (mode == "light" ? WHITE : { r: 23.0, g: 23.0, b: 21.0 })
          foreground = sg_fg || (mode == "light" ? { r: 10.0, g: 10.0, b: 10.0 } : { r: 245.0, g: 245.0, b: 244.0 })
          primary = sg_primary_bg || brand_colors[0] || source_accent || foreground
          primary_foreground = sg_primary_bg ? sg_primary_fg : nil
          accent = source_accent || primary
          secondary = sg_secondary_bg ||
                      (source_accent ? mix(background, source_accent, 0.16) : nil) ||
                      mix(background, primary, 0.18)
          secondary_foreground = sg_secondary_bg ? sg_secondary_fg : nil
          card_bg = sg_card_bg || mix(background, foreground, 0.03)
          card_fg = sg_card_fg
          border = sg_card_border || sg_btn_border
        else
          if mode == "light"
            background = WHITE
            foreground = { r: 10.0, g: 10.0, b: 10.0 }
          else
            background = { r: 23.0, g: 23.0, b: 21.0 }
            foreground = { r: 245.0, g: 245.0, b: 244.0 }
          end
          base_primary = sg_primary_bg || brand_colors[0] || source_accent || foreground
          primary = if mode == "dark" && dark?(base_primary) then mix(base_primary, WHITE, 0.3)
                    elsif mode == "light" && !dark?(base_primary) then mix(base_primary, BLACK, 0.15)
                    else base_primary
                    end
          primary_foreground = sg_primary_bg ? sg_primary_fg : nil
          base_accent = source_accent || primary
          accent = if mode == "dark" && dark?(base_accent) then mix(base_accent, WHITE, 0.25)
                   elsif mode == "light" && !dark?(base_accent) then mix(base_accent, BLACK, 0.12)
                   else base_accent
                   end
          secondary = sg_secondary_bg || mix(background, accent, mode == "light" ? 0.16 : 0.24)
          secondary_foreground = sg_secondary_bg ? sg_secondary_fg : nil
          card_bg = mix(background, foreground, mode == "light" ? 0.03 : 0.07)
          card_fg = nil
          border = nil
        end

        muted = mix(background, foreground, mode == "light" ? 0.05 : 0.1)
        muted_fg = mix(foreground, background, 0.4)
        final_border = border || mix(background, foreground, mode == "light" ? 0.12 : 0.2)
        sidebar = mix(background, foreground, mode == "light" ? 0.04 : 0.05)

        chart_candidates = [accent, primary, secondary] + brand_colors
        seen = {}
        unique_chart = chart_candidates.select do |color|
          hex = to_hex(color)
          next false if seen[hex]

          seen[hex] = true
        end
        chart = [
          unique_chart[0] || primary,
          unique_chart[1] || mix(primary, WHITE, 0.3),
          unique_chart[2] || mix(primary, BLACK, 0.25),
          unique_chart[3] || mix(primary, WHITE, 0.55),
          unique_chart[4] || mix(primary, BLACK, 0.45)
        ]

        { background: to_hex(background), foreground: to_hex(foreground),
          card: to_hex(card_bg), card_foreground: to_hex(card_fg || foreground),
          popover: to_hex(card_bg), popover_foreground: to_hex(card_fg || foreground),
          primary: to_hex(primary),
          primary_foreground: primary_foreground ? to_hex(primary_foreground) : readable(primary),
          secondary: to_hex(secondary),
          secondary_foreground: secondary_foreground ? to_hex(secondary_foreground) : readable(secondary),
          muted: to_hex(muted), muted_foreground: to_hex(muted_fg),
          accent: to_hex(accent), accent_foreground: readable(accent),
          destructive: mode == "light" ? "#dc2626" : "#ef4444",
          destructive_foreground: "#ffffff",
          border: to_hex(final_border), input: to_hex(final_border), ring: to_hex(accent),
          chart: chart.map { |color| to_hex(color) },
          sidebar: to_hex(sidebar), sidebar_foreground: to_hex(foreground),
          sidebar_primary: to_hex(primary),
          sidebar_primary_foreground: primary_foreground ? to_hex(primary_foreground) : readable(primary),
          sidebar_accent: to_hex(accent), sidebar_accent_foreground: readable(accent),
          sidebar_border: to_hex(final_border), sidebar_ring: to_hex(accent) }
      end

      # --- Output formatting -----------------------------------------------

      def palette_lines(palette)
        ["--background: #{palette[:background]};", "--foreground: #{palette[:foreground]};",
         "--card: #{palette[:card]};", "--card-foreground: #{palette[:card_foreground]};",
         "--popover: #{palette[:popover]};", "--popover-foreground: #{palette[:popover_foreground]};",
         "--primary: #{palette[:primary]};", "--primary-foreground: #{palette[:primary_foreground]};",
         "--secondary: #{palette[:secondary]};", "--secondary-foreground: #{palette[:secondary_foreground]};",
         "--muted: #{palette[:muted]};", "--muted-foreground: #{palette[:muted_foreground]};",
         "--accent: #{palette[:accent]};", "--accent-foreground: #{palette[:accent_foreground]};",
         "--destructive: #{palette[:destructive]};", "--destructive-foreground: #{palette[:destructive_foreground]};",
         "--border: #{palette[:border]};", "--input: #{palette[:input]};", "--ring: #{palette[:ring]};",
         "--chart-1: #{palette[:chart][0]};", "--chart-2: #{palette[:chart][1]};", "--chart-3: #{palette[:chart][2]};",
         "--chart-4: #{palette[:chart][3]};", "--chart-5: #{palette[:chart][4]};",
         "--sidebar: #{palette[:sidebar]};", "--sidebar-foreground: #{palette[:sidebar_foreground]};",
         "--sidebar-primary: #{palette[:sidebar_primary]};",
         "--sidebar-primary-foreground: #{palette[:sidebar_primary_foreground]};",
         "--sidebar-accent: #{palette[:sidebar_accent]};",
         "--sidebar-accent-foreground: #{palette[:sidebar_accent_foreground]};",
         "--sidebar-border: #{palette[:sidebar_border]};", "--sidebar-ring: #{palette[:sidebar_ring]};"]
      end

      def non_color_lines(fonts, radius, shadows, tracking_normal = nil, spacing = nil)
        lines = ["--font-sans: #{fonts[:sans]};", "--font-serif: #{fonts[:serif]};",
                 "--font-mono: #{fonts[:mono]};", "--radius: #{radius};",
                 "--shadow-x: #{shadows[:x]};", "--shadow-y: #{shadows[:y]};",
                 "--shadow-blur: #{shadows[:blur]};", "--shadow-spread: #{shadows[:spread]};",
                 "--shadow-opacity: #{shadows[:opacity]};", "--shadow-color: #{shadows[:color]};",
                 "--shadow-2xs: #{shadows[:shadow2xs]};", "--shadow-xs: #{shadows[:xs]};",
                 "--shadow-sm: #{shadows[:sm]};", "--shadow: #{shadows[:base]};",
                 "--shadow-md: #{shadows[:md]};", "--shadow-lg: #{shadows[:lg]};",
                 "--shadow-xl: #{shadows[:xl]};", "--shadow-2xl: #{shadows[:shadow2xl]};"]
        lines << "--tracking-normal: #{tracking_normal};" if tracking_normal
        lines << "--spacing: #{spacing};" if spacing
        lines
      end

      def indent(lines)
        lines.map { |line| "  #{line}" }.join("\n")
      end

      def theme_inline_block
        pairs = %w[background foreground card card-foreground popover popover-foreground
                   primary primary-foreground secondary secondary-foreground muted
                   muted-foreground accent accent-foreground destructive
                   destructive-foreground border input ring chart-1 chart-2 chart-3
                   chart-4 chart-5 sidebar sidebar-foreground sidebar-primary
                   sidebar-primary-foreground sidebar-accent sidebar-accent-foreground
                   sidebar-border sidebar-ring]
        lines = pairs.map { |name| "--color-#{name}: var(--#{name});" }
        lines += ["", "--font-sans: var(--font-sans);", "--font-mono: var(--font-mono);",
                  "--font-serif: var(--font-serif);", "",
                  "--radius-sm: calc(var(--radius) - 4px);", "--radius-md: calc(var(--radius) - 2px);",
                  "--radius-lg: var(--radius);", "--radius-xl: calc(var(--radius) + 4px);", ""]
        lines += %w[2xs xs sm].map { |size| "--shadow-#{size}: var(--shadow-#{size});" }
        lines << "--shadow: var(--shadow);"
        lines += %w[md lg xl 2xl].map { |size| "--shadow-#{size}: var(--shadow-#{size});" }
        "@theme inline {\n#{indent(lines)}\n}"
      end

      def layer_base
        <<~CSS.strip
          @layer base {
            * {
              @apply border-border outline-ring/50;
            }
            body {
              @apply bg-background text-foreground;
            }
          }
        CSS
      end
    end
  end
end
