# frozen_string_literal: true

module Poetry
  module Ui
    # A modal panel that slides in from a screen edge.
    module Sheet
      # A modal panel that slides in from a screen edge - navigation on
      # the left, detail/edit panels on the right, pickers on the bottom.
      # A re-skinned Dialog, so everything hard is INHERITED: the native
      # <dialog> + showModal() platform behavior (focus trap, Esc, top
      # layer, focus return), the data-open/data-closed pair, backdrop
      # dismissal, scroll lock, dismissible:, show_close_button:, and the
      # required title. The deltas: the side style (edge-anchored margins
      # replace the parent's centering) and the slide-in animation.
      #
      # @example
      #   render Poetry::Ui::Sheet::Component.new(side: :right) do |sheet|
      #     sheet.with_trigger { "Edit profile" }
      #     sheet.with_title { "Edit profile" }
      #     "Sheet body"
      #   end
      class Component < Dialog::Component
        # The closed vocabulary for the side style axis.
        SIDES = %i[top right bottom left].freeze

        # Projected into the registry, llms.txt, and the agent surface.
        AGENT_RULES = [
          "Open sheets with with_trigger(...) - never a hand-wired button.",
          "with_title is REQUIRED (the accessible name) - the inherited Dialog rule.",
          "Pick side by content: navigation left, detail/edit right, pickers bottom.",
          "Do not put must-not-lose confirmations in a Sheet - that is AlertDialog.",
          "Do not rebuild a centered Dialog with a Sheet; use Dialog."
        ].freeze

        # The Sheet gets its OWN controller - the dialog machinery plus
        # the presence-hold close (the closed slide-out finishes before
        # the panel hides).
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

        style :side, default: :right, required: true, variants: SIDES,
                     doc: "The edge the sheet slides in from - a physical direction (right stays right in RTL)."

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

        private

        # The Sheet deltas on the inherited panel: the side's edge classes
        # (the resolver applies variants only at the dictionary root; the
        # Sheet's visual root IS the :content element, so the side branch
        # merges in here) and the data-side stamp.
        def panel_classes
          [Style.side(side), content_class]
        end

        def panel_stamps
          { "data-side" => side }
        end
      end
    end
  end
end
