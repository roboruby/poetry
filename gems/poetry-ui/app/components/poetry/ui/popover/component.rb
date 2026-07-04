# frozen_string_literal: true

module Poetry
  module Ui
    module Popover
      # The controller identifiers, declared ONCE - every data attribute
      # derives from them through the Stimulus Builder, validated against
      # the controllers manifest (no hand-written wiring strings).
      POPOVER = %i[poetry core popover].freeze
      POPPER = %i[poetry core popper].freeze
      SIDES = %i[top right bottom left].freeze
      ALIGNS = %i[start center end].freeze

      # The popper-consumer trio's click-open member ([[CL Component -
      # Popover]]): a role=dialog panel anchored to its trigger - the APG
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
      class Component < Poetry::Core::Component
        AGENT_RULES = [
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

        option :open, :boolean, default: false
        # Radix Popover default FALSE - the deliberate contrast with the
        # menu family's modal: true (documented in both contracts).
        option :modal, :boolean, default: false
        option :side, :symbol, default: :bottom
        option :align, :symbol, default: :center # shadcn Content default
        option :side_offset, :integer, default: 4 # shadcn Content default
        option :align_offset, :integer, default: 0
        option :avoid_collisions, :boolean, default: true
        # role=dialog fallback name when no title part is present.
        option :label, :string
        # The panel's class merge seam (shadcn demo parity: the caller
        # overrides the w-72 default with content_class: "w-80"; root-level
        # class: styles the wrapper, not the panel).
        option :content_class, :string

        validates :side, inclusion: { in: SIDES }
        validates :align, inclusion: { in: ALIGNS }

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
          }.merge(trigger_stimulus_attributes)
          # Base UI trigger state: bare data-popup-open while open, NO
          # attribute while closed (absence IS the state).
          wiring["data-popup-open"] = "" if open
          Button::Component.new(**wiring, **options, &block)
        }

        # OPTIONAL alternate popper anchor (Radix PopoverAnchor): when
        # present IT carries the popper anchor target and the content
        # positions against it - the root then drops the trigger-selector
        # anchor value (targets beat selectors in popper's fallback chain).
        renders_one :anchor, lambda { |**options, &block|
          attrs = { "data-slot" => "popover-anchor" }
                  .merge(popper_stimulus { |popper| popper.with_target(:anchor) })
          content_tag(:div, attrs.merge(options)) { capture(&block) }
        }

        # Panel heading - presence wires the content's aria-labelledby
        # (POETRY ADDITION: new-york-v4 ships the part as an unwired div,
        # leaving a nameless role=dialog).
        renders_one :title

        # Supporting text - presence wires the content's aria-describedby.
        renders_one :description

        def before_render
          raise ArgumentError, "Popover requires with_trigger (the panel's control)" unless trigger?

          return if title? || label.present?

          # Lint-level warning, not an error: a role=dialog SHOULD have an
          # accessible name (with_title preferred, label: the fallback).
          Rails.logger&.warn(
            "poetry Popover: role=dialog panel has no accessible name - give it with_title or label:"
          )
        end

        def trigger_id
          "#{instance_id}-trigger"
        end

        def content_id
          "#{instance_id}-content"
        end

        def title_id
          "#{instance_id}-title"
        end

        def description_id
          "#{instance_id}-description"
        end

        def root_attributes
          html_attributes.merge_if_not_set(
            { "data-slot" => "popover" }
              .merge(root_stimulus_attributes)
              .merge(component_data_attributes)
          )
        end

        def content_attributes
          attrs = {
            "id" => content_id, "role" => "dialog", "tabindex" => "-1",
            "data-slot" => "popover-content", (open ? "data-open" : "data-closed") => "",
            # Initial placement, re-resolved live by popper on open.
            "data-side" => side, "data-align" => align,
            "class" => css(:content, class: content_class)
          }.merge(popper_stimulus { |popper| popper.with_target(:content) })
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

        # Server-stable unique id pair for the aria wiring (two popovers on
        # one page must not share ids); portal-safe (the controller resolves
        # content via aria-controls, not a Stimulus target).
        def instance_id
          @instance_id ||= "poetry-popover-#{SecureRandom.hex(4)}"
        end

        # BOTH controllers build into ONE Attributes instance - a plain
        # Hash#merge of two would overwrite data-controller instead of
        # token-concatenating it (the Accordion lesson).
        def root_stimulus_attributes
          attrs = Poetry::Core::HTML::Attributes.new
          popover = Poetry::Core::Stimulus::Builder.new(POPOVER, attrs)
          popover.register_controller
          popover.with_value(:open, open)
          popover.with_value(:modal, modal)
          popper = Poetry::Core::Stimulus::Builder.new(POPPER, attrs)
          popper.register_controller
          # The trigger anchors by id selector; an anchor part overrides it
          # with the anchor TARGET (render-time decision - slots may be set
          # in any order, so the trigger itself carries no popper target).
          popper.with_value(:anchor, "##{trigger_id}") unless anchor?
          popper.with_value(:side, side)
          popper.with_value(:align, align)
          popper.with_value(:side_offset, side_offset)
          popper.with_value(:align_offset, align_offset)
          popper.with_value(:avoid_collisions, avoid_collisions)
          attrs.to_attributes
        end

        def trigger_stimulus_attributes
          attrs = Poetry::Core::HTML::Attributes.new
          popover = Poetry::Core::Stimulus::Builder.new(POPOVER, attrs)
          popover.with_action(:toggle, on: :click)
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
