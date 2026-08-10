# frozen_string_literal: true

require "test_helper"

module Poetry
  module Core
    class StimulusContractTest < Minitest::Test
      # Real manifest controllers so identifier resolution and token
      # formats are live: accordion (value type, action toggle) and
      # action-bar (target count, action keydown - here with at: :window).
      module Probe
        class Component < Poetry::Core::Component
          use_stimulus do
            on :root do
              controller :accordion do
                register
                value :type
                action :toggle, on: :click
              end
            end
            on :bar do
              controller :action_bar do
                register
                target :count
                action :keydown, on: :keydown, at: :window
              end
            end
          end

          def self.component_title = "contract-probe"

          def call
            tag.div("probe", **stimulus_attributes_for(:root))
          end
        end
      end

      CLEAN_DOC = <<~HTML
        <div data-component="contract-probe" data-controller="poetry--core--accordion"
             data-poetry--core--accordion-type-value="single"
             data-action="click->poetry--core--accordion#toggle">
          <span data-controller="poetry--core--action-bar"
                data-poetry--core--action-bar-target="count"
                data-action="keydown@window->poetry--core--action-bar#keydown"></span>
        </div>
      HTML

      def verify(docs)
        StimulusContract.verify(component: Probe::Component, docs: Array(docs))
      end

      def test_matching_wiring_verifies_clean
        assert_empty verify(CLEAN_DOC)
      end

      def test_undeclared_action_is_found_with_a_paste_ready_suggestion
        doc = CLEAN_DOC.sub("click->poetry--core--accordion#toggle",
                            "click->poetry--core--accordion#toggle click->poetry--core--accordion#connect")
        findings = verify(doc)

        assert_equal ["undeclared-action"], findings.map(&:rule)
        assert_equal "action :connect, on: :click", findings.first.suggestion
      end

      def test_at_window_actions_round_trip
        doc = CLEAN_DOC.sub("keydown@window->poetry--core--action-bar#keydown",
                            "keydown@window->poetry--core--action-bar#keydown " \
                            "keydown@window->poetry--core--action-bar#clear")
        findings = verify(doc)

        assert_equal ["undeclared-action"], findings.map(&:rule)
        assert_equal "action :clear, on: :keydown, at: :window", findings.first.suggestion
      end

      def test_phantom_action_when_no_preview_renders_it
        doc = CLEAN_DOC.sub("data-action=\"click->poetry--core--accordion#toggle\"", "")
        findings = verify(doc)

        assert_equal ["phantom-action"], findings.map(&:rule)
        assert_match(/dead wiring or missing preview coverage/, findings.first.message)
      end

      def test_undeclared_and_phantom_values_by_key
        swapped = CLEAN_DOC.sub("data-poetry--core--accordion-type-value",
                                "data-poetry--core--accordion-collapsible-value")
        findings = verify(swapped)

        assert_equal %w[phantom-value undeclared-value], findings.map(&:rule).sort
        undeclared = findings.find { |f| f.rule == "undeclared-value" }

        assert_equal "value :collapsible", undeclared.suggestion
      end

      def test_undeclared_target_is_found
        doc = CLEAN_DOC.sub('data-poetry--core--action-bar-target="count"',
                            'data-poetry--core--action-bar-target="count all"')
        findings = verify(doc)

        assert_equal ["undeclared-target"], findings.map(&:rule)
        assert_equal "target :all", findings.first.suggestion
      end

      def test_phantom_controller_when_registration_never_renders
        doc = CLEAN_DOC.sub('data-controller="poetry--core--action-bar"', "")
        rules = verify(doc).map(&:rule)

        assert_includes rules, "phantom-controller"
      end

      def test_foreign_wiring_on_owned_nodes_is_found
        doc = CLEAN_DOC.sub("<span", '<span data-poetry--core--dialog-target="dialog"')
        findings = verify(doc)

        assert_equal ["foreign-wiring"], findings.map(&:rule)
        assert_match(/poetry--core--dialog/, findings.first.message)
      end

      def test_foreign_wiring_outside_owned_subtrees_is_ignored
        doc = "#{CLEAN_DOC}<div data-controller=\"poetry--core--dialog\"></div>"

        assert_empty verify(doc)
      end

      def test_components_without_declarations_are_skipped
        bare = Class.new(Poetry::Core::Component)

        assert_empty StimulusContract.verify(component: bare, docs: [CLEAN_DOC])
      end
    end
  end
end
