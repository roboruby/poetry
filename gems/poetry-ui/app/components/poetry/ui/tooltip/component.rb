# frozen_string_literal: true

module Poetry
  module Ui
    module Tooltip
      # The controller identifiers, declared ONCE - every data attribute
      # derives from them through the Stimulus Builder, validated against
      # the controllers manifest (no hand-written wiring strings).
      TOOLTIP = %i[poetry core tooltip].freeze
      POPPER = %i[poetry core popper].freeze
      SIDES = %i[top right bottom left].freeze
      ALIGNS = %i[start center end].freeze

      # The popper-consumer trio's timing machine ([[CL Component -
      # Tooltip]]): the hover/focus text hint that must never receive
      # focus. Two hosts, one owned controller: the root carries
      # poetry--core--tooltip (delay timers, the provider-scoped warm
      # grace, one-open-globally, close-on-scroll, open-only
      # aria-describedby) + poetry--core--popper (anchored positioning,
      # first consumer of the ARROW target). The content's dismissable
      # layer is TOKEN-ACTIVATED while open (Esc peels the tooltip first,
      # topmost-only); focus-scope is NOT composed at all - focus never
      # enters a tooltip, the defining trio contrast.
      #
      # A11y is the strictest of the trio: content is role=tooltip and the
      # trigger's aria-describedby exists WHILE OPEN ONLY (a describedby to
      # hidden content mis-announces); no aria-haspopup/expanded (a tooltip
      # is a description, not a popup the user operates); touch never opens
      # one (no long-press path, Radix-exact).
      class Component < Poetry::Core::Component
        AGENT_RULES = [
          "Use poetry_tooltip - never hand-roll title-attribute replacements or hover divs.",
          "Tooltip content is TEXT and never interactive/focusable - links, buttons, or inputs inside " \
          "are a contract violation (use Popover).",
          "Never put essential information only in a tooltip - touch users NEVER see it (no long-press " \
          "path, by design).",
          "The tooltip DESCRIBES; it never names. Icon-only triggers still require label: on the " \
          "composed Button.",
          "Wrap toolbar/button rows in ONE poetry_tooltip_provider so the warm grace makes the row " \
          "feel continuous.",
          "Rich visual content needs label: (the plain-text announcement).",
          "Do not pin tooltips open as onboarding callouts - that is a Popover."
        ].freeze

        option :open, :boolean, default: false
        # nil = inherit the provider's data-delay-duration (default 0 -
        # shadcn's provider override of Radix's 700, kept source-exact).
        option :delay_duration, :integer
        # nil = inherit the provider (the controller checks attribute
        # PRESENCE, so an unset value must render no attribute at all).
        option :disable_hoverable_content, :boolean
        option :side, :symbol, default: :top # Radix Tooltip default - the trio's odd one out
        option :align, :symbol, default: :center
        option :side_offset, :integer, default: 0 # shadcn Content default (the arrow supplies the gap)
        # Plain-text announcement override for rich content (the visual
        # children stay; the announced body becomes this text).
        option :label, :string
        # The bubble's class merge seam (caller classes win on conflicts).
        option :content_class, :string

        validates :side, inclusion: { in: SIDES }
        validates :align, inclusion: { in: ALIGNS }

        part "tooltip", "Root wrapper around the trigger and the bubble"
        part "tooltip-content", "The role=tooltip bubble - positioning, animation, and the open " \
                                "state ride here",
             states: {
               "data-open" => "bubble is open (the controller flips the pair at runtime)",
               "data-closed" => "bubble is closed (the server-rendered state; hidden rides along)",
               "data-instant" => { condition: "the open skipped the delay - warm-grace/" \
                                              "programmatic or keyboard focus (runtime-only; " \
                                              "absent on a delayed open)",
                                   values: %w[delay focus] },
               "data-side" => { condition: "always - the side (initial placement, re-resolved " \
                                           "live by popper after flip)",
                                values: SIDES.map(&:to_s) },
               "data-align" => { condition: "always - the alignment (re-resolved live by popper)",
                                 values: ALIGNS.map(&:to_s) }
             },
             vars: {
               "--transform-origin" => "the anchor-facing origin popper writes for scale-in " \
                                       "animation",
               "--available-width" => "viewport space left for the bubble (popper, post-flip)",
               "--available-height" => "viewport space left for the bubble (popper, post-flip)",
               "--anchor-width" => "the anchor's measured width (popper)",
               "--anchor-height" => "the anchor's measured height (popper)"
             }
        part "tooltip-arrow", "The arrow wrapper (aria-hidden) - popper pins it to the bubble's " \
                              "anchor-facing edge and rotates it toward the anchor",
             states: {
               "data-side" => { condition: "written by popper alongside the content's - the " \
                                           "resolved side, for per-side restyling",
                                values: SIDES.map(&:to_s) }
             }

        # The described control - commonly a poetry Button (demo parity:
        # with_trigger(variant: :outline) { "Hover" }). The slot owns the
        # state + timing wiring regardless of the composed content.
        # NO aria-haspopup/expanded/controls - the tooltip is invisible as
        # a popup; aria-describedby is written by the controller on open
        # (and server-rendered only when open: true).
        renders_one :trigger, lambda { |**options, &block|
          wiring = {
            "id" => trigger_id, "data-slot" => "tooltip-trigger"
          }.merge(trigger_stimulus_attributes)
          # Base UI trigger state: bare data-popup-open while open, NO
          # attribute while closed (absence IS the state).
          wiring["data-popup-open"] = "" if open
          wiring["aria-describedby"] = content_id if open
          Button::Component.new(**wiring, **options, &block)
        }

        # The same facts the before_render raise enforces, stated statically
        #: poetry check flags the omission without rendering (the
        # menu crash class - required slots the contract kept silent).
        REQUIRED_SLOTS = { trigger: "the described control" }.freeze

        # The forwarding-lambda component fact: with_trigger renders a
        # Button - callers get Button's full typed-slot contract statically.
        SLOT_RENDERS = { trigger: Button::Component }.freeze

        def before_render
          raise ArgumentError, "Tooltip requires with_trigger (the described control)" unless trigger?
        end

        def trigger_id
          "#{instance_id}-trigger"
        end

        # The controller resolves content by the id pair ("-trigger" ->
        # "-content"), portal-safe - no Stimulus target.
        def content_id
          "#{instance_id}-content"
        end

        def root_attributes
          html_attributes.merge_if_not_set(
            { "data-slot" => "tooltip" }
              .merge(root_stimulus_attributes)
              .merge(component_data_attributes)
          )
        end

        def content_attributes
          # The Radix triple (closed | delayed-open | instant-open) is now
          # the Base UI pair: a server-pinned open tooltip renders bare
          # data-open (the controller adds data-instant on ITS opens - the
          # reason attribute is runtime-only).
          attrs = {
            "id" => content_id, "role" => "tooltip",
            "data-slot" => "tooltip-content", (open ? "data-open" : "data-closed") => "",
            # Initial placement, re-resolved live by popper on open.
            "data-side" => side, "data-align" => align,
            "class" => css(:content, class: content_class)
          }.merge(popper_stimulus { |popper| popper.with_target(:content) })
          attrs["hidden"] = true unless open
          attrs
        end

        private

        def instance_id
          @instance_id ||= "poetry-tooltip-#{SecureRandom.hex(4)}"
        end

        # BOTH controllers build into ONE Attributes instance (the
        # Accordion lesson). The inherit-from-provider values render NO
        # attribute when unset - the controller falls back to the
        # [data-slot=tooltip-provider] ancestor's config.
        def root_stimulus_attributes
          attrs = Poetry::Core::HTML::Attributes.new
          tooltip = Poetry::Core::Stimulus::Builder.new(TOOLTIP, attrs)
          tooltip.register_controller
          tooltip.with_value(:open, open)
          tooltip.with_value(:delay_duration, delay_duration) unless delay_duration.nil?
          unless disable_hoverable_content.nil?
            tooltip.with_value(:disable_hoverable_content, disable_hoverable_content)
          end
          popper = Poetry::Core::Stimulus::Builder.new(POPPER, attrs)
          popper.register_controller
          popper.with_value(:side, side)
          popper.with_value(:align, align)
          popper.with_value(:side_offset, side_offset)
          attrs.to_attributes
        end

        # The Radix trigger handlers, ported: pointermove opens (touch
        # excluded, once per hover), pointerdown/click close (activation
        # dismisses the hint), focus opens instantly / blur closes.
        def trigger_stimulus_attributes
          attrs = Poetry::Core::HTML::Attributes.new
          tooltip = Poetry::Core::Stimulus::Builder.new(TOOLTIP, attrs)
          tooltip.with_action(:pointer_move, on: :pointermove)
          tooltip.with_action(:pointer_leave, on: :pointerleave)
          tooltip.with_action(:pointer_down, on: :pointerdown)
          tooltip.with_action(:click_close, on: :click)
          tooltip.with_action(:focus_open, on: :focus)
          tooltip.with_action(:blur_close, on: :blur)
          popper = Poetry::Core::Stimulus::Builder.new(POPPER, attrs)
          popper.with_target(:anchor)
          attrs.to_attributes
        end

        def popper_stimulus
          attrs = Poetry::Core::HTML::Attributes.new
          yield Poetry::Core::Stimulus::Builder.new(POPPER, attrs)
          attrs.to_attributes
        end
      end
    end
  end
end
