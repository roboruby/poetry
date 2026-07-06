# frozen_string_literal: true

# The real-browser layer, ported from poetry-ui: rake test:accessibility
# runs axe (wcag2a + wcag2aa) against every charts preview example in
# headless Chrome; rake test:visual screenshots the same corpus against
# committed baselines. Neither joins the default gate - they need Chrome.
# The corpus is the preview classes directly (the registry roster takes
# over when the charts registry lands, N10 W9).

POETRY_BROWSER_VIEWPORT = [1024, 768].freeze
POETRY_AXE_RULESETS = %w[wcag2a wcag2aa].freeze

# Preview examples with known, reviewed axe violations - the ONLY skip
# mechanism (no silent skips). A key that stops producing violations fails
# the run so this list can't go stale.
POETRY_AXE_SKIPS = {}.freeze

def poetry_charts_dummy_assets_dir
  Poetry::Charts.root.join("test/dummy/public/assets")
end

# [component, example, url] for every example of every charts preview.
def poetry_charts_preview_pages
  previews = ViewComponent::Preview.descendants
                                   .select { |preview| preview.name&.start_with?("Poetry::Charts::") }
                                   .sort_by(&:name)
  abort "no charts preview classes loaded" if previews.empty?

  previews.flat_map do |preview|
    key = preview.preview_name
    component = key.split("/").last
    preview.examples.sort.map { |example| [component, example, "/previews/#{key}/#{example}"] }
  end
end

def poetry_charts_browser_session(reduced_motion: false)
  require "capybara/cuprite"

  Capybara.register_driver(:poetry_cuprite) do |app|
    Capybara::Cuprite::Driver.new(app, window_size: POETRY_BROWSER_VIEWPORT,
                                       headless: true, timeout: 30, process_timeout: 30)
  end
  Capybara.server = :puma, { Silent: true }
  session = Capybara::Session.new(:poetry_cuprite, Rails.application)

  # The visual + axe passes emulate prefers-reduced-motion: reduce (CDP,
  # persists across navigations): deterministic screenshots regardless of
  # entrance animation, AND a standing proof that reduced-motion users get
  # the untouched chart - the Phase A baselines must match the pre-motion
  # recordings. The interaction task keeps real motion.
  if reduced_motion
    session.driver.browser.page.command(
      "Emulation.setEmulatedMedia",
      features: [{ "name" => "prefers-reduced-motion", "value" => "reduce" }]
    )
  end
  session
end

# Visit a preview page and wait for readiness (stamped inline while the
# chrome is static; flips to the Stimulus-booted flag when controllers land).
def poetry_charts_visit_preview(session, url)
  session.visit(url)
  raise "HTTP #{session.status_code} at #{url}" unless session.status_code == 200
  raise "preview never became ready at #{url}" unless session.has_css?("html[data-poetry-ready]", wait: 10)
end

namespace :browser do
  desc "Generate the static assets the component_preview layout serves (compiled Tailwind + " \
       "the charts controllers + importmap) into test/dummy/public/assets"
  task :assets do
    poetry_charts_boot!
    require "fileutils"
    require "json"

    dir = poetry_charts_dummy_assets_dir
    FileUtils.mkdir_p(dir)

    # (a) The real stylesheet: the exact css:verify_compiled build.
    File.write(dir.join("poetry.css"), poetry_charts_compile_tailwind)

    # (b) The controllers, verbatim, plus the Stimulus dist the gem
    # develops against.
    js_src = Poetry::Charts.root.join("app/javascript/poetry/charts")
    js_dest = dir.join("poetry/charts")
    FileUtils.rm_rf(js_dest)
    FileUtils.mkdir_p(js_dest.dirname)
    FileUtils.cp_r(js_src, js_dest)

    stimulus = Poetry::Charts.root.join("node_modules/@hotwired/stimulus/dist/stimulus.js")
    abort "missing #{stimulus} - run npm install in poetry-charts" unless stimulus.exist?
    FileUtils.cp(stimulus, dir.join("stimulus.js"))

    # Turbo drives the /interactive morph demo (A-W3): the form submit
    # becomes a same-context body swap, so the motion registry survives.
    turbo = Poetry::Charts.root.join("node_modules/@hotwired/turbo/dist/turbo.es2017-esm.js")
    abort "missing #{turbo} - run npm install in poetry-charts" unless turbo.exist?
    FileUtils.cp(turbo, dir.join("turbo.js"))

    # (c) The importmap resolving the bare specifiers to the copied files.
    imports = {
      "@hotwired/stimulus" => "/assets/stimulus.js",
      "@hotwired/turbo" => "/assets/turbo.js",
      "@poetry/charts" => "/assets/poetry/charts/index.js"
    }
    Dir.glob("**/*.js", base: js_dest).sort.each do |rel|
      next if rel == "index.js"

      imports["@poetry/charts/#{rel.delete_suffix(".js")}"] = "/assets/poetry/charts/#{rel}"
    end
    File.write(dir.join("importmap.json"), JSON.pretty_generate({ "imports" => imports }))

    puts "browser assets generated in #{dir}"
  end
end

def poetry_charts_axe_source
  require "axe/configuration"
  Axe::Configuration.instance.jslib
end

