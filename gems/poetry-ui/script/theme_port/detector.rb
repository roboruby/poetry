# frozen_string_literal: true

#
# N12 theme-port tooling (banked from the W1 vega run - see
# the theme-port plan close-out + docs/vega-port-ledger.txt).
# For the NEXT port (nova/mira/rhea): point the upstream path at the new
# style-<name>.css, re-run the detector for the diff/conflict report, then
# author a fresh PLAN in a copy of the writer. NOTE: the writer is a
# ONE-SHOT generator - themes/vega.css is canonical and has been hand-
# edited since generation (AA-hold comments); never regenerate over it.
# N12 W1b: the translation pipeline's front half.
#
# Inputs:  poetry-ui dictionaries (inline structural sets per cn name),
#          poetry-ui themes/default.css, poetry-charts themes/default.css,
#          upstream style-vega.css (pinned clone).
# Outputs: scratchpad/vega/report.txt   - human triage report
#          scratchpad/vega/parts.json   - machine form for the fragment writer
#
# Run: cd Code/poetry-ui && bundle exec ruby <this file>

require "json"
require "tailwind_merge"

UI_ROOT = "poetry-ui"
CHARTS_ROOT = "poetry-charts"
VEGA = File.expand_path("~/Desktop/save/shadcn-ui/apps/v4/registry/styles/style-vega.css")
OUT_DIR = __dir__

MERGER = TailwindMerge::Merger.new

# --- parse a theme css: cn-name => token array ------------------------------
def parse_theme(text)
  text.scan(/\.(cn-[a-z0-9-]+)\s*\{\s*@apply\s+([^;]+);/m).to_h do |name, body|
    [name, body.split(/\s+/)]
  end
end

# --- dictionary strings: cn-name => { tokens:, file:, interpolated: } -------
def dictionary_entries
  entries = {}
  Dir["#{UI_ROOT}/app/components/poetry/ui/*/style.rb",
      "#{CHARTS_ROOT}/app/components/poetry/charts/*/style.rb"].sort.each do |file|
    src = File.read(file)
    # Every string literal (double or single quoted) containing a cn token.
    src.scan(/"((?:[^"\\]|\\.)*)"|'((?:[^'\\]|\\.)*)'/).each do |dq, sq|
      literal = dq || sq
      next unless literal&.match?(/\bcn-[a-z0-9-]/)

      tokens = literal.split(/\s+/)
      names = tokens.select { |t| t.start_with?("cn-") && !t.include?('#{') }
      inline = tokens.reject { |t| t.start_with?("cn-") }
      names.each do |name|
        entries[name] ||= { "tokens" => [], "files" => [] }
        entries[name]["tokens"] |= inline
        entries[name]["files"] |= [file.sub("#{UI_ROOT}/", "").sub("#{CHARTS_ROOT}/", "charts:")]
      end
      if literal.include?('#{')
        entries["__interpolated__"] ||= []
        entries["__interpolated__"] << "#{File.basename(File.dirname(file))}: #{literal}"
      end
    end
  end
  entries
end

# --- conflict probe: does adding `token` to the inline set displace anything?
def displaced_by(inline_tokens, token)
  return [] if inline_tokens.empty?

  merged = MERGER.merge("#{inline_tokens.join(" ")} #{token}").split(/\s+/)
  inline_tokens - merged
end

vega = parse_theme(File.read(VEGA))
default_ui = parse_theme(File.read("#{UI_ROOT}/themes/default.css"))
default_charts = parse_theme(File.read("#{CHARTS_ROOT}/themes/default.css"))
default_all = default_ui.merge(default_charts)
dict = dictionary_entries
interpolated = dict.delete("__interpolated__") || []

shared = vega.keys & default_all.keys
vega_only = vega.keys - default_all.keys
poetry_only = default_all.keys - vega.keys

report = +""
parts = {}

identical = []
shared.sort.each do |name| # rubocop:disable Metrics/BlockLength
  v = vega[name]
  d = default_all[name]
  inline = dict.dig(name, "tokens") || []

  if v.sort == d.sort
    identical << name
    parts[name] = { "status" => "identical", "rule" => d }
    next
  end

  dup_inline = v & inline
  conflicts = {}
  (v - inline).each do |token|
    hits = displaced_by(inline, token)
    conflicts[token] = hits unless hits.empty?
  end

  parts[name] = {
    "status" => "diff",
    "vega" => v, "default" => d, "inline" => inline,
    "vega_only" => v - d, "default_only" => d - v,
    "dup_inline" => dup_inline, "inline_conflicts" => conflicts
  }

  report << "== #{name}\n"
  report << "  vega+  : #{(v - d).join(" ")}\n" unless (v - d).empty?
  report << "  vega-  : #{(d - v).join(" ")}\n" unless (d - v).empty?
  report << "  dup(in): #{dup_inline.join(" ")}\n" unless dup_inline.empty?
  conflicts.each { |t, hits| report << "  SPLIT-SIDE: #{t} displaces inline [#{hits.join(" ")}]\n" }
  report << "\n"
end

report << "#{"=" * 70}\nIDENTICAL (#{identical.size}): #{identical.join(" ")}\n\n"
report << "#{"=" * 70}\nVEGA-ONLY names (#{vega_only.size}) - triage drop/translate:\n"
vega_only.sort.each do |name|
  inline = dict.dig(name, "tokens")
  report << "  #{name}#{"  [poetry emits: #{inline.join(" ")}]" if inline}\n    #{vega[name].join(" ")}\n"
end
report << "\n#{"=" * 70}\nPOETRY-ONLY names (#{poetry_only.size}) - poetry-own surfaces (vega inherits/adapts):\n"
poetry_only.sort.each { |name| report << "  #{name}\n" }
report << "\n#{"=" * 70}\nINTERPOLATED dictionary strings (hand-check):\n"
interpolated.uniq.each { |line| report << "  #{line}\n" }

File.write(File.join(OUT_DIR, "report.txt"), report)
File.write(File.join(OUT_DIR, "parts.json"),
           JSON.pretty_generate({ "shared" => parts, "vega_only" => vega_only.sort.to_h { |n| [n, vega[n]] },
                                  "poetry_only" => poetry_only.sort }))

diff_count = parts.count { |_, p| p["status"] == "diff" }
split = parts.sum { |_, p| (p["inline_conflicts"] || {}).size }
puts "shared=#{shared.size} identical=#{identical.size} diff=#{diff_count} " \
     "vega_only=#{vega_only.size} poetry_only=#{poetry_only.size} split_side_hits=#{split}"
puts "report: #{File.join(OUT_DIR, "report.txt")}"
