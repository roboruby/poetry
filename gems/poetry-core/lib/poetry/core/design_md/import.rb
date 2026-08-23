# frozen_string_literal: true

module Poetry
  module Core
    class DesignMd
      # The import half of the DESIGN.md interop: a parsed document
      # (DesignMd.parse - ours or foreign) becomes a token-override PLAN the
      # host task renders into app/assets/tailwind/poetry/design-overrides.css.
      #
      # Three hard rules:
      #
      #   1. Contrast is enforced at the door. Every ContrastGate ledger pair
      #      a mapped override touches is measured on the MERGED set (defaults
      #      + overrides) against the WCAG AA floor; a failing pair drops its
      #      imported members from the plan and reports the nearest-passing
      #      suggestion (a deterministic OKLCH L-walk, chroma held). Only
      #      force: ships a failing pair.
      #   2. Fonts never enter CSS. A typography family becomes a report note
      #      plus a snippet the host opts into by hand.
      #   3. DROP-not-fabricate. Unmapped or unparseable values are listed in
      #      the report, never guessed into tokens.
      #
      # @example
      #   doc = Poetry::Core::DesignMd.parse(File.read("brand.DESIGN.md"))
      #   plan = Poetry::Core::DesignMd::Import.new.plan(doc)
      #   plan.overrides["light"] # => { "primary" => a Tokens::Color, ... }
      class Import
        AA = 4.5

        # Conservative cross-ecosystem role aliases - every application is
        # itself reported, so nothing maps silently. Names already matching
        # poetry roles pass through; an `on-<x>` name resolves to the
        # mapped `<x>-foreground` token when poetry ships one.
        ALIASES = {
          "text" => "foreground",
          "bg" => "background",
          "surface" => "card",
          "brand" => "primary",
          "danger" => "destructive",
          "error" => "destructive",
          "on-background" => "foreground"
        }.freeze

        Application = Struct.new(:role, :from, :mode, :color, keyword_init: true)
        Drop = Struct.new(:name, :value, :mode, :reason, keyword_init: true)
        ContrastResult = Struct.new(:mode, :label, :roles, :ratio, :pass, :suggestion, :shipped,
                                    keyword_init: true) do
          def to_s
            state = if pass
                      "pass"
                    else
                      (shipped ? "SHIPPED FAILING (forced)" : "FAILED - dropped")
                    end
            line = "[#{mode}] #{label}: #{format("%.2f", ratio)}:1 (AA needs >= #{AA}) #{state}"
            suggestion ? "#{line}; nearest passing: #{suggestion}" : line
          end
        end

        # pins: dark-mode values RESTATED from the shipped defaults for every
        # light-overridden token the source gave no dark value for. Without
        # them a light-only import's :root block would also win in dark mode
        # (:root and .dark tie on specificity; the overrides file loads
        # later) - pinning keeps dark exactly as shipped, no fabrication.
        Plan = Struct.new(:overrides, :pins, :radius, :applied, :dropped, :contrast, :typography_note,
                          keyword_init: true) do
          def any_overrides?
            radius || overrides.any? { |_mode, colors| colors.any? }
          end
        end

        def initialize(tokens: Tokens.load)
          @tokens = tokens
          @roles = tokens.color_names("light")
        end

        # @param doc [Hash] DesignMd.parse output
        # @param force [Boolean] ship overrides even when a touched pair fails AA
        # @return [Plan]
        def plan(doc, force: false)
          applied = []
          dropped = []
          map_colors(doc, applied, dropped)
          drop_unknown(doc, dropped)

          overrides = applied.group_by(&:mode).transform_values do |list|
            list.to_h { |application| [application.role, application.color] }
          end
          overrides = { "light" => {}, "dark" => {} }.merge(overrides)

          contrast = enforce_contrast(overrides, force: force)
          contrast.reject(&:pass).reject(&:shipped).each do |result|
            drop_failing_pair(result, overrides, applied, dropped)
          end

          Plan.new(overrides: overrides, pins: dark_pins(overrides), radius: doc["radius"],
                   applied: applied, dropped: dropped, contrast: contrast,
                   typography_note: typography_note(doc))
        end

        # The deterministic nearest-AA suggestion: walk the candidate's OKLCH
        # lightness away from the other member in 0.01 steps, chroma held,
        # until the pair passes or L leaves [0, 1] (then there is no passing
        # lightness on this hue/chroma axis).
        #
        # @param candidate [Tokens::Color] the color to walk
        # @param against [Tokens::Color] the fixed other member of the pair
        # @return [Tokens::Color, nil] the nearest passing color, or nil
        def nearest_aa(candidate, against)
          step = candidate.l > against.l ? 0.01 : -0.01
          color = candidate
          until color.contrast_ratio(against) >= AA
            next_l = (color.l + step).round(3)
            return nil unless next_l.between?(0.0, 1.0)

            color = color.with(l: next_l)
          end
          color
        end

        private

        def map_colors(doc, applied, dropped)
          (doc["colors"] || {}).each do |mode, colors|
            (colors || {}).each do |name, color|
              role, reason = resolve_role(name)
              if role
                applied << Application.new(role: role, from: name, mode: mode, color: color)
              else
                dropped << Drop.new(name: name, value: color.css, mode: mode, reason: reason)
              end
            end
          end
        end

        def resolve_role(name)
          return [name, nil] if @roles.include?(name)
          return [ALIASES[name], nil] if ALIASES.key?(name)

          if name.start_with?("on-")
            base, reason = resolve_role(name.delete_prefix("on-"))
            foreground = base && "#{base}-foreground"
            return [foreground, nil] if foreground && @roles.include?(foreground)

            return [nil, reason || "poetry ships no #{foreground} token"]
          end

          [nil, "no poetry role for #{name.inspect} (roles + aliases only - never guessed)"]
        end

        def drop_unknown(doc, dropped)
          (doc.dig("unknown", "colors") || {}).each do |name, value|
            dropped << Drop.new(name: name, value: value, mode: nil,
                                reason: "unparseable color value (hex/rgb/oklch only)")
          end
        end

        # Every ledger pair an override touches, measured on the merged set.
        def enforce_contrast(overrides, force:)
          Tokens::ContrastGate::LEDGER.flat_map do |mode, specs|
            touched = overrides.fetch(mode, {}).keys
            next [] if touched.empty?

            specs.filter_map do |spec|
              members = [spec[:fg], spec[:bg], spec[:bg_over]].compact
              next unless members.intersect?(touched)

              measure(mode, spec, overrides, force: force)
            end
          end
        end

        def measure(mode, spec, overrides, force:)
          fg = spec[:fg] == :white ? Tokens::Color::WHITE : merged(mode, spec[:fg], overrides)
          bg = merged_background(mode, spec, overrides)
          ratio = fg.contrast_ratio(bg)
          pass = ratio >= AA
          label = "#{spec[:fg] == :white ? "white" : spec[:fg]} on #{spec[:bg]}"
          label += "/#{format("%g", spec[:bg_alpha] * 100)}% over #{spec[:bg_over]}" if spec[:bg_alpha]

          roles = [spec[:fg], spec[:bg], spec[:bg_over]].compact - [:white]
          ContrastResult.new(mode: mode, label: label, roles: roles, ratio: ratio, pass: pass,
                             shipped: !pass && force,
                             suggestion: pass ? nil : suggestion_for(mode, spec, overrides))
        end

        # Walk the IMPORTED member of the failing pair (the text side when
        # both were imported); composited backgrounds walk the text side only.
        def suggestion_for(mode, spec, overrides)
          imported = overrides.fetch(mode, {})
          fg = spec[:fg] == :white ? Tokens::Color::WHITE : merged(mode, spec[:fg], overrides)
          bg = merged_background(mode, spec, overrides)

          if spec[:fg] != :white && imported.key?(spec[:fg])
            walked = nearest_aa(fg, bg)
            walked && "--#{spec[:fg]}: #{walked.css}"
          elsif imported.key?(spec[:bg]) && !spec[:bg_alpha]
            walked = nearest_aa(merged(mode, spec[:bg], overrides), fg)
            walked && "--#{spec[:bg]}: #{walked.css}"
          end
        end

        def drop_failing_pair(result, overrides, applied, dropped)
          mode = result.mode
          result.roles.each do |name|
            color = overrides.fetch(mode, {}).delete(name)
            next unless color

            applied.reject! { |application| application.mode == mode && application.role == name }
            dropped << Drop.new(name: name, value: color.css, mode: mode,
                                reason: "fails AA in the #{result.label} pair " \
                                        "(#{format("%.2f", result.ratio)}:1)#{suffix(result)}")
          end
        end

        def suffix(result)
          result.suggestion ? "; nearest passing: #{result.suggestion}" : ""
        end

        # Dark values restated from the shipped defaults for light-overridden
        # names the source left dark-silent (see the Plan docstring).
        def dark_pins(overrides)
          missing = overrides.fetch("light", {}).keys - overrides.fetch("dark", {}).keys
          missing.to_h { |name| [name, @tokens.color("dark", name)] }
        end

        def merged(mode, name, overrides)
          overrides.fetch(mode, {})[name] || @tokens.color(mode, name)
        end

        def merged_background(mode, spec, overrides)
          base = merged(mode, spec[:bg], overrides)
          return base unless spec[:bg_alpha]

          translucent = base.with(alpha: spec[:bg_alpha])
          translucent.composite_over(merged(mode, spec[:bg_over], overrides))
        end

        def typography_note(doc)
          family = doc.dig("typography", "family")
          return unless family

          "typography stays out of poetry CSS - to adopt the pairing, add to your app css: " \
            "body { font-family: #{family}; }"
        end
      end
    end
  end
end
