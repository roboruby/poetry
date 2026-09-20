#!/usr/bin/env ruby
# frozen_string_literal: true

# Contact sheets for a visual-walk review.
#
#   POETRY_THEME=mira bundle exec rake test:visual   # leaves candidates in tmp/visual_diffs
#   bundle exec ruby script/visual_review.rb mira    # -> tmp/visual_review/mira/index.html
#
# For every candidate the walk left in tmp/visual_diffs that has a baseline
# for the theme, writes <name>.png = baseline | candidate | diff (changed
# pixels in red) and an index.html sorted by how much changed. Review the
# index, then re-bless deliberately:
#
#   POETRY_THEME=mira POETRY_VISUAL_ONLY=a--b,c--d VISUAL_REBASELINE=1 bundle exec rake test:visual
#
# Needs ImageMagick (`magick`). Read-only over the baselines and candidates.

require "fileutils"
require "shellwords"
require "cgi"

theme = ARGV.shift or abort "usage: script/visual_review.rb <theme> [name ...]"
only = ARGV.dup
root = File.expand_path("..", __dir__)
baseline_dir = File.join(root, "test/visual_baselines", theme == "default" ? "" : theme)
diffs_dir = File.join(root, "tmp/visual_diffs")
out_dir = File.join(root, "tmp/visual_review", theme)
abort "no ImageMagick `magick` on PATH" unless system("which magick > /dev/null 2>&1")
abort "no baselines for #{theme} at #{baseline_dir}" unless Dir.exist?(baseline_dir)
FileUtils.mkdir_p(out_dir)

def sh(*, **)
  system(*, exception: false, **)
end

# The walk's own count (chunky_png, exact pixel equality) so the numbers
# match what `rake test:visual` reported - plus two triage aids: the
# bounding box of everything that changed, and whether the candidate is
# the baseline shifted by a pixel or two (layout drift, not a redesign).
def analyze(left, right)
  require "chunky_png"
  old_png = ChunkyPNG::Image.from_file(left)
  new_png = ChunkyPNG::Image.from_file(right)
  total = old_png.width * old_png.height
  unless old_png.width == new_png.width && old_png.height == new_png.height
    return { pixels: total, total: total, bbox: nil, shift: nil, note: "dimensions changed" }
  end

  diff = 0
  delta_sum = 0
  min_x = old_png.width
  min_y = old_png.height
  max_x = -1
  max_y = -1
  old_png.height.times do |y|
    old_row = old_png.row(y)
    new_row = new_png.row(y)
    old_row.each_index do |x|
      next if old_row[x] == new_row[x]

      diff += 1
      delta_sum += channel_delta(old_row[x], new_row[x])
      min_x = x if x < min_x
      max_x = x if x > max_x
      min_y = y if y < min_y
      max_y = y if y > max_y
    end
  end
  return { pixels: 0, total: total, bbox: nil, shift: nil } if diff.zero?

  bbox = [min_x, min_y, max_x, max_y]
  { pixels: diff, total: total, bbox: bbox, delta: (delta_sum.to_f / diff).round(1),
    shift: detect_shift(old_png, new_png, bbox) }
end

# Mean absolute difference across the four channels of two pixels (0-255).
def channel_delta(left, right)
  (ChunkyPNG::Color.r(left) - ChunkyPNG::Color.r(right)).abs +
    (ChunkyPNG::Color.g(left) - ChunkyPNG::Color.g(right)).abs +
    (ChunkyPNG::Color.b(left) - ChunkyPNG::Color.b(right)).abs +
    (ChunkyPNG::Color.a(left) - ChunkyPNG::Color.a(right)).abs
end

# Inside the changed box, does the candidate equal the baseline moved by
# (dx, dy) in -4..4? A near-total match means the content only slid.
def detect_shift(old_png, new_png, bbox)
  x0, y0, x1, y1 = bbox
  area = (x1 - x0 + 1) * (y1 - y0 + 1)
  best = nil
  (-4..4).each do |dy|
    (-4..4).each do |dx|
      next if dx.zero? && dy.zero?

      mismatches = 0
      (y0..y1).each do |y|
        sy = y + dy
        next mismatches += (x1 - x0 + 1) if sy.negative? || sy >= old_png.height

        old_row = old_png.row(sy)
        new_row = new_png.row(y)
        (x0..x1).each do |x|
          sx = x + dx
          mismatches += 1 if sx.negative? || sx >= old_png.width || old_row[sx] != new_row[x]
        end
        break if best && mismatches >= best[:mismatches]
      end
      best = { dx: dx, dy: dy, mismatches: mismatches } if best.nil? || mismatches < best[:mismatches]
    end
  end
  return nil unless best && best[:mismatches] <= area * 0.02

  [best[:dx], best[:dy]]
