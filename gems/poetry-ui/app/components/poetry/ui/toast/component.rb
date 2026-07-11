# frozen_string_literal: true

module Poetry
  module Ui
    module Toast
      # The controller identifier, declared ONCE (Builder-validated).
      TOAST = %i[poetry core toast].freeze
      VARIANTS = %i[default success info warning destructive].freeze
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

        # The sonner-slot icon set rides the variant (loader reserved for
        # a future promise API; default ships no icon).
        VARIANT_ICONS = {
          success: :"circle-check", info: :info, warning: :"triangle-alert", destructive: :"octagon-x"
        }.freeze

        style :variant, default: :default, required: true, variants: VARIANTS

        # nil = derived: 5000ms, or PERSISTENT when an action slot is
        # present (the missable-undo guard). <= 0 = persistent.
        option :duration, :integer
        # Derived from the variant: destructive announces assertively.
        option :politeness, :symbol, default: -> { variant == :destructive ? :assertive : :polite }
        option :closable, :boolean, default: true

        validates :politeness, inclusion: { in: POLITENESS }

        # The message (REQUIRED - the announced payload's first line).
        renders_one :title

        renders_one :description

        # Typed Button slot (undo / view / retry): clicking it dismisses
        # with reason "action" (the controller reads the origin slot).
        renders_one :action, lambda { |**options, &block|
          wiring = { "data-slot" => "toast-action" }.merge(action_stimulus_attributes)
          Button::Component.new(variant: :outline, size: :sm, **wiring, **options, &block)
        }

        # The same facts the before_render raise enforces, stated statically
        #: poetry check flags the omission without rendering (the
        # menu crash class - required slots the contract kept silent).
        REQUIRED_SLOTS = { title: "the message" }.freeze

        def before_render
          raise ArgumentError, "Toast requires with_title (the message)" unless title?
        end

        def effective_duration
          return duration unless duration.nil?

          action? ? 0 : 5000
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
            }.merge(toast_stimulus_attributes).merge(component_data_attributes)
          )
        end

        def close_button_attributes
          attrs = Poetry::Core::HTML::Attributes.new
          toast = Poetry::Core::Stimulus::Builder.new(TOAST, attrs)
          toast.with_target(:close)
          toast.with_action(:dismiss, on: :click)
          attrs.to_attributes.merge("data-slot" => "toast-close")
        end

        private

        # APG timing wiring: hover and focus-within hold the timer (the
        # window-blur / tab-hidden holds are wired by the controller).
        def toast_stimulus_attributes
          attrs = Poetry::Core::HTML::Attributes.new
          toast = Poetry::Core::Stimulus::Builder.new(TOAST, attrs)
          toast.register_controller
          toast.with_value(:duration, effective_duration)
          toast.with_value(:politeness, politeness)
          toast.with_action(:pause, on: %i[mouseenter focusin])
          toast.with_action(:resume, on: %i[mouseleave focusout])
          attrs.to_attributes
        end

        def action_stimulus_attributes
          attrs = Poetry::Core::HTML::Attributes.new
          toast = Poetry::Core::Stimulus::Builder.new(TOAST, attrs)
          toast.with_target(:action)
          toast.with_action(:dismiss, on: :click)
          attrs.to_attributes
        end
      end
    end
  end
end
