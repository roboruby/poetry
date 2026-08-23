# frozen_string_literal: true

module Poetry
  module Ui
    module Toolbar
      # The Toolbar - one Tab stop of grouped controls over a data surface
      # (bulk actions above a table, an editor's control strip). Base UI
      # ships Toolbar; poetry composes it from existing vocabulary: the
      # root wears
      # role=toolbar + the roving-focus engine, and the typed slots render
      # real Buttons / Inputs / Separators stamped as collection items -
      # arrows move between controls, Tab leaves the whole strip. The
      # roving caret guard is what makes an Input inside a toolbar
      # safe: horizontal arrows stay with the caret until its boundary.
      # Styling is utility-only (the Separator/Spinner rule).
      #
      # @example
      #   render Poetry::Ui::Toolbar::Component.new(label: "Bulk actions") do |toolbar|
      #     toolbar.with_button(variant: :outline) { "Archive" }
      #     toolbar.with_separator
      #     toolbar.with_input(name: "q", placeholder: "Filter…")
      #   end
      class Component < Poetry::Core::Component
        ROVING = %i[poetry core roving_focus].freeze

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

        renders_many :items, types: {
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

        style :orientation, default: :horizontal, variants: %i[horizontal vertical]

        option :label, :string, required: true
        option :loop, :boolean, default: true

        part "toolbar", "The role=toolbar root - one Tab stop; arrow keys rove across the " \
                        "slotted controls (roving-focus, with the caret guard protecting inputs)",
             states: {
               "data-orientation" => { condition: "always - which arrows rove",
                                       values: %w[horizontal vertical] }
             }

        def before_render
          raise ArgumentError, "Toolbar requires at least one control slot" unless items?
        end

        def call
          content_tag(:div, safe_join(items.map(&:to_s)), **root_attributes.to_attributes)
        end

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
      end
    end
  end
end
