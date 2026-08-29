#!/usr/bin/env ruby
# frozen_string_literal: true

# Upstream delta report - what changed in the sources poetry ports from,
# between two pins. The first step of a pin bump: read this together,
# then adopt or record each change. Read-only; bumps nothing.
#
#   bundle exec ruby script/upstream_delta.rb d0fae528 shadcn@4.19.0
#   UPSTREAM=/path/to/checkout ...   (default ~/Desktop/save/shadcn-ui)
#
# Refs may be shas or tags (pins are tagged releases from 4.19.0 on).
# Output: tmp/upstream_delta/<old>..<new>.md - per component: the theme
# rules per style (selectors added/removed, utility sets changed), the
# structural classes per part in the styled and classic tsx, the cn-*
# hook inventory, and files added/removed. The tsx extraction is a
# regex over className=/cn(/cva( string literals grouped by the enclosing
# function - lossy on purpose; a human reads the report.

require "English"
require "shellwords"
require "fileutils"
require_relative "../lib/poetry/ui/theme_fidelity"

UPSTREAM = File.expand_path(ENV.fetch("UPSTREAM", "~/Desktop/save/shadcn-ui"))
STYLES = "apps/v4/registry/styles"
STYLED = "apps/v4/registry/bases/base/ui"
CLASSIC = "apps/v4/registry/new-york-v4/ui"
THEMES = %w[vega nova mira rhea maia luma lyra sera].freeze

old_ref, new_ref = ARGV
abort "usage: script/upstream_delta.rb <old-ref> <new-ref>" unless old_ref && new_ref

def git(*args)
  out = `git -C #{Shellwords.escape(UPSTREAM)} #{args.map { |a| Shellwords.escape(a) }.join(" ")} 2>/dev/null`
  $CHILD_STATUS.success? ? out : ""
end

def sha(ref) = git("rev-parse", "--short=8", "#{ref}^{commit}").strip
def listing(ref, dir) = git("ls-tree", "-r", "--name-only", ref, dir).split("\n")
def show(ref, path) = git("show", "#{ref}:#{path}")

old_sha = sha(old_ref)
new_sha = sha(new_ref)
abort "unknown ref: #{old_ref}" if old_sha.empty?
abort "unknown ref: #{new_ref}" if new_sha.empty?

# --- component naming: the styled registry's file basenames are the vocabulary
component_files = listing(old_ref, STYLED) + listing(new_ref, STYLED)
component_names = component_files.map { |p| File.basename(p, ".tsx") }.uniq
components = component_names.sort_by { |c| -c.length }
component_of = lambda do |hook_or_selector|
  name = hook_or_selector.delete_prefix("[dark] ").sub(/\A\.?cn-/, "")
  components.find { |c| name == c || name.start_with?("#{c}-") } || name.split("-").first
end

# --- 1. theme rules per style
theme_changes = Hash.new { |h, k| h[k] = [] } # component => lines
THEMES.each do |theme|
  path = "#{STYLES}/style-#{theme}.css"
  old_css = show(old_ref, path)
  new_css = show(new_ref, path)
  old_rules = old_css.empty? ? {} : Poetry::Ui::ThemeFidelity.parse_css(old_css)
  new_rules = new_css.empty? ? {} : Poetry::Ui::ThemeFidelity.parse_css(new_css)
  (new_rules.keys - old_rules.keys).each do |sel|
    added_utilities = new_rules[sel]["apply"].to_a.sort.join(" ")
    theme_changes[component_of.call(sel)] << "- **#{theme}** `#{sel}` added: `#{added_utilities}`"
  end
  (old_rules.keys - new_rules.keys).each do |sel|
    theme_changes[component_of.call(sel)] << "- **#{theme}** `#{sel}` removed"
  end
  (old_rules.keys & new_rules.keys).each do |sel|
    dropped = (old_rules[sel]["apply"] - new_rules[sel]["apply"]).to_a.sort
    added = (new_rules[sel]["apply"] - old_rules[sel]["apply"]).to_a.sort
    raw_d = (old_rules[sel]["raw"] - new_rules[sel]["raw"]).to_a.sort
    raw_a = (new_rules[sel]["raw"] - old_rules[sel]["raw"]).to_a.sort
    next if dropped.empty? && added.empty? && raw_d.empty? && raw_a.empty?

    line = "- **#{theme}** `#{sel}`"
    line << " −`#{dropped.join(" ")}`" unless dropped.empty?
    line << " +`#{added.join(" ")}`" unless added.empty?
    line << " raw −`#{raw_d.join("; ")}`" unless raw_d.empty?
    line << " raw +`#{raw_a.join("; ")}`" unless raw_a.empty?
    theme_changes[component_of.call(sel)] << line
  end
end

