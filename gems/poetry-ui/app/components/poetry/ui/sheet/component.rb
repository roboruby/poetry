# frozen_string_literal: true

module Poetry
  module Ui
    module Sheet
      # The Sheet - the shipped Dialog re-skinned to slide in from a screen
      # edge, exactly the move shadcn makes one layer up (its sheet.tsx is
      # Radix Dialog re-exported). Everything hard is INHERITED: the native
      # <dialog> + showModal() platform trap (focus trap, Esc, top layer,
      # focus return), the poetry--core--dialog controller (the data-open/
      # data-closed pair,
      # coordinate-discriminated backdrop dismissal, scroll lock,
      # dismissible:), and the required title. The deltas: the side style
      # (edge-anchored margins replace the parent's m-auto centering), the
      # source's slide-in animation, and show_close_button.
      class Component < Dialog::Component
        SIDES = %i[top right bottom left].freeze

        # W5b commit 1: the Sheet gets its OWN controller - the dialog
        # machinery + the presence-hold close its dictionary was waiting on
        # (the Drawer subclass pattern, minus the swipe).
        CONTROLLER = %i[poetry core sheet].freeze

        AGENT_RULES = [
          "Open sheets with with_trigger(...) - never a hand-wired button.",
          "with_title is REQUIRED (the accessible name) - the inherited Dialog rule.",
          "Pick side by content: navigation left, detail/edit right, pickers bottom.",
          "Do not put must-not-lose confirmations in a Sheet - that is AlertDialog.",
          "Do not rebuild a centered Dialog with a Sheet; use Dialog."
        ].freeze

        # THE Sheet delta - a physical direction (source parity: right
        # stays right in RTL).
        style :side, default: :right, required: true, variants: SIDES

        # Source parity: showCloseButton.
        option :show_close_button, :boolean, default: true

        part "sheet", "Root wrapper around the trigger and the <dialog> element"
        part "sheet-content", "The <dialog> panel, anchored to a screen edge - the slide " \
                              "animation and the open state ride here",
             states: {
               "data-open" => "panel is open (the controller flips the pair at runtime)",
               "data-closed" => "panel is closed or animating out (the server-rendered state; " \
                                "the presence-hold close rides the closed slide-out)",
               "data-side" => { condition: "always - the edge the sheet slides in from",
                                values: SIDES.map(&:to_s) }
             }
        part "sheet-header", "Title block at the top of the panel"
        part "sheet-title", "The heading - the sheet's accessible name (required slot)"
        part "sheet-description", "Muted copy under the title, wired to aria-describedby"
        part "sheet-footer", "Action row pinned to the bottom of the panel"

        def before_render
          raise ArgumentError, "Sheet requires with_title (the accessible name)" unless title?
        end

        def root_attributes
          html_attributes.merge_if_not_set(
            { "data-slot" => "sheet" }
              .merge(stimulus_attributes do |dialog|
                dialog.register_controller
                dialog.with_value(:dismissible, dismissible)
              end)
              .merge(component_data_attributes)
          )
        end

        # The parent's <dialog> wiring with the Sheet deltas: the slot
        # rename, the data-side stamp, and the side's edge classes (the
        # resolver applies variants only at the dictionary root; the
        # Sheet's visual root IS the :content element, so the side branch
        # merges in here).
        def dialog_attributes
          attrs = {
            "class" => css(:content, class: Style.side(side)),
            "data-slot" => "sheet-content",
            "data-side" => side,
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

        private

        # The Dialog parent resolves its CONTROLLER lexically, so every
        # builder entry point re-declares here in Sheet's scope (the Drawer
        # subclass lesson, test-pinned there).
        def stimulus
          @stimulus ||= Poetry::Core::Stimulus::Builder.new(CONTROLLER, Poetry::Core::HTML::Attributes.new)
        end

        def stimulus_attributes
          attrs = Poetry::Core::HTML::Attributes.new
          yield Poetry::Core::Stimulus::Builder.new(CONTROLLER, attrs)
          attrs.to_attributes
        end

        def close_action
          stimulus.action(:close)
        end

        # Sheet-scoped label ids (two overlays on a page never collide).
        def instance_id
          @instance_id ||= "poetry-sheet-#{SecureRandom.hex(4)}"
        end
      end
    end
  end
end
