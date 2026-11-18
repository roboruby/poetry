# frozen_string_literal: true

module Poetry
  module Core
    # The declaration side of a Poetry behavior: a named, reusable piece of
    # a component's client behavior (arrow-key focus movement, dismissal on
    # Escape and outside press) that several components share. A behavior
    # module extends this and declares its name, a one-line description,
    # the rules agents must follow where it is used, and the wiring it
    # adds to the element that uses it:
    #
    #   module Poetry::Core::Behaviors::RovingFocus
    #     extend Poetry::Core::Behavior
    #
    #     behavior :roving_focus, "Arrow keys move focus across the items."
    #
    #     wiring do |orientation: nil, loop: nil|
    #       controller :roving_focus do
    #         register
    #         behavior_value :orientation, orientation
    #         behavior_value :loop, loop
    #         action :keydown, on: :keydown
    #       end
    #     end
    #   end
    #
    # A component uses it inside an element of its use_stimulus block,
    # where it lands in declaration order beside the element's own
    # controllers, or at class level with use_behavior:
    #
    #   use_stimulus do
    #     on(:list) { behavior :roving_focus, orientation: :option, loop: true }
    #   end
    #   use_behavior :dismissable
    #
    # A runtime behavior (`runtime: true`) is one the JavaScript activates
    # on its own, the overlay layers added when a popup opens. It declares
    # no wiring: it is named, described and ruled, and the JS suite proves
    # it, since no preview renders it.
    #
    # Poetry behaviors are Ruby declarations over Stimulus controllers and
    # the JS behaviors under poetry/core/behaviors. They are not Herb's
    # client behaviors, which follow elements the client adds and removes.
    module Behavior
      # Raised at class load for an invalid behavior declaration or use.
      class Error < Poetry::Core::Error; end

      # One use of a behavior: the module, the element it wires (nil for
      # a runtime behavior) and the caller's options.
      Use = Struct.new(:behavior, :element, :options, keyword_init: true)

      # The behavior name grammar: snake_case.
      NAME_PATTERN = /\A[a-z][a-z0-9_]*\z/
      # The agent-legibility budget for a behavior's description.
      DESCRIPTION_LIMIT = 200

      # The namespaces a behavior name resolves in, one per gem that ships
      # behaviors. A gem adds its own at load (`Behavior.namespaces <<
      # "Poetry::Motion::Behaviors"`); a name two namespaces define is an
      # error, so cross-gem names never shadow each other.
      #
      # @return [Array<String>]
      def self.namespaces
        @namespaces ||= ["Poetry::Core::Behaviors"]
      end

      # The behavior module for a name, or the module itself.
      #
      # @param name [Symbol, String, Module] a behavior name or module
      # @return [Module] a module extended with {Behavior}
      # @raise [Error] when no namespace or several define the name
      def self.resolve(name)
        return validate_module!(name) if name.is_a?(Module)

        found = namespaces.filter_map { |namespace| "#{namespace}::#{name.to_s.camelize}".safe_constantize }.uniq
        raise Error, "unknown behavior #{name.inspect} (looked in #{namespaces.join(", ")})" if found.empty?
        raise Error, "behavior #{name.inspect} is ambiguous (#{found.join(", ")}) - pass the module" if found.size > 1

        validate_module!(found.first)
      end

      # The module back, when it is a declared behavior.
      # @api private
      def self.validate_module!(behavior)
        return behavior if behavior.singleton_class.include?(Behavior) && behavior.behavior_name

        raise Error, "#{behavior} is not a Poetry behavior (extend Poetry::Core::Behavior and declare `behavior`)"
      end
      private_class_method :validate_module!

      # Names the behavior and describes it in one line.
      #
      # @param name [Symbol] snake_case; components use the behavior by it
      # @param description [String] what the behavior does, for the
      #   registry, llms.txt and the docs
      # @param runtime [Boolean] true when the JS activates the behavior on
      #   its own, so it declares no wiring
      # @return [void]
      # @raise [Error] for an invalid name or description
      def behavior(name, description, runtime: false)
        text = name.to_s
        raise Error, "#{self}: invalid behavior name #{name.inspect} - snake_case" unless NAME_PATTERN.match?(text)

        summary = description.to_s.strip
        if summary.empty? || summary.length > DESCRIPTION_LIMIT
          raise Error, "#{self}: behavior description must be present and at most #{DESCRIPTION_LIMIT} characters"
        end

        @behavior_name = text.to_sym
        @behavior_description = summary
        @behavior_runtime = runtime ? true : false
      end

      # The declared name.
      # @return [Symbol, nil]
      attr_reader :behavior_name

      # The declared description.
      # @return [String, nil]
      attr_reader :behavior_description

      # Whether the JS activates this behavior on its own.
      #
      # @return [Boolean]
      def runtime?
        @behavior_runtime ? true : false
      end

      # Adds a rule agents must follow wherever the behavior is used. Rules
      # project into every using component's agent rules, ahead of the
      # component's own, in the order the component uses its behaviors.
      #
      # @param rule [String]
      # @return [void]
      def agent_rule(rule)
        text = rule.to_s.strip
        raise Error, "#{self}: agent_rule must be present" if text.empty?

        agent_rules << text
      end

      # The declared agent rules, in order.
      # @return [Array<String>]
      def agent_rules
        @agent_rules ||= []
      end

      # The wiring the behavior adds to the element that uses it, as a
      # block evaluated in that element's use_stimulus context (controller,
      # event, and the behavior_value helper) with the caller's options as
      # keywords. Runtime behaviors declare none.
      #
      # @yield [**options] the element DSL block
      # @return [Proc, nil] the declared block when called without one
      def wiring(&block)
        return @wiring unless block
        raise Error, "#{self}: a runtime behavior declares no wiring" if runtime?

        @wiring = block
      end

      # Class-level additions the behavior makes to every component that
      # uses it (parts, options, methods), run once per using class.
      #
      # @yield [base, **options] the using class and the caller's options
      # @return [Proc, nil] the declared block when called without one
      def contributes(&block)
        return @contributes unless block

        @contributes = block
      end
    end
  end
end
