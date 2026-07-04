# frozen_string_literal: true

module Poetry
  module Ui
    module Accordion
      # The second first-port (Accordion): presence +
      # roving-focus together. Triggers are real buttons inside headings
      # (APG: Arrow keys move between headers as convenience - every
      # trigger stays tabbable, manageTabindex: false); panels are
      # role=region wired aria-labelledby; single non-collapsible marks
      # the locked-open trigger aria-disabled.
      class Component < Poetry::Core::Component
        ACCORDION = %i[poetry core accordion].freeze
        ROVING = %i[poetry core roving_focus].freeze
        TYPES = %i[single multiple].freeze
        HEADINGS = %i[h2 h3 h4 h5 h6].freeze

        AGENT_RULES = [
          "Items via with_item(value:, title:) { panel content } - value is the open-state key.",
          "type: :single (default) opens one at a time; pass collapsible: true to allow closing it.",
          "Server-render the open item(s) via open: %w[value] - never toggle data-open/data-closed by hand.",
          "heading_level: fits the page outline (h3 default) - the trigger button lives inside it.",
          "The chevron is built in - never add another indicator icon to the trigger."
        ].freeze

        option :type, :symbol, default: :single
        option :collapsible, :boolean, default: false
        option :open, :list, default: -> { [] }
        option :heading_level, :symbol, default: :h3

        validates :type, inclusion: { in: TYPES }
        validates :heading_level, inclusion: { in: HEADINGS }

        renders_many :items, lambda { |value:, title:, **options, &block|
          open_item = open_values.include?(value.to_s)
          item_id = "#{instance_id}-#{value}"
          content_tag(:div, class: css(:item), "data-slot" => "accordion-item",
                            "data-value" => value, (open_item ? "data-open" : "data-closed") => "", **options) do
            safe_join([accordion_header(item_id, title, open_item), accordion_panel(item_id, open_item, &block)])
          end
        }

        def before_render
          raise ArgumentError, "Accordion requires at least one with_item" unless items?
        end

        def open_values
          Array(open).map(&:to_s)
        end

        def root_attributes
          html_attributes.merge_if_not_set(
            { "data-slot" => "accordion", "data-orientation" => "vertical" }
              .merge(root_stimulus_attributes)
              .merge(component_data_attributes)
          )
        end

        private

        def instance_id
          @instance_id ||= "poetry-accordion-#{SecureRandom.hex(4)}"
        end

        def accordion_header(item_id, title, open_item)
          trigger_attrs = {
            type: "button", id: "#{item_id}-trigger", class: css(:trigger),
            # No state attribute on the trigger: the controller reflects only
            # aria-expanded here (the open/closed pair lives on the item and
            # panel) - aria-expanded IS the trigger's styling hook.
            "data-slot" => "accordion-trigger",
            "data-poetry-collection-item" => "",
            "aria-expanded" => open_item.to_s, "aria-controls" => "#{item_id}-panel"
          }.merge(stimulus_attributes(ACCORDION) { |accordion| accordion.with_action(:toggle, on: :click) })
          trigger_attrs["aria-disabled"] = "true" if open_item && type == :single && !collapsible

          content_tag(heading_level, class: css(:header), "data-slot" => "accordion-header") do
            content_tag(:button, trigger_attrs) do
              safe_join([title, chevron])
            end
          end
        end

        def accordion_panel(item_id, open_item, &block)
          attrs = {
            id: "#{item_id}-panel", role: "region", class: css(:content),
            "data-slot" => "accordion-content", (open_item ? "data-open" : "data-closed") => "",
            "aria-labelledby" => "#{item_id}-trigger"
          }
          attrs[:hidden] = true unless open_item
          content_tag(:div, attrs) do
            content_tag(:div, capture(&block), class: css(:inner))
          end
        end

        def chevron
          render(Icon::Component.new(name: :"chevron-down", class: css(:indicator)))
        end

        # BOTH controllers build into ONE Attributes instance - a plain
        # Hash#merge of two would overwrite data-controller instead of
        # token-concatenating it (caught by the render tests).
        def root_stimulus_attributes
          attrs = Poetry::Core::HTML::Attributes.new
          accordion = Poetry::Core::Stimulus::Builder.new(ACCORDION, attrs)
          accordion.register_controller
          accordion.with_value(:type, type)
          accordion.with_value(:collapsible, collapsible)
          roving = Poetry::Core::Stimulus::Builder.new(ROVING, attrs)
          roving.register_controller
          roving.with_value(:orientation, "vertical")
          roving.with_value(:manage_tabindex, false)
          roving.with_action(:keydown, on: :keydown)
          attrs.to_attributes
        end

        def stimulus_attributes(controller)
          attrs = Poetry::Core::HTML::Attributes.new
          yield Poetry::Core::Stimulus::Builder.new(controller, attrs)
          attrs.to_attributes
        end
      end
    end
  end
end
