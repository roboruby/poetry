# frozen_string_literal: true

module Poetry
  module Ui
    module AlertDialog
      # The AlertDialog - Dialog's `dismissible: false` posture, promoted
      # to a component: a must-be-answered confirmation. It reuses the
      # poetry--core--dialog controller and the
      # native <dialog> + showModal() platform trap UNCHANGED, hard-coding
      # the posture: backdrop clicks never dismiss (dismissible is not an
      # option here), while Esc still closes - the controller's
      # cancel->close deliberately ignores dismissibleValue, exactly Radix
      # AlertDialog's behavior (outside interaction prevented, escape
      # allowed). Deltas from Dialog: explicit role=alertdialog, title AND
      # description both required, typed action/cancel Button slots (both
      # dismiss the dialog through the shared controller; cancel takes
      # initial focus per APG), no X close button, and the source's size
      # variant + media well.
      #
      # @example Destructive confirmation
      #   render Poetry::Ui::AlertDialog::Component.new do |dialog|
      #     dialog.with_trigger(variant: :destructive) { "Delete project" }
      #     dialog.with_title { "Delete this project?" }
      #     dialog.with_description { "This cannot be undone." }
      #     dialog.with_cancel { "Cancel" }
      #     dialog.with_action(variant: :destructive) { "Delete" }
      #   end
      class Component < Poetry::Core::Component
        include Poetry::Ui::ComposableTrigger

        SIZES = %i[default sm].freeze

        AGENT_RULES = [
          "with_trigger(compose: true) { |wiring| ... } composes YOUR control as the trigger: " \
          "the block is yielded the wiring (id/aria + data: with the overlay's trigger slot " \
          "and Stimulus behavior) - splat it onto a wiring-free control " \
          "(poetry_sidebar_menu_button, a plain tag); without compose: the classic composed " \
          "Button renders.",
          "Destructive confirmations use AlertDialog with with_action(variant: :destructive) - " \
          "never a bare Dialog, never data-turbo-confirm.",
          "with_title AND with_description are REQUIRED (both raise).",
          "The action must be an explicit user activation - agents NEVER auto-submit the action.",
          "No extra form fields inside an AlertDialog - if input is needed, use a Dialog.",
          "Cancel keeps variant: :outline; do not make cancel visually primary."
        ].freeze

        # The same facts the before_render raise enforces, stated statically:
        # poetry check flags the omission without rendering (the menu crash
        # class - required slots the contract kept silent).
        REQUIRED_SLOTS = {
          title: "the accessible name", description: "the alertdialog must explain itself",
          action: "the confirming choice", cancel: "the safe way out"
        }.freeze

        # The forwarding-lambda fact: with_trigger renders a
        # Button - callers get Button's full typed-slot contract statically.
        SLOT_RENDERS = { trigger: Button::Component, action: Button::Component, cancel: Button::Component }.freeze

        # The trigger is a poetry Button wired to open - the inherited
        # Dialog pattern: with_trigger(variant: :destructive) { "Delete" }.
        renders_one :trigger, lambda { |**options, &block|
          composed_trigger({ "data-action" => stimulus_action(:open) }, options, &block) || begin
            options[:data] = { action: stimulus_action(:open) }.merge(options[:data] || {}) do |key, wired, caller|
              key == :action ? Poetry::Core::Config.current.stimulus_merger.merge_actions(wired, caller) : caller
            end
            Button::Component.new(**options, &block)
          end
        }
        renders_one :title
        renders_one :description
        # Optional icon/illustration well (the v4 source addition).
        renders_one :media
        # The confirming choice - a typed Button slot with the source
        # default (callers override to :destructive for deletes). Closes the
        # shared dialog on activation, exactly like Radix AlertDialogAction
        # (a caller passing their own data-action opts out of the auto-close).
        renders_one :action, lambda { |**options, &block|
          options[:data] = { slot: "alert-dialog-action", action: stimulus_action(:close) }.merge(options[:data] || {})
          Button::Component.new(**options, &block)
        }
        # The safe way out - outline (source default) and the INITIAL focus:
        # the native <dialog> focus heuristic honors autofocus (APG: focus
        # the least-destructive action). Like Radix AlertDialogCancel it
        # dismisses the dialog through the shared controller - without this
        # wiring the modal is unclosable except by Esc.
        renders_one :cancel, lambda { |**options, &block|
          wired_data = { slot: "alert-dialog-cancel", action: stimulus_action(:close) }
          options[:data] = wired_data.merge(options[:data] || {}) do |key, wired, caller|
            key == :action ? Poetry::Core::Config.current.stimulus_merger.merge_actions(wired, caller) : caller
          end
          Button::Component.new(variant: :outline, autofocus: true, **options, &block)
        }

        # The SHARED dialog controller (zero new JS) under AlertDialog's
        # own declarations - dismissible is the hard-coded false posture.
        use_stimulus do
          on :root do
            controller :dialog do
              register
              # The posture IS the identity - never caller-settable.
              value :dismissible, false
            end
          end
          on :content do
            controller :dialog do
              target :dialog
              action :close, on: :cancel
              # Wired but inert: backdropClose no-ops on dismissibleValue
              # false. Keep it - removing it would fork the Dialog wiring.
              action :backdrop_close, on: :click
            end
          end
          on :trigger do
            controller(:dialog) { action :open }
          end
          # Both the action and cancel Buttons close (same descriptor).
          on :close do
            controller(:dialog) { action :close }
          end
        end

        style :size, default: :default, required: true, variants: SIZES

        part "alert-dialog", "Root wrapper around the trigger and the <dialog> element"
        part "alert-dialog-content", "The role=alertdialog <dialog> panel - sizing, animation, " \
                                     "and the open state ride here",
             states: {
               "data-open" => "panel is open (the shared dialog controller flips the pair " \
                              "at runtime)",
               "data-closed" => "panel is closed (the server-rendered state)",
               "data-size" => { condition: "always - the resolved size",
                                values: SIZES.map(&:to_s) }
             }
        part "alert-dialog-header", "Title block - holds the optional media well, the title, " \
                                    "and the description"
        part "alert-dialog-title", "The heading - the alertdialog's accessible name " \
                                   "(required slot)"
        part "alert-dialog-description", "The explanation, wired to aria-describedby " \
                                         "(required slot)"
        part "alert-dialog-footer", "The choice row - cancel then action"

        def before_render
          raise ArgumentError, "AlertDialog requires with_title (the accessible name)" unless title?
          unless description?
            raise ArgumentError, "AlertDialog requires with_description (the alertdialog must explain itself)"
          end
          raise ArgumentError, "AlertDialog requires with_action (the confirming choice)" unless action?
          raise ArgumentError, "AlertDialog requires with_cancel (the safe way out)" unless cancel?
        end

        def title_id
          "#{instance_id}-title"
        end

        def description_id
          "#{instance_id}-description"
        end

        def root_attributes
          html_attributes.merge_if_not_set(
            { "data-slot" => "alert-dialog" }
              .merge(stimulus_attributes_for(:root))
              .merge(component_data_attributes)
          )
        end

        def dialog_attributes
          {
            "class" => css(:content),
            # Explicit role: overrides the implicit dialog role (aria-modal
            # still comes from showModal).
            "role" => "alertdialog",
            "data-slot" => "alert-dialog-content",
            "data-size" => size,
            "data-closed" => "",
            "aria-labelledby" => title_id,
            "aria-describedby" => description_id
          }.merge(stimulus_attributes_for(:content))
        end

        # The source's group-has-data-[slot] selector acrobatics, emitted as
        # explicit server-side conditionals - poetry knows at render time
        # whether media exists and which size was picked.
        def header_classes
          css(:header, class: [
            (css(:header_with_media) if media?),
            (css(:header_size_default) if size == :default),
            (css(:header_size_default_with_media) if media? && size == :default)
          ].compact.join(" "))
        end

        def media_classes
          css(:media, class: (css(:media_size_default) if size == :default))
        end

        def title_classes
          css(:title, class: (css(:title_beside_media) if media? && size == :default))
        end

        def footer_classes
          css(:footer, class: (css(:footer_size_sm) if size == :sm))
        end

        private

        # Server-stable unique id for the aria wiring.
        def instance_id
          @instance_id ||= poetry_instance_id("poetry-alert-dialog")
        end
      end
    end
  end
end
