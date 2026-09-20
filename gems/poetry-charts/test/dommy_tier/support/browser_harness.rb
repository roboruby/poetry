# frozen_string_literal: true

# Vendored from dommy-js-quickjs test/support/browser_harness.rb @
# 2b98eb6c5adc491f89425c2a08cc00a7462c90cb (the gem does not ship it - a
# spike finding). Keep byte-identical below this header; re-sync when the
# pinned SHA moves, and drop it if a released dommy-js-quickjs starts
# shipping a public harness.

module Dommy
  module Js
    # Test/dev harness for driving real frontend code (frameworks, bundles) on
    # Dommy + QuickJS. Bundles the things every such test needs:
    #
    #   - a parsed window + document host objects
    #   - browser bare-globals (Runtime#install_browser_globals)
    #   - an optional fetch stub (Dommy's __fetchy_stub__)
    #   - automatic capture of swallowed promise rejections (with JS backtraces)
    #     and console output — so failures surface instead of vanishing
    #   - a scheduler "pump" that drives deferred work (rAF/timeouts/microtasks)
    #
    #   h = BrowserHarness.new("<body>...</body>", fetch_stub: { "http://x/y" => {...} })
    #   h.load_script("vendor/turbo.umd.js")
    #   h.execute("...")
    #   h.pump
    #   assert_empty h.errors           # nothing was silently swallowed
    #   h.dispose
    class BrowserHarness
      attr_reader :window, :runtime, :errors, :logs

      def initialize(html = "<!DOCTYPE html><html><head></head><body></body></html>", fetch_stub: nil, iframe_docs: nil)
        @window = Dommy.parse(html)
        @window.__js_set__("__fetchy_stub__", fetch_stub) if fetch_stub
        @iframe_content = iframe_docs || {}
        @iframe_windows = @iframe_content.empty? ? [] : wire_iframe_documents(@iframe_content)
        @runtime = Dommy::Js::Quickjs::Runtime.new
        @errors = []
        @logs = []
        @runtime.on_unhandled_rejection { |err| @errors << err }
        @runtime.on_log { |log| @logs << log }
        @runtime.define_host_object("document", @window.document)
        @runtime.install_window(@window)
        @runtime.install_browser_globals
        # Each iframe window is its own Window; expose the seeded constructors on
        # it (after install_window has seeded them) so cross-window instanceof and
        # `iframe.contentWindow.Element` / `.DOMException` resolve.
        @iframe_windows.each { |w| @runtime.expose_constructors_on(w) }
      end

      def execute(js) = @runtime.execute(js)
      def evaluate(js) = @runtime.evaluate(js)
      def load_script(path) = @runtime.load_script(::File.read(path))

      # Register/extend the fetch stub (url => { status:, body:, contentType: }).
      def stub_fetch(map)
        # Read the internal stash directly (nil for absent); __js_get__ now returns
        # the ABSENT sentinel for unset globals (JS-undefined semantics).
        existing = @window.globals["__fetchy_stub__"] || {}
        @window.__js_set__("__fetchy_stub__", existing.merge(map))
      end

      # Drive deferred work to completion: drain microtasks, advance the
      # deterministic clock (firing rAF/timeouts), repeat. Frameworks defer
      # rendering to the next repaint, so a single drain isn't enough.
      def pump(rounds: 20, step_ms: 16)
        rounds.times do
          wire_dynamic_iframes
          @runtime.drain_microtasks
          @window.scheduler.advance_time(step_ms)
          @runtime.drain_microtasks
        end
        self
      end

      # Wire iframes created at runtime (`frame.src = "…"; body.appendChild(frame)`)
      # whose src has vendored content: populate contentDocument and fire `load`
      # so a `frame.onload` handler (e.g. the Selectors-API suites that run their
      # tests against the iframe document) executes. Idempotent.
      def wire_dynamic_iframes
        return if @iframe_content.empty?

        @window.document.query_selector_all("iframe").each do |iframe|
          next if iframe.content_document

          src = iframe.get_attribute("src").to_s
          markup = @iframe_content[src.sub(/#.*\z/, "")]
          next unless markup

          sub = Dommy.parse(markup)
          sub.document.default_view = sub
          # Carry the URL fragment onto the nested window's location so `:target`
          # (and location.hash) resolve in the framed document.
          sub.location.__internal_set_url__(src) if src.include?("#")
          iframe.__internal_set_content_document__(sub.document)
          @runtime.expose_constructors_on(sub)
          @iframe_windows << sub
          iframe.dispatch_event(Dommy::Event.new("load"))
        end
      end

      # Human-readable dump of captured rejections (message + JS stack) — handy
      # in an assertion message when a framework path silently fails.
      def error_report
        @errors.map { |e| "#{e.class}: #{e.message}\n  #{Array(e.backtrace).first(6).join("\n  ")}" }.join("\n")
      end

      def dispose = @runtime&.dispose

      private

      # Populate each `<iframe src=...>` whose src maps to provided markup with a
      # parsed nested document, so `iframe.contentDocument` resolves (WPT tests
      # that exercise XML/XHTML documents via dummy iframes). Each nested document
      # gets its OWN window as `defaultView` (so `iframe.contentWindow.document`
      # is the nested doc, not the top one) — the constructors are exposed on it
      # separately. Returns the nested windows.
      def wire_iframe_documents(iframe_docs)
        @window.document.query_selector_all("iframe").filter_map do |iframe|
          src = iframe.get_attribute("src").to_s
          markup = iframe_docs[src]
          next unless markup

          sub = Dommy.parse(markup)
          sub.document.default_view = sub
          # Reflect the resource's content type so the nested document reports
          # the right "HTML document" status — XML/XHTML documents preserve
          # element-name case (createElement / tagName), unlike HTML documents.
          sub.document.content_type =
            if src.end_with?(".xhtml")
              "application/xhtml+xml"
            elsif src.end_with?(".xml")
              "text/xml"
            else
              sub.document.content_type
            end
          iframe.__internal_set_content_document__(sub.document)
          sub
        end
      end
    end
  end
end
