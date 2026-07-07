# frozen_string_literal: true

require "yaml"

module Poetry
  module Core
    # DESIGN.md interop (N14 W1): poetry WRITES and READS the design-skill
    # ecosystem's shared artifact - the file the slop-gate analogue emits (`study`),
    # the design-rule analogue authors, Anthropic's frontend-design reads, and google-labs'
    # open spec (github.com/google-labs-code/design.md, alpha) formalizes.
    #
    # Serialized files carry both interop surfaces at once:
    #
    #   - YAML front matter in the google-labs shape (`version`/`name`/flat
    #     `colors:`/`typography:`/`rounded:`), plus namespaced extensions the
    # spec tolerates: `modes.dark` (poetry ships BOTH modes) and
    #     a `poetry:` block (source-of-truth pointers, contrast policy, theme
    #     treatment) that makes parse -> serialize lossless;
    #   - Markdown sections in the spec's canonical order (its linter checks
    #     section-order), readable by humans and section-walking skills.
    #
    # `parse` is deliberately more tolerant than `serialize`: poetry-authored
    # files rebuild exactly from the front matter (round-trip guarantee:
    # serialize(parse(md)) is byte-identical for files serialize emitted);
    # foreign files fall back to the section walker (heading variants across
    # the ecosystems, colors in hex/rgb/oklch). What cannot be parsed lands
    # in doc["unknown"] - the import pipeline (W2) DROPS it with a report,
    # never guesses (the poetry-reactive ethos).
    class DesignMd
      # The google-labs canonical section order (the spec's own linter warns
      # on out-of-order sections).
      SECTIONS = ["Overview", "Colors", "Typography", "Layout", "Elevation & Depth",
                  "Shapes", "Components", "Do's and Don'ts"].freeze

      COMPONENTS_POINTER = "/poetry/llms.txt"

      # Heading classifier for the tolerant walker - the spellings the three
      # ecosystems actually use (the slop-gate analogue writes British "colour anchor").
      HEADING_KINDS = {
        colors: /\b(?:colou?rs?|palette)\b/i,
        typography: /\b(?:typography|type(?:\s+pairing)?|fonts?)\b/i,
        shapes: /\b(?:shapes?|radius|radii|corners?|rounded)\b/i
      }.freeze

      # A color-looking CSS value anywhere in a line.
      COLOR_VALUE = /(#\h{3,8}\b|rgba?\([^)]*\)|oklch\([^)]*\))/i
      # `name: value` in bullets, definition lines, or `| name | value |` rows.
      NAME_VALUE_LINE = %r{\A\s*(?:[-*]\s+)?(?:\*\*)?([A-Za-z][\w /-]*?)(?:\*\*)?\s*[:=]\s*(.+)\z}

      class << self
        # Build a document hash from the live token model. `details` carries
        # the per-theme presentation metadata: "typography" (pairing/family -
        # metadata only, no poetry theme moves a font token;),
        # "treatment", "components_count", optional "description".
        def build(tokens:, theme:, details:)
          gate = Tokens::ContrastGate.new(tokens)
          {
            "name" => "poetry #{theme}",
            "theme" => theme,
            "description" => details["description"] ||
              "poetry #{theme} - semantic role tokens (shared across every poetry theme) " \
              "under the #{theme} component treatment.",
            "colors" => tokens.modes.to_h do |mode|
              [mode, tokens.color_names(mode).to_h { |name| [name, tokens.color(mode, name)] }]
            end,
            "typography" => details.fetch("typography"),
            "radius" => tokens.radius_css,
            "radius_scale" => Tokens::Generator::RADIUS_SCALE.dup,
            "contrast" => {
              "floor" => "WCAG 2.2 AA (4.5:1) - locked, every gated pair ",
              "target" => "AAA (7:1) wherever achievable at lock time",
              "gate" => "Poetry::Core::Tokens::ContrastGate",
              "aa_exceptions" => gate.results.select { |result| result.lock == :aa }.map(&:to_s)
            },
            "treatment" => details.fetch("treatment"),
            "components" => { "count" => details.fetch("components_count"), "pointer" => COMPONENTS_POINTER },
            "generator" => details["generator"]
          }.compact
        end

        def serialize(doc)
          "#{front_matter(doc)}#{body(doc)}"
        end

        def parse(markdown)
          fm, prose = split_front_matter(markdown.to_s)
          return from_poetry_front_matter(fm) if fm&.key?("poetry")

          from_foreign(fm, prose)
        end

        # --- serialization -------------------------------------------------

        def front_matter(doc)
          light = doc.dig("colors", "light") || {}
          dark = doc.dig("colors", "dark") || {}
          data = {
            "version" => "alpha",
            "name" => doc["name"],
            "description" => doc["description"],
            "colors" => light.transform_values(&:css),
            "modes" => { "dark" => dark.transform_values(&:css) },
            "typography" => { "body" => { "fontFamily" => doc.dig("typography", "family") } },
            "rounded" => resolved_rounded(doc),
            "poetry" => {
              "theme" => doc["theme"],
              "source" => Tokens::DEFAULT_RELATIVE_PATH,
              "generator" => doc["generator"],
              "dark_mode" => "class.dark ",
              "radius" => doc["radius"],
              "radius_scale" => doc["radius_scale"],
              "typography_pairing" => doc.dig("typography", "pairing"),
              "treatment" => doc["treatment"],
              "components_count" => doc.dig("components", "count"),
              "components_pointer" => doc.dig("components", "pointer"),
              "contrast_policy" => doc["contrast"]
            }.compact
          }
          "#{YAML.dump(data)}---\n"
        end

        # The radius scale resolved to concrete px (rem at 16px/em) - the
        # spec's `rounded:` wants plain dimensions foreign tools can consume;
        # the calc() truth stays under poetry.radius_scale.
        def resolved_rounded(doc)
          base_px = radius_px(doc["radius"])
          return {} unless base_px

          (doc["radius_scale"] || {}).to_h do |step, value|
            factor = value[/\*\s*([\d.]+)\s*\)/, 1]&.to_f || 1.0
            [step, "#{format("%g", base_px * factor)}px"]
          end
        end

        def radius_px(radius)
          number = radius.to_s[/[\d.]+/]&.to_f
          return unless number

          radius.to_s.include?("rem") ? number * 16 : number
        end

        def body(doc)
          [overview_section(doc), colors_section(doc), typography_section(doc),
           layout_section, elevation_section(doc), shapes_section(doc),
           components_section(doc), dos_and_donts_section].join("\n")
        end

        def overview_section(doc)
          <<~MD
            # DESIGN.md - #{doc["name"]}

            #{doc["description"]}

            ## Overview

            - design system: poetry - server-rendered Rails components (ViewComponent + Stimulus + Tailwind v4)
            - theme: #{doc["theme"]} - #{doc["treatment"]}
            - token source: one DTCG file shared by every poetry theme (`#{Tokens::DEFAULT_RELATIVE_PATH}`);
              themes are component-treatment layers, not palettes
            - dark mode: the `.dark` class - both modes ship in this file
          MD
        end

        def colors_section(doc)
          light = doc.dig("colors", "light") || {}
          dark = doc.dig("colors", "dark") || {}
          rows = light.keys.map { |name| "| #{name} | #{light[name].css} | #{dark[name]&.css} |" }
          <<~MD
            ## Colors

            Semantic roles only - components never reference raw palette values
            (the class verifier and `poetry check` enforce this).

            | role | light | dark |
            |---|---|---|
            #{rows.join("\n")}
          MD
        end

        def typography_section(doc)
          <<~MD
            ## Typography

            - pairing: #{doc.dig("typography", "pairing")} (app-level metadata - no poetry theme
              moves a font token;)
            - family: #{doc.dig("typography", "family")}
          MD
        end

        def layout_section
          <<~MD
            ## Layout

            - spacing: the Tailwind v4 default scale (0.25rem base unit) - poetry adds no spacing tokens
            - structure: components size to their container; page layout stays host-owned
          MD
        end

        def elevation_section(doc)
          <<~MD
            ## Elevation & Depth

            - shadows and overlay scrims are theme treatment (the `cn-*` layer), not tokens -
              #{doc["theme"]} ships its own elevation story
          MD
        end

        def shapes_section(doc)
          scale = (doc["radius_scale"] || {}).map { |step, value| "#{step} #{value}" }.join(" - ")
          <<~MD
            ## Shapes

            - radius: #{doc["radius"]} (`--radius`)
            - scale: #{scale}
          MD
        end

        def components_section(doc)
          <<~MD
            ## Components

            - catalog: #{doc.dig("components", "count")} components - the registry is the truth; read
              `#{doc.dig("components", "pointer")}` (or `llms-full.txt` with events and variants)
              instead of duplicating it here
            - consume via `poetry_*` helpers; styling rides the theme's `cn-*` classes,
              never per-instance CSS
          MD
        end

        def dos_and_donts_section
          <<~MD
            ## Do's and Don'ts

            - Do pick variants by intent - one `primary` action per view; `destructive`
              only for irreversible actions.
            - Do keep both modes honest - every surface must hold in light and dark.
            - Don't hand-write hex/oklch in markup - use role tokens (`bg-primary`,
              `text-destructive`, ...); `poetry check` flags raw color classes.
            - Don't paint white text on solid `destructive` in dark mode - dark
              destructive renders at 60% over the background.
            - Don't introduce new colors, shadows, or radii without adding tokens first.
          MD
        end

        # --- parsing ---------------------------------------------------------

        def split_front_matter(markdown)
          match = markdown.match(/\A---\n(.*?)\n---\n?(.*)\z/m)
          return [nil, markdown] unless match

          [YAML.safe_load(match[1], permitted_classes: [], aliases: true), match[2]]
        rescue Psych::SyntaxError
          [nil, markdown]
        end

        # A file serialize emitted: everything rebuilds from the front matter,
        # so serialize(parse(md)) == md.
        def from_poetry_front_matter(front)
          meta = front["poetry"]
          light, light_unknown = parse_color_map(front["colors"])
          dark, dark_unknown = parse_color_map(front.dig("modes", "dark"))
          {
            "name" => front["name"],
            "theme" => meta["theme"],
            "description" => front["description"],
            "colors" => { "light" => light, "dark" => dark },
            "typography" => { "pairing" => meta["typography_pairing"],
                              "family" => front.dig("typography", "body", "fontFamily") },
            "radius" => meta["radius"],
            "radius_scale" => meta["radius_scale"],
            "contrast" => meta["contrast_policy"],
            "treatment" => meta["treatment"],
            "components" => { "count" => meta["components_count"], "pointer" => meta["components_pointer"] },
            "generator" => meta["generator"],
            "unknown" => { "colors" => light_unknown.merge(dark_unknown), "sections" => [] }
          }
        end

        # A foreign DESIGN.md (the slop-gate analogue study, an external design tool export, hand-authored):
        # front matter where present, then the section walker over the prose.
        def from_foreign(front, prose)
          front ||= {}
          light, unknown_colors = parse_color_map(front["colors"])
          walked = walk_sections(prose)

          walked[:colors].each do |name, value|
            next if light.key?(name)

            color = Tokens::Color.parse(value)
            color ? light[name] = color : unknown_colors[name] = value
          end

          {
            "name" => front["name"],
            "theme" => nil,
            "description" => front["description"],
            "colors" => { "light" => light, "dark" => walked[:dark_colors] },
            "typography" => { "pairing" => nil,
                              "family" => front.dig("typography", "body", "fontFamily") || walked[:family] },
            "radius" => foreign_radius(front) || walked[:radius],
            "radius_scale" => nil,
            "contrast" => nil,
            "treatment" => nil,
            "components" => nil,
            "unknown" => { "colors" => unknown_colors.merge(walked[:unknown_colors]),
                           "sections" => walked[:unknown_sections] }
          }
        end

        # Flat name => css-string map -> [{name => Color}, {name => raw}].
        def parse_color_map(map)
          parsed = {}
          unknown = {}
          (map || {}).each do |name, value|
            color = Tokens::Color.parse(value)
            color ? parsed[normalize_name(name)] = color : unknown[normalize_name(name)] = value
          end
          [parsed, unknown]
        end

        def foreign_radius(front)
          rounded = front["rounded"]
          return rounded.values.first&.to_s if rounded.is_a?(Hash) && rounded.any?

          rounded&.to_s
        end

        # The tolerant section walker: headings classified by HEADING_KINDS,
        # `name: value` lines mined inside each. Returns raw findings; the
        # importer decides what maps onto poetry roles.
        def walk_sections(prose)
          result = { colors: {}, dark_colors: {}, unknown_colors: {}, unknown_sections: [],
                     family: nil, radius: nil }
          each_section(prose) do |heading, lines|
            kind = HEADING_KINDS.find { |_kind, pattern| heading.match?(pattern) }&.first
            case kind
            when :colors then walk_colors(lines, result)
            when :typography then walk_typography(lines, result)
            when :shapes then walk_shapes(lines, result)
            else result[:unknown_sections] << heading
            end
          end
          result
        end

        def each_section(prose)
          heading = nil
          lines = []
          prose.each_line do |line|
            if (match = line.match(/\A\#{1,6}\s+(.+?)\s*\z/))
              yield(heading, lines) if heading
              heading = match[1]
              lines = []
            else
              lines << line.chomp
            end
          end
          yield(heading, lines) if heading
        end

        def walk_colors(lines, result)
          table_modes = nil
          lines.each do |line|
            if line.strip.start_with?("|")
              table_modes = color_table_row(line, table_modes, result)
            elsif (match = line.match(NAME_VALUE_LINE))
              assign_color(result, match[1], match[2])
            end
          end
        end

        # Handles `| role | light | dark |` and `| name | value |` tables.
        # Returns the sniffed header layout so data rows know their columns.
        def color_table_row(line, table_modes, result)
          cells = line.split("|").map(&:strip).reject(&:empty?)
          return table_modes if cells.all? { |cell| cell.match?(/\A:?-+:?\z/) } # separator row

          if table_modes.nil?
            header = cells.map(&:downcase)
            return { light: header.index("light"), dark: header.index("dark") } if header.include?("light")

            return { light: 1, dark: nil } # value column follows the name
          end

          name = cells[0]
          assign_color(result, name, cells[table_modes[:light]].to_s)
          if table_modes[:dark] && (dark = Tokens::Color.parse(cells[table_modes[:dark]].to_s))
            result[:dark_colors][normalize_name(name)] = dark
          end
          table_modes
        end

        def assign_color(result, name, raw)
          value = raw[COLOR_VALUE, 1] || raw.strip
          color = Tokens::Color.parse(value)
          key = normalize_name(name)
          color ? result[:colors][key] = value : result[:unknown_colors][key] = raw.strip
        end

        def walk_typography(lines, result)
          lines.each do |line|
            match = line.match(NAME_VALUE_LINE)
            next unless match
            next unless match[1].match?(/\A(?:font[\s-]?family|family|body|pairing|type)\z/i)

            result[:family] ||= match[2].strip
          end
        end

        def walk_shapes(lines, result)
          lines.each do |line|
            next unless line.match?(/radius|rounded/i)

            dimension = line[/([\d.]+(?:px|rem|em))/, 1]
            result[:radius] ||= dimension if dimension
          end
        end

        def normalize_name(name)
          name.to_s.strip.downcase.gsub(/\s+/, "-")
        end
      end
    end
  end
end
