# frozen_string_literal: true

module Poetry
  module Ui
    module Toast
      VARIANTS = %i[default success info warning destructive loading].freeze
      POLITENESS = %i[polite assertive].freeze

      # One notification (Toast): poetry's OWN build -
      # the source ships the sonner library (a React dependency poetry
      # cannot take), so poetry keeps sonner's visual language (popover
      # token surface, the variant icon set) on Radix-Toast a11y
      # semantics. The item is role=status aria-live=OFF: it never
      # announces itself - on connect the poetry--core--toast controller
      # speaks ONCE through the announce singleton at the variant's
      # politeness (destructive -> assertive), the Radix duplication
      # insight (injecting a node that IS a live region mis-announces).
      #
      # Timing is APG/WCAG 2.2.1: the auto-dismiss timer pauses on hover,
      # focus-within, window blur and tab-hidden; duration <= 0 means
      # persistent - and an ACTION-BEARING toast defaults to persistent
      # (a missable undo is a bug). Toasts never steal focus on show; the
      # toaster's F8 hotkey reaches them. Swipe-to-dismiss is gated on
      # browser verification and does not ship in this pass (contract).
      class Component < Poetry::Core::Component
        AGENT_RULES = [
          "Server-side toasts go through turbo_stream.poetry_toast / the flash recipe - never " \
          "hand-append into #poetry-toaster.",
          "Undo/consequence toasts MUST carry an action slot - action-bearing toasts default to " \
          "persistent (duration nil); give an explicit duration only when missing the action is safe.",
          "variant: :destructive is for failures the user must hear about (it announces ASSERTIVELY); " \
          "do not use it for styling.",
          "Never put required interactions in a toast (toasts are missable) - that is AlertDialog.",
          "Toasts are supplementary: never the only place an outcome is recorded."
        ].freeze

        # The sonner-slot icon set rides the variant (default ships no
        # icon; loading spins - the promise-lifecycle opener).
        VARIANT_ICONS = {
          success: :"circle-check", info: :info, warning: :"triangle-alert",
          destructive: :"octagon-x", loading: :"loader-circle"
        }.freeze

        style :variant, default: :default, required: true, variants: VARIANTS

        # nil = derived: 5000ms, or PERSISTENT when an action slot is
        # present (the missable-undo guard). <= 0 = persistent.
        option :duration, :integer
        # Derived from the variant: destructive announces assertively.
        option :politeness, :symbol, default: -> { variant == :destructive ? :assertive : :polite }
        option :closable, :boolean, default: true

        validates :politeness, inclusion: { in: POLITENESS }

        part "toast", "The notification item itself (<li>, role=status) - variant, open state, " \
                      "and the toaster's stack facts all ride here",
             states: {
               "data-open" => "toast is showing (the server-rendered state; the dismiss exit " \
                              "flips the pair before removal)",
               "data-closed" => "toast is animating out",
               "data-variant" => { condition: "always - the resolved variant",
                                   values: VARIANTS.map(&:to_s) },
               "data-queued" => "the toaster holds it hidden past the visible limit " \
                                "(timer paused until a slot frees up)"
             },
             vars: {
               "--poetry-toast-index" => "stack position written by the toaster's reflow " \
                                         "(newest visible toast = 0)"
             }
        part "toast-icon", "The variant's icon well (aria-hidden; the default variant " \
                           "renders none)"
        part "toast-title", "The message - the announced payload's first line (required slot)"
        part "toast-description", "Supporting copy under the title"

        # APG timing wiring: hover and focus-within hold the timer (the
        # window-blur / tab-hidden holds are wired by the controller).
        use_stimulus do
          on :root do
            controller :toast do
              register
              value :duration, from: :effective_duration
              value :politeness
              action :pause, on: %i[mouseenter focusin]
              action :resume, on: %i[mouseleave focusout]
            end
          end
          on :action do
            controller :toast do
              target :action
              action :dismiss, on: :click
            end
          end
          on :close do
            controller :toast do
              target :close
              action :dismiss, on: :click
            end
          end
        end

        # The message (REQUIRED - the announced payload's first line).
        renders_one :title

        renders_one :description

        # Typed Button slot (undo / view / retry): clicking it dismisses
        # with reason "action" (the controller reads the origin slot).
        renders_one :action, lambda { |**options, &block|
          wiring = { "data-slot" => "toast-action" }.merge(stimulus_attributes_for(:action))
          # Caller attribute keys merge WITH the wiring (stimulus concat)
          # instead of replacing it at the kwargs splat; component options
          # (variant: etc.) stay plain kwargs.
          attr_keys = options.keys.select { |k| k == :data || k.to_s.start_with?("data-", "aria-") }
          caller_attrs = attr_keys.to_h { |k| [k, options.delete(k)] }
          merged = Poetry::Core::HTML::Attributes.merged(wiring, caller_attrs)
          Button::Component.new(variant: :outline, size: :sm, **merged.symbolize_keys, **options, &block)
        }

        # The same facts the before_render raise enforces, stated statically
        #: poetry check flags the omission without rendering (the
        # menu crash class - required slots the contract kept silent).
        REQUIRED_SLOTS = { title: "the message" }.freeze

        # The forwarding-lambda component fact: with_action renders a
        # Button - callers get Button's full typed-slot contract statically.
        SLOT_RENDERS = { action: Button::Component }.freeze

        def before_render
          raise ArgumentError, "Toast requires with_title (the message)" unless title?
        end

        def effective_duration
          return duration unless duration.nil?

          # Action-bearing toasts are persistent (a missable undo is a
          # bug); so are loading toasts - the promise recipe REPLACES
          # them (turbo_stream.replace on the toast id) when the job
          # settles, and an auto-dismissed loading state is a lie.
          action? || variant == :loading ? 0 : 5000
        end

        def variant_icon
          VARIANT_ICONS[variant]
        end

        def root_attributes
          html_attributes.merge_if_not_set(
            {
              "data-slot" => "toast", "data-variant" => variant, "data-open" => "",
              # aria-live=off ON PURPOSE: the announce singleton does the
              # talking, exactly once (items are duplicated-announcement
              # sources otherwise - the Radix insight).
              "role" => "status", "aria-live" => "off", "aria-atomic" => "true",
              "tabindex" => "0"
            }.merge(stimulus_attributes_for(:root)).merge(component_data_attributes)
          )
        end

        def close_button_attributes
          stimulus_attributes_for(:close).merge("data-slot" => "toast-close")
        end
      end
    end
  end
end
