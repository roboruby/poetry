# frozen_string_literal: true

#
# theme-port tooling: the thin-body scan (added after it caught a
# real miss - vega's menubar separator shipped color-only, losing
# poetry's theme-side h-px structure). Flags any rule whose body is much
# thinner than default's for the same name: usually an upstream
# delta-rule (their structure lives in markup) mechanically replacing a
# poetry full-body rule. Known-intentional thin bodies (vega-adjudicated
# judgment calls) are allowlisted.
#
# Run: ruby script/theme_port/thin_scan.rb [theme ...]  (default: all non-default)

INTENTIONAL = %w[cn-alert-title].freeze

def parse(file)
  File.read(file).scan(/\.(cn-[a-z0-9-]+)\s*\{\s*@apply\s+([^;]+);/m).to_h { |n, b| [n, b.split(/\s+/)] }
end

ui = File.expand_path("../..", __dir__)
default = parse(File.join(ui, "themes/default.css"))
themes = ARGV.any? ? ARGV : Dir[File.join(ui, "themes/*.css")].map { |f| File.basename(f, ".css") } - ["default"]

failed = false
themes.sort.each do |t|
  theme = parse(File.join(ui, "themes/#{t}.css"))
  thin = theme.select do |n, b|
    default[n] && default[n].size >= 4 && b.size <= 2 && (default[n] - b).size >= 3 &&
      !INTENTIONAL.include?(n)
  end
  puts "== #{t}: #{thin.size} suspiciously thin vs default"
  thin.each { |n, b| puts "  #{n}: [#{b.join(" ")}]  (default has #{default[n].size} tokens)" }
  failed ||= thin.any?
end
exit(failed ? 1 : 0)
