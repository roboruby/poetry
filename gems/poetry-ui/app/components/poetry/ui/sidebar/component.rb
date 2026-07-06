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

        CONTROLLER = %i[poetry core sidebar].freeze

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

        renders_one :nav
        renders_one :inset

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
            }.merge(root_stimulus_attributes).merge(component_data_attributes)
          )
        end

        def peer_attributes
          {
            "data-slot" => "sidebar", "class" => css(:peer),
            "data-state" => data_state, "data-collapsible" => data_collapsible,
            "data-variant" => variant, "data-side" => side
          }.merge(peer_stimulus_attributes)
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
          attrs.merge(mobile_stimulus_attributes)
        end

        def mobile_title_id
          @mobile_title_id ||= "poetry-sidebar-mobile-#{SecureRandom.hex(4)}"
        end

        private

        def root_stimulus_attributes
          attrs = Poetry::Core::HTML::Attributes.new
          sidebar = Poetry::Core::Stimulus::Builder.new(CONTROLLER, attrs)
          sidebar.register_controller
          sidebar.with_value(:open, open)
          sidebar.with_value(:collapsible, collapsible)
          attrs.to_attributes
        end

        def peer_stimulus_attributes
          attrs = Poetry::Core::HTML::Attributes.new
          sidebar = Poetry::Core::Stimulus::Builder.new(CONTROLLER, attrs)
          sidebar.with_target(:sidebar)
          attrs.to_attributes
        end

        def inner_stimulus_attributes
          attrs = Poetry::Core::HTML::Attributes.new
          sidebar = Poetry::Core::Stimulus::Builder.new(CONTROLLER, attrs)
          sidebar.with_target(:inner)
          attrs.to_attributes
        end
        public :inner_stimulus_attributes

        def mobile_stimulus_attributes
          attrs = Poetry::Core::HTML::Attributes.new
          sidebar = Poetry::Core::Stimulus::Builder.new(CONTROLLER, attrs)
          sidebar.with_target(:mobile_dialog)
          sidebar.with_action(:close_mobile, on: :cancel)
          sidebar.with_action(:mobile_backdrop_close, on: :click)
          attrs.to_attributes
        end

        def mobile_inner_stimulus_attributes
          attrs = Poetry::Core::HTML::Attributes.new
          sidebar = Poetry::Core::Stimulus::Builder.new(CONTROLLER, attrs)
          sidebar.with_target(:mobile_inner)
          attrs.to_attributes
        end
        public :mobile_inner_stimulus_attributes
      end
    end
  end
end
