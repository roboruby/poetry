# frozen_string_literal: true

module Poetry
  module Ui
    # A panel group divided by draggable splitter handles.
    module Resizable
      # A group of panels - side by side or stacked - divided by draggable
      # splitter handles, so the reader can redistribute the space. Panels
      # are flex children whose flex-grow IS the percentage, handles are
      # role=separator splitters with full keyboard support (arrows step,
      # Home/End jump), and the controller owns the drag + keyboard
      # redistribution. Declare panels with with_panel; the component
      # interleaves the handles and wires the ARIA.
      #
      # @example
      #   render Poetry::Ui::Resizable::Component.new(class: "h-48 rounded-lg border") do |group|
      #     group.with_panel(default_size: 25) { tag.div("Sidebar") }
      #     group.with_panel { tag.div("Content") }
      #   end
      class Component < Poetry::Core::Component
        # The closed vocabulary for the group-axis option.
        DIRECTIONS = %i[horizontal vertical].freeze

        # Projected into the registry, llms.txt, and the agent surface.
        AGENT_RULES = [
          "Declare panels with with_panel(default_size:, min_size:, max_size:) - sizes are " \
          "PERCENTAGES and the component interleaves the separator handles.",
          "direction: :horizontal is side-by-side (the default); :vertical stacks.",
          "Handles are keyboard splitters (arrows step, Home/End jump) - never replace them " \
          "with styled divs.",
          "Nest a group inside a panel for two-axis layouts - groups self-scope."
        ].freeze

        # The with_panel content-block requirement, stated statically for
        # static checks.
        SLOT_REQUIRED_CONTENT = { panel: "the panel content" }.freeze

        # The same facts the before_render raise enforces, stated statically
        # so static checks can flag too few panels without rendering.
        REQUIRED_SLOTS = { panel: "at least two panels" }.freeze

        # One panel per call: default_size/min_size/max_size are
        # percentages of the group; the content block is required.
        renders_many :panels, lambda { |default_size: nil, min_size: nil, max_size: nil, classes: nil, &block|
          raise ArgumentError, "Resizable with_panel requires a content block (the panel content)" unless block

          panel_defs << Panel.new(default_size: default_size, min_size: min_size,
                                  max_size: max_size, classes: classes, block: block)
          nil
        }

        use_stimulus do
          on :root do
            controller :resizable do
              register
              value :orientation, from: :direction
            end
          end
          # The full drag trio + keyboard on each handle; panels are found
          # by DOM position (no targets).
          on :handle do
            controller :resizable do
              action :drag_start, on: :pointerdown
              action :drag_move, on: :pointermove
              action :drag_end, on: :pointerup
              action :keydown, on: :keydown
            end
          end
        end

        # The group axis: :horizontal lays panels side by side, :vertical
        # stacks them.
        option :direction, :symbol, default: :horizontal
        # Renders the grip dots on each handle.
        option :grip, :boolean, default: false

        validates :direction, inclusion: { in: DIRECTIONS }

        part "resizable-panel-group", "The flex group root - the splitter controller rides here",
             states: {
               "data-orientation" => { condition: "the group axis", values: DIRECTIONS.map(&:to_s) }
             }
        part "resizable-panel", "One flex child whose flex-grow IS its percentage - the controller " \
                                "rewrites the inline flex on every resize",
             states: {
               "data-min-size" => "the panel's minimum percentage, rendered when with_panel passes " \
                                  "min_size: (the controller's clamp floor)",
               "data-max-size" => "the panel's maximum percentage, rendered when with_panel passes " \
                                  "max_size: (the controller's clamp ceiling)"
             }
        part "resizable-handle", "The role=separator splitter between panels - drag and keyboard " \
                                 "resizing live here; its aria-valuenow tracks the preceding panel"

        # @api private
        def before_render
          # panels? forces the render block (the slot-predicate rule -
          # panel_defs is empty until it runs).
          raise ArgumentError, "Resizable requires at least two with_panel declarations" unless
            panels? && panel_defs.size >= 2
        end

        # @api private
        def panel_defs
          @panel_defs ||= []
        end

        # Even shares when default_size: is omitted.
        # @api private
        def size_of(panel)
          panel.default_size || (100.0 / panel_defs.size).round(2)
        end

        # @api private
        def root_attributes
          html_attributes.merge_if_not_set(
            {
              "data-slot" => "resizable-panel-group", "data-orientation" => direction
            }.merge(stimulus_attributes_for(:root)).merge(component_data_attributes)
          )
        end

        # @api private
        def panel_attributes(panel, index)
          attrs = {
            "id" => panel_id(index), "data-slot" => "resizable-panel",
            "class" => [css(:panel), panel.classes].compact.join(" "),
            "style" => "flex: #{size_of(panel)} 1 0px"
          }
          attrs["data-min-size"] = panel.min_size if panel.min_size
          attrs["data-max-size"] = panel.max_size if panel.max_size
          attrs
        end

        # The splitter: a separator whose value tracks the PRECEDING
        # panel; its visual orientation is PERPENDICULAR to the group axis
        # (a side-by-side group has a vertical bar), which is also what
        # the dictionary's aria-[orientation] selectors key on.
        # @api private
        def handle_attributes(index)
          before = panel_defs[index]
          {
            "role" => "separator", "tabindex" => "0",
            "data-slot" => "resizable-handle",
            "aria-orientation" => direction == :horizontal ? "vertical" : "horizontal",
            "aria-controls" => panel_id(index),
            # Server-rendered initial value (the controller reconciles on
            # connect) - the splitter announces even before JS.
            "aria-valuenow" => size_of(before).round,
            # The announced bounds fall back to 10/90 percent when the
            # panel declares no min_size:/max_size: clamp.
            "aria-valuemin" => before.min_size || 10,
            "aria-valuemax" => before.max_size || 90,
            "class" => css(:handle)
          }.merge(stimulus_attributes_for(:handle))
        end

        # @api private
        def panel_id(index)
          "#{instance_id}-panel-#{index}"
        end

        # One declared panel: its size bounds, extra classes, and content block.
        # @api private
        Panel = Data.define(:default_size, :min_size, :max_size, :classes, :block)

        private

        def instance_id
          @instance_id ||= poetry_instance_id("poetry-resizable")
        end
      end
    end
  end
end
