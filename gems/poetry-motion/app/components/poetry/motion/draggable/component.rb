# frozen_string_literal: true

module Poetry
  module Motion
    module Draggable
      # Content you can pick up and move - a sticker, a playful card. It
      # follows the drag, within its parent's box when bounded:, and springs
      # home on release unless snap_back: false leaves it where it was
      # dropped. Dragging is direct manipulation and works under reduced
      # motion; only the spring home is skipped. Where it lands is not
      # saved: the server renders it in place.
      #
      # @example
      #   <div class="relative h-64">
      #     <%= poetry_draggable(bounded: true) do %><span class="text-4xl">🎉</span><% end %>
      #   </div>
      class Component < Poetry::Core::Component
        include Poetry::Motion::Options

        requires_content "the content that drags"

        # The axes a drag can be locked to.
        AXES = %i[both x y].freeze

        AGENT_RULES = [
          "Dragging is decoration or play here; never the only way to do something. A drag that reorders " \
          "or chooses needs a keyboard and a button path too."
        ].freeze

        use_behavior :drag

        use_stimulus do
          on :root do
            controller :draggable, if: :animate do
              register
              value :axis, from: :axis_name, unless: -> { axis == :both }
              value :bounded, if: :bounded
              value :snap_back, false, unless: :snap_back
              value :spring
            end
          end
        end

        motion_options spring: :snappy
        option :axis, :symbol, default: :both, doc: "both drags freely; x or y locks it to one axis."
        option :bounded, :boolean, default: false, doc: "Keeps the drag inside the parent's box."
        option :snap_back, :boolean, default: true,
                                     doc: "Springs home on release; false leaves it where it was dropped."

        validates :axis, inclusion: { in: AXES }

        part "draggable", "The content that drags",
             states: { "data-dragging" => "a drag is under way" },
             vars: { "--motion-drag-x" => "the drag's x offset, in pixels",
                     "--motion-drag-y" => "the drag's y offset, in pixels" }

        def before_render
          ensure_content!
        end

        def call
          tag.div(content, **root_attributes)
        end

        private

        def axis_name = axis.to_s
      end
    end
  end
end
