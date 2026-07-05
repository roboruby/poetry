# frozen_string_literal: true

module Poetry
  module Ui
    module NavigationMenu
      # The NavigationMenu - a site-nav DISCLOSURE BAR (never a menu role):
      # top-level links and hoverable/clickable triggers whose panels open
      # under their items. The W4 decision's viewport=false mode: each panel
      # is its own popup on the presence machinery, positioned inside its
      # relative item; the Base UI morphing shared viewport is deferred.
      #
      #   <%= poetry_navigation_menu(label: "Main") do |nav| %>
      #     <% nav.with_item("Products", value: "products") do %>
      #       <%= poetry_navigation_menu_link(href: products_path) { "All products" } %>
      #     <% end %>
      #     <% nav.with_link("Docs", href: docs_path) %>
      #   <% end %>
      class Component < Poetry::Core::Component
        AGENT_RULES = [
          "label: is REQUIRED (the nav landmark's accessible name).",
          "with_item(title, value:) declares a trigger + panel; with_link(title, href:) is a " \
          "top-level destination - use links for pages, panels for groups of links.",
          "Panel content is poetry_navigation_menu_link entries (active: marks the current page) - " \
          "never buttons; navigation navigates.",
          "This is a DISCLOSURE bar: Tab moves through it normally and nothing traps - do not " \
          "wire menu/menuitem roles."
        ].freeze

        CONTROLLER = %i[poetry core navigation_menu].freeze

        option :label, :string

        Entry = Data.define(:title, :value, :href, :panel)

        renders_many :items, lambda { |title, value: nil, href: nil, &panel|
          if href.nil? && panel.nil?
            raise ArgumentError, "NavigationMenu item #{title.inspect} needs href: (a link) or a panel block"
          end

          entries << Entry.new(title: title, value: value&.to_s || title.to_s.parameterize, href: href,
                               panel: panel)
          nil
        }

        def with_link(title, href:)
          with_item(title, href: href)
        end

        def entries
          @entries ||= []
        end

        def before_render
          raise ArgumentError, "NavigationMenu requires label: (the nav landmark's name)" if label.blank?
          raise ArgumentError, "NavigationMenu requires at least one with_item or with_link" unless items?
        end

        def root_attributes
          html_attributes.merge_if_not_set(
            {
              "aria-label" => label, "data-slot" => "navigation-menu",
              # The mode marker the dictionary's group-data-[viewport=false]
              # chrome keys on.
              "data-viewport" => "false"
            }.merge(root_stimulus_attributes).merge(component_data_attributes)
          )
        end

        def item_attributes(entry)
          attrs = {
            "data-slot" => "navigation-menu-item", "data-value" => entry.value,
            "class" => css(:item)
          }
          attrs.merge!(item_stimulus_attributes) if entry.panel
          attrs
        end

        def trigger_attributes(entry)
          {
            "type" => "button", "data-slot" => "navigation-menu-trigger",
            "aria-expanded" => "false", "aria-controls" => panel_id(entry),
            "class" => "#{css(:trigger)} group"
          }.merge(trigger_stimulus_attributes)
        end

        def panel_attributes(entry)
          {
            "id" => panel_id(entry), "data-slot" => "navigation-menu-content",
            "data-closed" => "", "hidden" => true,
            "class" => "#{css(:content)} #{css(:content_position)}"
          }
        end

        def panel_id(entry)
          "#{instance_id}-panel-#{entry.value}"
        end

        private

        def instance_id
          @instance_id ||= "poetry-nav-#{SecureRandom.hex(4)}"
        end

        def root_stimulus_attributes
          attrs = Poetry::Core::HTML::Attributes.new
          nav = Poetry::Core::Stimulus::Builder.new(CONTROLLER, attrs)
          nav.register_controller
          nav.with_action(:keydown, on: :keydown)
          nav.with_action(:focus_left, on: :focusout)
          attrs.to_attributes
        end

        def item_stimulus_attributes
          attrs = Poetry::Core::HTML::Attributes.new
          nav = Poetry::Core::Stimulus::Builder.new(CONTROLLER, attrs)
          nav.with_action(:schedule_open, on: :pointerenter)
          nav.with_action(:schedule_close, on: :pointerleave)
          attrs.to_attributes
        end

        def trigger_stimulus_attributes
          attrs = Poetry::Core::HTML::Attributes.new
          nav = Poetry::Core::Stimulus::Builder.new(CONTROLLER, attrs)
          nav.with_action(:toggle, on: :click)
          attrs.to_attributes
        end
      end
    end
  end
end
