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

        # The pinned mode a component class inherits: the pin of the
        # root-most pinned ancestor below Poetry::Core::Component, the class
        # itself included. The dictionary a subclass inherits was written by
        # the kit that originated it, so that kit's mode wins: a host
        # `Acme::Badge2 < Poetry::Ui::Badge::Component` stays Tailwind under
        # an `Acme` BEM pin, while a host `Acme::Pill < Poetry::Core::Component`
        # takes the pin. A declaration (`css_mode :bem`) beats every pin.
        #
        # @param klass [Class] a component class (named)
        # @return [Symbol, nil]
        def inherited_for(klass)
          chain = klass.ancestors.grep(Class)
                       .take_while { |ancestor| ancestor != Poetry::Core::Component }
          chain.reverse_each do |ancestor|
            mode = self.for(ancestor)
            return mode if mode
          end
          nil
        end

        # @return [Hash{String => Symbol}] namespace => mode
        def pins
          @pins ||= {}
        end

        # The class-name merger a component in `mode` merges with. Each mode
        # has a merger kind: `:bem` merges with a {BemMerger} (token dedupe,
        # no utility conflict semantics), `:tailwind` with a
        # {TailwindMerger}. The global `Config.current.classname_merger` is
        # honoured whenever it is of the right kind - a host's customised
        # Tailwind merger still serves poetry-ui and every Tailwind kit, a
        # host's BEM merger still serves its BEM kit - and a mismatch falls
        # back to the stock merger of the mode, so a global set for one kit
        # never reaches a kit of the other kind.
        #
        # @param mode [Symbol] :tailwind or :bem
        # @return [#merge]
        def merger_for(mode)
          global = Poetry::Core::Config.current.classname_merger
          global_is_bem = global.is_a?(Poetry::Core::CSS::BemMerger)
          if validate!(mode) == :bem
            global_is_bem ? global : stock_merger(:bem)
          else
            global_is_bem ? stock_merger(:tailwind) : global
          end
        end

        # The stock merger of a mode, built once (a Tailwind merger carries
        # a cache and a mutex).
        #
        # @param mode [Symbol]
        # @return [#merge]
        def stock_merger(mode)
          @stock_mergers ||= {}
          @stock_mergers[mode] ||= mode == :bem ? Poetry::Core::CSS::BemMerger.new : Poetry::Core::CSS::TailwindMerger.new
        end

        # @param mode [Symbol, String]
        # @return [Symbol]
        # @raise [Poetry::Core::Error] for anything but :tailwind or :bem
        def validate!(mode)
          mode = mode.to_sym
          return mode if MODES.include?(mode)

          raise Poetry::Core::Error, "unknown css_mode #{mode.inspect} (expected :tailwind or :bem)"
        end

        private_class_method :stock_merger
      end
    end
  end
end
