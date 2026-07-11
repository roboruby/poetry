# frozen_string_literal: true

module Poetry
  module Ui
    module AlertDialog
      # The AlertDialog - Dialog's `dismissible: false` posture, promoted to
      # a component (AlertDialog): a must-be-answered
      # confirmation. It reuses the poetry--core--dialog controller and the
      # native <dialog> + showModal() platform trap UNCHANGED, hard-coding
      # the posture: backdrop clicks never dismiss (dismissible is not an
      # option here), while Esc still closes - the controller's
      # cancel->close deliberately ignores dismissibleValue, exactly Radix
      # AlertDialog's behavior (outside interaction prevented, escape
      # allowed). Deltas from Dialog: explicit role=alertdialog, title AND
      # description both required, typed action/cancel Button slots (cancel
      # takes initial focus per APG), no X close button, and the source's
      # size variant + media well.
      class Component < Poetry::Core::Component
        SIZES = %i[default sm].freeze

        AGENT_RULES = [
          "Destructive confirmations use AlertDialog with with_action(variant: :destructive) - " \
          "never a bare Dialog, never data-turbo-confirm.",
          "with_title AND with_description are REQUIRED (both raise).",
          "The action must be an explicit user activation - agents NEVER auto-submit the action.",
          "No extra form fields inside an AlertDialog - if input is needed, use a Dialog.",
          "Cancel keeps variant: :outline; do not make cancel visually primary."
        ].freeze

        # The SHARED controller (zero new JS - the whole point): the
        # component renders dismissible-value=false itself, not the caller.
        CONTROLLER = %i[poetry core dialog].freeze

        style :size, default: :default, required: true, variants: SIZES

        # The trigger is a poetry Button wired to open - the inherited
        # Dialog pattern: with_trigger(variant: :destructive) { "Delete" }.
        renders_one :trigger, lambda { |**options, &block|
          options[:data] = { action: stimulus.action(:open) }.merge(options[:data] || {})
          Button::Component.new(**options, &block)
        }
        renders_one :title
        renders_one :description
        # Optional icon/illustration well (the v4 source addition).
        renders_one :media
        # The confirming choice - a typed Button slot with the source
        # default (callers override to :destructive for deletes).
        renders_one :action, lambda { |**options, &block|
          options[:data] = { slot: "alert-dialog-action" }.merge(options[:data] || {})
          Button::Component.new(**options, &block)
        }
        # The safe way out - outline (source default) and the INITIAL focus:
        # the native <dialog> focus heuristic honors autofocus (APG: focus
        # the least-destructive action).
        renders_one :cancel, lambda { |**options, &block|
          options[:data] = { slot: "alert-dialog-cancel" }.merge(options[:data] || {})
          Button::Component.new(variant: :outline, autofocus: true, **options, &block)
        }

        # The same facts the before_render raise enforces, stated statically
        #: poetry check flags the omission without rendering (the
        # menu crash class - required slots the contract kept silent).
        REQUIRED_SLOTS = {
          title: "the accessible name", description: "the alertdialog must explain itself",
          action: "the confirming choice", cancel: "the safe way out"
        }.freeze

        # The forwarding-lambda component fact: with_trigger renders a
        # Button - callers get Button's full typed-slot contract statically.
        SLOT_RENDERS = { trigger: Button::Component, action: Button::Component, cancel: Button::Component }.freeze

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
              .merge(stimulus_attributes do |dialog|
                dialog.register_controller
                # The posture IS the identity - never caller-settable.
                dialog.with_value(:dismissible, false)
              end)
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
          }.merge(stimulus_attributes do |dialog|
            dialog.with_target(:dialog)
            dialog.with_action(:close, on: :cancel)
            # Wired but inert: backdropClose no-ops on dismissibleValue
            # false. Keep it - removing it would fork the Dialog wiring.
            dialog.with_action(:backdrop_close, on: :click)
          end)
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

        # A manifest-validated Builder for descriptor strings (pure - never
        # touches the component's own html_attributes).
        def stimulus
          @stimulus ||= Poetry::Core::Stimulus::Builder.new(CONTROLLER, Poetry::Core::HTML::Attributes.new)
        end

        # Builds one element's Stimulus attributes through the Builder so
        # every target / value / action name is manifest-validated.
        def stimulus_attributes
          attrs = Poetry::Core::HTML::Attributes.new
          yield Poetry::Core::Stimulus::Builder.new(CONTROLLER, attrs)
          attrs.to_attributes
        end

        # Server-stable unique id for the aria wiring.
        def instance_id
          @instance_id ||= "poetry-alert-dialog-#{SecureRandom.hex(4)}"
        end
      end
    end
  end
end
