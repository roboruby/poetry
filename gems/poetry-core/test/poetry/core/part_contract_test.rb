# frozen_string_literal: true

require "test_helper"

module Poetry
  module Core
    # The part contract: the Parts DSL (declaration + validation +
    # registry shape) and the PartContract DOM verifier (every rule, both
    # directions), plus the state.js vocabulary sync gate.
    class PartContractTest < Minitest::Test
      # -- the Parts DSL ---------------------------------------------------

      def component_class(&block)
        Class.new(Poetry::Core::Component) do
          def self.name = "Poetry::Core::Fabricated::Component"
          class_eval(&block) if block
        end
      end

      def test_part_definitions_are_registry_shaped
        klass = component_class do
          part "widget", "The root"
          part "widget-panel", "The panel",
               states: { "data-open" => "while open",
                         "data-side" => { condition: "resolved side", values: %w[top bottom] } },
               vars: { "--widget-width" => "panel width" }
        end

        assert_equal [
          { "name" => "widget", "description" => "The root" },
          { "name" => "widget-panel", "description" => "The panel",
            "states" => [
              { "attr" => "data-open", "condition" => "while open" },
              { "attr" => "data-side", "condition" => "resolved side", "values" => %w[top bottom] }
            ],
            "vars" => [{ "name" => "--widget-width", "description" => "panel width" }] }
        ], klass.part_definitions
      end

      # An embedded component's root wearing a part the outer declares (an
      # icon rendered as the indicator glyph) belongs to the outer contract.
      def test_embedded_component_root_wearing_a_declared_part_is_owned
        parts = [{ "name" => "outer", "description" => "root" },
                 { "name" => "outer-check", "description" => "the glyph" }]
        wearing = %(<div data-component="outer" data-slot="outer">) +
                  %(<svg data-component="icon" data-slot="outer-check"></svg></div>)

        assert_empty PartContract.verify(title: "outer", parts: parts, docs: [wearing])

        own_slot = %(<div data-component="outer" data-slot="outer">) +
                   %(<svg data-component="icon" data-slot="icon"></svg></div>)
        findings = PartContract.verify(title: "outer", parts: parts, docs: [own_slot])

        assert_equal ["phantom-part"], findings.map(&:rule)
      end

      def test_parts_are_not_inherited
        parent = component_class { part "widget", "The root" }
        child = Class.new(parent) do
          def self.name = "Poetry::Core::FabricatedChild::Component"
        end

        assert_empty child.part_definitions
        assert_equal 1, parent.part_definitions.size
      end

      def test_declaration_validation_raises
        [
          -> { component_class { part "Widget", "bad name" } },
          -> { component_class { part "widget", "" } },
          -> { component_class { part "widget", "ok", states: { "open" => "not a data attr" } } },
          -> { component_class { part "widget", "ok", states: { "data-open" => "" } } },
          -> { component_class { part "widget", "ok", states: { "data-side" => { values: %w[top] } } } },
          -> { component_class { part "widget", "ok", vars: { "width" => "not a custom property" } } },
          -> { component_class { part "widget", "ok", vars: { "--width" => "" } } },
          -> { component_class { part("widget", "ok") && part("widget", "again") } }
        ].each do |declaration|
          assert_raises(Poetry::Core::Error) { declaration.call }
        end
      end

      # -- the verifier ----------------------------------------------------

      WIDGET_PARTS = [
        { "name" => "widget", "description" => "The root" },
        { "name" => "widget-panel", "description" => "The panel",
          "states" => [
            { "attr" => "data-open", "condition" => "while open" },
            { "attr" => "data-side", "condition" => "resolved side", "values" => %w[top bottom] }
          ],
          "vars" => [{ "name" => "--widget-width", "description" => "panel width" }] }
      ].freeze

      CLEAN_DOC = <<~HTML
        <div data-component="widget" data-slot="widget">
          <div data-slot="widget-panel" data-open data-side="top" style="--widget-width: 12rem"></div>
        </div>
      HTML

      def verify(docs:, parts: WIDGET_PARTS, sources: "")
        PartContract.verify(title: "widget", parts: parts, docs: Array(docs), sources: sources)
      end

      def rules(findings) = findings.map(&:rule).sort

      def test_a_faithful_contract_is_clean
        assert_empty verify(docs: CLEAN_DOC)
      end

      def test_missing_root_and_slotless_component
        assert_equal ["missing-root"], rules(verify(docs: "<div></div>", parts: []))
        assert_equal ["slotless-component"],
                     rules(verify(docs: '<div data-component="widget"></div>', parts: []))
      end

      def test_undeclared_part_carries_a_scaffold_suggestion
        findings = verify(docs: CLEAN_DOC + '<div data-component="widget" data-slot="widget">' \
                                            '<span data-slot="widget-badge" data-active ' \
                                            'style="--badge-hue: 12"></span></div>')

        assert_equal ["undeclared-part"], rules(findings)
        assert_equal 'part "widget-badge", "TODO", states: { "data-active" => "TODO" }, ' \
                     'vars: { "--badge-hue" => "TODO" }',
                     findings.first.suggestion
      end

      def test_phantom_part
        parts = WIDGET_PARTS + [{ "name" => "widget-ghost", "description" => "never rendered" }]

        assert_equal ["phantom-part"], rules(verify(docs: CLEAN_DOC, parts: parts))
      end

      def test_state_reconciliation_both_directions
        undeclared = CLEAN_DOC.sub("data-open", "data-open data-loading")

        assert_equal ["undeclared-state"], rules(verify(docs: undeclared))

        parts = [WIDGET_PARTS[0],
                 WIDGET_PARTS[1].merge("states" => WIDGET_PARTS[1]["states"] +
                   [{ "attr" => "data-dragging", "condition" => "while dragged" }])]

        assert_equal ["unverified-state"], rules(verify(docs: CLEAN_DOC, parts: parts))
        # ...but a JS-vocabulary state (setState writes it at runtime) and a
        # source-mentioned state both verify without rendering.
        vocabulary = [WIDGET_PARTS[0],
                      WIDGET_PARTS[1].merge("states" => WIDGET_PARTS[1]["states"] +
                        [{ "attr" => "data-pressed", "condition" => "while pressed" }])]

        assert_empty verify(docs: CLEAN_DOC, parts: vocabulary)
        assert_empty verify(docs: CLEAN_DOC, parts: parts,
                            sources: 'element.setAttribute("data-dragging", "")')
      end

      def test_unknown_state_value
        assert_equal ["unknown-state-value"],
                     rules(verify(docs: CLEAN_DOC.sub('data-side="top"', 'data-side="left"')))
      end

      def test_var_reconciliation_both_directions
        undeclared = CLEAN_DOC.sub("--widget-width: 12rem", "--widget-width: 12rem; --stray: 1")

        assert_equal ["undeclared-var"], rules(verify(docs: undeclared))

        parts = [WIDGET_PARTS[0],
                 WIDGET_PARTS[1].merge("vars" => WIDGET_PARTS[1]["vars"] +
                   [{ "name" => "--widget-origin", "description" => "set by the popper" }])]

        assert_equal ["unverified-var"], rules(verify(docs: CLEAN_DOC, parts: parts))
        assert_empty verify(docs: CLEAN_DOC, parts: parts,
                            sources: 'style.setProperty("--widget-origin", origin)')
      end

      def test_wildcard_vars_match_dynamic_families
        parts = [WIDGET_PARTS[0],
                 WIDGET_PARTS[1].merge("vars" => [{ "name" => "--widget-*",
                                                    "description" => "per-instance seams" }])]

        assert_empty verify(docs: CLEAN_DOC, parts: parts)
      end

      def test_unnamed_stateful_element
        doc = CLEAN_DOC.sub("</div>\n</div>", "</div><span data-active></span>\n</div>")

        assert_equal ["unnamed-stateful"], rules(verify(docs: doc))
      end

      def test_ownership_shields_embedded_components
        # A foreign component rendered inside widget's preview: its parts,
        # states, and vars belong to IT - widget's contract stays clean and
        # gains no undeclared findings from the guest.
        doc = CLEAN_DOC.sub("</div>\n</div>", <<~HTML)
          </div>
            <button data-component="guest" data-slot="guest" data-loading
                    style="--guest-pad: 1px"></button>
          </div>
        HTML

        assert_empty verify(docs: doc)
      end

      def test_infrastructure_attributes_are_not_state
        doc = CLEAN_DOC.sub("data-open",
                            'data-open data-controller="poetry--core--x" data-action="click->x#go" ' \
                            'data-poetry--core--x-target="panel" data-poetry--core--x-open-value="true" ' \
                            'data-poetry-collection-item data-turbo-permanent data-testid="panel"')

        assert_empty verify(docs: doc)
      end

      # -- the state.js sync gate -------------------------------------------

      def test_state_vocabulary_mirrors_state_js
        js = Poetry::Core.root.join("app/javascript/poetry/core/helpers/state.js").read
        vocabulary_block = js[/export const VOCABULARY = \{.*?\n\}/m]

        refute_nil vocabulary_block, "state.js VOCABULARY block not found - update the extraction"
        js_attributes = vocabulary_block.scan(/"(data-[a-z-]+)"/).flatten.uniq.sort

        assert_equal js_attributes, PartContract::STATE_VOCABULARY.sort,
                     "PartContract::STATE_VOCABULARY has drifted from helpers/state.js VOCABULARY"
      end
    end
  end
end
