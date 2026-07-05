# frozen_string_literal: true

module Poetry
  module Ui
    module Drawer
      # The Drawer - the gesture overlay: a Sheet-shaped edge dialog you can
      # SWIPE away. Everything hard is inherited (the native <dialog> +
      # showModal() platform trap, required title, dismissible:); the deltas
      # are the poetry--core--drawer controller (the swipe CSS-var contract
      # + the presence-hold animated close - the first consumer of the N6
      # presence machinery) and the drawer chrome (edge-rounded popup,
      # transition-driven enter/exit, the optional swipe handle).
      #
      # Deferred with their machinery (the W3b scope walls): snap points,
      # nested drawer stacking, bleed.
      class Component < Dialog::Component
        DIRECTIONS = %i[down up left right].freeze

        AGENT_RULES = [
          "Open drawers with with_trigger(...) - never a hand-wired button.",
          "with_title is REQUIRED (the accessible name) - the inherited Dialog rule.",
          "direction: is the DISMISS direction: :down is the mobile bottom sheet (the default); " \
          "left/right make an edge panel - prefer Sheet on desktop.",
          "show_swipe_handle: true renders the grab pill - use it on bottom sheets so the " \
          "gesture is discoverable.",
          "Esc and the backdrop still dismiss (the platform trap) - the swipe is an addition, " \
          "never the only way out."
        ].freeze

        CONTROLLER = %i[poetry core drawer].freeze

        # The dismissal direction (the Base UI swipeDirection vocabulary);
        # the edge chrome + swipe axis derive from it.
        style :direction, default: :down, required: true, variants: DIRECTIONS

        option :show_swipe_handle, :boolean, default: false

        def before_render
          raise ArgumentError, "Drawer requires with_title (the accessible name)" unless title?
        end

        def root_attributes
          html_attributes.merge_if_not_set(
            { "data-slot" => "drawer" }
              .merge(stimulus_attributes do |drawer|
                drawer.register_controller
                drawer.with_value(:dismissible, dismissible)
                drawer.with_value(:direction, direction)
              end)
              .merge(component_data_attributes)
          )
        end

        # The <dialog> IS the drawer popup: the chrome + swipe wiring land
        # here. The swipe vars are written to this element by the controller
        # and ::backdrop inherits them (the overlay fade rides along).
        def dialog_attributes
          attrs = {
            "class" => css(:content, class: Style.direction(direction)),
            "data-slot" => "drawer-content",
            "data-swipe-direction" => direction,
            "data-closed" => "",
            "aria-labelledby" => title_id
          }.merge(stimulus_attributes do |drawer|
            drawer.with_target(:dialog)
            drawer.with_action(:close, on: :cancel)
            drawer.with_action(:backdrop_close, on: :click)
            drawer.with_action(:swipe_start, on: :pointerdown)
            drawer.with_action(:swipe_move, on: :pointermove)
            drawer.with_action(:swipe_end, on: :pointerup)
            drawer.with_action(:swipe_cancel, on: :pointercancel)
          end)
          attrs["aria-describedby"] = description_id if description?
          attrs
        end

        private

        # The Dialog parent resolves its CONTROLLER lexically, so every
        # builder entry point re-declares here in Drawer's scope - including
        # the memoized `stimulus` the inherited trigger slot wires its open
        # action through.
        def stimulus
          @stimulus ||= Poetry::Core::Stimulus::Builder.new(CONTROLLER, Poetry::Core::HTML::Attributes.new)
        end

        def stimulus_attributes
          attrs = Poetry::Core::HTML::Attributes.new
          yield Poetry::Core::Stimulus::Builder.new(CONTROLLER, attrs)
          attrs.to_attributes
        end

        def close_action
          Poetry::Core::Stimulus::Builder
            .new(CONTROLLER, Poetry::Core::HTML::Attributes.new)
            .action(:close, on: :click)
        end
      end
    end
  end
end
