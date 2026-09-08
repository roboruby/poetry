# frozen_string_literal: true

module Poetry
  module Ui
    # A site-navigation bar with disclosure panels.
    module NavigationMenu
      # A site-navigation bar - a <nav> landmark, never a menu role:
      # top-level links plus triggers whose panels of links open on
      # hover or click beneath their items. It is a DISCLOSURE bar,
      # so Tab moves through it normally and nothing traps focus.
      #
      # By default each panel opens under its own item. viewport: true
      # switches to one shared card that morphs its size and position
      # between triggers - the fit for rich title-and-description panel
      # grids.
      #
      # @example Disclosure bar with a panel and a link
      #   <%= poetry_navigation_menu(label: "Main") do |nav| %>
      #     <% nav.with_item("Products", value: "products") do %>
      #       <%= poetry_navigation_menu_link(href: products_path) { "All products" } %>
      #     <% end %>
      #     <% nav.with_link("Docs", href: docs_path) %>
      #   <% end %>
      class Component < Poetry::Core::Component
        # Projected into the registry, llms.txt, and the agent surface.
        AGENT_RULES = [
          "label: is REQUIRED (the nav landmark's accessible name).",
          "with_item(title, value:) declares a trigger + panel; with_link(title, href:) is a " \
          "top-level destination - use links for pages, panels for groups of links.",
          "Panel content is poetry_navigation_menu_link entries (active: marks the current page) - " \
          "never buttons; navigation navigates.",
          "This is a DISCLOSURE bar: Tab moves through it normally and nothing traps - do not " \
          "wire menu/menuitem roles. Keys: ArrowLeft/ArrowRight step between triggers and links, " \
          "ArrowDown opens the focused trigger's panel (focus stays on the trigger; Tab enters it), " \
          "Escape closes and returns focus to the trigger.",
          "Rich panels (title + description grids) want viewport: true - the shared morphing " \
          "card contains and sizes them; the default per-item mode suits simple link lists " \
          "(the top-nav block shows the viewport pattern)."
        ].freeze

        # One declared bar entry - a link (href:) or a trigger + panel pair
        # (disabled: renders the trigger inert).
        # @api private
        Entry = Data.define(:title, :value, :href, :panel, :disabled)

        renders_many :items,
                     doc: "The bar entries. with_item(title, value:) { panel } declares a trigger + panel " \
                          "(disabled: true renders the trigger inert - native disabled plus data-disabled; hover " \
                          "and click never open its panel); with_item(title, href:) a top-level link (with_link " \
                          "is the shorthand).",
                     renders: lambda { |title, value: nil, href: nil, disabled: false, &panel|
                       if href.nil? && panel.nil?
                         raise ArgumentError,
                               "NavigationMenu item #{title.inspect} needs href: (a link) or a panel block"
                       end
                       if href && disabled
                         raise ArgumentError,
                               "NavigationMenu item #{title.inspect}: disabled: applies to a trigger, not a link"
                       end

                       entries << Entry.new(title: title, value: value&.to_s || title.to_s.parameterize, href: href,
                                            panel: panel, disabled: disabled)
                       nil
                     }

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
          # BOTH controllers on ONE element, declared together - the wiring
          # merges through the Builder, never as two separate Attributes
          # joined with plain Hash#merge (that drops one controller's
          # tokens).
          on :positioner do
            controller(:popper) { target :content }
            controller :navigation_menu do
              action :cancel_close, on: :pointerenter
              action :schedule_close, on: :pointerleave
            end
          end
        end

        option :label, :string, required: true,
                                doc: "The nav landmark's accessible name - a page may hold more than one nav."
        option :viewport, :boolean, default: false,
                                    doc: "Opts into the shared morphing viewport: panels adopt into one positioned " \
                                         "card that morphs size and position between triggers. Off, each panel opens " \
                                         "under its own item (also the no-JS shape)."

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
               "data-closed" => "its panel is closed (written after the first close)",
               "data-disabled" => "disabled: true - inert (native disabled rides along; hover and " \
                                  "click never open the panel, the arrows step over it)"
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
               "data-instant" => "suppresses the morph transitions for one painted frame (cold opens)",
               "data-starting-style" => "the enter transition's first frame (the presence module's " \
                                        "two-frame trick)",
               "data-ending-style" => "held through the exit transition before the popup hides"
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

        # Enforces the required label and at least one entry.
        # @api private
        def before_render
          raise ArgumentError, "NavigationMenu requires label: (the nav landmark's name)" if label.blank?
          raise ArgumentError, "NavigationMenu requires at least one with_item or with_link" unless items?
        end

        # Declares a top-level destination link - shorthand for
        # with_item(title, href:).
        # @param title [String] the visible link text
        # @param href [String] the destination URL
        def with_link(title, href:)
          with_item(title, href: href)
        end

        # The declared entries, in bar order.
        # @api private
        def entries
          @entries ||= []
        end

        # @api private
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

        # @api private
        def item_attributes(entry)
          attrs = {
            "data-slot" => "navigation-menu-item", "data-value" => entry.value,
            "class" => css(:item)
          }
          attrs.merge!(stimulus_attributes_for(:item)) if entry.panel
          attrs
        end

        # @api private
        def trigger_attributes(entry)
          attrs = {
            "type" => "button", "data-slot" => "navigation-menu-trigger",
            "aria-expanded" => "false", "aria-controls" => panel_id(entry),
            "class" => "#{css(:trigger)} group"
          }
          if entry.disabled
            attrs["disabled"] = true # inert: no focus, no click
            attrs["data-disabled"] = "" # the contract's styling hook
          end
          attrs.merge(stimulus_attributes_for(:trigger))
        end

        # @api private
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

        # The shared shell (viewport mode): the positioner is re-anchored
        # against the ACTIVE trigger on each activation with the full
        # positioning engine; the popup carries the morphing size vars;
        # panels adopt into the viewport.
        # @api private
        def positioner_attributes
          attrs = {
            "data-slot" => "navigation-menu-positioner", "hidden" => true,
            "class" => css(:positioner)
          }
          attrs.merge(stimulus_attributes_for(:positioner))
        end

        # @api private
        def panel_id(entry)
          "#{instance_id}-panel-#{entry.value}"
        end

        private

        def instance_id
          @instance_id ||= poetry_instance_id("poetry-nav")
        end

        private :entries, :root_attributes, :item_attributes, :trigger_attributes, :panel_attributes
        private :positioner_attributes, :panel_id
      end
    end
  end
end
