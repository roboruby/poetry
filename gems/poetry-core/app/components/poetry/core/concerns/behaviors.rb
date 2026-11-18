# frozen_string_literal: true

module Poetry
  module Core
    module Concerns
      # The behaviors a component uses ({Poetry::Core::Behavior}): recorded
      # at class load, folded through inheritance like tools and wiring,
      # and projected into the registry's `behaviors` section and the
      # component's agent rules.
      #
      # Two ways in. Inside a use_stimulus element, `behavior :name,
      # **options` adds the behavior's wiring to that element in
      # declaration order; at class level, `use_behavior :name` records a
      # runtime behavior, one the JS activates on its own, or adds a wired
      # one to an element with `on:`.
      module Behaviors
        extend ActiveSupport::Concern

        class_methods do
          # Uses a behavior on this component.
          #
          # @param name [Symbol, Module] the behavior's name or module
          # @param on [Symbol, nil] the element a wired behavior attaches
          #   to, appended after the element's declared controllers
          # @param options [Hash] the behavior's own options
          # @return [void]
          # @raise [Poetry::Core::Behavior::Error] for an unknown behavior,
          #   a wired behavior without on:, or a runtime one with it
          # @example
          #   use_behavior :dismissable
          def use_behavior(name, on: nil, **options)
            behavior = Poetry::Core::Behavior.resolve(name)
            element = on
            if element
              use_stimulus { on(element) { behavior(behavior, **options) } }
            elsif behavior.wiring
              raise Poetry::Core::Behavior::Error,
                    "#{self}: behavior #{behavior.behavior_name} adds wiring - pass on: the element it wires"
            else
              record_behavior_use(Poetry::Core::Behavior::Use.new(behavior: behavior, element: nil, options: options))
            end
          end

          # This class's own behavior uses, in declaration order.
          #
          # @return [Array<Poetry::Core::Behavior::Use>]
          def own_behavior_uses
            @own_behavior_uses ||= []
          end

          # The effective behavior uses after inheritance: ancestors first.
          # An inherited use on an element this class redeclares without
          # extend: true goes with the element's inherited wiring.
          #
          # @return [Array<Poetry::Core::Behavior::Use>]
          def behavior_uses
            inherited = superclass.respond_to?(:behavior_uses) ? superclass.behavior_uses : []
            replaced = own_stimulus_elements.reject { |_, element| element.extend_inherited }.keys
            inherited.reject { |use| use.element && replaced.include?(use.element) } + own_behavior_uses
          end

          # The registry-shaped projection: one entry per behavior, with the
          # elements it wires (plain string keys, YAML-safe).
          #
          # @return [Array<Hash>]
          def behavior_definitions
            behavior_uses.group_by(&:behavior).map do |behavior, uses|
              definition = { "name" => behavior.behavior_name.to_s, "description" => behavior.behavior_description }
              elements = uses.filter_map { |use| use.element&.to_s }.uniq
              definition["elements"] = elements if elements.any?
              definition["runtime"] = true if behavior.runtime?
              definition
            end
          end

          # The rules agents must follow with this component: each used
          # behavior's rules in use order, then the component's own
          # AGENT_RULES.
          #
          # @return [Array<String>]
          def agent_rules
            from_behaviors = behavior_uses.map(&:behavior).uniq.flat_map(&:agent_rules)
            own = const_defined?(:AGENT_RULES) ? self::AGENT_RULES : []
            (from_behaviors + own).uniq
          end

          # Records one use and runs the behavior's class-level
          # contributions on this class.
          #
          # @param use [Poetry::Core::Behavior::Use]
          # @return [void]
          # @api private
          def record_behavior_use(use)
            if own_behavior_uses.any? { |other| other.behavior == use.behavior && other.element == use.element }
              where = use.element ? " on #{use.element.inspect}" : ""
              raise Poetry::Core::Behavior::Error, "#{self}: behavior #{use.behavior.behavior_name} used twice#{where}"
            end

            own_behavior_uses << use
            use.behavior.contributes&.call(self, **use.options)
          end
        end
      end
    end
  end
end
