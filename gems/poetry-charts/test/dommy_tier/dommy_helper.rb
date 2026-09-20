# frozen_string_literal: true

# The dommy tier for poetry-charts (the poetry-ui pattern): the REAL
# chart controllers - vendored d3 kernel and live renderer included -
# driven headlessly in Minitest on Dommy + QuickJS. What this tier proves
# that vitest/jsdom can't: the whole flattened bundle (kernel + renderer +
# controllers) running on a REAL non-V8 engine against a real DOM, at
# Minitest speed. NOT covered here, permanently (dommy has no layout
# engine, by design): pointer geometry - the tooltip's pointermove bisect
# and the brush/zoom drag stay browser-only; the keyboard layer, the event
# API, and the kernel re-render are all layout-free and live here.
#
# One build artifact, cached under tmp/dommy_tier/: the flattened
# controllers bundle. Unlike poetry-ui's, it must flatten THREE module
# shapes: the minified d3 kernel (one trailing `export {a as b, ...}` -
# rewritten to a globalThis namespace + per-import destructuring), the
# hand-written helper modules (bare named exports, concatenated in
# dependency order), and the controllers (`export default class` ->
# registration, IIFE-wrapped). No compiled CSS: chart behavior is
# attribute-driven (embedded coordinates), not class-driven - computed
# styles stay with poetry-ui's tier and the browser pass.

ENV["RAILS_ENV"] = "test"

require_relative "../dummy/config/environment"
require "minitest/autorun"
require "dommy"
require "dommy/js/quickjs"
require_relative "support/browser_harness"

require "digest"
require "fileutils"

Rails.application.eager_load!

