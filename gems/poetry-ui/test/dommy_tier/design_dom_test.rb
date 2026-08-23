# frozen_string_literal: true

require_relative "dommy_helper"
require "nokogiri"

module DommyTier
  # The DesignLint DOM tier over the rendered catalog: computed
  # styles from dommy (real cascade, no browser) feed the painted-axis
  # rules - type-scale monotony, invisible surface boundaries,
  # near-identical adjacent surfaces. One page per registry component (the
  # default example carries the representative anatomy; the browser tiers
  # sweep the full example corpus for a11y/visual).
  #
  # Skip ledger, axe-skips discipline: the ONLY mechanism, reviewed reasons,
  # and a key that stops firing FAILS the run so the ledger cannot go stale.
  class DesignDomTest < TestCase
    DESIGN_DOM_SKIPS = {}.freeze

    STYLE_PROPS = %w[font-size background-color border-width border-top-width box-shadow gap display visibility].freeze

    def test_rendered_component_pages_carry_no_painted_design_slop
      violations = {}
      component_previews.each do |key, preview, example|
        findings = lint_page(key, preview, example)
        violations["#{key}/#{example}"] = findings if findings.any?
      end

      unexpected = violations.reject { |page, _| DESIGN_DOM_SKIPS.key?(page) }
      stale = DESIGN_DOM_SKIPS.keys - violations.keys

      assert_empty stale, "stale design-dom skips (no longer firing): #{stale.join(", ")}"
      assert_empty(unexpected.map { |page, findings| "#{page}: #{findings.join("; ")}" })
    end

    private

    # [registry key, preview class, first example] per component.
    def component_previews
      registry = YAML.safe_load_file(Poetry::Ui.root.join("config/component_registry.yml"))
      registry.fetch("components").keys.sort.filter_map do |key|
        preview = ViewComponent::Preview.find(key)
        next unless preview

        example = preview.examples.min
        [key, preview, example]
      end
    end

    def lint_page(key, preview, example)
      html = render_preview_html(preview, example)
      harness = render_in_dommy(html, stimulus: false)
      harness.execute(<<~JS)
        document.querySelectorAll("body *").forEach((el, i) => el.setAttribute("data-dl", String(i)));
      JS
      styles_map = JSON.parse(harness.evaluate(<<~JS))
        JSON.stringify(Object.fromEntries([...document.querySelectorAll("body *")].map((el) => {
          const cs = getComputedStyle(el);
          return [el.getAttribute("data-dl"), {
            #{STYLE_PROPS.map { |prop| %("#{prop}": cs.getPropertyValue("#{prop}")) }.join(", ")}
          }];
        })))
      JS
      doc = Nokogiri::HTML5.fragment(harness.evaluate("document.body.innerHTML"))
      styles = ->(el) { styles_map.fetch(el["data-dl"], {}) }
      Poetry::Core::DesignLint.lint_dom(doc: doc, styles: styles, file: "previews/#{key}/#{example}")
    end

    # Through ViewComponent's own preview pipeline (handles template-backed
    # previews and preview locals the same way the previews controller does).
    def render_preview_html(preview, example)
      render_preview(example, from: preview).to_html
    end
  end
end
