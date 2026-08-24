# frozen_string_literal: true

module Poetry
  module Ui
    # Transient notifications.
    module Toast
      # The closed vocabulary for the variant axis.
      VARIANTS = %i[default success info warning destructive loading].freeze
      # The closed vocabulary for announcement politeness.
      POLITENESS = %i[polite assertive].freeze

      # One notification, rendered inside a Toaster region. The item
      # itself is role=status with aria-live off: it never announces
      # itself - on arrival the controller speaks it exactly once through
      # a shared live region at the variant's politeness (:destructive
      # announces assertively), so duplicating the announcement by hand
      # is a regression.
      #
      # The auto-dismiss timer pauses on hover, focus-within, window
      # blur, and hidden tabs; duration <= 0 means persistent - and an
      # action-bearing toast defaults to persistent (a missable undo is a
      # bug). Toasts never steal focus on show; the toaster's hotkey
      # (F8 by default) reaches them.
      #
      # @example An undo toast (persistent because it carries an action)
      #   render Poetry::Ui::Toast::Component.new(variant: :success) do |toast|
      #     toast.with_title { "Message archived" }
      #     toast.with_action { "Undo" }
      #   end
      class Component < Poetry::Core::Component
        # The icon each variant renders (:default ships none; :loading spins).
        VARIANT_ICONS = {
          success: :"circle-check", info: :info, warning: :"triangle-alert",
          destructive: :"octagon-x", loading: :"loader-circle"
        }.freeze

        # Projected into the registry, llms.txt, and the agent surface.
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

        # The same facts the before_render raise enforces, stated statically:
        # poetry check flags the omission without rendering.
        REQUIRED_SLOTS = { title: "the message" }.freeze

        # The component behind the forwarding slot: with_action renders a Button.
        SLOT_RENDERS = { action: Button::Component }.freeze

        slot_doc :title, "The message (REQUIRED - the announced payload's first line)."
        renders_one :title

        slot_doc :description, "Supporting copy under the title."
        renders_one :description

        slot_doc :action, "Typed Button slot (undo / view / retry): clicking it dismisses the toast with reason " \
                          "\"action\". Its presence makes the toast persistent by default."
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

        style :variant, default: :default, required: true, variants: VARIANTS,
                        doc: "The intent axis: it picks the icon, and :destructive announces assertively while " \
                             ":loading defaults to persistent."

        option :duration, :integer,
               doc: "nil = derived: 5000ms, or PERSISTENT when an action slot is present (the missable-undo guard). " \
                    "<= 0 = persistent."
        option :politeness, :symbol, default: -> { variant == :destructive ? :assertive : :polite },
                                     doc: "Derived from the variant: destructive announces assertively."
        option :show_close_button, :boolean, default: true,
                                             doc: "The corner dismiss button - named as the dialog family names it."

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

        # @api private
        def before_render
          raise ArgumentError, "Toast requires with_title (the message)" unless title?
        end

        # @api private
        def effective_duration
          return duration unless duration.nil?

          # Action-bearing toasts are persistent (a missable undo is a
          # bug); so are loading toasts - the promise recipe REPLACES
          # them (turbo_stream.replace on the toast id) when the job
          # settles, and an auto-dismissed loading state is a lie.
          action? || variant == :loading ? 0 : 5000
        end

        # @api private
        def variant_icon
          VARIANT_ICONS[variant]
        end

        # @api private
        def root_attributes
          html_attributes.merge_if_not_set(
            {
              "data-slot" => "toast", "data-variant" => variant, "data-open" => "",
              # aria-live=off ON PURPOSE: the announce singleton does the
              # talking, exactly once (an item that is itself a live
              # region would announce a second time).
              "role" => "status", "aria-live" => "off", "aria-atomic" => "true",
              "tabindex" => "0"
            }.merge(stimulus_attributes_for(:root)).merge(component_data_attributes)
          )
        end

        # @api private
        def close_button_attributes
          stimulus_attributes_for(:close).merge("data-slot" => "toast-close")
        end

        private :effective_duration, :variant_icon, :root_attributes, :close_button_attributes
      end
    end
  end
end
