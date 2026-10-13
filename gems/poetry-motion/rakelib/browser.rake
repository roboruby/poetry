# frozen_string_literal: true

# The real-browser layer (the poetry-charts rig): rake test:accessibility
# runs axe (wcag2a + wcag2aa) against every effect preview in headless
# Chrome, and rake test:visual screenshots the same pages against
# test/visual_baselines. Both emulate reduced motion, so they capture the
# finished state the server renders and prove the policy leaves it in
# place. Neither joins the default gate - they need Chrome.

POETRY_MOTION_VIEWPORT = [1024, 768].freeze
POETRY_MOTION_AXE_RULESETS = %w[wcag2a wcag2aa].freeze
POETRY_MOTION_PIXEL_TOLERANCE = 0.001
# Previews the headless rig cannot draw, each with its reason. Axe still runs on them.
POETRY_MOTION_VISUAL_SKIPS = {
  "globe--default.png" => "WebGL: headless Chrome in the rig has no GPU context, so the canvas is blank; " \
                          "the globe is proven in a real browser instead"
}.freeze

def poetry_motion_assets_dir = Poetry::Motion.root.join("test/dummy/public/assets")

# [component, example, url] for every example of every effect preview.
def poetry_motion_preview_pages
  previews = ViewComponent::Preview.descendants.select { |preview| preview.name&.start_with?("Poetry::Motion::") }
  abort "no motion preview classes loaded" if previews.empty?

  previews.sort_by(&:name).flat_map do |preview|
    key = preview.preview_name
    preview.examples.sort.map { |example| [key.split("/").last, example, "/previews/#{key}/#{example}"] }
  end
end

def poetry_motion_compile_tailwind
  require "tailwindcss/ruby"
  require "tmpdir"

  styles = Poetry::Core::Style.descendants.select { |style| style.name&.start_with?("Poetry::Motion::") }
  sources = Dir[Poetry::Motion.root.join("app/components/**/preview.rb").to_s] +
            [Poetry::Motion.root.join("test/dummy/app/views/layouts/component_preview.html.erb").to_s,
             Poetry::Core.root.join("app/views/poetry/core/preview.html.erb").to_s]
  Dir.mktmpdir("poetry-motion-css") do |dir|
    File.write(File.join(dir, "safelist.txt"), Poetry::Core::CSS::Safelist.new(style_classes: styles).text)
    File.write(File.join(dir, "entry.css"), <<~CSS)
      @import "tailwindcss" source(none);
      @import "#{Poetry::Core.root.join("tokens/tokens.css")}";
      @import "#{Poetry::Core.root.join("tokens/tailwind-theme.css")}";
      @import "#{Poetry::Core.root.join("tokens/aliases.css")}";
      @import "#{Poetry::Motion.root.join("app/assets/stylesheets/poetry-motion.css")}";
      @source "#{File.join(dir, "safelist.txt")}";
      #{sources.map { |source| %(@source "#{source}";) }.join("\n")}
    CSS
    out = File.join(dir, "out.css")
    system(Tailwindcss::Ruby.executable, "-i", File.join(dir, "entry.css"), "-o", out,
           exception: true, out: File::NULL, err: File::NULL)
    File.read(out)
  end
end

def poetry_motion_browser_session
  require "capybara/cuprite"

  Capybara.register_driver(:poetry_motion_cuprite) do |app|
    Capybara::Cuprite::Driver.new(app, window_size: POETRY_MOTION_VIEWPORT, headless: true,
                                       timeout: 30, process_timeout: 30)
  end
  Capybara.server = :puma, { Silent: true }
  session = Capybara::Session.new(:poetry_motion_cuprite, Rails.application)
  session.driver.browser.page.command("Emulation.setEmulatedMedia",
                                      features: [{ "name" => "prefers-reduced-motion", "value" => "reduce" }])
  session
end

def poetry_motion_visit(session, url)
  session.visit(url)
  raise "HTTP #{session.status_code} at #{url}" unless session.status_code == 200
  raise "preview never became ready at #{url}" unless session.has_css?("html[data-poetry-ready]", wait: 10)
end

namespace :browser do
  desc "Generate the static assets the preview layout serves into test/dummy/public/assets"
  task :assets do
    poetry_motion_boot!
    require "fileutils"
    require "json"

    dir = poetry_motion_assets_dir
    FileUtils.rm_rf(dir)
    FileUtils.mkdir_p(dir)
    File.write(dir.join("poetry.css"), poetry_motion_compile_tailwind)

    imports = { "@hotwired/stimulus" => "/assets/stimulus.js" }
    FileUtils.cp(Poetry::Motion.root.join("node_modules/@hotwired/stimulus/dist/stimulus.js"), dir.join("stimulus.js"))
    { "poetry/motion" => ["@poetry/motion", Poetry::Motion.root],
      "poetry/motion-kernel" => [nil, Poetry::Motion.root],
      "poetry/core" => ["@poetry/controllers", Poetry::Core.root] }.each do |subpath, (package, gem_root)|
      FileUtils.mkdir_p(dir.join(subpath).dirname)
      FileUtils.cp_r(gem_root.join("app/javascript", subpath), dir.join(subpath))
      next unless package

      Dir.glob("**/*.js", base: dir.join(subpath)).each do |rel|
        imports["#{package}/#{rel.delete_suffix(".js")}"] = "/assets/#{subpath}/#{rel}"
      end
      imports[package] = "/assets/#{subpath}/index.js"
    end
    imports["@poetry/motion/engine"] = "/assets/poetry/motion-kernel/engine.js"
    File.write(dir.join("importmap.json"), JSON.pretty_generate({ "imports" => imports }))
    puts "browser assets generated in #{dir}"
  end
