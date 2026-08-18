# frozen_string_literal: true

require "digest"
require "json"

module Poetry
  module Ui
    # The report-only upstream watch: a committed token manifest pins
    # what upstream's registry looked like when poetry last synced, and
    # `rake upstream:watch` diffs
    # the current checkout against it. poetry is deliberately NOT a 1:1
    # class-string port (AA fixes, cn-* theme layer, added variants), so
    # this is an ALARM, not a parity gate - the diff surfaces which
    # families moved upstream and which tokens changed; humans decide what
    # matters. Extraction noise (prop names, prose) cancels out in the
    # diff because both sides use the same extractor.
    #
    # The one hard edge: families listed in VERBATIM_FAMILIES are claimed
    # as verbatim ports, so any upstream change there fails the watch.
    module UpstreamWatch
      module_function

      # Registry dirs scanned inside the upstream checkout. new-york-v4 is
      # the surface poetry ported from (upstream now calls it the legacy
      # source registry); bases/{base,aria,radix}/ui is its in-flight
      # successor - watched so the migration shows up here, not in a
      # surprise re-review.
      SCAN_DIRS = [
        "apps/v4/registry/new-york-v4/ui",
        "apps/v4/registry/new-york-v4/charts",
        "apps/v4/registry/bases/base/ui",
        "apps/v4/registry/bases/aria/ui",
        "apps/v4/registry/bases/radix/ui"
      ].freeze

      # Non-TSX upstream sources poetry ports from, hash-watched whole
      # (typeset is a CSS-driven prose system, not a registry family).
      WATCHED_FILES = [
        "apps/v4/app/(app)/(typeset)/typeset.css"
      ].freeze

      # Family keys (as they appear in the manifest, e.g.
      # "new-york-v4/ui/button") poetry claims as VERBATIM ports - any
      # upstream change fails the watch instead of just reporting. Empty
      # until a port explicitly claims verbatim status.
      VERBATIM_FAMILIES = [].freeze

      # All string-literal contents in the TSX, whitespace-split, deduped.
      # Backtick templates get their ${...} interpolations blanked first
      # so expression internals don't leak in as tokens.
      def extract_tokens(source)
        literals = []
        source.scan(/"((?:[^"\\]|\\.)*)"|'((?:[^'\\]|\\.)*)'|`((?:[^`\\]|\\.)*)`/m) do |dq, sq, bt|
          literals << (dq || sq || bt.gsub(/\$\{[^}]*\}/, " "))
        end
        literals.join(" ").split.uniq.sort
      end

      # relative-family-key => sorted token list, for every .tsx under the
      # scan dirs that exist in this checkout.
      def scan_families(root)
        SCAN_DIRS.each_with_object({}) do |dir, families|
          base = File.join(root, dir)
          next unless Dir.exist?(base)

          Dir.glob(File.join(base, "**", "*.tsx")).each do |file|
            key = file.delete_prefix("#{File.join(root, "apps/v4/registry")}/").delete_suffix(".tsx")
            families[key] = extract_tokens(File.read(file))
          end
        end
      end

      def scan_watched_files(root)
        WATCHED_FILES.each_with_object({}) do |path, hashes|
          file = File.join(root, path)
          hashes[path] = File.exist?(file) ? Digest::SHA256.hexdigest(File.read(file)) : nil
        end
      end

      def build_manifest(root, pin:, generated_at:)
        {
          "pin" => pin,
          "generated_at" => generated_at,
          "families" => scan_families(root),
          "watched_files" => scan_watched_files(root)
        }
      end

      # The drift between the committed manifest and a fresh scan.
      def diff(manifest, current)
        old_families = manifest.fetch("families", {})
        new_families = current.fetch("families", {})

        changed = (old_families.keys & new_families.keys).filter_map do |key|
          added = new_families[key] - old_families[key]
          removed = old_families[key] - new_families[key]
          [key, { added: added, removed: removed }] unless added.empty? && removed.empty?
        end.to_h

        {
          added_families: (new_families.keys - old_families.keys).sort,
          removed_families: (old_families.keys - new_families.keys).sort,
          changed: changed,
          watched_changed: manifest.fetch("watched_files", {}).keys.reject do |path|
            manifest["watched_files"][path] == current.fetch("watched_files", {})[path]
          end
        }
      end

      def drift?(diff)
        diff.values_at(:added_families, :removed_families, :watched_changed).any?(&:any?) ||
          diff[:changed].any?
      end

      def verbatim_violations(diff, families: VERBATIM_FAMILIES)
        families.select do |family|
          diff[:changed].key?(family) || diff[:removed_families].include?(family)
        end
      end

      # Human report. roster: poetry family names (underscored) used to
      # annotate which upstream families poetry actually ports.
      def format_report(diff, roster: [], token_cap: 12)
        return ["No upstream drift since the pin."] unless drift?(diff)

        ported = ->(key) { roster.include?(File.basename(key).tr("-", "_")) ? "ported" : "not ported" }
        cap = lambda do |tokens|
          shown = tokens.first(token_cap).join(" ")
          tokens.size > token_cap ? "#{shown} (+#{tokens.size - token_cap} more)" : shown
        end

        lines = diff[:added_families].map { |k| "NEW upstream family: #{k} (#{ported.call(k)})" }
        diff[:removed_families].each { |k| lines << "REMOVED upstream family: #{k} (#{ported.call(k)})" }
        diff[:changed].sort.each do |key, delta|
          lines << "CHANGED: #{key} (#{ported.call(key)})"
          lines << "  + #{cap.call(delta[:added])}" if delta[:added].any?
          lines << "  - #{cap.call(delta[:removed])}" if delta[:removed].any?
        end
        diff[:watched_changed].each { |path| lines << "CHANGED watched file: #{path}" }
        lines
      end
    end
  end
end