# --- 2. structural classes per part (tsx), grouped by the enclosing function
def class_tokens_by_function(src)
  blocks = src.split(/^(?=(?:export )?(?:function|const) [A-Z][A-Za-z]* ?[(=])/)
  blocks.each_with_object({}) do |block, out|
    name = block[/\A(?:export )?(?:function|const) ([A-Z][A-Za-z]*)/, 1] or next
    strings = block.scan(/className=\{?\s*cn\(\s*"([^"]*)"/).flatten +
              block.scan(/className="([^"]*)"/).flatten +
              block.scan(/cva\(\s*"([^"]*)"/).flatten
    out[name] = strings.flat_map(&:split).uniq.sort
  end
end

structural_changes = Hash.new { |h, k| h[k] = [] }
files_added = []
files_removed = []

def structural_delta(old_ref, new_ref, label, path, changes)
  old_src = show(old_ref, path)
  new_src = show(new_ref, path)
  return if old_src == new_src

  component = File.basename(path, ".tsx")
  old_fns = class_tokens_by_function(old_src)
  new_fns = class_tokens_by_function(new_src)
  (new_fns.keys - old_fns.keys).each do |fn|
    changes[component] << "- **#{label}** `#{fn}` added: `#{new_fns[fn].join(" ")}`"
  end
  (old_fns.keys - new_fns.keys).each { |fn| changes[component] << "- **#{label}** `#{fn}` removed" }
  (old_fns.keys & new_fns.keys).each do |fn|
    dropped = old_fns[fn] - new_fns[fn]
    added = new_fns[fn] - old_fns[fn]
    next if dropped.empty? && added.empty?

    line = "- **#{label}** `#{fn}`"
    line << " −`#{dropped.join(" ")}`" unless dropped.empty?
    line << " +`#{added.join(" ")}`" unless added.empty?
    changes[component] << line
  end
  return unless changes[component].empty?

  changes[component] << "- **#{label}** file changed (no className delta the extractor can see)"
end

[[STYLED, "styled"], [CLASSIC, "classic"]].each do |dir, label|
  old_files = listing(old_ref, dir).select { |p| p.end_with?(".tsx") }
  new_files = listing(new_ref, dir).select { |p| p.end_with?(".tsx") }
  (new_files - old_files).each { |p| files_added << "#{label}: #{File.basename(p)}" }
  (old_files - new_files).each { |p| files_removed << "#{label}: #{File.basename(p)}" }
  (old_files & new_files).each { |path| structural_delta(old_ref, new_ref, label, path, structural_changes) }
end

# --- 3. hook inventory
hooks_at = lambda do |ref|
  files = listing(ref, STYLED) + listing(ref, STYLES)
  files.flat_map { |p| show(ref, p).scan(/cn-[a-z0-9-]+/) }.to_set
end
old_hooks = hooks_at.call(old_ref)
new_hooks = hooks_at.call(new_ref)
hooks_added = (new_hooks - old_hooks).to_a.sort
hooks_removed = (old_hooks - new_hooks).to_a.sort

# --- 4. commits
commits = git("log", "--format=%h %ad %s", "--date=short", "#{old_ref}..#{new_ref}", "--", STYLES, STYLED,
              CLASSIC).lines.map(&:chomp)

# --- report
touched = (theme_changes.keys + structural_changes.keys).uniq.sort
out = "# Upstream delta #{old_ref} (#{old_sha}) → #{new_ref} (#{new_sha})\n\n"
out << "Sources: `#{STYLES}`, `#{STYLED}`, `#{CLASSIC}` in #{UPSTREAM}. "
out << "#{commits.size} commits touched them; #{touched.size} components changed; "
out << "#{files_added.size} files added, #{files_removed.size} removed; "
out << "hooks +#{hooks_added.size} / −#{hooks_removed.size}.\n\n"
out << "## Commits\n\n" << commits.map { |c| "- #{c}" }.join("\n") << "\n\n"
unless files_added.empty? && files_removed.empty?
  out << "## Files\n\n"
  files_added.each { |f| out << "- added #{f}\n" }
  files_removed.each { |f| out << "- removed #{f}\n" }
  out << "\n"
end
unless hooks_added.empty? && hooks_removed.empty?
  out << "## Hook inventory\n\n"
  unless hooks_added.empty?
    out << "- added (#{hooks_added.size}): " << hooks_added.map { |h|
      "`#{h}`"
    }.join(", ") << "\n"
  end
  unless hooks_removed.empty?
    out << "- removed (#{hooks_removed.size}): " << hooks_removed.map { |h|
      "`#{h}`"
    }.join(", ") << "\n"
  end
  out << "\n"
end
out << "## Per component\n\n"
touched.each do |component|
  out << "### #{component}\n\n"
  unless structural_changes[component].empty?
    out << "Structural classes (tsx):\n\n" << structural_changes[component].join("\n") << "\n\n"
  end
  unless theme_changes[component].empty?
    out << "Theme rules (#{theme_changes[component].size} changes):\n\n"
    out << theme_changes[component].join("\n") << "\n\n"
  end
end

dir = File.expand_path("../tmp/upstream_delta", __dir__)
FileUtils.mkdir_p(dir)
report = File.join(dir, "#{old_sha}..#{new_sha}.md")
File.write(report, out)
puts "#{report} (#{out.lines.size} lines)"
puts "components: #{touched.join(", ")}"
puts "files added: #{files_added.join(", ")}" unless files_added.empty?
puts "hooks: +#{hooks_added.size} / -#{hooks_removed.size}"
