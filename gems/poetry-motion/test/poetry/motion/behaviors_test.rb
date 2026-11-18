# frozen_string_literal: true

require "test_helper"

module Poetry
  module Motion
    # The Ruby side of the ten JS behaviors: each resolves by name from
    # poetry-motion's namespace, is a runtime behavior (an effect's
    # controller runs it), and projects into a using component's registry
    # entry and agent rules.
    class BehaviorsTest < ActiveSupport::TestCase
      NAMES = %i[animate spring stagger scroll_value pointer frame layout drag gesture canvas].freeze
      JS = Poetry::Motion.root.join("app/javascript/poetry/motion/behaviors")

      class EffectComponent < Poetry::Core::Component
        AGENT_RULES = ["The effect's own rule."].freeze

        use_behavior :animate
        use_behavior :pointer
        use_behavior :spring

        def call = tag.div("effect")
      end

      def test_each_resolves_from_the_motion_namespace_as_a_runtime_behavior
        NAMES.each do |name|
          behavior = Poetry::Core::Behavior.resolve(name)

          assert_equal "Poetry::Motion::Behaviors::#{name.to_s.camelize}", behavior.name
          assert_predicate behavior, :runtime?, name
          assert_nil behavior.wiring, name
        end
      end

      def test_each_has_its_js_behavior_and_nothing_else_does
        assert_equal NAMES.map(&:to_s).sort, JS.glob("*.js").map { |file| file.basename(".js").to_s }.sort
        NAMES.each do |name|
          export = "use#{name.to_s.camelize}"

          assert_includes JS.join("#{name}.js").read, "export function #{export}(", name
        end
      end

      def test_a_component_lists_its_behaviors_and_leads_with_their_rules
        definitions = EffectComponent.behavior_definitions

        assert_equal(%w[animate pointer spring], definitions.map { |definition| definition["name"] })
        assert(definitions.all? { |definition| definition["runtime"] })

        rules = EffectComponent.agent_rules

        assert_match(/decoration/, rules.first)
        assert_equal "The effect's own rule.", rules.last
        assert_includes rules, Poetry::Motion::Behaviors::Pointer.agent_rules.first
      end
    end
  end
end
