# frozen_string_literal: true

module Poetry
  module Ui
    # Hover/focus text hints.
    module Tooltip
      # The placement vocabularies - the popper-consumer kit owns them.
      SIDES = Poetry::Ui::PopperConsumer::SIDES
      # The closed vocabulary for the align axis.
      ALIGNS = Poetry::Ui::PopperConsumer::ALIGNS

      # A hover/focus text hint. The bubble describes its trigger and
      # never receives focus: content is role=tooltip, the trigger's
      # aria-describedby exists only while open (a description pointing
      # at hidden content mis-announces), and no aria-haspopup/expanded
      # is written - a tooltip is a description, not a popup the user
      # operates. Opening is delayed on hover but instant on keyboard
      # focus; only one tooltip is open globally; Esc closes the tooltip
      # first when overlays are stacked; touch never opens one, so
      # essential information must never live only in a tooltip.
      #
      # Content must be plain text, never interactive - use Popover for
      # links or controls. Wrap rows of triggers in one
      # poetry_tooltip_provider so moving along the row skips the delay.
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
        include Poetry::Ui::PopperConsumer

        # Projected into the registry, llms.txt, and the agent surface.
        AGENT_RULES = [
          ComposableTrigger::AGENT_RULE,
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
        # poetry check flags the omission without rendering.
        REQUIRED_SLOTS = { trigger: "the described control" }.freeze

        # The component behind the forwarding slot: with_trigger renders a Button.
        SLOT_RENDERS = { trigger: Button::Component }.freeze

        # The described control - commonly a poetry Button
        # (with_trigger(variant: :outline) { "Hover" }). The slot owns the
        # state + timing wiring regardless of the composed content.
        # NO aria-haspopup/expanded/controls - the tooltip is invisible as
        # a popup; aria-describedby is written by the controller on open
        # (and server-rendered only when open: true).
        renders_one :trigger, lambda { |**options, &block|
          wiring = {
            "id" => trigger_id, "data-slot" => "tooltip-trigger"
          }.merge(stimulus_attributes_for(:trigger))
          # Open state is a bare data-popup-open presence attribute -
          # absent while closed (absence IS the state).
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
              value :align_offset
              value :avoid_collisions
            end
          end
          # The trigger handlers: pointermove opens (touch excluded, once
          # per hover), pointerdown/click close, focus opens instantly /
          # blur closes.
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
          # The arrow's positioning target.
          on :arrow do
            controller(:popper) { target :arrow }
          end
        end

        # Server-renders the tooltip open.
        option :open, :boolean, default: false
        # The hover-open delay in ms; nil inherits the provider's (default 0).
        option :delay_duration, :integer
        # When true the bubble closes as the pointer leaves the trigger -
        # it cannot be hovered into; nil inherits the provider.
        option :disable_hoverable_content, :boolean
        # Placement defaults: :top with side_offset 0 (the arrow supplies the gap).
        popper_placement_options(side: :top, side_offset: 0)
        # Plain-text announcement override for rich content (the visual
        # children stay; the announced body becomes this text).
        option :label, :string
        # The bubble's class merge seam (caller classes win on conflicts).
        option :content_class, :string

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
             vars: Poetry::Ui::PopperConsumer.content_vars("bubble")
        part "tooltip-arrow", "The arrow wrapper (aria-hidden) - popper pins it to the bubble's " \
                              "anchor-facing edge and rotates it toward the anchor",
             states: {
               "data-side" => { condition: "written by popper alongside the content's - the " \
                                           "resolved side, for per-side restyling",
                                values: SIDES.map(&:to_s) }
             }

        # @api private
        def before_render
          raise ArgumentError, "Tooltip requires with_trigger (the described control)" unless trigger?
        end

        # @api private
        def content_attributes
          # A server-pinned open tooltip renders bare data-open; the
          # controller adds data-instant on ITS opens - the reason
          # attribute is runtime-only.
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

      end
    end
  end
end
