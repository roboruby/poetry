# frozen_string_literal: true

module Poetry
  module Ui
    # Modal confirmations that must be answered.
    module AlertDialog
      # A modal confirmation that must be answered before anything else.
      # Built on the native <dialog> element: clicking the backdrop never
      # dismisses it, though Esc still cancels. Use it for destructive or
      # irreversible actions; for anything needing input, use Dialog.
      #
      # Title and description are both required, as are the action and
      # cancel buttons - both close the dialog when activated, and cancel
      # (the least-destructive choice) takes initial focus. There is no
      # corner close button.
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
        include Poetry::Ui::FamilyIdentity

        # The closed vocabulary for the size axis.
        SIZES = %i[default sm].freeze

        # Projected into the registry, llms.txt, and the agent surface.
        AGENT_RULES = [
          ComposableTrigger::AGENT_RULE,
          "Destructive confirmations use AlertDialog with with_action(variant: :destructive) - " \
          "never a bare Dialog, never data-turbo-confirm.",
          "with_title AND with_description are REQUIRED (both raise).",
          "The action must be an explicit user activation - agents NEVER auto-submit the action.",
          "No extra form fields inside an AlertDialog - if input is needed, use a Dialog.",
          "Cancel keeps variant: :outline; do not make cancel visually primary."
        ].freeze

        # Slots the component cannot render without; static checks read this without rendering.
        REQUIRED_SLOTS = {
          title: "the accessible name", description: "the alertdialog must explain itself",
          action: "the confirming choice", cancel: "the safe way out"
        }.freeze

        # Slots that render a Button; slot keywords are forwarded as Button props.
        SLOT_RENDERS = { trigger: Button::Component, action: Button::Component, cancel: Button::Component }.freeze

        renders_one :trigger,
                    doc: "The button that opens the dialog; keywords are forwarded as Button props.",
                    renders: lambda { |**options, &block|
                      composed_trigger({ "data-action" => stimulus_action(:open) }, options, &block) || begin
                        merger = Poetry::Core::Config.current.stimulus_merger
                        wired_data = { action: stimulus_action(:open) }
                        options[:data] = wired_data.merge(options[:data] || {}) do |key, wired, caller|
                          key == :action ? merger.merge_actions(wired, caller) : caller
                        end
                        Button::Component.new(**options, &block)
                      end
                    }
        renders_one :title, doc: "The heading - the dialog's accessible name (required)."
        renders_one :description, doc: "The explanation read alongside the title by assistive tech (required)."
        renders_one :media, doc: "Optional icon/illustration well above the title."
        renders_one :action,
                    doc: "The confirming choice (required) - a Button; pass variant: :destructive for deletes. " \
                         "Activating it also closes the dialog (a caller-supplied data-action opts out).",
                    renders: lambda { |**options, &block|
                      options[:data] =
                        { slot: "alert-dialog-action", action: stimulus_action(:close) }.merge(options[:data] || {})
                      Button::Component.new(**options, &block)
                    }
        renders_one :cancel,
                    doc: "The safe way out (required) - an outline Button that takes initial focus and closes the " \
                         "dialog on activation.",
                    renders: lambda { |**options, &block|
                      merger = Poetry::Core::Config.current.stimulus_merger
                      wired_data = { slot: "alert-dialog-cancel", action: stimulus_action(:close) }
                      options[:data] = wired_data.merge(options[:data] || {}) do |key, wired, caller|
                        key == :action ? merger.merge_actions(wired, caller) : caller
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

        style :size, default: :default, required: true, variants: SIZES,
                     doc: "The panel size; :sm compacts the layout and switches the footer to a two-column grid."

        option :content_class, :string, doc: "Extra classes merged onto the panel element."

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
        part "alert-dialog-media", "The optional media well above the title (an icon or illustration) - the " \
                                   "header's first row; absent unless with_media is used"
        part "alert-dialog-title", "The heading - the alertdialog's accessible name " \
                                   "(required slot)"
        part "alert-dialog-description", "The explanation, wired to aria-describedby " \
                                         "(required slot)"
        part "alert-dialog-footer", "The choice row - cancel then action"

        # Enforces the four required slots.
        # @api private
        def before_render
          raise ArgumentError, "AlertDialog requires with_title (the accessible name)" unless title?
          unless description?
            raise ArgumentError, "AlertDialog requires with_description (the alertdialog must explain itself)"
          end
          raise ArgumentError, "AlertDialog requires with_action (the confirming choice)" unless action?
          raise ArgumentError, "AlertDialog requires with_cancel (the safe way out)" unless cancel?
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
        def dialog_attributes
          {
            "class" => css(:content, class: content_class),
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

        # The media/size layout branches emitted as explicit server-side
        # conditionals - poetry knows at render time whether media exists
        # and which size was picked, so no CSS selector gymnastics.
        # @api private
        def header_classes
          css(:header, class: [
            (css(:header_with_media) if media?),
            (css(:header_size_default) if size == :default),
            (css(:header_size_default_with_media) if media? && size == :default)
          ].compact.join(" "))
        end

        # @api private
        def media_classes
          css(:media, class: (css(:media_size_default) if size == :default))
        end

        # @api private
        def title_classes
          css(:title, class: (css(:title_beside_media) if media? && size == :default))
        end

        # @api private
        def footer_classes
          css(:footer, class: (css(:footer_size_sm) if size == :sm))
        end

        private :title_id, :description_id, :dialog_attributes, :header_classes, :media_classes, :title_classes
        private :footer_classes
      end
    end
  end
end
