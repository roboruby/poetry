# frozen_string_literal: true

module Poetry
  module Ui
    # The toast viewport.
    module Toaster
      # The closed vocabulary for the corner axis.
      POSITIONS = %i[top-left top-center top-right bottom-left bottom-center bottom-right].freeze

      # The toast viewport: a labeled role=region list rendered once in
      # the layout, and the append target for streamed toasts
      # (id=poetry-toaster). It is data-turbo-permanent - toasts survive
      # Drive visits, so flash-after-redirect stays visible. The region
      # owns the hotkey (F8 by default: focus the most recent toast, with
      # prior focus restored after dismiss), enforces the visible limit
      # (overflow queues hidden with timers held), and keeps the stack's
      # positions as toasts come and go.
      #
      # Server code appends toasts with turbo_stream.poetry_toast(title:
      # "Saved", variant: :success) - from controller responses, form
      # streams, and broadcasts. To surface Rails flash as toasts, render
      # the mapping next to the toaster in the layout (see the example).
      #
      # @example The flash -> toast mapping in the layout
      #   <%= poetry_toaster do %>
      #     <% flash.each do |kind, message| %>
      #       <%= poetry_toast(variant: kind.to_s == "alert" ? :destructive : :default) do |toast| %>
      #         <% toast.with_title { message } %>
      #       <% end %>
      #     <% end %>
      #   <% end %>
      class Component < Poetry::Core::Component
        # The stream append target (the turbo_stream.poetry_toast default).
        DEFAULT_ID = "poetry-toaster"

        # Projected into the registry, llms.txt, and the agent surface.
        AGENT_RULES = [
          "Exactly ONE poetry_toaster per layout; it is data-turbo-permanent.",
          "Server-side toasts go through turbo_stream.poetry_toast / the flash recipe - never " \
          "hand-append into #poetry-toaster.",
          "Client-side (no round-trip) toasts go through poetry_toast_trigger(template:) + a " \
          "<template> holding the rendered poetry_toast - the trigger stamps it into the region.",
          "Do not announce() toast content yourself - the toast controller already does; " \
          "double-announcing is a regression."
        ].freeze

        # Values only, zero actions: the controller wires its own
        # window-keydown (hotkey) and dismiss listeners in connect.
        use_stimulus do
          on :root do
            controller :toaster do
              register
              value :hotkey
              value :limit
              value :position
            end
          end
        end

        # The stack's corner - set here, not per toast; each toast's slide
        # direction follows it.
        style :position, default: :"bottom-right", required: true, variants: POSITIONS

        # The keyboard shortcut that focuses the most recent toast.
        option :hotkey, :string, default: "F8"
        # The maximum visible toasts; overflow queues hidden with timers held.
        option :limit, :integer, default: 3

        part "toaster", "The toast viewport itself (<ol>, role=region, data-turbo-permanent) - " \
                        "the corner geometry and the Turbo Stream append target ride here",
             states: {
               "data-position" => { condition: "always - the corner; each toast's slide " \
                                               "direction keys off it via group/toaster",
                                    values: POSITIONS.map(&:to_s) },
               "data-poetry-top-layer" => { condition: "always - the dismissal layer exempts " \
                                                       "presses here, so clicking a toast never " \
                                                       "dismisses the overlay under it" }
             }

        # @api private
        def root_attributes
          html_attributes.merge_if_not_set(
            {
              "id" => DEFAULT_ID, "data-slot" => "toaster",
              "role" => "region", "aria-label" => t("poetry.toast.region_label", hotkey: hotkey),
              "tabindex" => "-1", "data-turbo-permanent" => "",
              # The dismissal layer's top-layer exemption: presses inside
              # the toaster are never "outside" an open overlay.
              "data-poetry-top-layer" => "",
              # The toast items key their slide direction on this via the
              # group-data selector (items render independently of the
              # region - a streamed toast cannot know the corner).
              "data-position" => position
            }.merge(stimulus_attributes_for(:root)).merge(component_data_attributes)
          )
        end
      end
    end
  end
end
