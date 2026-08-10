# frozen_string_literal: true

module Poetry
  module Ui
    module Resizable
      # The Resizable panel group - the APG window splitter on flex (the W4
      # decision: no react-resizable-panels): panels are flex children whose
      # flex-grow IS the percentage, handles are role=separator splitters,
      # and poetry--core--resizable owns the drag + keyboard redistribution.
      # Declare panels with with_panel; the component interleaves the
      # handles and wires the ARIA.
      #
      # Deferred with the library's machinery: persistence, collapsible
      # panels, the imperative API.
      class Component < Poetry::Core::Component
        DIRECTIONS = %i[horizontal vertical].freeze

        AGENT_RULES = [
          "Declare panels with with_panel(default_size:, min_size:, max_size:) - sizes are " \
          "PERCENTAGES and the component interleaves the separator handles.",
          "direction: :horizontal is side-by-side (the default); :vertical stacks.",
          "Handles are keyboard splitters (arrows step, Home/End jump) - never replace them " \
          "with styled divs.",
          "Nest a group inside a panel for two-axis layouts - groups self-scope."
        ].freeze

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

        option :direction, :symbol, default: :horizontal
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

        Panel = Data.define(:default_size, :min_size, :max_size, :classes, :block)

        # The lambda's raise, declared (the SLOT_BUILDERS pattern): poetry
        # check states the same requirement statically.
        SLOT_REQUIRED_CONTENT = { panel: "the panel content" }.freeze

        renders_many :panels, lambda { |default_size: nil, min_size: nil, max_size: nil, classes: nil, &block|
          raise ArgumentError, "Resizable with_panel requires a content block (the panel content)" unless block

          panel_defs << Panel.new(default_size: default_size, min_size: min_size,
                                  max_size: max_size, classes: classes, block: block)
          nil
        }

        def panel_defs
          @panel_defs ||= []
        end

        # The same facts the before_render raise enforces, stated statically
        #: poetry check flags the omission without rendering (the
        # menu crash class - required slots the contract kept silent).
        REQUIRED_SLOTS = { panel: "at least two panels" }.freeze

        def before_render
          # panels? forces the render block (the slot-predicate rule -
          # panel_defs is empty until it runs).
          raise ArgumentError, "Resizable requires at least two with_panel declarations" unless
            panels? && panel_defs.size >= 2
        end

        # Even shares when default_size: is omitted.
        def size_of(panel)
          panel.default_size || (100.0 / panel_defs.size).round(2)
        end

        def root_attributes
          html_attributes.merge_if_not_set(
            {
              "data-slot" => "resizable-panel-group", "data-orientation" => direction
            }.merge(stimulus_attributes_for(:root)).merge(component_data_attributes)
          )
        end

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

        # The splitter: a separator whose value tracks the PRECEDING panel
        # (the upstream convention); its visual orientation is
        # PERPENDICULAR to the group axis (a side-by-side group has a
        # vertical bar), which is also what the dictionary's
        # aria-[orientation] selectors key on.
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
            "aria-valuemin" => before.min_size || 10,
            "aria-valuemax" => before.max_size || 90,
            "class" => css(:handle)
          }.merge(stimulus_attributes_for(:handle))
        end

        def panel_id(index)
          "#{instance_id}-panel-#{index}"
        end

        private

        def instance_id
          @instance_id ||= "poetry-resizable-#{SecureRandom.hex(4)}"
        end
      end
    end
  end
end
