# frozen_string_literal: true

require "json"

module Poetry
  module Core
    # Design-tool token ingestion (Figma variables, Paper "Copy theme", or any
    # DTCG / CSS-custom-property source) into the SAME token-override plan the
    # DESIGN.md importer already runs.
    #
    # TokenImport does exactly one job: turn a foreign token export into the
    # `doc` hash `DesignMd::Import#plan` consumes. Everything downstream is
    # unchanged, so every imported swatch inherits poetry's contrast law for
    # free -- the WCAG 2.2 AA gate, the DROP-not-fabricate rule, the
    # deterministic nearest-AA suggestion, the dark-mode pins. There is no new
    # verification code here by design: a Figma palette that fails AA is
    # dropped at the door exactly like a hand-authored DESIGN.md's would be.
    #
    # Three input formats, one pipeline (dispatched by extension; the host
    # tasks poetry:design:import / poetry:figma:import / poetry:paper:import all
    # funnel through `load`):
    #
    #   .json -> figma    : a DTCG / Figma-variables / Tokens-Studio export
    #   .css  -> css_vars : a Paper "Copy theme" or shadcn CSS custom-property block
    #   .md   -> DesignMd.parse : the existing DESIGN.md path
    #
    # Tolerant like DesignMd.parse: whatever cannot be resolved to a poetry role
    # or parsed as a color lands in doc["unknown"]["colors"], and the planner
    # REPORTS it rather than guessing (the poetry-reactive ethos).
    module TokenImport
      # Path segments (from Figma collections/modes or CSS selectors) that name
      # a color mode. Anything else defaults to light; poetry then PINS dark
      # from its shipped defaults for light-only imports (DesignMd::Import).
      # ("default" is deliberately NOT here -- it collides with the shadcn
      # `primary/DEFAULT` group-leaf convention, which is far more common than
      # a Figma mode literally named "Default"; light is the fallback anyway.)
      MODES = { "light" => "light", "day" => "light",
                "dark" => "dark", "night" => "dark" }.freeze

      # Leaf segments that are a wrapper, not the role itself: `primary/DEFAULT`
      # is the `primary` role, `primary/foreground` is `primary-foreground`.
      BASE_LEAVES = %w[default base value main].freeze
      FOREGROUND_LEAVES = %w[foreground fg on text contrast].freeze

      # Grouping segments that carry no semantic role (the DTCG top group, a
      # collection named "Tokens", etc.). Dropped before role resolution so a
      # standalone `color/foreground` token is the `foreground` role, not
      # `color-foreground`, while `primary/foreground` still joins.
      WRAPPERS = %w[color colors colour colours tokens token theme palette semantic].freeze

      class << self
        # Dispatch by file extension. Returns a DesignMd `doc` for any source;
        # markdown falls through to DesignMd.parse so the three host tasks share
        # one code path.
        def load(path)
          content = File.read(path)
          name = File.basename(path)
          case File.extname(path).downcase
          when ".json" then figma(JSON.parse(content), name: name)
          when ".css"  then css_vars(content, name: name)
          else DesignMd.parse(content)
          end
        end

        # A DTCG / Figma-variables / Tokens-Studio export -> doc. The export
        # shape varies by plugin (nested groups, collection/mode dimensions,
        # `{alias}` references, hex strings vs DTCG color objects), so the
        # walker is deliberately tolerant: it finds every color-ish leaf, keys
        # it by dotted path AND last segment for alias resolution, then maps
        # each to a poetry role and mode.
        def figma(data, name: "figma")
          leaves = []
          collect_leaves(data, [], leaves)
          by_path = leaves.to_h { |leaf| [leaf[:path].join(".").downcase, leaf[:value]] }
          by_leaf = leaves.to_h { |leaf| [leaf[:path].last.to_s.downcase, leaf[:value]] }

          light = {}
          dark = {}
          unknown = {}
          radius = nil

          leaves.each do |leaf|
            role = role_name(leaf[:path])
            if role == "radius"
              radius ||= dimension_css(leaf[:value])
              next
            end
            next unless color_leaf?(leaf)

            color = resolve_color(leaf[:value], by_path, by_leaf, 0)
            bucket = detect_mode(leaf[:path]) == "dark" ? dark : light
            color ? bucket[role] = color : unknown[role] ||= raw_value(leaf[:value])
          end

          build_doc(name: name, light: light, dark: dark, unknown: unknown, radius: radius)
        end

        # A CSS custom-property theme (Paper "Copy theme", shadcn drop-in, or a
        # Tailwind v4 `@theme` block) -> doc. `:root`/`@theme`/`html`/`:host`
        # blocks are light; a `.dark` (or dark data-attr) block is dark. `var()`
        # references are resolved within their own mode; concrete hex/oklch/rgb
        # values parse directly.
        def css_vars(css, name: "theme")
          modes = { "light" => {}, "dark" => {} }
          each_block(css) do |mode, declarations|
            declarations.each { |var, value| modes[mode][var] = value }
          end

          light = {}
          dark = {}
          unknown = {}
          radius = nil

          modes.each do |mode, vars|
            vars.each do |var, raw|
              role = css_role(var)
              if role == "radius"
                radius ||= raw.strip if mode == "light"
                next
              end
              color = resolve_css_value(raw, vars)
              bucket = mode == "dark" ? dark : light
              color ? bucket[role] = color : unknown[role] ||= raw.strip
            end
          end

          build_doc(name: name, light: light, dark: dark, unknown: unknown, radius: radius)
        end

        private

        # --- shared -------------------------------------------------------

        def build_doc(name:, light:, dark:, unknown:, radius:)
          {
            "name" => name,
            "theme" => nil,
            "description" => nil,
            "colors" => { "light" => light, "dark" => dark },
            "typography" => { "pairing" => nil, "family" => nil },
            "radius" => radius,
            "radius_scale" => nil,
            "contrast" => nil,
            "treatment" => nil,
            "components" => nil,
            "unknown" => { "colors" => unknown, "sections" => [] }
          }
        end

        # Role name from a token path: drop mode segments, treat a DEFAULT/base
        # leaf as its parent, a foreground/on/text leaf as `<parent>-foreground`,
        # otherwise the leaf itself. Normalized to poetry's kebab role spelling;
        # DesignMd::Import's ALIASES + role table decide the final mapping (and
        # DROP + report anything with no poetry home).
        def role_name(path)
          segments = path.map(&:to_s).reject { |s| MODES.key?(s.downcase) || WRAPPERS.include?(s.downcase) }
          leaf = segments.last.to_s
          parent = segments[-2]
          role =
            if BASE_LEAVES.include?(leaf.downcase) && parent
              parent
            elsif FOREGROUND_LEAVES.include?(leaf.downcase) && parent
              "#{parent}-foreground"
            else
              leaf
            end
          normalize(role)
        end

        def detect_mode(path)
          hit = path.filter_map { |s| MODES[s.to_s.downcase] }.last
          hit || "light"
        end

        def normalize(name)
          name.to_s.strip.downcase.gsub(/[^a-z0-9]+/, "-").gsub(/\A-+|-+\z/, "")
        end

        # --- DTCG / Figma walking ----------------------------------------

        def collect_leaves(node, path, out)
          return unless node.is_a?(Hash)

          if token?(node)
            out << { path: path, value: token_value(node), type: token_type(node) }
            return
          end

          node.each do |key, child|
            next if key.to_s.start_with?("$")

            collect_leaves(child, path + [key.to_s], out)
          end
        end

        def token?(node)
          node.is_a?(Hash) && (node.key?("$value") || (node.key?("value") && node.key?("type")))
        end

        def token_value(node)
          node.key?("$value") ? node["$value"] : node["value"]
        end

        def token_type(node)
          node["$type"] || node["type"]
        end

        # A color leaf is one typed "color", or (type-less) one whose value
        # resolves to a color. Radius is handled separately, before this.
        def color_leaf?(leaf)
          type = leaf[:type].to_s.downcase
          return true if type == "color"
          return false unless type.empty?

          !color_shape(leaf[:value]).nil?
        end

        # Resolve a DTCG value (string, alias, or color object) to a Color, or
        # nil. Aliases (`{group.token}` / `{token}`) chase by dotted path then by
        # last segment, with a small recursion cap.
        def resolve_color(value, by_path, by_leaf, depth)
          return nil if depth > 12

          if value.is_a?(String) && (ref = value[/\A\{(.+)\}\z/, 1])
            target = by_path[ref.downcase] || by_leaf[ref.split(".").last.to_s.downcase]
            return target ? resolve_color(target, by_path, by_leaf, depth + 1) : nil
          end

          color_shape(value)
        end

        # A concrete DTCG color value -> Color (never an alias here).
        def color_shape(value)
          case value
          when String then Tokens::Color.parse(value)
          when Hash then color_object(value)
          end
        end

        def color_object(obj)
          space = obj["colorSpace"] || obj["$colorSpace"]
          if space == "oklch"
            Tokens::Color.from_dtcg(obj)
          elsif %w[srgb srgb-linear rgb].include?(space) && obj["components"].is_a?(Array)
            Tokens::Color.from_srgb(obj["components"].first(3).map(&:to_f), alpha: (obj["alpha"] || 1.0).to_f)
          elsif (hex = obj["hex"] || obj["value"]).is_a?(String)
            Tokens::Color.parse(hex)
          end
        rescue ArgumentError
          nil
        end

        def dimension_css(value)
          case value
          when Hash
            v = value["value"] || value["$value"]
            v && "#{format("%g", v.to_f)}#{value["unit"] || "px"}"
          when Numeric then "#{format("%g", value)}px"
          when String then value.strip
          end
        end

        def raw_value(value)
          value.is_a?(String) ? value.strip : value.inspect
        end

        # --- CSS custom-property parsing ---------------------------------

        # Yield [mode, {var => value}] for each recognised selector block. Naive
        # brace matching is fine: token themes are flat declaration blocks.
        def each_block(css)
          css.to_s.gsub(%r{/\*.*?\*/}m, "").scan(/([^{}]+)\{([^{}]*)\}/m).each do |selector, body|
            mode = block_mode(selector.strip)
            next unless mode

            declarations = body.scan(/--([\w-]+)\s*:\s*([^;]+);/).to_h { |var, value| [var, value.strip] }
            yield(mode, declarations) unless declarations.empty?
          end
        end

        def block_mode(selector)
          lower = selector.downcase
          return "dark" if lower.include?(".dark") || lower.include?("data-theme=\"dark\"") ||
                           lower.include?("data-theme=dark") || lower.include?("[data-mode=dark")
          return "light" if lower.include?(":root") || lower.start_with?("@theme") ||
                            lower.include?("html") || lower.include?(":host")

          nil
        end

        # Drop a leading Tailwind `color-` namespace so `--color-primary` and
        # `--primary` both land on the `primary` role.
        def css_role(var)
          normalize(var.delete_prefix("color-"))
        end

        def resolve_css_value(raw, vars, depth = 0)
          return nil if depth > 12

          if (ref = raw.strip[/\Avar\(\s*--([\w-]+)\s*(?:,[^)]*)?\)\z/, 1])
            target = vars[ref]
            return target ? resolve_css_value(target, vars, depth + 1) : nil
          end

          Tokens::Color.parse(raw.strip)
        end
      end
    end
  end
end
