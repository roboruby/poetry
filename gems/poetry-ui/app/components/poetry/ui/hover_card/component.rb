# frozen_string_literal: true

module Poetry
  module Ui
    module HoverCard
      # The placement vocabularies - the popper-consumer kit owns them.
      SIDES = Poetry::Ui::PopperConsumer::SIDES
      ALIGNS = Poetry::Ui::PopperConsumer::ALIGNS

      # The popper-consumer trio's pointer-only member: a rich preview
      # behind a LINK, for sighted pointer users, BY DESIGN not an
      # interaction path. The root carries
      # poetry--core--hover-card (open/close pair timers, the touch
      # double-guard, the focus mirror, the per-open tabindex strip, the
      # selection hold) + poetry--core--popper; the content's dismissable
      # layer is TOKEN-ACTIVATED while open. NO focus-scope anywhere in
      # the lifecycle (focus never moves in - the trio's simplest
      # teardown) and NO aria surface (no haspopup/expanded/describedby,
      # role-less content - advertising a keyboard-unreachable surface to
      # AT is worse than silence, Radix-exact).
      #
      # THE REACHABLE-ELSEWHERE RULE (non-negotiable): everything in a
      # hover card must exist at the trigger link's destination - the
      # trigger stays an <a href> because it is simultaneously the no-JS
      # fallback, the touch path, and the keyboard path.
      #
      # @example A profile preview behind a real link
      #   render Poetry::Ui::HoverCard::Component.new do |card|
      #     card.with_trigger(href: "/users/nextjs") { "@nextjs" }
      #     "Joined December 2021."
      #   end
      class Component < Poetry::Core::Component
        include Poetry::Ui::ComposableTrigger
        include Poetry::Ui::PopperConsumer

        AGENT_RULES = [
          ComposableTrigger::AGENT_RULE,
          "Use poetry_hover_card - never hand-roll hover-div previews.",
          "THE REACHABLE-ELSEWHERE RULE (non-negotiable): every piece of information in a hover card " \
          "MUST exist at the trigger link's destination (or another keyboard/touch-reachable surface). " \
          "The card is pointer-only enrichment - keyboard and touch users never see inside it.",
          "The trigger must be a REAL link with a real href - it is the fallback, the touch path, and " \
          "the keyboard path all at once. For a button LOOK, pass variant:/size: (renders through " \
          "Button, still an <a> via href:) - never swap the tag to :button.",
          "NO interactive elements inside the card - they get tabindex=-1 stripped and become " \
          "pointer-only traps. Actions belong in a Popover or at the destination.",
          "Don't add aria-expanded/haspopup to the trigger - advertising an unreachable surface is " \
          "worse than silence (Radix-aligned).",
          "Never use HoverCard for hints (Tooltip) or for content users act on (Popover).",
          "Prefer defer: for expensive previews - a lazy turbo-frame that fetches on first open."
        ].freeze

        # The same facts the before_render raise enforces, stated statically:
        # poetry check flags the omission without rendering (the menu crash
        # class - required slots the contract kept silent).
        REQUIRED_SLOTS = { trigger: "the enriched link" }.freeze

        # The enriched LINK (Radix Primitive.a): a real navigable <a> -
        # THE no-JS fallback. tag: passthrough exists but change it
        # knowingly (an <a> is the contract's fallback story). NO
        # aria-haspopup/expanded/describedby - the card is invisible to
        # the accessibility tree on purpose. Built as a lazy anatomy part
        # (rendered at render time, not at with_trigger time).
        #
        # variant:/size: route through Button::Component (the tooltip
        # convention) - Button's href-implies-anchor keeps the trigger a
        # REAL <a> wearing button styling, so the reachable-elsewhere
        # contract holds (the upstream sides demo look, contract intact).
        renders_one :trigger, lambda { |href: nil, tag: :a, **options, &block|
          @trigger_href = href
          attrs = {
            "id" => trigger_id, "data-slot" => "hover-card-trigger"
          }.merge(stimulus_attributes_for(:trigger))
          # Base UI trigger state: bare data-popup-open while open, NO
          # attribute while closed (absence IS the state).
          attrs["data-popup-open"] = "" if open
          next composed_trigger(attrs, options, &block) if options[:compose]
          if options.key?(:variant) || options.key?(:size)
            next Button::Component.new(href: href, **attrs, **options, &block)
          end

          attrs["href"] = href if href.present?
          Trigger.new(tag_name: tag, attributes: Poetry::Core::HTML::Attributes.merged(attrs, options))
        }

        use_stimulus do
          on :root do
            controller :hover_card do
              register
              value :open
              value :open_delay
              value :close_delay
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
          # The Radix trigger handlers, ported: pointerenter/leave pair
          # timers (touch excluded), focus opens immediately / blur closes,
          # and the touchstart guard (a tap navigates, never focus-opens).
          on :trigger do
            controller :hover_card do
              action :pointer_enter, on: :pointerenter
              action :pointer_leave, on: :pointerleave
              action :focus_open, on: :focus
              action :blur_close, on: :blur
              action :touch_guard, on: :touchstart
            end
            controller(:popper) { target :anchor }
          end
          on :content do
            controller(:popper) { target :content }
          end
        end

        option :open, :boolean, default: false
        # Defer the card body to a lazy turbo-frame. The panel is
        # hidden until hover, so the fetch fires on first open for free;
        # the component block (if any) becomes the frame's placeholder.
        option :defer, :string
        option :open_delay, :integer, default: 600 # Base UI PreviewCard OPEN_DELAY
        option :close_delay, :integer, default: 300 # the grace window over the trigger+content pair
        # Placement: shadcn Content defaults (bottom / center / 4 / 0).
        popper_placement_options(side: :bottom, side_offset: 4)
        # The panel's class merge seam (demo parity: content_class: "w-80"
        # overrides the source w-64).
        option :content_class, :string

        part "hover-card", "Root wrapper around the trigger link and the panel"
        part "hover-card-trigger", "The enriched link itself - simultaneously the no-JS " \
                                   "fallback, the touch path, and the keyboard path",
             states: {
               "data-popup-open" => "bare while the card is open; absent while closed " \
                                    "(Base UI absence-is-the-state)"
             }
        part "hover-card-content", "The role-less preview panel (invisible to AT on purpose) - " \
                                   "positioning, animation, and the open state ride here",
             states: {
               "data-open" => "card is open (the controller flips the pair at runtime)",
               "data-closed" => "card is closed (the server-rendered state; hidden rides along)",
               "data-side" => { condition: "always - the side (initial placement, re-resolved " \
                                           "live by popper after flip)",
                                values: SIDES.map(&:to_s) },
               "data-align" => { condition: "always - the alignment (re-resolved live by popper)",
                                 values: ALIGNS.map(&:to_s) }
             },
             vars: Poetry::Ui::PopperConsumer.content_vars

        def before_render
          raise ArgumentError, "HoverCard requires with_trigger (the enriched link)" unless trigger?

          return if @trigger_href.present?

          # Lint-level warning, not an error (anchors-without-href exist in
          # legacy hosts): a trigger without a real destination defeats the
          # reachable-elsewhere contract.
          Rails.logger&.warn(
            "poetry HoverCard: trigger has no href - the link IS the keyboard/touch/no-JS path " \
            "(the reachable-elsewhere rule)"
          )
        end

        def content_attributes
          attrs = {
            "id" => content_id,
            "data-slot" => "hover-card-content", (open ? "data-open" : "data-closed") => "",
            # Initial placement, re-resolved live by popper on open.
            "data-side" => side, "data-align" => align,
            "class" => css(:content, class: content_class)
          }.merge(stimulus_attributes_for(:content))
          attrs["hidden"] = true unless open
          attrs
        end

      end

      # The trigger anatomy part. Plain ViewComponent::Base ON PURPOSE:
      # Poetry::Core::Component descendants register in the component
      # registry, and the trigger is anatomy, not a component (the
      # DropdownMenu precedent).
      #
      # @api private
      class Trigger < Poetry::Core::Component
        internal_component!

        # Carries pre-built wiring only. (@attributes is Component's
        # ActiveModel storage - the wiring rides its own ivar.)
        def initialize(tag_name:, attributes:)
          super({})
          @tag_name = tag_name
          @trigger_attributes = attributes
        end

        def call
          content_tag(@tag_name, content, @trigger_attributes)
        end
      end
    end
  end
end
