# frozen_string_literal: true

module Poetry
  module Core
    module CSS
      # The CSS mode a component renders in (`:tailwind` resolves the Style
      # dictionary to utilities; `:bem` emits the block/modifier token IR
      # for a kit that brings its own CSS), decided per kit. Resolution,
      # innermost first: a `css_mode:` keyword on the `css` call; the mode
      # the component class declares (`css_mode :bem`, inherited); the mode
      # pinned for its namespace here; the global
      # `Poetry::Core::Config.current.css_mode`. poetry-ui and poetry-charts
      # pin their namespaces to `:tailwind` at load, so a host's global -
      # set for a kit of its own on the DSL - never reaches them, and a
      # Tailwind-native kit and a BEM kit render side by side.
      #
      # A module-level registry, not config: tests replace the config
      # object freely, and a pin must survive that.
      #
      # @example A kit pins its namespace once
      #   Poetry::Core::CSS::Modes.pin("Acme::Ui", :bem)
      #
      # @api private
      module Modes
        MODES = %i[tailwind bem].freeze

        module_function

        # Pins every component under a namespace to a mode. The longest
        # matching namespace wins, so a nested kit can differ from its parent.
        #
        # @param namespace [String, Module] the constant prefix ("Acme::Ui")
        # @param mode [Symbol] :tailwind or :bem
        # @return [Symbol] the mode
        def pin(namespace, mode)
          pins[namespace.to_s] = validate!(mode)
        end

        # Removes a pin (tests).
        #
        # @param namespace [String, Module]
        # @return [Symbol, nil] the mode that was pinned
        def unpin(namespace)
          pins.delete(namespace.to_s)
        end

        # The pinned mode for a component class, or nil when no namespace
        # covers it.
        #
        # @param klass [Class] a component class (named)
        # @return [Symbol, nil]
        def for(klass)
          name = klass.name.to_s
          namespace = pins.keys.select { |prefix| name == prefix || name.start_with?("#{prefix}::") }.max_by(&:length)
          namespace && pins[namespace]
        end

        # @return [Hash{String => Symbol}] namespace => mode
        def pins
          @pins ||= {}
        end

        # @param mode [Symbol, String]
        # @return [Symbol]
        # @raise [Poetry::Core::Error] for anything but :tailwind or :bem
        def validate!(mode)
          mode = mode.to_sym
          return mode if MODES.include?(mode)

          raise Poetry::Core::Error, "unknown css_mode #{mode.inspect} (expected :tailwind or :bem)"
        end
      end
    end
  end
end
