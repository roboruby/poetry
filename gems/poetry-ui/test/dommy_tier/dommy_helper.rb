# frozen_string_literal: true

# The dommy tier: poetry's middle test tier. Real Stimulus
# controllers + real computed styles, headlessly, at Minitest speed - no
# browser. Sits between the unit tier (rendered-HTML assertions) and the
# real-browser pass (rake test:accessibility / test:visual), catching 4 of
# the 6 browser-pass bug classes: UA semantics (dialog display), purged
# CSS, dark-mode cascade split-brain, and Stimulus registration/behavior.
# NOT covered here, permanently (dommy has no layout engine, by design):
# layout sizing and coordinate hit-testing - those stay browser-only.
#
# Two build artifacts, both cached under tmp/dommy_tier/:
#   - the dummy host's compiled Tailwind CSS (same recipe as rake
#     css:verify_compiled: tokens + theme + vendored animate + shadcn
#     utilities + safelist), keyed on the safelist + input contents
#   - a flattened controllers bundle (Stimulus UMD + poetry's ES modules
# with imports/exports rewritten - the spike's approach), keyed
#     on source mtimes
#
# Known degradation (spike finding, unchanged here): Dommy.parse drops the
# body's attributes on FRAGMENT input, so pages are always built as full
# <!DOCTYPE html> documents; dark mode is toggled via a class on <html>.

ENV["RAILS_ENV"] = "test"

require_relative "../dummy/config/environment"
require "minitest/autorun"
require "dommy"
require "dommy/js/quickjs"
require_relative "support/browser_harness"

require "digest"
require "fileutils"
require "tailwindcss/ruby"
require "tmpdir"

# The Style dictionaries live in app/components - eager-load so
# Poetry::Core::Style.descendants (the safelist source) is complete.
Rails.application.eager_load!

