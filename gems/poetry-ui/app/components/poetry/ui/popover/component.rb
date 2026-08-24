# frozen_string_literal: true

module Poetry
  module Ui
    # A click-opened panel anchored to its trigger.
    module Popover
      # The placement vocabularies - the popper-consumer kit owns them.
      SIDES = Poetry::Ui::PopperConsumer::SIDES
      # The closed vocabulary for the align axis.
      ALIGNS = Poetry::Ui::PopperConsumer::ALIGNS

      # A click-opened role=dialog panel anchored to its trigger, for
      # interactive content: small forms, filters, pickers. Opening
      # moves focus to the first tabbable element in the panel; Escape
      # or outside interaction closes it and returns focus to the
      # trigger. Non-modal by default - the rest of the page stays
      # interactive while it is open.
      #
      # with_trigger composes a Button as the control. Name the panel
      # via with_title (preferred) or label: - a dialog needs an
      # accessible name. The focus and dismiss behavior activates only
      # while open, so closed popovers cost nothing at page load.
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

        # Projected into the registry, llms.txt, and the agent surface.
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

        # Slots the component cannot render without; static checks read this without rendering.
        REQUIRED_SLOTS = { trigger: "the panel's control" }.freeze

        # The class each slot's builder renders - with_trigger composes a
        # Button, so callers get Button's full option contract.
        SLOT_RENDERS = { trigger: Button::Component }.freeze

        slot_doc :trigger, "The control that opens the panel - a composed Button. The slot owns the " \
                           "aria-haspopup/expanded/controls wiring regardless of the composed content, so " \
                           "composition cannot drop the aria; aria-controls renders even while closed (the stable id " \
                           "is the wiring's resolution seam)."
        renders_one :trigger, lambda { |**options, &block|
          wiring = {
            "id" => trigger_id, "data-slot" => "popover-trigger",
            "aria-haspopup" => "dialog", "aria-expanded" => open.to_s, "aria-controls" => content_id
          }.merge(stimulus_attributes_for(:trigger))
          # Trigger open state: bare data-popup-open while open, NO
          # attribute while closed (absence IS the state).
          wiring["data-popup-open"] = "" if open
          composed_trigger(wiring, options, &block) ||
            Button::Component.new(**wiring, **options, &block)
        }

        slot_doc :anchor, "Optional alternate anchor: when present, the panel positions against IT instead of the " \
                          "trigger (targets beat selectors in the positioning fallback chain)."
        renders_one :anchor, lambda { |**options, &block|
          attrs = { "data-slot" => "popover-anchor" }
                  .merge(stimulus_attributes_for(:anchor_part))
          content_tag(:div, attrs.merge(options)) { capture(&block) }
        }

        slot_doc :title, "Panel heading - presence wires the content's aria-labelledby, so the title names the dialog."
        renders_one :title

        slot_doc :description, "Supporting text - presence wires the content's aria-describedby."
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

        option :open, :boolean, default: false, doc: "Server-renders the panel open."
        option :modal, :boolean, default: false,
                                 doc: "Reserves interaction for the panel while open; the default keeps the rest of " \
                                      "the page interactive."
        # The placement axes for the anchored panel (side, align, offsets).
        popper_placement_options(side: :bottom, side_offset: 4)
        option :label, :string, doc: "role=dialog fallback name when no title part is present."
        option :content_class, :string,
               doc: "Class merge seam for the panel itself (e.g. widen the default with content_class: \"w-80\") - " \
                    "root-level class: styles the wrapper, not the panel."

        part "popover", "Root wrapper around the trigger, the optional anchor, and the panel"
        part "popover-anchor", "Optional alternate popper anchor - when " \
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

        # Enforces the required trigger and warns on a nameless dialog.
        # @api private
        def before_render
          raise ArgumentError, "Popover requires with_trigger (the panel's control)" unless trigger?

          return if title? || label.present?

          # Lint-level warning, not an error: a role=dialog SHOULD have an
          # accessible name (with_title preferred, label: the fallback).
          Rails.logger&.warn(
            "poetry Popover: role=dialog panel has no accessible name - give it with_title or label:"
          )
        end

        # @api private
        def title_id
          "#{instance_id}-title"
        end

        # @api private
        def description_id
          "#{instance_id}-description"
        end

        # @api private
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

        private :title_id, :description_id, :content_attributes
      end
    end
  end
end
