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
          "wire menu/menuitem roles.",
          "Rich panels (title + description grids) want viewport: true - the shared morphing " \
          "card contains and sizes them; the default per-item mode suits simple link lists " \
          "(the top-nav block shows the viewport pattern)."
        ].freeze

        use_stimulus do
          on :root do
            controller :navigation_menu do
              register
              action :keydown, on: :keydown
              action :focus_left, on: :focusout
            end
            # The whole positioning engine is viewport-gated.
            controller :popper, if: :viewport do
              register
              value :side, "bottom"
              value :align, "start"
              value :side_offset, 6
              value :strategy, "absolute"
            end
          end
          # Hover intent per panel-bearing item (the call site gates
          # per-entry - plain links carry no wiring).
          on :item do
            controller :navigation_menu do
              action :schedule_open, on: :pointerenter
              action :schedule_close, on: :pointerleave
            end
          end
          on :trigger do
            controller(:navigation_menu) { action :toggle, on: :click }
          end
          # BOTH controllers on ONE element - the declaration retires the
          # survey's one structural Accordion-lesson violation (two
          # separate Attributes merged with plain Hash#merge).
          on :positioner do
            controller(:popper) { target :content }
            controller :navigation_menu do
              action :cancel_close, on: :pointerenter
              action :schedule_close, on: :pointerleave
            end
          end
        end

        # required: the hand raise in before_render carries the message;
        # the flag carries the fact to the registry (: the floating
        # crash - a required option the static tier could not see).
        option :label, :string, required: true
        # The morphing shared viewport: panels adopt into one
        # positioned popup that morphs size/position between triggers. false
        # (the default) keeps the per-item popovers - also the no-JS shape.
        option :viewport, :boolean, default: false

        Entry = Data.define(:title, :value, :href, :panel)

        part "navigation-menu", "The <nav> landmark around the whole disclosure bar",
             states: {
               "data-viewport" => "the mode marker (\"true\" = shared morphing viewport, \"false\" = " \
                                  "per-item panels) - the dictionary's group-data chrome keys on it"
             }
        part "navigation-menu-list", "The bar row holding every item"
        part "navigation-menu-item", "One bar entry - wraps a trigger + panel pair or a top-level link",
             states: {
               "data-value" => "the entry's value - the controller's open/close key"
             }
        part "navigation-menu-trigger", "The disclosure button opening its panel",
             states: {
               "data-popup-open" => "its panel is open (written with aria-expanded - the chevron " \
                                    "rotation hook)",
               "data-open" => "its panel is open (the controller writes both vocabularies)",
               "data-closed" => "its panel is closed (written after the first close)"
             }
        part "navigation-menu-content", "One item's panel - presence-animated; in viewport mode it is " \
                                        "adopted into the shared viewport on first activation",
             states: {
               "data-open" => "panel is open (presence flips the pair at runtime)",
               "data-closed" => "panel is closed or animating out (the server-rendered state)",
               "data-activation-direction" => "which way the activation traveled between triggers " \
                                              "(left/right, viewport mode) - keys the slide styles",
               "data-viewport-panel" => "stamped once the panel is adopted into the shared viewport"
             }
        part "navigation-menu-positioner", "The viewport-mode shell popper positions against the " \
                                           "active trigger",
             states: {
               "data-instant" => "suppresses the morph transitions for one painted frame (cold opens)"
             },
             vars: {
               "--positioner-width" => "the pinned morph width (reset to auto once the transition settles)",
               "--positioner-height" => "the pinned morph height (reset to auto once the transition settles)"
             }
        part "navigation-menu-popup", "The morphing card inside the positioner - open state and the " \
                                      "size transition ride here",
             states: {
               "data-open" => "a panel is showing (the controller flips the pair)",
               "data-closed" => "the popup is closed (the server-rendered state)",
               "data-instant" => "suppresses the morph transitions for one painted frame (cold opens)"
             },
             vars: {
               "--popup-width" => "the pinned morph width (reset to auto once the transition settles)",
               "--popup-height" => "the pinned morph height (reset to auto once the transition settles)"
             }
        part "navigation-menu-viewport", "The adoption container inside the popup - adopted panels " \
                                         "stack absolutely in it"
        part "navigation-menu-link", "A REAL destination link - top-level (with_link) or a panel entry " \
                                     "(poetry_navigation_menu_link)",
             states: {
               "data-active" => "the current page (active: true)"
             }

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
              "data-viewport" => viewport.to_s
            }.merge(stimulus_attributes_for(:root)).merge(component_data_attributes)
          )
        end

        def item_attributes(entry)
          attrs = {
            "data-slot" => "navigation-menu-item", "data-value" => entry.value,
            "class" => css(:item)
          }
          attrs.merge!(stimulus_attributes_for(:item)) if entry.panel
          attrs
        end

        def trigger_attributes(entry)
          {
            "type" => "button", "data-slot" => "navigation-menu-trigger",
            "aria-expanded" => "false", "aria-controls" => panel_id(entry),
            "class" => "#{css(:trigger)} group"
          }.merge(stimulus_attributes_for(:trigger))
        end

        def panel_attributes(entry)
          {
            "id" => panel_id(entry), "data-slot" => "navigation-menu-content",
            "data-closed" => "", "hidden" => true,
            # Viewport mode: panels stack absolutely inside the shared viewport
            # (adopted on first activation); per-item mode positions under the
            # relative item.
            "class" => "#{css(:content)} #{viewport ? css(:viewport_panel) : css(:content_position)}"
          }
        end

        # The shared shell (viewport mode): popper positions the positioner
        # against the ACTIVE trigger (poetry--core--popper rides the nav root;
        # the controller re-anchors it per activation - full floating-ui,
        #); the popup carries the morphing size vars; panels adopt into
        # the viewport.
        def positioner_attributes
          attrs = {
            "data-slot" => "navigation-menu-positioner", "hidden" => true,
            "class" => css(:positioner)
          }
          attrs.merge(stimulus_attributes_for(:positioner))
        end

        def panel_id(entry)
          "#{instance_id}-panel-#{entry.value}"
        end

        private

        def instance_id
          @instance_id ||= "poetry-nav-#{SecureRandom.hex(4)}"
        end
      end
    end
  end
end
