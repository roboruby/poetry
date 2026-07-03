# frozen_string_literal: true

module Poetry
  module Ui
    module Sheet
      # The Sheet - the shipped Dialog re-skinned to slide in from a screen
      # edge, exactly the move shadcn makes one layer up (its sheet.tsx is
      # Radix Dialog re-exported). Everything hard is INHERITED: the native
      # <dialog> + showModal() platform trap (focus trap, Esc, top layer,
      # focus return), the poetry--core--dialog controller (data-state,
      # coordinate-discriminated backdrop dismissal, scroll lock,
      # dismissible:), and the required title. The deltas: the side style
      # (edge-anchored margins replace the parent's m-auto centering), the
      # source's slide-in animation, and show_close_button.
      class Component < Dialog::Component
        SIDES = %i[top right bottom left].freeze

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
            "data-state" => "closed",
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

        # Sheet-scoped label ids (two overlays on a page never collide).
        def instance_id
          @instance_id ||= "poetry-sheet-#{SecureRandom.hex(4)}"
        end
      end
    end
  end
end
