# frozen_string_literal: true

module Poetry
  module Ui
    module Tooltip
      # Shared placement vocabularies, declared once at module level.
      SIDES = %i[top right bottom left].freeze
      ALIGNS = %i[start center end].freeze

      # The popper-consumer trio's timing machine: the
      # hover/focus text hint that must never receive
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
      #
      # @example A described icon button
      #   render Poetry::Ui::Tooltip::Component.new do |tooltip|
      #     tooltip.with_trigger(variant: :outline, size: :icon, label: "Print") do
      #       poetry_icon(name: :printer)
      #     end
      #     "Print the current page"
      #   end
      class Component < Poetry::Core::Component
        include Poetry::Ui::ComposableTrigger

        AGENT_RULES = [
          "with_trigger(compose: true) { |wiring| ... } composes YOUR control as the trigger: " \
          "the block is yielded the wiring (id/aria + data: with the overlay's trigger slot " \
          "and Stimulus behavior) - splat it onto a wiring-free control " \
          "(poetry_sidebar_menu_button, a plain tag); without compose: the classic composed " \
          "Button renders.",
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

        # The same facts the before_render raise enforces, stated statically:
        # poetry check flags the omission without rendering (the menu crash
        # class - required slots the contract kept silent).
        REQUIRED_SLOTS = { trigger: "the described control" }.freeze

        # The forwarding-lambda fact: with_trigger renders a
        # Button - callers get Button's full typed-slot contract statically.
        SLOT_RENDERS = { trigger: Button::Component }.freeze

        # The described control - commonly a poetry Button (demo parity:
        # with_trigger(variant: :outline) { "Hover" }). The slot owns the
        # state + timing wiring regardless of the composed content.
        # NO aria-haspopup/expanded/controls - the tooltip is invisible as
        # a popup; aria-describedby is written by the controller on open
        # (and server-rendered only when open: true).
        renders_one :trigger, lambda { |**options, &block|
          wiring = {
            "id" => trigger_id, "data-slot" => "tooltip-trigger"
          }.merge(stimulus_attributes_for(:trigger))
          # Base UI trigger state: bare data-popup-open while open, NO
          # attribute while closed (absence IS the state).
          wiring["data-popup-open"] = "" if open
          wiring["aria-describedby"] = content_id if open
          composed_trigger(wiring, options, &block) ||
            Button::Component.new(**wiring, **options, &block)
        }

        use_stimulus do
          on :root do
            # Full identifier: the bare :tooltip suffix is ambiguous the
            # moment a host also loads poetry-charts (poetry--charts--
            # tooltip joins the manifest catalog).
            controller "poetry--core--tooltip" do
              register
              value :open
              # Inherit-from-provider: unset renders NO attribute - the
              # controller falls back to [data-slot=tooltip-provider].
              value :delay_duration, unless: -> { delay_duration.nil? }
              value :disable_hoverable_content, unless: -> { disable_hoverable_content.nil? }
            end
            controller :popper do
              register
              value :side
              value :align
              value :side_offset
            end
          end
          # The Radix trigger handlers, ported: pointermove opens (touch
          # excluded, once per hover), pointerdown/click close, focus opens
          # instantly / blur closes.
          on :trigger do
            controller "poetry--core--tooltip" do
              action :pointer_move, on: :pointermove
              action :pointer_leave, on: :pointerleave
              action :pointer_down, on: :pointerdown
              action :click_close, on: :click
              action :focus_open, on: :focus
              action :blur_close, on: :blur
            end
            controller(:popper) { target :anchor }
          end
          on :content do
            controller(:popper) { target :content }
          end
          # The arrow target (previously a hand-written string in the ERB).
          on :arrow do
            controller(:popper) { target :arrow }
          end
        end

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
              .merge(stimulus_attributes_for(:root))
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
          }.merge(stimulus_attributes_for(:content))
          attrs["hidden"] = true unless open
          attrs
        end

        private

        def instance_id
          @instance_id ||= poetry_instance_id("poetry-tooltip")
        end
      end
    end
  end
end