def poetry_charts_axe_violations(session)
  session.execute_script(poetry_charts_axe_source) unless session.evaluate_script("typeof window.axe !== 'undefined'")
  session.execute_script(<<~JS)
    window.__poetryAxe = null;
    axe.run(document, { runOnly: { type: "tag", values: #{POETRY_AXE_RULESETS.to_json} } })
      .then(results => { window.__poetryAxe = { violations: JSON.parse(JSON.stringify(results.violations)) }; })
      .catch(error => { window.__poetryAxe = { error: String(error) }; });
  JS

  result = nil
  100.times do
    result = session.evaluate_script("window.__poetryAxe")
    break if result

    sleep 0.1
  end
  raise "axe.run timed out" unless result
  raise "axe.run failed: #{result["error"]}" if result["error"]

  result["violations"]
end

namespace :test do
  desc "Run axe (#{POETRY_AXE_RULESETS.join(", ")}) against every charts preview example " \
       "in headless Chrome (not in the default gate - needs Chrome)"
  task accessibility: :"browser:assets" do
    session = poetry_charts_browser_session(reduced_motion: true)

    failures = []
    skipped = []
    stale_skips = []
    pages = poetry_charts_preview_pages

    pages.each do |component, example, url|
      key = "#{component}/#{example}"
      poetry_charts_visit_preview(session, url)
      violations = poetry_charts_axe_violations(session)

      if POETRY_AXE_SKIPS.key?(key)
        if violations.empty?
          stale_skips << key
        else
          skipped << "#{key} (#{violations.map { |v| v["id"] }.uniq.join(", ")}): #{POETRY_AXE_SKIPS[key]}"
        end
        next
      end

      violations.each do |violation|
        violation["nodes"].each do |node|
          failures << [key.ljust(32), violation["impact"].to_s.ljust(12),
                       violation["id"].ljust(28), Array(node["target"]).join(" ")].join(" ")
        end
      end
    end

    skipped.each { |line| puts "SKIPPED (known violation) #{line}" }

    unless stale_skips.empty?
      abort "stale POETRY_AXE_SKIPS entries (no violations any more - remove them):\n  #{stale_skips.join("\n  ")}"
    end

    unless failures.empty?
      header = ["component/example".ljust(32), "impact".ljust(12), "rule".ljust(28), "selector"].join(" ")
      abort "axe violations (#{POETRY_AXE_RULESETS.join("/")}):\n#{header}\n#{failures.join("\n")}"
    end

    puts "accessibility: #{pages.size} preview pages clean against #{POETRY_AXE_RULESETS.join("+")} " \
         "(#{skipped.size} documented skips)"
  end

  desc "Screenshot every charts preview example and compare against test/visual_baselines " \
       "(VISUAL_REBASELINE=1 re-records; not in the default gate - needs Chrome)"
  task visual: :"browser:assets" do
    require "fileutils"

    session = poetry_charts_browser_session(reduced_motion: true)
    # Per-theme goldens (N12): the default set stays flat; non-default
    # themes keep their own subdirectory (POETRY_THEME=<name>).
    theme = poetry_charts_theme_name
    baseline_dir = Poetry::Charts.root.join("test/visual_baselines")
    baseline_dir = baseline_dir.join(theme) unless theme == "default"
    diffs_dir = Poetry::Charts.root.join("tmp/visual_diffs")
    rebaseline = ENV["VISUAL_REBASELINE"] == "1"
    FileUtils.mkdir_p(baseline_dir)

    created = []
    failures = []
    compared = 0

    poetry_charts_preview_pages.each do |component, example, url|
      name = "#{component}--#{example}.png"
      baseline = baseline_dir.join(name)
      poetry_charts_visit_preview(session, url)

      candidate = Poetry::Charts.root.join("tmp", "visual_candidate.png")
      FileUtils.mkdir_p(candidate.dirname)
      session.driver.save_screenshot(candidate.to_s, full: true)

      if rebaseline || !baseline.exist?
        FileUtils.mv(candidate, baseline)
        created << name
      else
        compared += 1
        if (diff = poetry_charts_visual_diff(baseline, candidate))
          FileUtils.mkdir_p(diffs_dir)
          FileUtils.mv(candidate, diffs_dir.join(name))
          failures << "#{name}: #{diff} (candidate in tmp/visual_diffs/#{name})"
        else
          FileUtils.rm_f(candidate)
        end
      end
    end

    puts "visual: #{created.size} baselines #{rebaseline ? "re-recorded" : "created"}" unless created.empty?

    unless failures.empty?
      abort "visual regressions (#{failures.size} of #{compared} compared):\n  #{failures.join("\n  ")}"
    end

    puts "visual: #{compared} screenshots match test/visual_baselines (tolerance #{POETRY_VISUAL_PIXEL_TOLERANCE})"
  end
end

# Pixel tolerance when the byte-compare misses: identical dimensions and at
# most this fraction of differing pixels still passes (sub-pixel AA jitter).
POETRY_VISUAL_PIXEL_TOLERANCE = 0.001

# Per-file overrides for KNOWN nondeterministic renders - each entry
# carries its reason; anything else rides the global tolerance.
POETRY_VISUAL_TOLERANCES = {}.freeze

def poetry_charts_visual_diff(baseline_path, candidate_path)
  baseline = baseline_path.binread
  candidate = candidate_path.binread
  return nil if baseline == candidate

  require "chunky_png"
  old_png = ChunkyPNG::Image.from_blob(baseline)
  new_png = ChunkyPNG::Image.from_blob(candidate)
  return "dimensions changed #{old_png.width}x#{old_png.height} -> #{new_png.width}x#{new_png.height}" unless
    old_png.width == new_png.width && old_png.height == new_png.height

  total = old_png.width * old_png.height
  diff = 0
  old_png.height.times do |y|
    old_row = old_png.row(y)
    new_row = new_png.row(y)
    old_row.each_index { |x| diff += 1 unless old_row[x] == new_row[x] }
  end
  tolerance = POETRY_VISUAL_TOLERANCES.fetch(File.basename(baseline_path.to_s), POETRY_VISUAL_PIXEL_TOLERANCE)
  return nil if diff <= total * tolerance

  "#{diff}/#{total} pixels differ (#{(diff * 100.0 / total).round(2)}%)"
end
