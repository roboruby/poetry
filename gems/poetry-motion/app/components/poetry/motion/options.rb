# frozen_string_literal: true

module Poetry
  module Motion
    # The motion options an effect declares, each validated against the
    # motion tokens: an effect calls `motion_options` with the options it
    # takes and their defaults, and every effect also gets `animate:` to
    # turn its motion off.
    #
    #   motion_options spring: :gentle, trigger: :in_view, delay: 0
    #
    # The values reach the effect's controller as Stimulus values, and the
    # motion policy reads the tokens they name.
    module Options
      extend ActiveSupport::Concern

      included do
        # The motion options this effect declared.
        class_attribute :motion_option_names, instance_accessor: false, default: [].freeze
      end

      # The duration tokens (--motion-duration-*); duration: also takes milliseconds.
      DURATIONS = %i[fast normal slow].freeze
      # The easing tokens (--motion-ease-*).
      EASINGS = %i[standard emphasized exit].freeze
      # The spring tokens (--motion-spring-*).
      SPRINGS = %i[gentle snappy bouncy].freeze
      # When an effect starts: on connect, when it scrolls into view, or on hover.
      TRIGGERS = %i[load in_view hover].freeze

      # What each option means, for the registry and the docs.
      DOCS = {
        duration: "How long the motion runs: a duration token (#{DURATIONS.join(", ")}) or milliseconds.",
        easing: "The easing token: #{EASINGS.join(", ")}.",
        spring: "The spring token: #{SPRINGS.join(", ")}.",
        trigger: "When the motion starts: #{TRIGGERS.join(", ")}.",
        delay: "Milliseconds to wait before the motion starts.",
        once: "Plays the motion the first time only, when the trigger can fire again."
      }.freeze

      class_methods do
        # Declares `animate:` and the motion options given, with their
        # defaults.
        #
        # @param triggers [Array<Symbol>, nil] the triggers this effect supports, when not all of {TRIGGERS}
        # @param defaults [Hash{Symbol => Object}] option name => default
        # @return [void]
        # @raise [ArgumentError] for an option poetry-motion does not define
        def motion_options(triggers: TRIGGERS, **defaults)
          unknown = defaults.keys - DOCS.keys
          raise ArgumentError, "#{self}: unknown motion option(s) #{unknown.join(", ")}" if unknown.any?

          option :animate, :boolean, default: true,
                                     doc: "Turns the motion off; the effect renders its finished state either way."
          defaults.each { |name, default| motion_option(name, default, triggers) }
          self.motion_option_names = defaults.keys.freeze
        end

        private

        # One motion option with its type and validation.
        # @api private
        def motion_option(name, default, triggers)
          case name
          when :duration
            option :duration, ActiveModel::Type::Value.new, default: default, doc: DOCS[:duration]
          when :easing, :spring
            option name, :symbol, default: default, doc: DOCS[name]
            validates name, inclusion: { in: Options.const_get("#{name.to_s.upcase}S") }
          when :trigger
            option :trigger, :symbol, default: default, doc: "When the motion starts: #{triggers.join(", ")}."
            validates :trigger, inclusion: { in: triggers }
          when :delay
            option :delay, :integer, default: default, doc: DOCS[:delay]
          when :once
            option :once, :boolean, default: default, doc: DOCS[:once]
          end
        end
      end

      # Raises for a motion option out of range: a duration that is neither a
      # token nor milliseconds, or a negative delay. Effects call it from
      # before_render.
      #
      # @return [void]
      # @raise [ArgumentError]
      def ensure_motion_options!
        names = self.class.motion_option_names
        if names.include?(:duration) &&
           !(DURATIONS.include?(duration.to_s.to_sym) || duration.to_s.match?(/\A[1-9]\d*\z/))
          raise ArgumentError, "#{self.class.component_title} duration: #{duration.inspect} is not " \
                               "#{DURATIONS.join(", ")} or milliseconds"
        end
        return unless names.include?(:delay) && delay.to_i.negative?

        raise ArgumentError, "#{self.class.component_title} delay: must be zero or more milliseconds"
      end

      # Raises unless the numeric option is within the range.
      #
      # @param name [Symbol] the option
      # @param range [Range] the values it may take
      # @return [void]
      # @raise [ArgumentError]
      def ensure_within!(name, range)
        value = public_send(name)
        return if range.cover?(value)

        raise ArgumentError, "#{self.class.component_title} #{name}: #{value.inspect} is outside #{range}"
      end
    end
  end
end
