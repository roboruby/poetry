# frozen_string_literal: true

# The real-browser layer (N2 test spine): rake test:accessibility runs axe
# (wcag2a + wcag2aa) against every registry component's preview examples in
# headless Chrome; rake test:visual screenshots the same corpus against
# committed baselines. Both boot the dummy host under Capybara/Cuprite and
# drive the /previews/<preview_name>/<example> pages (PreviewsController +
# the component_preview layout: compiled Tailwind + live Stimulus). Neither
# joins the default gate - they need a local Chrome.

POETRY_BROWSER_VIEWPORT = [1024, 768].freeze
POETRY_AXE_RULESETS = %w[wcag2a wcag2aa].freeze

# Preview examples with known, reviewed axe violations - the ONLY skip
# mechanism (no silent skips). Key: "<component>/<example>"; value: the
# reason the violation is acceptable or the follow-up it awaits. A key that
# stops producing violations fails the run so this list can't go stale.
POETRY_AXE_SKIPS = {
  # Inherited shadcn destructive-palette contrast (design-token decisions,
  # not preview bugs) - fixing means retuning --destructive/--muted tokens
  # against shadcn new-york-v4 parity, which needs a design review.
  "alert/destructive" => "color-contrast 4.49:1 (needs 4.5) - destructive description #ea1a23 on white; " \
                         "shadcn destructive token, review with the token retune",
  "attachment/error" => "color-contrast 4.11:1 - error-state description tint #ec333c on white at text-xs; " \
                        "shadcn destructive token, review with the token retune",
  "bubble/destructive" => "color-contrast 4.0:1 - destructive text #e7000b on destructive-tinted bubble #fde6e7; " \
                          "shadcn destructive token pair, review with the token retune"
}.freeze

# ---------------------------------------------------------------------------
# Shared harness
# ---------------------------------------------------------------------------

def poetry_ui_dummy_assets_dir
  Poetry::Ui.root.join("test/dummy/public/assets")
end

# [component, example, url] for every preview example of every registry
# component - the registry is the roster (17 components), the preview
# classes are the corpus.
def poetry_ui_preview_pages
  require "yaml"
  registry = YAML.safe_load_file(Poetry::Ui.root.join("config/component_registry.yml"))
  registry.fetch("components").keys.sort.flat_map do |key|
    preview = ViewComponent::Preview.find(key)
    abort "no preview class for registry component #{key}" unless preview

    # Every segment after the poetry/ui namespace, dash-joined: last-segment
    # naming let poetry/ui/command/dialog shadow poetry/ui/dialog at
    # dialog--*.png (272 baseline files for 273 shots, and the two pages
    # took turns diffing ~0.24% against the one baseline - the tolerance
    # entry that looked like animation jitter).
    component = key.delete_prefix("poetry/ui/").tr("/", "-")
    preview.examples.sort.map { |example| [component, example, "/previews/#{key}/#{example}"] }
  end
end

def poetry_ui_browser_session
  require "capybara/cuprite"

  Capybara.register_driver(:poetry_cuprite) do |app|
    Capybara::Cuprite::Driver.new(app, window_size: POETRY_BROWSER_VIEWPORT,
                                       headless: true, timeout: 30, process_timeout: 30)
  end
  Capybara.server = :puma, { Silent: true }
  session = Capybara::Session.new(:poetry_cuprite, Rails.application)

  # The layout's motion kill-switch lives behind prefers-reduced-motion
  # (the poetry-charts pattern); the rig emulates it via CDP - persists
  # across navigations - so screenshots stay deterministic while a real
  # browser sees live motion.
  session.driver.browser.page.command(
    "Emulation.setEmulatedMedia",
    features: [{ "name" => "prefers-reduced-motion", "value" => "reduce" }]
  )
  session
end

# Visit a preview page and wait until Stimulus has booted (the layout flips
# data-poetry-ready after registering poetry's controllers) - so axe and the
# screenshots see the wired DOM, not the pre-JS one.
def poetry_ui_visit_preview(session, url)
  session.visit(url)
  raise "HTTP #{session.status_code} at #{url}" unless session.status_code == 200
  raise "Stimulus never booted at #{url}" unless session.has_css?("html[data-poetry-ready]", wait: 10)
end

# ---------------------------------------------------------------------------
# Static assets for the preview layout
# ---------------------------------------------------------------------------

