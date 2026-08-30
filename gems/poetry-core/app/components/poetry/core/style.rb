# frozen_string_literal: true

module Poetry
  module Core
    # The sidecar style class for a component: the dictionary from the
    # component's style surface (declared with `style :attr, variants:` on the
    # component) to CSS utility classes, resolved through the in-tree
    # {CSS::Resolver}.
    #
    # @example
    #   class Badge::Style < Poetry::Core::Style
    #     base "inline-flex items-center rounded-md"
    #     element :icon, "size-3 shrink-0"
    #     variant :color, red: "bg-destructive/15 text-destructive",
    #                     gray: "bg-muted text-muted-foreground"
    #     compound({ color: :red, mode: :dark }, "bg-destructive/25")
    #   end
    #
    # Defaults are NOT declared here - they live in exactly one place, the
    # component's `style :attr, default:` (the single source of truth; the
    # component's ActiveModel attributes resolve them before render). A
    # `defaults` call raises to enforce that.
    class Style
      class << self
        # Each Style class owns a resolver; subclasses extend a copy of their
        # parent's dictionary.
        #
        # @return [CSS::Resolver]
        def resolver
          @resolver ||= superclass.respond_to?(:resolver) ? superclass.resolver.dup : CSS::Resolver.new
        end

        # -- The dictionary DSL (delegates to the resolver) --------------------

        # Declares the root element's always-present utility classes - the
        # dictionary's base layer, emitted before any variant classes.
        #
        # @param classes [String] space-separated utility classes
        # @example
        #   base "inline-flex items-center rounded-md"
        # @return [void]
        def base(classes)
          resolver.base(classes)
        end

        # Declares the classes of a named inner element of the component's
        # anatomy, resolved with `css(:name)` at render.
        #
        # @param name [Symbol] the element name (:icon, :label, ...)
        # @param classes [String] space-separated utility classes
        # @example
        #   element :icon, "size-3 shrink-0"
        # @return [void]
        def element(name, classes)
          resolver.element(name, classes)
        end

        # Declares one style axis: the classes each value of the component's
        # matching `style :attr` declaration resolves to.
        #
        # @param attr [Symbol] the style attribute this axis resolves
        # @param mapping [Hash{Symbol => String}] variant value => utility classes
        # @example
        #   variant :color, red: "bg-destructive/15 text-destructive",
        #                   gray: "bg-muted text-muted-foreground"
        # @return [void]
        def variant(attr, mapping)
          resolver.variant(attr, mapping)
        end

        # Declares classes emitted only when EVERY criteria pair matches the
        # resolved style values - the cross-axis refinement a single
        # variant cannot express.
        #
        # @param criteria [Hash{Symbol => Object}] style attribute => value pairs
        # @param classes [String] utility classes added on a full match
        # @example
        #   compound({ color: :red, mode: :dark }, "bg-destructive/25")
        # @return [void]
        def compound(criteria, classes)
          resolver.compound(criteria, classes)
        end

        # Single-source-of-defaults enforcement: defaults belong on the
        # component (`style :attr, default:`), never in the style dictionary.
        #
        # @return [void]
        # @raise [Poetry::Core::Error] always
        def defaults(*)
          raise Poetry::Core::Error,
                "#{name} declares defaults in the style dictionary - defaults live on the component " \
                "(`style :attr, default:`), the single source of truth"
        end

        # Resolves utility classes for the given criteria (and optional
        # element). The `class:` option appends caller classes, which win on
        # Tailwind conflicts.
        #
        # @param element [Symbol, nil] a declared element name, or nil for the root
        # @param options [Hash] style attribute => value criteria, plus `class:`
        # @return [String] the resolved utility classes
        def css(element = nil, **options)
          extra = options.delete(:class)
          resolver.render(element, extra: extra, **options)
        end

        # { attr => [values] } - the declared variant space, for previews,
        # docs, and the registry.
        #
        # @return [Hash{Symbol => Array<Symbol>}]
        def variant_options
          resolver.variant_options
        end

        # The sibling component class by convention
        # (Poetry::Core::X::Style -> Poetry::Core::X::Component).
        #
        # @return [Class, nil]
        def component_class
          module_parent.const_get(:Component, false)
        rescue NameError
          nil
        end

        # The BEM block this dictionary belongs to, derived from the sibling
        # component ("poetry/core/x" -> "poetry-core-x").
        #
        # @return [String, nil]
        def bem_block
          component_class&.component_path&.tr("/", "-")
        end

        # The capsule digest of this dictionary (the :bem leak-guard).
        #
        # @return [String]
        def capsule
          resolver.digest
        end
      end

      # Instance-level mirror so `styler.css(...)` keeps working from the
      # Styles concern.
      #
      # @return [String] the resolved utility classes (see {.css})
      def css(...)
        self.class.css(...)
      end
    end
  end
end
