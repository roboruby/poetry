# frozen_string_literal: true

module Poetry
  module Ui
    module Pagination
      # The Pagination - data-driven (Rails hands you current + total from a
      # collection), so the component owns the truncation math instead of
      # making you compose every <li>. A `<nav aria-label>` of Button-styled
      # links: outline for the current page (aria-current=page), ghost for
      # the rest; first/last always shown, current +/- siblings around it,
      # ellipses for the gaps. path: is a callable page -> url.
      class Component < Poetry::Core::Component
        AGENT_RULES = [
          "poetry_pagination(current:, total:, path:) - never hand-build the <nav>/<ul>/<li> list.",
          "path: is a callable ->(page) { url } (e.g. ->(p) { products_path(page: p) }).",
          "The current page is aria-current=page + the outline variant; the rest are ghost links."
        ].freeze

        option :current, :integer, required: true
        option :total, :integer, required: true
        option :siblings, :integer, default: 1
        option :label, :string, default: "pagination"
        option :previous_label, :string, default: "Previous"
        option :next_label, :string, default: "Next"

        # The page sequence with :gap markers where pages are elided. Small
        # ranges show every page; larger ones show first, last, and a window
        # of +/- siblings around current.
        def items
          return (1..total).to_a if total <= 5 + (siblings * 2)

          window = ((current - siblings)..(current + siblings)).select { |page| page > 1 && page < total }
          with_gaps([1, *window, total])
        end

        def current?(page) = page == current
        def path_for(page) = @path.call(page)

        # A numbered page link: outline+aria-current for the current page,
        # ghost otherwise; icon-sized. data-slot + data-active are the
        # source-exact hooks.
        def page_options(page)
          {
            tag: :a, href: path_for(page), size: :icon,
            # A descriptive accessible name that still contains the visible
            # number (WCAG label-in-name); the icon-sized Button requires it.
            label: "Go to page #{page}",
            variant: current?(page) ? :outline : :ghost,
            "aria-current": current?(page) ? "page" : nil,
            data: { slot: "pagination-link", active: current?(page) }
          }.compact
        end

        # Prev/Next: default-sized ghost links with the edge padding tweak;
        # disabled (aria-disabled, no navigation) at the boundary.
        def edge_options(page, aria_label, padding)
          {
            tag: :a, href: path_for(page), variant: :ghost, size: :default,
            disabled: page < 1 || page > total,
            "aria-label": aria_label, class: padding,
            data: { slot: "pagination-link" }
          }
        end

        def previous_options = edge_options(current - 1, "Go to previous page", "pl-2!")
        def next_options = edge_options(current + 1, "Go to next page", "pr-2!")

        def root_attributes
          html_attributes.merge_if_not_set(
            { "role" => "navigation", "aria-label" => label, "data-slot" => "pagination" }
              .merge(component_data_attributes)
          )
        end

        private

        # path: is passed as a keyword but held as a callable, not an option
        # (options are typed data; a proc is behavior).
        def initialize(path:, **)
          super(**)
          @path = path
        end

        def with_gaps(pages)
          pages.each_with_object([]) do |page, sequence|
            previous = sequence.reject { |item| item == :gap }.last
            sequence << :gap if previous && page - previous > 1
            sequence << page
          end
        end
      end
    end
  end
end