namespace :browser do
  desc "Generate the static assets the component_preview layout serves " \
       "(compiled Tailwind + poetry's Stimulus controllers + importmap) into test/dummy/public/assets"
  task :assets do
    poetry_ui_boot!
    require "fileutils"
    require "json"

    dir = poetry_ui_dummy_assets_dir
    FileUtils.mkdir_p(dir)

    # (a) The real stylesheet: the exact css:verify_compiled build (tokens +
    # theme + vendored animate/shadcn + full safelist).
    File.write(dir.join("poetry.css"), poetry_ui_compile_tailwind)

    # (b) The controllers, verbatim (ESM with bare @poetry/controllers/*
    # specifiers), plus the Stimulus dist poetry-core develops against.
    js_src = Poetry::Core.root.join("app/javascript/poetry/core")
    js_dest = dir.join("poetry/controllers")
    FileUtils.rm_rf(js_dest)
    FileUtils.mkdir_p(js_dest.dirname)
    FileUtils.cp_r(js_src, js_dest)

    stimulus = Poetry::Core.root.join("node_modules/@hotwired/stimulus/dist/stimulus.js")
    abort "missing #{stimulus} - run npm install in poetry-core" unless stimulus.exist?
    FileUtils.cp(stimulus, dir.join("stimulus.js"))

    # (c) The importmap resolving the bare specifiers to the copied files -
    # the same shape poetry-core's config/importmap.rb pins in a real host.
    imports = {
      "@hotwired/stimulus" => "/assets/stimulus.js",
      "@poetry/controllers" => "/assets/poetry/controllers/index.js"
    }
    Dir.glob("**/*.js", base: js_dest).sort.each do |rel|
      next if rel == "index.js"

      imports["@poetry/controllers/#{rel.delete_suffix(".js")}"] = "/assets/poetry/controllers/#{rel}"
    end
    File.write(dir.join("importmap.json"), JSON.pretty_generate({ "imports" => imports }))

    puts "browser assets generated in #{dir}"
  end
end

# ---------------------------------------------------------------------------
# rake test:accessibility
# ---------------------------------------------------------------------------

def poetry_ui_axe_source
  require "axe/configuration"
  Axe::Configuration.instance.jslib # the axe.min.js bundled with axe-core-api
end

def poetry_ui_axe_violations(session)
  session.execute_script(poetry_ui_axe_source) unless session.evaluate_script("typeof window.axe !== 'undefined'")
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
  desc "Run axe (#{POETRY_AXE_RULESETS.join(", ")}) against every registry component's preview " \
       "examples in headless Chrome (not in the default gate - needs Chrome)"
  task accessibility: :"browser:assets" do
    session = poetry_ui_browser_session

    failures = []
    skipped = []
    stale_skips = []
    pages = poetry_ui_preview_pages

    pages.each do |component, example, url|
      key = "#{component}/#{example}"
      poetry_ui_visit_preview(session, url)
      violations = poetry_ui_axe_violations(session)

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

  # -------------------------------------------------------------------------
  # rake test:visual
  # -------------------------------------------------------------------------

  desc "Screenshot every registry component's preview examples and compare against " \
       "test/visual_baselines (VISUAL_REBASELINE=1 re-records; not in the default gate - needs Chrome)"
  task visual: :"browser:assets" do
    require "fileutils"

    session = poetry_ui_browser_session
    # Per-theme goldens (N12): the default set stays flat (no churn); each
    # non-default theme keeps its own subdirectory, recorded once with
    # POETRY_THEME=<name> VISUAL_REBASELINE=1 (browser:assets compiles the
    # same theme via poetry_ui_compile_tailwind's POETRY_THEME default).
    theme = poetry_ui_theme_name
    baseline_dir = Poetry::Ui.root.join("test/visual_baselines")
    baseline_dir = baseline_dir.join(theme) unless theme == "default"
    diffs_dir = Poetry::Ui.root.join("tmp/visual_diffs")
    rebaseline = ENV["VISUAL_REBASELINE"] == "1"
    FileUtils.mkdir_p(baseline_dir)

    created = []
    failures = []
    compared = 0

    poetry_ui_preview_pages.each do |component, example, url|
      name = "#{component}--#{example}.png"
      baseline = baseline_dir.join(name)
      poetry_ui_visit_preview(session, url)

      candidate = Poetry::Ui.root.join("tmp", "visual_candidate.png")
      session.driver.save_screenshot(candidate.to_s, full: true)

      if rebaseline || !baseline.exist?
        FileUtils.mv(candidate, baseline)
        created << name
      else
        compared += 1
        if (diff = poetry_ui_visual_diff(baseline, candidate))
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
# carries its reason; anything else rides the global tolerance. (The one
# historical entry - dialog--default.png at 0.005, blamed on animation
# timing - was really the command/dialog name shadow above: two pages
# alternating against one baseline. Removed with the naming fix; W2a.)
POETRY_VISUAL_TOLERANCES = {}.freeze

def poetry_ui_visual_diff(baseline_path, candidate_path)
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
