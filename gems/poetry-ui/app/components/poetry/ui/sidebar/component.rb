# frozen_string_literal: true

module Poetry
  module Ui
    # The app-shell frame: collapsible navigation column plus content inset.
    module Sidebar
      # The app-shell frame: a collapsible navigation column plus the main
      # content inset. Reach for it as the outermost layout of an
      # application screen. The collapse is pure CSS off data-state; the
      # controller flips the attribute, persists the sidebar_state cookie,
      # and binds Cmd/Ctrl+B. Server-first: pass open: from the cookie
      # (cookies[:sidebar_state] != "false") so the first paint matches the
      # user's last choice with no flash. Below the md breakpoint the
      # column becomes a slide-in sheet.
      #
      # @example App shell wired to the persisted cookie
      #   <%= poetry_sidebar(open: cookies[:sidebar_state] != "false", collapsible: :icon) do |shell| %>
      #     <% shell.with_nav do %>
      #       <%= poetry_sidebar_group do %>...menu...<% end %>
      #     <% end %>
      #     <% shell.with_inset do %>
      #       <%= poetry_sidebar_trigger %>
      #       <main>...page...</main>
      #     <% end %>
      #   <% end %>
      class Component < Poetry::Core::Component
        # The closed vocabulary for the side axis.
        SIDES = %i[left right].freeze
        # The closed vocabulary for the column-treatment axis.
        VARIANTS = %i[sidebar floating inset].freeze
        # The closed vocabulary for the collapse-mode axis.
        COLLAPSIBLE = %i[offcanvas icon none].freeze

        # The expanded column width.
        WIDTH = "16rem"
        # The collapsed icon-rail width.
        WIDTH_ICON = "3rem"
        # The mobile sheet's panel width.
        WIDTH_MOBILE = "18rem"

        # Projected into the registry, llms.txt, and the agent surface.
        AGENT_RULES = [
          "Wrap the WHOLE shell: with_nav is the sidebar column, with_inset is the page area " \
          "(the trigger lives in the inset).",
          "Read the persisted state server-side - open: cookies[:sidebar_state] != \"false\" - so the " \
          "first paint has no collapse flash.",
          "collapsible: :icon keeps icon rails visible when collapsed; :offcanvas slides it fully away; " \
          ":none is a static column.",
          "Menu entries are poetry_sidebar_menu_button(href:) links (active: marks the current route) - " \
          "navigation navigates."
        ].freeze

        # The same facts the before_render raise enforces, stated statically
        # so static checks can flag a missing nav without rendering.
        REQUIRED_SLOTS = { nav: "the sidebar column" }.freeze

        renders_one :nav, doc: "The sidebar column's content (required) - groups, menus, header/footer."
        renders_one :inset, doc: "The page area beside the column - rendered as the <main> inset."

        use_stimulus do
          on :root do
            controller :sidebar do
              register
              value :open
              value :collapsible
            end
          end
          on :peer do
            controller(:sidebar) { target :sidebar }
          end
          on :inner do
            controller(:sidebar) { target :inner }
          end
          # The mobile sheet <dialog>: the Dialog-family cancel/backdrop
          # pair under sidebar-namespaced action names.
          on :mobile do
            controller :sidebar do
              target :mobile_dialog
              action :close_mobile, on: :cancel
              action :mobile_backdrop_close, on: :click
            end
          end
          on :mobile_inner do
            controller(:sidebar) { target :mobile_inner }
          end
          # Rendered by the poetry_sidebar_trigger / poetry_sidebar_rail
          # helpers (helper-side strings; declared here so the contract
          # covers the whole family surface).
          on :trigger do
            controller(:sidebar) { action :toggle, on: :click }
          end
        end

        option :open, :boolean, default: true,
                                doc: "The expanded/collapsed state at first paint - feed it from the persisted " \
                                     "cookie so there is no collapse flash."
        option :side, :symbol, default: :left, doc: "Which edge the column hangs on."
        option :variant, :symbol, default: :sidebar,
                                  doc: "The column treatment: flush column, floating card, or inset panel."
        option :collapsible, :symbol, default: :offcanvas,
                                      doc: "What collapsing does: slide fully away, shrink to an icon rail, or :none " \
                                           "for a static column."

        validates :side, inclusion: { in: SIDES }
        validates :variant, inclusion: { in: VARIANTS }
        validates :collapsible, inclusion: { in: COLLAPSIBLE }

        part "sidebar-wrapper", "The provider shell around the column, the mobile dialog, and the inset",
             vars: {
               "--sidebar-width" => "the expanded column width (16rem) - the gap/container geometry reads it",
               "--sidebar-width-icon" => "the collapsed icon-rail width (3rem)"
             }
        part "sidebar", "The desktop state peer - the collapse state lives here and the pure-CSS " \
                        "group-data chrome keys on it",
             states: {
               "data-state" => "expanded or collapsed - the controller flips it and persists the cookie",
               "data-collapsible" => { condition: "the collapse mode WHILE collapsed (empty while expanded " \
                                                  "- source parity)",
                                       values: %w[offcanvas icon none] },
               "data-variant" => { condition: "the column treatment", values: %w[sidebar floating inset] },
               "data-side" => { condition: "which edge the column hangs on", values: %w[left right] }
             }
        part "sidebar-gap", "The in-flow width ghost that pushes the inset over - its width animates " \
                            "on collapse"
        part "sidebar-container", "The fixed-position column itself",
             states: {
               "data-side" => { condition: "which edge it pins to", values: %w[left right] }
             }
        part "sidebar-inner", "The flex column receiving the nav slot - the mobile mode adopts its " \
                              "children from here"
        part "sidebar-mobile", "The mobile sheet <dialog> (below md) - server-rendered empty; the " \
                               "controller adopts the nav children on open",
             states: {
               "data-open" => "sheet is open (presence flips the pair at runtime)",
               "data-closed" => "sheet is closed (the server-rendered state)",
               "data-mobile" => "always \"true\" - the mobile-mode marker",
               "data-side" => { condition: "which edge the sheet slides from", values: %w[left right] },
               "data-sidebar" => "always \"sidebar\" - the suite-wide sub-part marker"
             },
             vars: {
               "--sidebar-width" => "overridden inline to the mobile sheet width (18rem)"
             }
        part "sidebar-mobile-inner", "The adoption container the nav children move into while the " \
                                     "sheet is open"
        part "sidebar-inset", "The <main> page area beside the column"
        part "sidebar-header", "Top block of the column (with_nav content)"
        part "sidebar-footer", "Bottom block of the column"
        part "sidebar-content", "The scrollable middle of the column"
        part "sidebar-group", "One titled section inside the content"
        part "sidebar-group-label", "The section heading - fades and collapses away in icon mode"
        part "sidebar-menu", "The <ul> of menu items inside a group"
        part "sidebar-menu-item", "One <li> menu row (the group/menu-item hover scope)"
        part "sidebar-menu-button", "The row's link (href:) or button - the navigation entry itself",
             states: {
               "data-active" => "the current route (active: - links also get aria-current=page)",
               "data-open" => "when the button is a collapsible's trigger - the disclosure state the " \
                              "collapsible controller flips",
               "data-size" => "the row size variant (default, sm, or lg) - the action/badge tops key on it",
               "data-variant" => { condition: "always - the treatment", values: %w[default outline] }
             }
        part "sidebar-menu-action", "The item-corner action button, absolutely positioned in the row",
             states: {
               "data-sidebar" => "always \"menu-action\" - the suite-wide sub-part marker"
             }
        part "sidebar-menu-badge", "The trailing count/status chrome in the row corner - " \
                                   "pointer-transparent",
             states: {
               "data-sidebar" => "always \"menu-badge\" - the suite-wide sub-part marker"
             }

        # @api private
        def before_render
          raise ArgumentError, "Sidebar requires with_nav (the sidebar column)" unless nav?
        end

        # @api private
        def data_state
          open ? "expanded" : "collapsed"
        end

        # data-collapsible carries the mode only WHILE collapsed - the
        # expanded peer has an empty data-collapsible.
        # @api private
        def data_collapsible
          open ? "" : collapsible.to_s
        end

        # @api private
        def inset_variant?
          %i[floating inset].include?(variant)
        end

        # @api private
        def root_attributes
          html_attributes.merge_if_not_set(
            {
              "data-slot" => "sidebar-wrapper",
              "style" => "--sidebar-width: #{WIDTH}; --sidebar-width-icon: #{WIDTH_ICON};",
              "class" => css(:wrapper)
            }.merge(stimulus_attributes_for(:root)).merge(component_data_attributes)
          )
        end

        # @api private
        def peer_attributes
          {
            "data-slot" => "sidebar", "class" => css(:peer),
            "data-state" => data_state, "data-collapsible" => data_collapsible,
            "data-variant" => variant, "data-side" => side
          }.merge(stimulus_attributes_for(:peer))
        end

        # @api private
        def gap_classes
          inset_variant? ? "#{css(:gap)} #{css(:gap_inset)}" : css(:gap)
        end

        # @api private
        def container_classes
          inset_variant? ? "#{css(:container)} #{css(:container_inset)}" : css(:container)
        end

        # The mobile sheet <dialog> (DOM-move): server-rendered
        # EMPTY - the controller adopts the nav children on open. Skinned
        # with the Sheet's presence classes off the sidebar dictionary;
        # md:hidden keeps it out of the desktop layout wholesale.
        # @api private
        def mobile_dialog_attributes
          attrs = {
            "data-slot" => "sidebar-mobile", "data-sidebar" => "sidebar",
            "data-mobile" => "true", "data-side" => side, "data-closed" => "",
            "class" => "#{css(:mobile)} #{Style.mobile_side(side)}",
            "style" => "--sidebar-width: #{WIDTH_MOBILE};",
            "aria-labelledby" => mobile_title_id
          }
          attrs.merge(stimulus_attributes_for(:mobile))
        end

        # @api private
        def mobile_title_id
          @mobile_title_id ||= poetry_instance_id("poetry-sidebar-mobile")
        end

        private :data_state, :data_collapsible, :inset_variant?, :root_attributes, :peer_attributes, :gap_classes
        private :container_classes, :mobile_dialog_attributes, :mobile_title_id
      end
    end
  end
end
