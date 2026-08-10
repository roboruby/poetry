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
      # dismissible:, show_close_button:), and the required title. The
      # deltas: the side style (edge-anchored margins replace the parent's
      # m-auto centering) and the source's slide-in animation.
      class Component < Dialog::Component
        SIDES = %i[top right bottom left].freeze

        # W5b commit 1: the Sheet gets its OWN controller - the dialog
        # machinery + the presence-hold close its dictionary was waiting on
        # (the Drawer subclass pattern, minus the swipe).
        # Redeclaring both elements REPLACES Dialog's :dialog controller
        # wholesale (replace-on-redeclare); the inherited trigger lambda and
        # close_action late-bind here through stimulus_action.
        use_stimulus do
          on :root do
            controller :sheet do
              register
              value :dismissible
            end
          end
          on :content do
            controller :sheet do
              target :dialog
              action :close, on: :cancel
              action :backdrop_close, on: :click
            end
          end
          on :trigger do
            controller(:sheet) { action :open }
          end
          on :close do
            controller(:sheet) { action :close }
          end
        end

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
              .merge(stimulus_attributes_for(:root))
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
          }.merge(stimulus_attributes_for(:content))
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