end

def poetry_motion_axe_violations(session)
  require "axe/configuration"
  loaded = session.evaluate_script("typeof window.axe !== 'undefined'")
  session.execute_script(Axe::Configuration.instance.jslib) unless loaded
  session.execute_script(<<~JS)
    window.__poetryAxe = null;
    axe.run(document, { runOnly: { type: "tag", values: #{POETRY_MOTION_AXE_RULESETS.to_json} } })
      .then(results => { window.__poetryAxe = { violations: JSON.parse(JSON.stringify(results.violations)) }; })
      .catch(error => { window.__poetryAxe = { error: String(error) }; });
  JS
  result = nil
  100.times do
    break if (result = session.evaluate_script("window.__poetryAxe"))

    sleep 0.1
  end
  raise "axe.run timed out" unless result
  raise "axe.run failed: #{result["error"]}" if result["error"]

  result["violations"]
end

def poetry_motion_visual_diff(baseline_path, candidate_path)
  return nil if baseline_path.binread == candidate_path.binread

  require "chunky_png"
  old_png = ChunkyPNG::Image.from_blob(baseline_path.binread)
  new_png = ChunkyPNG::Image.from_blob(candidate_path.binread)
  unless old_png.width == new_png.width && old_png.height == new_png.height
    return "dimensions changed #{old_png.width}x#{old_png.height} -> #{new_png.width}x#{new_png.height}"
  end

  total = old_png.width * old_png.height
  diff = (0...old_png.height).sum { |y| old_png.row(y).zip(new_png.row(y)).count { |a, b| a != b } }
  return nil if diff <= total * POETRY_MOTION_PIXEL_TOLERANCE

  "#{diff}/#{total} pixels differ (#{(diff * 100.0 / total).round(2)}%)"
end

namespace :test do
  desc "Run axe against every effect preview in headless Chrome (needs Chrome; not in the default gate)"
  task accessibility: :"browser:assets" do
    session = poetry_motion_browser_session
    pages = poetry_motion_preview_pages
    failures = pages.flat_map do |component, example, url|
      poetry_motion_visit(session, url)
      poetry_motion_axe_violations(session).flat_map do |violation|
        violation["nodes"].map do |node|
          "#{component}/#{example} #{violation["id"]} #{Array(node["target"]).join(" ")}"
        end
      end
    end
    abort "axe violations:\n  #{failures.join("\n  ")}" unless failures.empty?

    puts "accessibility: #{pages.size} preview pages clean against #{POETRY_MOTION_AXE_RULESETS.join("+")}"
  end

  desc "Screenshot every effect preview against test/visual_baselines (VISUAL_REBASELINE=1 re-records; needs Chrome)"
  task visual: :"browser:assets" do
    require "fileutils"

    session = poetry_motion_browser_session
    baselines = Poetry::Motion.root.join("test/visual_baselines")
    diffs = Poetry::Motion.root.join("tmp/visual_diffs")
    rebaseline = ENV["VISUAL_REBASELINE"] == "1"
    created = []
    failures = []
    compared = 0
    poetry_motion_preview_pages.each do |component, example, url|
      name = "#{component}--#{example}.png"
      if POETRY_MOTION_VISUAL_SKIPS.key?(name)
        next puts("visual: skipped #{name} (#{POETRY_MOTION_VISUAL_SKIPS[name]})")
      end

      baseline = baselines.join(name)
      poetry_motion_visit(session, url)
      candidate = Poetry::Motion.root.join("tmp/visual_candidate.png")
      FileUtils.mkdir_p(candidate.dirname)
      session.driver.save_screenshot(candidate.to_s, full: true)
      if rebaseline || !baseline.exist?
        FileUtils.mv(candidate, baseline)
        created << name
      else
        compared += 1
        if (diff = poetry_motion_visual_diff(baseline, candidate))
          FileUtils.mkdir_p(diffs)
          FileUtils.mv(candidate, diffs.join(name))
          failures << "#{name}: #{diff}"
        else
          FileUtils.rm_f(candidate)
        end
      end
    end
    puts "visual: #{created.size} baselines #{rebaseline ? "re-recorded" : "created"}" unless created.empty?
    abort "visual regressions:\n  #{failures.join("\n  ")}" unless failures.empty?

    puts "visual: #{compared} screenshots match test/visual_baselines (tolerance #{POETRY_MOTION_PIXEL_TOLERANCE})"
  end
end