end

candidates = Dir[File.join(diffs_dir, "*.png")].select do |c|
  name = File.basename(c, ".png")
  (only.empty? || only.include?(name)) && File.exist?(File.join(baseline_dir, "#{name}.png"))
end
abort "no candidates for #{theme} in tmp/visual_diffs (run the walk first)" if candidates.empty?

# subtle: few pixels changed and each moved little (mean channel-sum delta
# under 32/1020) - anti-aliasing, gamma, a renderer update, not a design
# change; shift: the same pixels slid 1-4px; local: a small region changed;
# broad: look at it.
def visual_verdict(stats)
  return stats[:note] if stats[:note]
  return "identical" unless stats[:bbox]
  return "shift #{stats[:shift].join(",")}px" if stats[:shift]

  pct = stats[:pixels] * 100.0 / stats[:total]
  return "subtle (mean delta #{stats[:delta]})" if stats[:delta] && stats[:delta] < 32 && pct < 1.5

  x0, y0, x1, y1 = stats[:bbox]
  (x1 - x0) * (y1 - y0) < stats[:total] * 0.05 ? "local" : "broad"
end

rows = candidates.map do |candidate|
  name = File.basename(candidate, ".png")
  baseline = File.join(baseline_dir, "#{name}.png")
  diff = File.join(out_dir, "#{name}.diff.png")
  sheet = File.join(out_dir, "#{name}.png")
  sh("magick", "compare", "-fuzz", "0%", "-highlight-color", "red", "-lowlight-color", "white",
     baseline, candidate, diff, out: File::NULL, err: File::NULL)
  # baseline | candidate | diff, side by side (the index labels the order).
  sh("magick", baseline, candidate, diff, "+append", "-bordercolor", "#e4e4e7", "-border", "1", sheet)
  stats = analyze(baseline, candidate)
  pct = (stats[:pixels] * 100.0 / stats[:total]).round(2)
  verdict = visual_verdict(stats)
  { name: name, pixels: stats[:pixels], pct: pct, bbox: stats[:bbox], verdict: verdict,
    sheet: File.basename(sheet) }
end
rows = rows.sort_by { |r| -r[:pct] }

html = "<!doctype html><meta charset='utf-8'><title>visual review - #{CGI.escapeHTML(theme)}</title>"
html << "<style>body{font:14px system-ui;margin:24px;background:#fafafa;color:#111}h1{font-size:18px}" \
        ".row{margin:0 0 40px}.row h2{font-size:14px;margin:0 0 6px;font-weight:600}" \
        ".row img{max-width:100%;display:block}.meta{color:#666;margin-left:8px;font-weight:400}" \
        "nav a{margin-right:12px}</style>"
html << "<h1>#{CGI.escapeHTML(theme)}: #{rows.size} candidates (baseline | candidate | diff)</h1>"
links = rows.map do |r|
  "<a href='##{r[:name]}'>#{CGI.escapeHTML(r[:name])} (#{r[:pct]}%, #{CGI.escapeHTML(r[:verdict])})</a>"
end.join
html << "<nav>#{links}</nav>"
rows.each do |r|
  html << "<div class='row' id='#{r[:name]}'>"
  box = r[:bbox] ? " box #{r[:bbox].join(",")}" : ""
  meta = "#{r[:pixels]} px, #{r[:pct]}% - #{CGI.escapeHTML(r[:verdict])}#{box}"
  html << "<h2>#{CGI.escapeHTML(r[:name])}<span class='meta'>#{meta}</span></h2>"
  html << "<img src='#{r[:sheet]}' loading='lazy'></div>"
end
File.write(File.join(out_dir, "index.html"), html)
puts "#{rows.size} sheets -> #{File.join(out_dir, "index.html")}"
rows.each do |r|
  puts format("  %<name>-45s %<pixels>8d px  %<pct>6.2f%%  %<verdict>s", name: r[:name], pixels: r[:pixels],
                                                                         pct: r[:pct], verdict: r[:verdict])
end
