# frozen_string_literal: true

module Poetry
  module Ui
    module Drawer
      # The Drawer - the gesture overlay: a Sheet-shaped edge dialog you can
      # SWIPE away. Everything hard is inherited (the native <dialog> +
      # showModal() platform trap, required title, dismissible:); the deltas
      # are the poetry--core--drawer controller (the swipe CSS-var contract
      # + the presence-hold animated close - the first consumer of the
      # presence machinery) and the drawer chrome (edge-rounded popup,
      # transition-driven enter/exit, the optional swipe handle).
      #
      # Snap points shipped 2026-08-01 (snap_points:); still deferred with
      # their machinery: nested drawer stacking visuals, bleed.
      #
      # @example
      #   render Poetry::Ui::Drawer::Component.new(show_swipe_handle: true) do |drawer|
      #     drawer.with_trigger { "Open drawer" }
      #     drawer.with_title { "Move goal" }
      #     drawer.with_description { "Set your daily activity goal." }
      #     "Drawer body"
      #   end
      class Component < Dialog::Component
        DIRECTIONS = %i[down up left right].freeze

        SNAP_POINT_LENGTH = /\A\d+(\.\d+)?(px|rem)\z/

        AGENT_RULES = [
          "Open drawers with with_trigger(...) - never a hand-wired button.",
          "with_title is REQUIRED (the accessible name) - the inherited Dialog rule.",
          "direction: is the DISMISS direction: :down is the mobile bottom sheet (the default); " \
          "left/right make an edge panel - prefer Sheet on desktop.",
          "show_swipe_handle: true renders the grab pill - use it on bottom sheets so the " \
          "gesture is discoverable.",
          "Esc and the backdrop still dismiss (the platform trap) - the swipe is an addition, " \
          "never the only way out.",
          "modal: false keeps the page interactive (no scrim, no focus trap) - pair a wired " \
          "footer close; Esc while focus is inside still exits.",
          "snap_points: [\"31rem\", 1] snaps a bottom sheet between preset heights (ascending " \
          "fractions or px/rem lengths; opens at the first) - direction: :down only."
        ].freeze

        # Replace-on-redeclare: both elements re-controller to :drawer;
        # the inherited trigger lambda late-binds through stimulus_action.
        use_stimulus do
          on :root do
            controller :drawer do
              register
              value :dismissible
              value :direction
              value :modal
              value :snap_points, from: :snap_points_json, if: -> { snap_points.present? }
            end
          end
          on :content do
            controller :drawer do
              target :dialog
              action :close, on: :cancel
              action :backdrop_close, on: :click
              # A non-modal dialog never fires cancel - Esc rides its own
              # keydown exit (guarded controller-side to modal: false).
              action :escape_close, on: :keydown, unless: :modal
              action :swipe_start, on: :pointerdown
              action :swipe_move, on: :pointermove
              action :swipe_end, on: :pointerup
              action :swipe_cancel, on: :pointercancel
            end
          end
          on :trigger do
            controller(:drawer) { action :open }
          end
          # The Drawer renders no corner close button - an empty
          # redeclaration ERASES Dialog's inherited :close element (and
          # with it the dialog identifier that would make unqualified
          # stimulus_action ambiguous).
          on :close
        end

        # The dismissal direction (the Base UI swipeDirection vocabulary);
        # the edge chrome + swipe axis derive from it.
        style :direction, default: :down, required: true, variants: DIRECTIONS

        option :show_swipe_handle, :boolean, default: false

        # Source parity: modal={false}. Non-modal opens with show() - no
        # top layer, no scrim, no focus trap, no scroll lock; the page
        # behind stays interactive. Esc (while focus is inside), the
        # swipe, and any wired close button still exit; there is no
        # backdrop to click, so pointer dismissal is off by nature.
        option :modal, :boolean, default: true

        # Source parity: snapPoints - preset resting heights for a bottom
        # sheet, ascending: fractions of the full height (0..1] or CSS
        # px/rem lengths (the source's ["31rem", 1]). The popup runs
        # full-height and opens at the first point; drags move between
        # points, below the first dismisses. direction: :down only.
        option :snap_points, ActiveModel::Type::Value.new

        part "drawer", "Root wrapper around the trigger and the <dialog> element"
        part "drawer-content", "The <dialog> popup - the edge chrome, presence animation, and " \
                               "the swipe contract all ride here (::backdrop inherits the " \
                               "swipe vars, so the overlay fade rides along)",
             states: {
               "data-open" => "popup is open (the controller flips the pair at runtime)",
               "data-closed" => "popup is closed or animating out (the server-rendered state)",
               "data-swipe-direction" => { condition: "always - the dismiss direction",
                                           values: DIRECTIONS.map(&:to_s) },
               "data-swiping" => "a pointer drag is tracking (transitions go duration-0 - the " \
                                 "drawer follows the finger)",
               "data-snap-points" => "snap_points: present - the popup runs full-height and " \
                                     "--drawer-snap-point-offset rests it at the current point",
               "data-starting-style" => "the enter transition's first frame (the presence " \
                                        "helper's two-frame trick)",
               "data-ending-style" => "held through the exit transition before the native " \
                                      "close()"
             },
             vars: {
               "--drawer-swipe-movement-x" => "px dragged toward a left/right dismissal " \
                                              "(controller-written during swipes)",
               "--drawer-swipe-movement-y" => "px dragged toward an up/down dismissal " \
                                              "(controller-written during swipes)",
               "--drawer-swipe-progress" => "0..1 fraction of the dismiss travel (the backdrop " \
                                            "fade rides it)",
               "--drawer-swipe-strength" => "remaining-travel factor set on release - scales " \
                                            "the exit duration so a mostly-swiped drawer " \
                                            "closes fast"
             }
        part "drawer-swipe-handle", "The grab pill (show_swipe_handle: true, aria-hidden) - a " \
                                    "drag may always start on it"
        part "drawer-header", "Title block at the top of the popup"
        part "drawer-title", "The heading - the drawer's accessible name (required slot)"
        part "drawer-description", "Muted copy under the title, wired to aria-describedby"
        part "drawer-body", "The scrollable content region between header and footer"
        part "drawer-footer", "Action row pinned to the bottom of the popup"

        def before_render
          raise ArgumentError, "Drawer requires with_title (the accessible name)" unless title?

          validate_snap_points! if snap_points.present?
        end

        # The parent's show_close_button does not apply: a Drawer has no
        # corner X (source parity - the source closes by swipe, backdrop,
        # or footer actions), so the inherited option is hidden from
        # introspection. A projected option the template ignores would be
        # a contract lie.
        def self.option_attributes
          super - %i[show_close_button]
        end

        def root_attributes
          html_attributes.merge_if_not_set(
            { "data-slot" => "drawer" }
              .merge(stimulus_attributes_for(:root))
              .merge(component_data_attributes)
          )
        end

        # The <dialog> IS the drawer popup: the chrome + swipe wiring land
        # here. The swipe vars are written to this element by the controller
        # and ::backdrop inherits them (the overlay fade rides along).
        def dialog_attributes
          attrs = {
            # Non-modal show() skips the top layer, so the UA :modal
            # positioning (fixed + inset:0) must be re-stated explicitly -
            # the direction margins and over-constraint sizing then work
            # exactly as they do in the top layer.
            "class" => css(:content, class: [Style.direction(direction),
                                             (css(:nonmodal) unless modal)].compact.join(" ")),
            "data-slot" => "drawer-content",
            "data-swipe-direction" => direction,
            "data-closed" => "",
            "aria-labelledby" => title_id
          }.merge(stimulus_attributes_for(:content))
          # The attribute drives the dictionary's full-height sizing; the
          # controller reads the value for the offset physics.
          attrs["data-snap-points"] = "" if snap_points.present?
          attrs["aria-describedby"] = description_id if description?
          attrs
        end

        private

        def validate_snap_points!
          unless direction == :down
            raise ArgumentError, "Drawer snap_points: is a bottom-sheet recipe - direction: :down only"
          end

          valid = snap_points.is_a?(Array) && snap_points.any? && snap_points.all? do |point|
            (point.is_a?(Numeric) && point.positive? && point <= 1) ||
              (point.is_a?(String) && point.match?(SNAP_POINT_LENGTH))
          end
          return if valid

          raise ArgumentError, "Drawer snap_points: entries are fractions in (0, 1] or CSS " \
                               'px/rem lengths ("31rem", "400px"), ascending'
        end

        # Host-facing close descriptor (no template consumer) - the
        # explicit click event preserved from the pre-declaration shape.
        def close_action
          stimulus_action(:close, on: :click)
        end

        def snap_points_json = snap_points.to_json
      end
    end
  end
end