module DommyTier
  CACHE_DIR = Pathname.new(File.expand_path("../../tmp/dommy_tier", __dir__))

  STIMULUS_UMD = Poetry::Charts.root.join("node_modules/@hotwired/stimulus/dist/stimulus.umd.js")
  JS_DIR = Poetry::Charts.root.join("app/javascript/poetry/charts")

  # Dependency order: each module only reads names defined above it.
  MODULE_FILES = %w[
    motion/sector.js motion/tween.js motion/flip.js
    live/renderer.js adapter_registry.js adapters/chartjs.js
  ].freeze

  # Bump when the flattening transform below changes (busts the JS cache).
  JS_TRANSFORM_VERSION = "1"

  # `import { a, b as c } from "..."` (the name list crosses newlines) or
  # `import Default from "..."`.
  IMPORT_STATEMENT = /^import\s*(\{[^}]*\}|\w+)\s*from\s*["']([^"']+)["']\s*;?\s*\n/

  module_function

  def controllers_js_path
    @controllers_js_path ||= begin
      unless STIMULUS_UMD.exist?
        raise "Stimulus UMD bundle not found at #{STIMULUS_UMD} - run `npm install` in poetry-charts"
      end

      cache = CACHE_DIR.join("controllers-#{js_digest}.js")
      unless cache.exist?
        FileUtils.mkdir_p(CACHE_DIR)
        cache.write(flattened_bundle)
      end
      cache
    end
  end

  def module_paths = MODULE_FILES.map { |rel| JS_DIR.join(rel) }
  def controller_paths = JS_DIR.glob("*_controller.js").sort

  def js_digest
    sources = [STIMULUS_UMD, JS_DIR.join("d3.js")] + module_paths + controller_paths
    Digest::SHA256.hexdigest(
      JS_TRANSFORM_VERSION + sources.map { |path| "#{path}:#{File.mtime(path).to_f}" }.join("\n")
    )[0, 16]
  end

  # The vendored kernel ends in ONE `export { internal as exported, ... }`
  # statement (esbuild ESM output); everything before it is the module
  # body. Rewrite to an IIFE returning the export map on a globalThis
  # namespace - modules then destructure their imports from it.
  def kernel_js
    source = JS_DIR.join("d3.js").read
    match = source.match(/export\s*\{([^}]*)\}\s*;?\s*\z/m)
    raise "d3 kernel: trailing export statement not found (bundle shape changed?)" unless match

    pairs = match[1].split(",").map(&:strip).reject(&:empty?).map do |entry|
      internal, _, exported = entry.partition(/\s+as\s+/)
      exported = internal if exported.empty?
      "#{exported.strip}: #{internal.strip}"
    end
    "globalThis.__poetryChartsD3 = (() => {\n#{source[0...match.begin(0)]}\nreturn { #{pairs.join(", ")} };\n})();"
  end

  # Replace import statements with what the flattened scope needs: nothing
  # for Stimulus (the UMD preamble provides Controller) and same-name module
  # imports (the module body is already in scope above), a destructure for
  # kernel imports, and alias consts for renamed module imports.
  def rewrite_imports(source)
    source.gsub(IMPORT_STATEMENT) do
      names = Regexp.last_match(1)
      spec = Regexp.last_match(2)
      next "" unless names.start_with?("{") # default imports: scope provides

      entries = names.delete("{}").split(",").map(&:strip).reject(&:empty?).map do |entry|
        original, _, aliased = entry.partition(/\s+as\s+/)
        [original.strip, aliased.strip]
      end

      if spec == "@poetry/charts/d3"
        list = entries.map { |original, aliased| aliased.empty? ? original : "#{original}: #{aliased}" }
        "const { #{list.join(", ")} } = globalThis.__poetryChartsD3;\n"
      elsif spec == "@hotwired/stimulus"
        ""
      else
        entries.filter_map { |original, aliased| "const #{aliased} = #{original};\n" unless aliased.empty? }.join
      end
    end
  end

  def stimulus_identifier(path)
    "poetry--charts--#{path.basename(".js").to_s.delete_suffix("_controller").tr("_", "-")}"
  end

  def flattened_controller(path)
    source = rewrite_imports(path.read)
             .sub("export default class",
                  %(globalThis.__poetryChartsControllers["#{stimulus_identifier(path)}"] = class))
    "(() => {\n#{source}\n})();"
  end

  # Guarded fallbacks for QuickJS/dommy gaps the controllers touch
  # unguarded. Dommy 0.9 DOES ship MutationObserver (probed 2026-07-05 -
  # live's script-replacement channel and Stimulus's late-mount detection
  # run for real here); the no-op class is belt and braces for a future
  # dommy that drops it, keeping connect() alive at the cost of those two
  # channels. matchMedia is absent = no-preference, so tweens run on the
  # pumped rAF clock.
  SHIMS = <<~JS
    if (typeof globalThis.queueMicrotask !== "function") {
      globalThis.queueMicrotask = (callback) => Promise.resolve().then(callback);
    }
    if (typeof globalThis.MutationObserver !== "function") {
      globalThis.MutationObserver = class { observe() {} disconnect() {} takeRecords() { return []; } };
    }
  JS

  def flattened_bundle
    <<~JS
      #{STIMULUS_UMD.read}
      const { Controller } = Stimulus;
      #{SHIMS}
      globalThis.__poetryChartsControllers = {};
      #{kernel_js}
      #{module_paths.map { |path| rewrite_imports(path.read).gsub(/^export /, "") }.join("\n")}
      #{controller_paths.map { |path| flattened_controller(path) }.join("\n")}
      window.__poetryApp = Stimulus.Application.start();
      for (const [identifier, controller] of Object.entries(globalThis.__poetryChartsControllers)) {
        window.__poetryApp.register(identifier, controller);
      }
    JS
  end

  # --- the test case --------------------------------------------------------

  class TestCase < ViewComponent::TestCase
    def teardown
      @harnesses&.each(&:dispose)
      super
    end

    # Renders a chart component through the dummy host (or accepts raw
    # HTML) and loads it into a dommy page with the flattened controllers
    # booted. Returns the BrowserHarness.
    def render_in_dommy(component_or_html, stimulus: true, &)
      html = if component_or_html.respond_to?(:render_in)
               render_inline(component_or_html, &).to_html
             else
               component_or_html.to_s
             end
      harness = Dommy::Js::BrowserHarness.new(page_document(html))
      boot_controllers(harness) if stimulus
      (@harnesses ||= []) << harness
      harness
    end

    def assert_no_js_errors(harness)
      assert_empty harness.errors, "swallowed JS errors:\n#{harness.error_report}"
    end

    private

    def page_document(html)
      <<~HTML
        <!DOCTYPE html>
        <html>
          <head></head>
          <body>#{html}</body>
        </html>
      HTML
    end

    def boot_controllers(harness)
      harness.load_script(DommyTier.controllers_js_path.to_s)
      harness.pump
    end
  end
end
