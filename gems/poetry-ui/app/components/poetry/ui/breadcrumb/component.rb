# frozen_string_literal: true

module Poetry
  module Ui
    module Breadcrumb
      # The Breadcrumb - data-driven like Pagination: declare the trail
      # (with_item per crumb, with_ellipsis for a collapsed middle) and the
      # component owns the <nav>/<ol> chrome, the separators, and the
      # current-page semantics. An item WITH href: is a link; the last item
      # (or any without href:) is the current page (aria-current="page").
      #
      #   <%= poetry_breadcrumb do |crumb| %>
      #     <% crumb.with_item("Home", href: "/") %>
      #     <% crumb.with_ellipsis %>
      #     <% crumb.with_item("Breadcrumb") %>
      #   <% end %>
      class Component < Poetry::Core::Component
        AGENT_RULES = [
          "Declare the trail with with_item(label, href:) - never hand-build the nav/ol/li chain.",
          "The current page is the item WITHOUT href: (it renders aria-current=page, not a link).",
          "Collapse a long middle with with_ellipsis - it announces 'More' to screen readers."
        ].freeze

        Entry = Data.define(:label, :href, :ellipsis)

        # Items append to one ordered trail so crumbs and an ellipsis
        # interleave in declaration order.
        renders_many :items, lambda { |label = nil, href: nil, ellipsis: false|
          entries << Entry.new(label: label, href: href, ellipsis: ellipsis)
          nil
        }

        def with_ellipsis
          with_item(ellipsis: true)
        end

        def entries
          @entries ||= []
        end

        def before_render
          # items? is the SLOT predicate: it forces the render block (which
          # populates entries) - reading @entries directly here would run
          # before the block ever executed.
          raise ArgumentError, "Breadcrumb requires at least one with_item" unless items?
        end

        def root_attributes
          html_attributes.merge_if_not_set(
            { "aria-label" => "breadcrumb", "data-slot" => "breadcrumb" }.merge(component_data_attributes)
          )
        end
      end
    end
  end
end
