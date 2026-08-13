# frozen_string_literal: true

module Poetry
  module Ui
    module Sidebar
      # The Sidebar - the app-shell frame: a collapsible navigation column
      # plus the main content inset, coordinated by poetry--core--sidebar
      # (the collapse is pure CSS off data-state; the controller flips the
      # attribute, persists the sidebar_state cookie, and binds Cmd/Ctrl+B).
      # Server-first: pass open: from the cookie
      # (cookies[:sidebar_state] != "false") so the first paint matches the
      # user's last choice with no flash.
      #
      #   <%= poetry_sidebar(open: cookies[:sidebar_state] != "false", collapsible: :icon) do |shell| %>
      #     <% shell.with_nav do %>
      #       <%= poetry_sidebar_group do %>...menu...<% end %>
      #     <% end %>
      #     <% shell.with_inset do %>
      #       <%= poetry_sidebar_trigger %>
      #       <main>...page...</main>
      #     <% end %>
      #   <% end %>
      #
      # v1 is desktop-complete; the mobile-Sheet mode is deferred (W5b).
      class Component < Poetry::Core::Component
        SIDES = %i[left right].freeze
        VARIANTS = %i[sidebar floating inset].freeze
        COLLAPSIBLE = %i[offcanvas icon none].freeze

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

        WIDTH = "16rem"
        WIDTH_ICON = "3rem"
        # SIDEBAR_WIDTH_MOBILE (source): the mobile sheet's panel width.
        WIDTH_MOBILE = "18rem"

        option :open, :boolean, default: true
        option :side, :symbol, default: :left
        option :variant, :symbol, default: :sidebar
        option :collapsible, :symbol, default: :offcanvas

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
               "data-sidebar" => "always \"sidebar\" - the upstream sub-part marker"
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
               "data-size" => "the row size variant (default, sm, or lg) - the action/badge tops key on it",
               "data-variant" => { condition: "always - the treatment", values: %w[default outline] }
             }
        part "sidebar-menu-action", "The item-corner action button, absolutely positioned in the row",
             states: {
               "data-sidebar" => "always \"menu-action\" - the upstream sub-part marker"
             }
        part "sidebar-menu-badge", "The trailing count/status chrome in the row corner - " \
                                   "pointer-transparent",
             states: {
               "data-sidebar" => "always \"menu-badge\" - the upstream sub-part marker"
             }

        renders_one :nav
        renders_one :inset

        # The same facts the before_render raise enforces, stated statically
        #: poetry check flags the omission without rendering (the
        # menu crash class - required slots the contract kept silent).
        REQUIRED_SLOTS = { nav: "the sidebar column" }.freeze

        def before_render
          raise ArgumentError, "Sidebar requires with_nav (the sidebar column)" unless nav?
        end

        def data_state
          open ? "expanded" : "collapsed"
        end

        # data-collapsible carries the mode only WHILE collapsed (source
        # parity) - the expanded peer has an empty data-collapsible.
        def data_collapsible
          open ? "" : collapsible.to_s
        end

        def inset_variant?
          %i[floating inset].include?(variant)
        end

        def root_attributes
          html_attributes.merge_if_not_set(
            {
              "data-slot" => "sidebar-wrapper",
              "style" => "--sidebar-width: #{WIDTH}; --sidebar-width-icon: #{WIDTH_ICON};",
              "class" => css(:wrapper)
            }.merge(stimulus_attributes_for(:root)).merge(component_data_attributes)
          )
        end

        def peer_attributes
          {
            "data-slot" => "sidebar", "class" => css(:peer),
            "data-state" => data_state, "data-collapsible" => data_collapsible,
            "data-variant" => variant, "data-side" => side
          }.merge(stimulus_attributes_for(:peer))
        end

        def gap_classes
          inset_variant? ? "#{css(:gap)} #{css(:gap_inset)}" : css(:gap)
        end

        def container_classes
          inset_variant? ? "#{css(:container)} #{css(:container_inset)}" : css(:container)
        end

        # The mobile sheet <dialog> (DOM-move): server-rendered
        # EMPTY - the controller adopts the nav children on open. Skinned
        # with the Sheet's presence classes off the sidebar dictionary;
        # md:hidden keeps it out of the desktop layout wholesale.
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

        def mobile_title_id
          @mobile_title_id ||= "poetry-sidebar-mobile-#{SecureRandom.hex(4)}"
        end
      end
    end
  end
end
