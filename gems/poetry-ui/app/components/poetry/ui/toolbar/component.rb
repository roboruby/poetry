# frozen_string_literal: true

module Poetry
  module Ui
    # Single-Tab-stop control strips.
    module Toolbar
      # One Tab stop of grouped controls over a data surface - bulk
      # actions above a table, an editor's control strip. The root wears
      # role=toolbar; the typed slots render real Buttons, Inputs, and
      # Separators, and arrow keys move between them while Tab leaves the
      # whole strip. An Input inside stays safe to edit: horizontal
      # arrows stay with the text caret until it reaches a boundary.
      #
      # label: is required - screen readers announce it on entering the
      # toolbar. Styling is utility-only; restyle via data-slot=toolbar.
      #
      # @example
      #   render Poetry::Ui::Toolbar::Component.new(label: "Bulk actions") do |toolbar|
      #     toolbar.with_button(variant: :outline) { "Archive" }
      #     toolbar.with_separator
      #     toolbar.with_input(name: "q", placeholder: "Filter…")
      #   end
      class Component < Poetry::Core::Component
        # The roving-focus controller's identifier path.
        ROVING = %i[poetry core roving_focus].freeze

        # Projected into the registry, llms.txt, and the agent surface.
        AGENT_RULES = [
          "A Toolbar is ONE Tab stop: arrows move between its controls - use it for grouped " \
          "actions over a surface (table bulk actions, editor strips), never as page navigation.",
          "Compose through the typed slots: with_button (a real poetry Button - tag: :a makes it " \
          "a link), with_input (search/filter - the caret keeps its arrow keys), with_separator " \
          "(orientation flips automatically).",
          "label: is the toolbar's accessible name and is required - screen readers announce it " \
          "on entry.",
          "A ToggleGroup composed inside keeps its own arrow navigation (its items rove locally); " \
          "place it between separators so the seam reads as a group."
        ].freeze

        # The same fact the before_render raise enforces, stated
        # statically: poetry check flags the omission without rendering.
        REQUIRED_SLOTS = { button: "at least one control (with_button / with_input)" }.freeze

        renders_many :items,
                     doc: "The control slots: with_button (a real Button - tag: :a makes it a link), with_input " \
                          "(search/filter), with_separator (its orientation flips automatically).",
                     types: {
                       button: {
                         renders: ->(**options) { Poetry::Ui::Button::Component.new(**item_options(options)) },
                         as: :button
                       },
                       input: {
                         renders: ->(**options) { Poetry::Ui::Input::Component.new(**item_options(options)) },
                         as: :input
                       },
                       separator: {
                         renders: lambda { |**options|
                           Poetry::Ui::Separator::Component.new(
                             orientation: orientation == :horizontal ? :vertical : :horizontal,
                             class: "self-stretch", **options
                           )
                         },
                         as: :separator
                       }
                     }

        style :orientation, default: :horizontal, variants: %i[horizontal vertical],
                            doc: "The strip's axis; :vertical stacks the controls and flips the arrow keys."

        option :label, :string, required: true, doc: "The toolbar's accessible name. Required."
        option :loop, :boolean, default: true, doc: "Whether arrow navigation wraps at the ends."

        part "toolbar", "The role=toolbar root - one Tab stop; arrow keys rove across the " \
                        "slotted controls (roving-focus, with the caret guard protecting inputs)",
             states: {
               "data-orientation" => { condition: "always - which arrows rove",
                                       values: %w[horizontal vertical] }
             }

        # @api private
        def before_render
          raise ArgumentError, "Toolbar requires at least one control slot" unless items?
        end

        # @api private
        def call
          content_tag(:div, safe_join(items.map(&:to_s)), **root_attributes.to_attributes)
        end

        # @api private
        def root_attributes
          html_attributes.merge_if_not_set(
            {
              "role" => "toolbar", "aria-label" => label, "aria-orientation" => orientation,
              "data-slot" => "toolbar", "data-orientation" => orientation
            }.merge(component_data_attributes).merge(roving_attributes)
          )
        end

        private

        # Every slotted control is a roving collection item; a disabled one
        # is filtered from the collection (the tabs idiom - roving reads
        # data-disabled, the native attribute alone is invisible to it).
        def item_options(options)
          extra = { "data-poetry-collection-item" => "" }
          extra["data-disabled"] = "" if options[:disabled]
          options.merge(extra)
        end

        def roving_attributes
          attrs = Poetry::Core::HTML::Attributes.new
          roving = Poetry::Core::Stimulus::Builder.new(ROVING, attrs)
          roving.register_controller
          roving.with_value(:orientation, orientation)
          roving.with_value(:loop, loop)
          roving.with_action(:keydown, on: :keydown)
          attrs.to_attributes
        end

        private :root_attributes
      end
    end
  end
end
