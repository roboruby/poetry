# frozen_string_literal: true

module Poetry
  module Ui
    module HoverCard
      # The controller identifiers, declared ONCE - every data attribute
      # derives from them through the Stimulus Builder, validated against
      # the controllers manifest (no hand-written wiring strings).
      HOVER_CARD = %i[poetry core hover_card].freeze
      POPPER = %i[poetry core popper].freeze
      SIDES = %i[top right bottom left].freeze
      ALIGNS = %i[start center end].freeze

      # The popper-consumer trio's pointer-only member ([[CL Component -
      # HoverCard]]): a rich preview behind a LINK, for sighted pointer
      # users, BY DESIGN not an interaction path. The root carries
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
      class Component < Poetry::Core::Component
        AGENT_RULES = [
          "Use poetry_hover_card - never hand-roll hover-div previews.",
          "THE REACHABLE-ELSEWHERE RULE (non-negotiable): every piece of information in a hover card " \
          "MUST exist at the trigger link's destination (or another keyboard/touch-reachable surface). " \
          "The card is pointer-only enrichment - keyboard and touch users never see inside it.",
          "The trigger must be a REAL link with a real href - it is the fallback, the touch path, and " \
          "the keyboard path all at once.",
          "NO interactive elements inside the card - they get tabindex=-1 stripped and become " \
          "pointer-only traps. Actions belong in a Popover or at the destination.",
          "Don't add aria-expanded/haspopup to the trigger - advertising an unreachable surface is " \
          "worse than silence (Radix-aligned).",
          "Never use HoverCard for hints (Tooltip) or for content users act on (Popover).",
          "Prefer defer: for expensive previews - a lazy turbo-frame that fetches on first open."
        ].freeze

        option :open, :boolean, default: false
        # N13 W5: defer the card body to a lazy turbo-frame. The panel is
        # hidden until hover, so the fetch fires on first open for free;
        # the component block (if any) becomes the frame's placeholder.
        option :defer, :string
        option :open_delay, :integer, default: 700 # Radix Root default (shadcn passes nothing)
        option :close_delay, :integer, default: 300 # the grace window over the trigger+content pair
        option :side, :symbol, default: :bottom
        option :align, :symbol, default: :center # shadcn Content default
        option :side_offset, :integer, default: 4 # shadcn Content default
        option :align_offset, :integer, default: 0
        option :avoid_collisions, :boolean, default: true
        # The panel's class merge seam (demo parity: content_class: "w-80"
        # overrides the source w-64).
        option :content_class, :string

        validates :side, inclusion: { in: SIDES }
        validates :align, inclusion: { in: ALIGNS }

        # The enriched LINK (Radix Primitive.a): a real navigable <a> -
        # THE no-JS fallback. tag: passthrough exists but change it
        # knowingly (an <a> is the contract's fallback story). NO
        # aria-haspopup/expanded/describedby - the card is invisible to
        # the accessibility tree on purpose. Built as a lazy anatomy part
        # (rendered at render time, not at with_trigger time).
        renders_one :trigger, lambda { |href: nil, tag: :a, **options|
          @trigger_href = href
          attrs = {
            "id" => trigger_id, "data-slot" => "hover-card-trigger"
          }.merge(trigger_stimulus_attributes)
          # Base UI trigger state: bare data-popup-open while open, NO
          # attribute while closed (absence IS the state).
          attrs["data-popup-open"] = "" if open
          attrs["href"] = href if href.present?
          Trigger.new(tag_name: tag, attributes: attrs.merge(options))
        }

        # The same facts the before_render raise enforces, stated statically
        #: poetry check flags the omission without rendering (the
        # menu crash class - required slots the contract kept silent).
        REQUIRED_SLOTS = { trigger: "the enriched link" }.freeze

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

        def trigger_id
          "#{instance_id}-trigger"
        end

        # The id pair exists for STRUCTURAL resolution only ("-trigger" ->
        # "-content") - deliberately NOT wired to aria-controls/describedby
        # (no AT contract to express).
        def content_id
          "#{instance_id}-content"
        end

        def root_attributes
          html_attributes.merge_if_not_set(
            { "data-slot" => "hover-card" }
              .merge(root_stimulus_attributes)
              .merge(component_data_attributes)
          )
        end

        def content_attributes
          attrs = {
            "id" => content_id,
            "data-slot" => "hover-card-content", (open ? "data-open" : "data-closed") => "",
            # Initial placement, re-resolved live by popper on open.
            "data-side" => side, "data-align" => align,
            "class" => css(:content, class: content_class)
          }.merge(popper_stimulus { |popper| popper.with_target(:content) })
          attrs["hidden"] = true unless open
          attrs
        end

        private

        def instance_id
          @instance_id ||= "poetry-hover-card-#{SecureRandom.hex(4)}"
        end

        # BOTH controllers build into ONE Attributes instance (the
        # Accordion lesson).
        def root_stimulus_attributes
          attrs = Poetry::Core::HTML::Attributes.new
          hover_card = Poetry::Core::Stimulus::Builder.new(HOVER_CARD, attrs)
          hover_card.register_controller
          hover_card.with_value(:open, open)
          hover_card.with_value(:open_delay, open_delay)
          hover_card.with_value(:close_delay, close_delay)
          popper = Poetry::Core::Stimulus::Builder.new(POPPER, attrs)
          popper.register_controller
          popper.with_value(:side, side)
          popper.with_value(:align, align)
          popper.with_value(:side_offset, side_offset)
          popper.with_value(:align_offset, align_offset)
          popper.with_value(:avoid_collisions, avoid_collisions)
          attrs.to_attributes
        end

        # The Radix trigger handlers, ported: pointerenter/leave pair
        # timers (touch excluded), focus opens immediately / blur closes
        # (a keyboard user SEES the card), and the touchstart guard
        # (preventDefault so a tap can never synthesize a focus-open - it
        # just navigates the link).
        def trigger_stimulus_attributes
          attrs = Poetry::Core::HTML::Attributes.new
          hover_card = Poetry::Core::Stimulus::Builder.new(HOVER_CARD, attrs)
          hover_card.with_action(:pointer_enter, on: :pointerenter)
          hover_card.with_action(:pointer_leave, on: :pointerleave)
          hover_card.with_action(:focus_open, on: :focus)
          hover_card.with_action(:blur_close, on: :blur)
          hover_card.with_action(:touch_guard, on: :touchstart)
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

      # The trigger anatomy part. Plain ViewComponent::Base ON PURPOSE:
      # Poetry::Core::Component descendants register in the component
      # registry, and the trigger is anatomy, not a component (the
      # DropdownMenu precedent).
      class Trigger < ViewComponent::Base
        # Carries pre-built wiring only; intentionally does not chain to
        # ViewComponent::Base#initialize.
        def initialize(tag_name:, attributes:) # rubocop:disable Lint/MissingSuper
          @tag_name = tag_name
          @attributes = attributes
        end

        def call
          content_tag(@tag_name, content, @attributes)
        end
      end
    end
  end
end