module DommyTier
  CACHE_DIR = Pathname.new(File.expand_path("../../tmp/dommy_tier", __dir__))

  STIMULUS_UMD = Poetry::Core.root.join("node_modules/@hotwired/stimulus/dist/stimulus.umd.js")
  CONTROLLERS_DIR = Poetry::Core.root.join("app/javascript/poetry/core")

  # Bump when the dommy-safe transform below changes (busts the CSS cache).
  CSS_TRANSFORM_VERSION = "1"

  module_function

  # --- compiled CSS (the css:verify_compiled recipe, made dommy-safe) ------
  #
  # Two dommy 0.9 parser limits (probed empirically, 2026-07-02) force a
  # post-processing pass over the raw Tailwind v4 output:
  #
  #   1. lexbor (dommy's stylesheet tokenizer via makiri) DROPS nested rules
  #      (`.x { &:hover {} }` loses the inner rule) - so the build runs with
  #      --optimize, whose Lightning CSS pass flattens all nesting away.
  #   2. lexbor destroys identifier escapes when serializing selector text
  #      (`.a\:b` comes back as `.a:b` = class a + pseudo b, never matching) -
  #      so every escaped class selector is rewritten to its equivalent
  #      attribute form `[class~="a:b"]` (same 0,1,0 specificity), which both
  #      lexbor and dommy's matcher handle. Dommy DOES match escaped classes
  #      in querySelector - the mangling is only in stylesheet parsing.
  #
  # Same-recipe caveat: aside from those two mechanical transforms the build
  # is the css:verify_compiled recipe byte for byte (same entry, safelist,
  # tokens, vendored layers).

  def compiled_css
    @compiled_css ||= begin
      cache = CACHE_DIR.join("compiled-#{css_digest}.css")
      build_compiled_css(cache) unless cache.exist?
      cache.read
    end
  end

  def css_inputs
    %w[tokens/tokens.css tokens/tailwind-theme.css
       vendor/tw-animate-css/tw-animate.css vendor/shadcn-tailwind/tailwind.css
       tokens/aliases.css]
      .map { |path| Poetry::Core.root.join(path) }
  end

  def safelist_text
    styles = Poetry::Core::Style.descendants.select(&:name)
    Poetry::Core::CSS::Safelist.new(style_classes: styles,
                                    template_classes: Poetry::Ui.template_classes).text
  end

  def css_digest
    Digest::SHA256.hexdigest(CSS_TRANSFORM_VERSION + safelist_text + css_inputs.map(&:read).join)[0, 16]
  end

  def build_compiled_css(cache)
    FileUtils.mkdir_p(CACHE_DIR)
    Dir.mktmpdir("poetry-dommy-css") do |dir|
      File.write(File.join(dir, "safelist.txt"), safelist_text)
      File.write(File.join(dir, "entry.css"), <<~CSS)
        @import "tailwindcss";
        #{css_inputs.map { |path| %(@import "#{path}";) }.join("\n")}
        @source "#{File.join(dir, "safelist.txt")}";
      CSS
      out = File.join(dir, "out.css")
      # --optimize = the Lightning CSS pass that flattens nesting (limit 1).
      system(Tailwindcss::Ruby.executable, "-i", File.join(dir, "entry.css"), "-o", out,
             "--optimize", exception: true, out: File::NULL, err: File::NULL)
      cache.write(attribute_form_class_selectors(File.read(out)))
    end
  end

  # A class token in a selector: simple ident chars, char escapes (\[ \: \.),
  # and hex escapes with their terminating space (\32 xl -> "2xl").
  CLASS_TOKEN = /\.((?:\\[0-9a-fA-F]{1,6} ?|\\[^0-9a-fA-F]|[\w-])+)/

  # Rewrite `.escaped\:class` -> `[class~="escaped:class"]` (limit 2). Only
  # tokens containing a backslash are touched, so decimals in declaration
  # values (`0.93`) and plain classes pass through byte-identical.
  def attribute_form_class_selectors(css)
    css.gsub(CLASS_TOKEN) do
      token = Regexp.last_match(1)
      token.include?("\\") ? %([class~="#{unescape_css_identifier(token)}"]) : ".#{token}"
    end
  end

  def unescape_css_identifier(token)
    token.gsub(/\\([0-9a-fA-F]{1,6}) ?|\\(.)/) do
      hex = Regexp.last_match(1)
      hex ? hex.hex.chr(Encoding::UTF_8) : Regexp.last_match(2)
    end
  end

  # --- flattened controllers bundle (the spike's approach) -----------
  #
  # Dommy 0.9 has no ES-module loader wired into the harness, so the
  # @poetry/controllers module graph is flattened into one classic script:
  # strip import statements, unwrap helper `export`s into the top-level
  # scope, and rewrite each controller's `export default class` into a
  # registration on globalThis.__poetryControllers - each controller wrapped
  # in an IIFE so module-level names never collide across files. Controller
  # comes from the Stimulus UMD global. Re-check at dommy 1.0 for native ESM
  # loading to drop this step.

  def controllers_js_path
    @controllers_js_path ||= begin
      unless STIMULUS_UMD.exist?
        raise "Stimulus UMD bundle not found at #{STIMULUS_UMD} - run `npm install` in poetry-core " \
              "(the dommy tier flattens poetry's controllers against that bundle)"
      end
      cache = CACHE_DIR.join("controllers-#{js_digest}.js")
      unless cache.exist?
        FileUtils.mkdir_p(CACHE_DIR)
        cache.write(flattened_bundle)
      end
      cache
    end
  end

  def helper_files
    # state.js first: function declarations hoist, but presence's exported
    # consts read nothing at define time - ordering is belt and braces.
    CONTROLLERS_DIR.glob("helpers/*.js").sort_by { |path| path.basename.to_s == "state.js" ? "" : path.to_s }
  end

  def controller_files
    CONTROLLERS_DIR.glob("*_controller.js").sort
  end

  def js_digest
    sources = [STIMULUS_UMD] + helper_files + controller_files
    Digest::SHA256.hexdigest(sources.map { |path| "#{path}:#{File.mtime(path).to_f}" }.join("\n"))[0, 16]
  end

  # Remove `import ... from "..."` statements (single- or multi-line - the
  # character class crosses newlines) so the flattened scope provides the
  # names instead.
  def strip_imports(source)
    source.gsub(/^import\b[^"']*["'][^"']+["']\s*\n/, "")
  end

  def stimulus_identifier(path)
    "poetry--core--#{path.basename(".js").to_s.delete_suffix("_controller").tr("_", "-")}"
  end

  def flattened_controller(path)
    source = strip_imports(path.read)
             .sub("export default class", %(globalThis.__poetryControllers["#{stimulus_identifier(path)}"] = class))
    "(() => {\n#{source}\n})();"
  end

  def flattened_bundle
    <<~JS
      #{STIMULUS_UMD.read}
      const { Controller } = Stimulus;
      globalThis.__poetryControllers = {};
      #{helper_files.map { |path| strip_imports(path.read).gsub(/^export /, "") }.join("\n")}
      #{controller_files.map { |path| flattened_controller(path) }.join("\n")}
      window.__poetryApp = Stimulus.Application.start();
      for (const [identifier, controller] of Object.entries(globalThis.__poetryControllers)) {
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

    # Renders a ViewComponent through the dummy host (or accepts raw HTML)
    # and loads it into a dommy page primed with the compiled Tailwind CSS
    # and poetry's Stimulus controllers. Returns the BrowserHarness.
    #
    #   css: false          skip the compiled stylesheet (UA-semantics tests)
    #   stimulus: false     skip the controllers (pure computed-style tests)
    #   dark: true          the class strategy - .dark on <html>
    #   color_scheme: :dark the media strategy - prefers-color-scheme only
    def render_in_dommy(component_or_html, css: true, stimulus: true, dark: false, color_scheme: nil, &)
      html = if component_or_html.respond_to?(:render_in)
               render_inline(component_or_html, &).to_html
             else
               component_or_html.to_s
             end
      harness = Dommy::Js::BrowserHarness.new(page_document(html, css: css, dark: dark))
      apply_color_scheme(harness, color_scheme) if color_scheme
      boot_controllers(harness) if stimulus
      (@harnesses ||= []) << harness
      harness
    end

    def assert_no_js_errors(harness)
      assert_empty harness.errors, "swallowed JS errors:\n#{harness.error_report}"
    end

    private

    # Always a full document: fragment parsing drops body/html attributes
    # (spike friction finding), and the dark class must sit on <html>.
    def page_document(html, css:, dark:)
      <<~HTML
        <!DOCTYPE html>
        <html#{%( class="dark") if dark}>
          <head>#{"<style>#{DommyTier.compiled_css}</style>" if css}</head>
          <body>#{html}</body>
        </html>
      HTML
    end

    def apply_color_scheme(harness, scheme)
      harness.window.media_environment.prefers_color_scheme = scheme.to_s
      harness.window.__internal_media_environment_changed__
    end

    def boot_controllers(harness)
      harness.load_script(DommyTier.controllers_js_path.to_s)
      harness.pump
    end
  end
end
