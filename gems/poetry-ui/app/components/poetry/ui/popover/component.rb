# frozen_string_literal: true

module Poetry
  module Ui
    module Popover
      # The placement vocabularies - the popper-consumer kit owns them.
      SIDES = Poetry::Ui::PopperConsumer::SIDES
      ALIGNS = Poetry::Ui::PopperConsumer::ALIGNS

      # The popper-consumer trio's click-open member: a role=dialog panel
      # anchored to its trigger - the APG
      # dialog-pattern-lite. Two hosts, one owned controller: the root
      # carries poetry--core--popover (toggle / dismiss / focus-in+return)
      # + poetry--core--popper (anchored positioning); the content's layer
      # controllers (focus-scope, dismissable) are TOKEN-ACTIVATED by the
      # popover controller on open - a statically-connected trap on hidden
      # content would steal focus at page load, so the markup renders NO
      # layer tokens.
      #
      # Deliberate contrasts with the menu family: modal defaults FALSE
      # (Radix Popover parity), focus moves to the first tabbable on open
      # (focus-scope's mount default, not vetoed - no data-open-reason),
      # and the trigger has no custom keydown (native button Enter/Space).
      #
      # @example
      #   render Poetry::Ui::Popover::Component.new do |popover|
      #     popover.with_trigger(variant: :outline) { "Open popover" }
      #     popover.with_title { "Dimensions" }
      #     tag.p("Set the dimensions for the layer.")
      #   end
      class Component < Poetry::Core::Component
        include Poetry::Ui::ComposableTrigger
        include Poetry::Ui::PopperConsumer

        AGENT_RULES = [
          ComposableTrigger::AGENT_RULE,
          "Use poetry_popover - never hand-roll an anchored role=dialog panel with Tailwind.",
          "Popover content is INTERACTIVE - for text-only hover hints use Tooltip; for pointer-only " \
          "previews use HoverCard.",
          "Give the panel a name: use with_title (preferred) or label: - a role=dialog without a name " \
          "fails the audit.",
          "Icon-only triggers MUST have an accessible name (the composed Button's label: rule).",
          "Default is NON-modal (modal: false) - reach for modal: true only when stray outside " \
          "interaction would corrupt the task; reach for Dialog when the task deserves full modality.",
          "Critical-path panels must also be reachable without JS (full page or server-rendered " \
          "open: true) - popovers are JS-required interaction.",
          "Do not nest a Popover inside a Popover - restructure (the layer stack allows it; " \
          "comprehension does not)."
        ].freeze

        # The same facts the before_render raise enforces, stated
        # statically: poetry check flags the omission without rendering
        # (the menu crash class - required slots the contract kept silent).
        REQUIRED_SLOTS = { trigger: "the panel's control" }.freeze

        # The forwarding-lambda fact: with_trigger renders a Button -
        # callers get Button's full typed-slot contract statically.
        SLOT_RENDERS = { trigger: Button::Component }.freeze

        # The trigger is a poetry Button wired as the dialog control (demo
        # parity: with_trigger(variant: :outline) { "Open popover" }) - the
        # slot owns the aria-haspopup/expanded/controls wiring regardless
        # of the composed content, so composition cannot drop the aria.
        # aria-controls is rendered ALWAYS (Radix: open-only) - the static
        # server id is the controller's structural-resolution seam.
        renders_one :trigger, lambda { |**options, &block|
          wiring = {
            "id" => trigger_id, "data-slot" => "popover-trigger",
            "aria-haspopup" => "dialog", "aria-expanded" => open.to_s, "aria-controls" => content_id
          }.merge(stimulus_attributes_for(:trigger))
          # Base UI trigger state: bare data-popup-open while open, NO
          # attribute while closed (absence IS the state).
          wiring["data-popup-open"] = "" if open
          composed_trigger(wiring, options, &block) ||
            Button::Component.new(**wiring, **options, &block)
        }

        # OPTIONAL alternate popper anchor (Radix PopoverAnchor): when
        # present IT carries the popper anchor target and the content
        # positions against it - the root then drops the trigger-selector
        # anchor value (targets beat selectors in popper's fallback chain).
        renders_one :anchor, lambda { |**options, &block|
          attrs = { "data-slot" => "popover-anchor" }
                  .merge(stimulus_attributes_for(:anchor_part))
          content_tag(:div, attrs.merge(options)) { capture(&block) }
        }

        # Panel heading - presence wires the content's aria-labelledby
        # (POETRY ADDITION: new-york-v4 ships the part as an unwired div,
        # leaving a nameless role=dialog).
        renders_one :title

        # Supporting text - presence wires the content's aria-describedby.
        renders_one :description

        use_stimulus do
          on :root do
            controller :popover do
              register
              value :open
              value :modal
            end
            controller :popper do
              register
              # The trigger anchors by id selector; an anchor part
              # overrides it with the anchor TARGET (render-time decision -
              # slots may be set in any order, so the trigger itself
              # carries no popper target).
              value :anchor, from: :trigger_anchor_selector, unless: :anchor?
              value :side
              value :align
              value :side_offset
              value :align_offset
              value :avoid_collisions
            end
          end
          on :trigger do
            controller(:popover) { action :toggle, on: :click }
          end
          on :anchor_part do
            controller(:popper) { target :anchor }
          end
          on :content do
            controller(:popper) { target :content }
          end
        end

        option :open, :boolean, default: false
        # Radix Popover default FALSE - the deliberate contrast with the
        # menu family's modal: true (documented in both contracts).
        option :modal, :boolean, default: false
        # Placement: shadcn Content defaults (bottom / center / 4 / 0).
        popper_placement_options(side: :bottom, side_offset: 4)
        # role=dialog fallback name when no title part is present.
        option :label, :string
        # The panel's class merge seam (shadcn demo parity: the caller
        # overrides the w-72 default with content_class: "w-80"; root-level
        # class: styles the wrapper, not the panel).
        option :content_class, :string

        part "popover", "Root wrapper around the trigger, the optional anchor, and the panel"
        part "popover-anchor", "Optional alternate popper anchor (Radix PopoverAnchor) - when " \
                               "present the panel positions against it instead of the trigger"
        part "popover-content", "The role=dialog panel - positioning, animation, and the open " \
                                "state ride here",
             states: {
               "data-open" => "panel is open (the controller flips the pair at runtime)",
               "data-closed" => "panel is closed (the server-rendered state; hidden rides along)",
               "data-side" => { condition: "always - the side (initial placement, re-resolved " \
                                           "live by popper after flip)",
                                values: SIDES.map(&:to_s) },
               "data-align" => { condition: "always - the alignment (re-resolved live by popper)",
                                 values: ALIGNS.map(&:to_s) }
             },
             vars: Poetry::Ui::PopperConsumer.content_vars
        part "popover-header", "Title block wrapping the title and description (renders only " \
                               "when either is present)"
        part "popover-title", "The heading - the panel's accessible name via aria-labelledby"
        part "popover-description", "Muted copy under the title, wired to aria-describedby"

        def before_render
          raise ArgumentError, "Popover requires with_trigger (the panel's control)" unless trigger?

          return if title? || label.present?

          # Lint-level warning, not an error: a role=dialog SHOULD have an
          # accessible name (with_title preferred, label: the fallback).
          Rails.logger&.warn(
            "poetry Popover: role=dialog panel has no accessible name - give it with_title or label:"
          )
        end

        def title_id
          "#{instance_id}-title"
        end

        def description_id
          "#{instance_id}-description"
        end

        def content_attributes
          attrs = {
            "id" => content_id, "role" => "dialog", "tabindex" => "-1",
            "data-slot" => "popover-content", (open ? "data-open" : "data-closed") => "",
            # Initial placement, re-resolved live by popper on open.
            "data-side" => side, "data-align" => align,
            "class" => css(:content, class: content_class)
          }.merge(stimulus_attributes_for(:content))
          if title?
            attrs["aria-labelledby"] = title_id
          elsif label.present?
            attrs["aria-label"] = label
          end
          attrs["aria-describedby"] = description_id if description?
          attrs["hidden"] = true unless open
          attrs
        end

        private

        def trigger_anchor_selector = "##{trigger_id}"
      end
    end
  end
end
