# frozen_string_literal: true

require "json"
require "yaml"

module Poetry
  module Ui
    # The theme transcription-fidelity contract: every way a ported theme's
    # cn-* rules differ from their source at the port pin is recorded - with
    # a reason - in config/theme_fidelity/deviations.yml, and the gate
    # (css:verify_fidelity) holds the two in exact two-way agreement:
    #
    #   - a theme edit that changes the diff fails until the deviation is
    #     recorded (no undocumented drift lands), and
    #   - a recorded deviation that no longer exists fails as stale (a
    #     receipt cannot outlive the code it describes).
    #
    # The source side is a frozen parse snapshot
    # (config/theme_fidelity/upstream-<pin>.json) generated once from the
    # pinned checkout via css:fidelity_snapshot - the pin never moves under
    # a release, so the snapshot is immutable. Bumping the pin is a
    # deliberate ceremony: regenerate the snapshot, re-review the new diff,
    # re-reason the deviations file.
    module ThemeFidelity
      # The eight ported themes (default is the reference, not a port).
      THEMES = %w[vega nova mira rhea maia luma lyra sera].freeze
      # Where the snapshot and the deviations contract live.
      DIR = "config/theme_fidelity"
      # The selector-presence diff sides.
      SELECTOR_KINDS = %w[missing_selectors poetry_selectors].freeze
      # The per-rule diff sides.
      DIFF_KINDS = %w[dropped added raw_dropped raw_added].freeze

      module_function

      # Parses a theme stylesheet into { selector => { "apply" => [utils],
      # "raw" => [declarations] } }. Handles both shapes: poetry's flat
      # themes/<t>.css and the source's .style-<t> { ... } wrapper. Only
      # cn-* selectors participate; comments are stripped; a .dark ancestor
      # scopes the key with a "[dark] " prefix so both sides stay keyed
      # identically.
      def parse_css(text)
        text = text.gsub(%r{/\*.*?\*/}m, " ")
        rules = Hash.new { |h, k| h[k] = { "apply" => Set.new, "raw" => Set.new } }
        stack = []
        buffer = +""
        text.each_line do |line|
          stripped = line.strip
          next if stripped.empty?

          buffer << " " << stripped
          while (idx = buffer.index(/[{};]/))
            char = buffer[idx]
            stmt = buffer[0...idx].strip
            buffer = buffer[(idx + 1)..]
            case char
            when "{" then stack.push(stmt)
            when "}" then stack.pop
            when ";"
              cn = stack.reverse.find { |s| s.include?("cn-") }
              next unless cn

              key = cn.sub(/\A&\s*/, "").strip
              dark = stack.any? { |s| s == ".dark" || s.include?(".dark ") } ? "[dark] " : ""
              key = "#{dark}#{key}"
              if stmt.start_with?("@apply")
                stmt.delete_prefix("@apply").strip.split(/\s+/).each { |u| rules[key]["apply"] << u }
              elsif stmt.include?(":") && !stmt.start_with?("@")
                rules[key]["raw"] << stmt
              end
            end
          end
        end
        rules
      end

      # The per-theme diff between a source parse and a poetry parse:
      # selectors only one side has, and per shared selector the dropped
      # (source-only) and added (poetry-only) utilities and raw
      # declarations. Selectors with no difference are omitted.
      def diff(upstream, poetry)
        result = {
          "missing_selectors" => (upstream.keys - poetry.keys).sort,
          "poetry_selectors" => (poetry.keys - upstream.keys).sort,
          "rules" => {}
        }
        (upstream.keys & poetry.keys).sort.each do |sel|
          dropped = (upstream[sel]["apply"] - poetry[sel]["apply"]).to_a.sort
          added = (poetry[sel]["apply"] - upstream[sel]["apply"]).to_a.sort
          raw_dropped = (upstream[sel]["raw"] - poetry[sel]["raw"]).to_a.sort
          raw_added = (poetry[sel]["raw"] - upstream[sel]["raw"]).to_a.sort
          next if dropped.empty? && added.empty? && raw_dropped.empty? && raw_added.empty?

          entry = {}
          entry["dropped"] = dropped if dropped.any?
          entry["added"] = added if added.any?
          entry["raw_dropped"] = raw_dropped if raw_dropped.any?
          entry["raw_added"] = raw_added if raw_added.any?
          result["rules"][sel] = entry
        end
        result
      end

      # Every theme's diff against the committed snapshot.
      def current_diffs(root)
        snapshot = JSON.parse(File.read(snapshot_path(root)))
        THEMES.to_h do |theme|
          upstream = snapshot.fetch("themes").fetch(theme)
                             .transform_values { |v| v.transform_values(&:to_set) }
          poetry = parse_css(File.read(File.join(root, "themes", "#{theme}.css")))
          [theme, diff(upstream, poetry)]
        end
      end

      # Exact two-way reconciliation against deviations.yml. Returns a list
      # of finding strings; empty means the contract holds.
      def verify(root)
        deviations = YAML.load_file(File.join(root, DIR, "deviations.yml"))
        findings = []
        current_diffs(root).each do |theme, actual|
          verify_selector_lists(theme, actual, deviations.fetch(theme, {}), findings)
          verify_rules(theme, actual, deviations.fetch(theme, {}), findings)
        end
        findings
      end

      # Reconciles a theme's selector-presence lists against the record.
      # @api private
      def verify_selector_lists(theme, actual, recorded, findings)
        SELECTOR_KINDS.each do |kind|
          actual_list = actual[kind]
          recorded_list = recorded.dig(kind, "list") || []
          (actual_list - recorded_list).each do |sel|
            findings << "#{theme}: #{kind.tr("_", " ")} #{sel} is not recorded - add it with a reason"
          end
          (recorded_list - actual_list).each do |sel|
            findings << "#{theme}: recorded #{kind.tr("_", " ")} #{sel} no longer differs - stale entry"
          end
          if actual_list.any? && recorded.dig(kind, "reason").to_s.strip.empty?
            findings << "#{theme}: #{kind.tr("_", " ")} needs a reason"
          end
        end
      end

      # Reconciles a theme's per-rule utility diffs against the record.
      # @api private
      def verify_rules(theme, actual, recorded, findings)
        actual_rules = actual["rules"]
        recorded_rules = recorded.fetch("rules", {})

        (actual_rules.keys - recorded_rules.keys).each do |sel|
          findings << "#{theme}: #{sel} deviates but is not recorded - add it with a reason"
        end
        (recorded_rules.keys - actual_rules.keys).each do |sel|
          findings << "#{theme}: recorded deviation for #{sel} no longer exists - stale entry"
        end

        (actual_rules.keys & recorded_rules.keys).each do |sel|
          DIFF_KINDS.each do |kind|
            missing = (actual_rules[sel][kind] || []) - (recorded_rules[sel][kind] || [])
            stale = (recorded_rules[sel][kind] || []) - (actual_rules[sel][kind] || [])
            findings << "#{theme}: #{sel} #{kind} not recorded: #{missing.join(" ")}" if missing.any?
            findings << "#{theme}: #{sel} recorded #{kind} now stale: #{stale.join(" ")}" if stale.any?
          end
          findings << "#{theme}: #{sel} needs a reason" if recorded_rules[sel]["reason"].to_s.strip.empty?
        end
      end

      # Writes the frozen source snapshot from a pinned checkout - the
      # pin-bump ceremony's first step.
      def write_snapshot(root, checkout:, pin:)
        themes = THEMES.to_h do |theme|
          css = `cd #{checkout} && git show #{pin}:apps/v4/registry/styles/style-#{theme}.css`
          raise "no source for #{theme} at #{pin}" if css.empty?

          [theme, parse_css(css).transform_values { |v| v.transform_values { |set| set.to_a.sort } }]
        end
        path = File.join(root, DIR, "upstream-#{pin}.json")
        File.write(path, JSON.pretty_generate("pin" => pin, "themes" => themes))
        path
      end

      # The committed snapshot's path - exactly one may exist.
      #
      # @return [String]
      def snapshot_path(root)
        candidates = Dir.glob(File.join(root, DIR, "upstream-*.json"))
        unless candidates.length == 1
          raise "expected exactly one #{DIR}/upstream-<pin>.json, found #{candidates.length}"
        end

        candidates.first
      end
    end
  end
end
