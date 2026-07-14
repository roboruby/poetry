# frozen_string_literal: true

module Poetry
  module Ui
    module Toaster
      # The controller identifier, declared ONCE (Builder-validated).
      TOASTER = %i[poetry core toaster].freeze
      POSITIONS = %i[top-left top-center top-right bottom-left bottom-center bottom-right].freeze

      # The toast viewport (Toast): a labeled
      # role=region <ol> rendered ONCE in the layout - the Turbo Stream
      # append target (id=poetry-toaster, data-turbo-permanent: toasts
      # survive Drive visits, so flash-after-redirect stays visible). The
      # poetry--core--toaster controller acquires the announce singleton
      # for its lifetime, owns the F8 hotkey (focus to the most recent
      # toast; prior focus remembered for the dismiss return), enforces
      # the visible limit (overflow queues hidden with timers held), and
      # writes the stack reflow index (--poetry-toast-index).
      #
      # THE RAILS-NATIVE PATH (core): server code appends toasts with
      # turbo_stream.poetry_toast(title: "Saved", variant: :success) -
      # from controller responses, form streams, and
      # Turbo::StreamsChannel.broadcast_append_to in jobs.
      #
      # THE FLASH -> TOAST RECIPE (documented, opt-in - apps own their
      # flash semantics): render the mapping next to the toaster in the
      # application layout; stream responses skip flash and append.
      #
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

        AGENT_RULES = [
          "Exactly ONE poetry_toaster per layout; it is data-turbo-permanent.",
          "Server-side toasts go through turbo_stream.poetry_toast / the flash recipe - never " \
          "hand-append into #poetry-toaster.",
          "Do not announce() toast content yourself - the toast controller already does; " \
          "double-announcing is a regression."
        ].freeze

        # On the TOASTER, not the toast (the region owns the corner).
        style :position, default: :"bottom-right", required: true, variants: POSITIONS

        option :hotkey, :string, default: "F8"
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
            }.merge(toaster_stimulus_attributes).merge(component_data_attributes)
          )
        end

        private

        # The controller wires its own window-keydown (hotkey) and dismiss
        # listeners in connect - values only, no data-action needed.
        def toaster_stimulus_attributes
          attrs = Poetry::Core::HTML::Attributes.new
          toaster = Poetry::Core::Stimulus::Builder.new(TOASTER, attrs)
          toaster.register_controller
          toaster.with_value(:hotkey, hotkey)
          toaster.with_value(:limit, limit)
          toaster.with_value(:position, position)
          attrs.to_attributes
        end
      end
    end
  end
end
