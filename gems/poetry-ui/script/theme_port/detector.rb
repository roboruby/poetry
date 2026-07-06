# frozen_string_literal: true

#
# N12 theme-port tooling (banked from the W1 vega run, parameterized for
# See the theme-port close-out +
# docs/*-port-ledger.txt). Run per theme for the diff/conflict report,
# then author a fresh PLAN in script/theme_port/plans/<theme>.rb for
# write_theme.rb. NOTE: writer.rb is the frozen W1 vega artifact - a
# ONE-SHOT generator; themes/vega.css is canonical and hand-edited; never
# regenerate over a shipped fragment.
#
# Inputs:  poetry-ui dictionaries (inline structural sets per cn name),
#          poetry-ui themes/default.css, poetry-charts themes/default.css,
#          upstream style-<theme>.css (pinned clone).
# Outputs: script/theme_port/report-<theme>.txt - human triage report
#          script/theme_port/parts-<theme>.json - machine form for the writer
#
# Run: cd Code/poetry-ui && bundle exec ruby script/theme_port/detector.rb <theme>

require "json"
require "tailwind_merge"

UI_ROOT = "poetry-ui"
CHARTS_ROOT = "poetry-charts"
THEME = ARGV.fetch(0, "vega")
UPSTREAM = File.expand_path("~/Desktop/save/shadcn-ui/apps/v4/registry/styles/style-#{THEME}.css")
abort "no upstream style-#{THEME}.css at the pinned clone" unless File.exist?(UPSTREAM)
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

upstream = parse_theme(File.read(UPSTREAM))
default_ui = parse_theme(File.read("#{UI_ROOT}/themes/default.css"))
default_charts = parse_theme(File.read("#{CHARTS_ROOT}/themes/default.css"))
default_all = default_ui.merge(default_charts)
dict = dictionary_entries
interpolated = dict.delete("__interpolated__") || []

shared = upstream.keys & default_all.keys
upstream_only = upstream.keys - default_all.keys
poetry_only = default_all.keys - upstream.keys

report = +""
parts = {}

identical = []
shared.sort.each do |name| # rubocop:disable Metrics/BlockLength
  v = upstream[name]
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
    "upstream" => v, "default" => d, "inline" => inline,
    "upstream_only" => v - d, "default_only" => d - v,
    "dup_inline" => dup_inline, "inline_conflicts" => conflicts
  }

  report << "== #{name}\n"
  report << "  #{THEME}+  : #{(v - d).join(" ")}\n" unless (v - d).empty?
  report << "  #{THEME}-  : #{(d - v).join(" ")}\n" unless (d - v).empty?
  report << "  dup(in): #{dup_inline.join(" ")}\n" unless dup_inline.empty?
  conflicts.each { |t, hits| report << "  SPLIT-SIDE: #{t} displaces inline [#{hits.join(" ")}]\n" }
  report << "\n"
end

report << "#{"=" * 70}\nIDENTICAL (#{identical.size}): #{identical.join(" ")}\n\n"
report << "#{"=" * 70}\n#{THEME.upcase}-ONLY names (#{upstream_only.size}) - triage drop/translate:\n"
upstream_only.sort.each do |name|
  inline = dict.dig(name, "tokens")
  report << "  #{name}#{"  [poetry emits: #{inline.join(" ")}]" if inline}\n    #{upstream[name].join(" ")}\n"
end
report << "\n#{"=" * 70}\nPOETRY-ONLY names (#{poetry_only.size}) - poetry-own surfaces (#{THEME} inherits/adapts):\n"
poetry_only.sort.each { |name| report << "  #{name}\n" }
report << "\n#{"=" * 70}\nINTERPOLATED dictionary strings (hand-check):\n"
interpolated.uniq.each { |line| report << "  #{line}\n" }

File.write(File.join(OUT_DIR, "report-#{THEME}.txt"), report)
File.write(File.join(OUT_DIR, "parts-#{THEME}.json"),
           JSON.pretty_generate({ "shared" => parts,
                                  "upstream_only" => upstream_only.sort.to_h { |n| [n, upstream[n]] },
                                  "poetry_only" => poetry_only.sort }))

diff_count = parts.count { |_, p| p["status"] == "diff" }
split = parts.sum { |_, p| (p["inline_conflicts"] || {}).size }
puts "shared=#{shared.size} identical=#{identical.size} diff=#{diff_count} " \
     "#{THEME}_only=#{upstream_only.size} poetry_only=#{poetry_only.size} split_side_hits=#{split}"
puts "report: #{File.join(OUT_DIR, "report-#{THEME}.txt")}"
