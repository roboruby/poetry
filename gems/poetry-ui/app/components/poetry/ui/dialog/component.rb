# frozen_string_literal: true

module Poetry
  module Ui
    module Dialog
      # The Dialog - the depth-moat overlay, on the PLATFORM trap:
      # a native <dialog> + showModal() owns focus trapping, Esc, top-layer
      # stacking, and focus return; the poetry--core--dialog controller adds
      # the data-open/data-closed pair, backdrop dismissal, and the scroll
      # lock. The title is
      # REQUIRED (the accessible name - aria-labelledby is always wired).
      class Component < Poetry::Core::Component
        AGENT_RULES = [
          "Open dialogs with with_trigger(...) - never a hand-wired button.",
          "with_title is REQUIRED (the accessible name); with_description when the purpose needs explaining.",
          "Confirmations that must not be lost use dismissible: false (backdrop clicks stop closing).",
          "Destructive confirmations pair a destructive Button in the footer - never auto-submit."
        ].freeze

        # The controller identifier, declared ONCE - every data attribute
        # derives from it through the Stimulus Builder, validated against
        # the controllers manifest (no hand-written wiring strings).
        CONTROLLER = %i[poetry core dialog].freeze

        option :dismissible, :boolean, default: true

        part "dialog", "Root wrapper around the trigger and the <dialog> element"
        part "dialog-content", "The <dialog> panel - positioning, animation, and the open " \
                               "state ride here",
             states: {
               "data-open" => "panel is open (the controller flips the pair at runtime)",
               "data-closed" => "panel is closed or animating out (the server-rendered state)"
             }
        part "dialog-header", "Title block at the top of the panel"
        part "dialog-title", "The heading - the dialog's accessible name (required slot)"
        part "dialog-description", "Muted copy under the title, wired to aria-describedby"
        part "dialog-footer", "Action row at the bottom of the panel"

        # The trigger is a poetry Button wired to open the dialog - agents
        # pass Button props: with_trigger(variant: :outline) { "Open" }.
        renders_one :trigger, lambda { |**options, &block|
          options[:data] = { action: stimulus.action(:open) }.merge(options[:data] || {})
          Button::Component.new(**options, &block)
        }
        renders_one :title
        renders_one :description
        renders_one :footer

        # The same facts the before_render raise enforces, stated statically
        #: poetry check flags the omission without rendering (the
        # menu crash class - required slots the contract kept silent).
        REQUIRED_SLOTS = { title: "the accessible name" }.freeze

        # The forwarding-lambda component fact: with_trigger renders a
        # Button - callers get Button's full typed-slot contract statically.
        SLOT_RENDERS = { trigger: Button::Component }.freeze

        def before_render
          raise ArgumentError, "Dialog requires with_title (the accessible name)" unless title?
        end

        def title_id
          "#{instance_id}-title"
        end

        def description_id
          "#{instance_id}-description"
        end

        def root_attributes
          html_attributes.merge_if_not_set(
            { "data-slot" => "dialog" }
              .merge(stimulus_attributes do |dialog|
                dialog.register_controller
                dialog.with_value(:dismissible, dismissible)
              end)
              .merge(component_data_attributes)
          )
        end

        def dialog_attributes
          attrs = {
            "class" => css(:content),
            "data-slot" => "dialog-content",
            "data-closed" => "",
            "aria-labelledby" => title_id
          }.merge(stimulus_attributes do |dialog|
            dialog.with_target(:dialog)
            dialog.with_action(:close, on: :cancel)
            dialog.with_action(:backdrop_close, on: :click)
          end)
          attrs["aria-describedby"] = description_id if description?
          attrs
        end

        # Validated action descriptor for the template's close button.
        def close_action
          stimulus.action(:close)
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

        # Server-stable unique id for the aria wiring (two dialogs on one
        # page must not share label ids).
        def instance_id
          @instance_id ||= "poetry-dialog-#{SecureRandom.hex(4)}"
        end
      end
    end
  end
end
