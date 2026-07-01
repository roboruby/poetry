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
      # https://tailwindcss.com/docs/colors
      COLORS = %i[
        red
        orange
        amber
        yellow
        lime
        green
        emerald
        teal
        cyan
        sky
        blue
        indigo
        violet
        purple
        fuchsia
        pink
        rose
        slate
        gray
        zinc
        neutral
        stone
      ].freeze

      # https://tailwindcss.com/docs/fill
      FILLS = %i[
        none
        inherit
        current
        transparent
        black
        white
      ].freeze

      class << self
        # Each Style class owns a resolver; subclasses extend a copy of their
        # parent's dictionary.
        def resolver
          @resolver ||= superclass.respond_to?(:resolver) ? superclass.resolver.dup : CSS::Resolver.new
        end

        # -- The dictionary DSL (delegates to the resolver) --------------------

        def base(classes)
          resolver.base(classes)
        end

        def element(name, classes)
          resolver.element(name, classes)
        end

        def variant(attr, mapping)
          resolver.variant(attr, mapping)
        end

        def compound(criteria, classes)
          resolver.compound(criteria, classes)
        end

        # Single-source-of-defaults enforcement: defaults belong on the
        # component (`style :attr, default:`), never in the style dictionary.
        def defaults(*)
          raise Poetry::Core::Error,
                "#{name} declares defaults in the style dictionary - defaults live on the component " \
                "(`style :attr, default:`), the single source of truth"
        end

        # Resolves utility classes for the given criteria (and optional
        # element). The `class:` option appends caller classes, which win on
        # Tailwind conflicts.
        def css(element = nil, **options)
          extra = options.delete(:class)
          resolver.render(element, extra: extra, **options)
        end

        # { attr => [values] } - the declared variant space, for previews,
        # docs, and the registry.
        def variant_options
          resolver.variant_options
        end

        # The sibling component class by convention
        # (Poetry::Core::X::Style -> Poetry::Core::X::Component).
        def component_class
          module_parent.const_get(:Component, false)
        rescue NameError
          nil
        end

        # The BEM block this dictionary belongs to, derived from the sibling
        # component ("poetry/core/x" -> "poetry-core-x").
        def bem_block
          component_class&.component_path&.tr("/", "-")
        end

        # The capsule digest of this dictionary (the :bem leak-guard).
        def capsule
          resolver.digest
        end
      end

      # Instance-level mirror so `styler.css(...)` keeps working from the
      # Styles concern.
      def css(...)
        self.class.css(...)
      end
    end
  end
end
