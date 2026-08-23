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
      #
      # @example Paginating a product list
      #   render Poetry::Ui::Pagination::Component.new(current: 3, total: 12,
      #                                                path: ->(page) { products_path(page: page) })
      class Component < Poetry::Core::Component
        # :outline is upstream parity and stays the default; :filled renders
        # the current page as the primary Button (the outline marker is easy
        # to mistake for a hover/focus ring; the data-index block and docs
        # adopt :filled).
        CURRENT_VARIANTS = %i[outline filled].freeze

        # The edge treatment: :labeled (chevron + responsive text, upstream
        # parity, default), :icons (chevron-only - table footers/toolbars),
        # :none (no Previous/Next at all).
        EDGES = %i[labeled icons none].freeze

        AGENT_RULES = [
          "poetry_pagination(current:, total:, path:) - never hand-build the <nav>/<ul>/<li> list.",
          "path: is a callable ->(page) { url } (e.g. ->(p) { products_path(page: p) }).",
          "The current page is aria-current=page; current_variant: :outline (upstream parity, " \
          "default) or :filled (the primary treatment - unambiguous active state); the rest are " \
          "ghost links.",
          "edges: :icons renders chevron-only Previous/Next (the table-footer posture); " \
          ":none drops them for a bare page list; pages: false drops the numbers " \
          "(pair with edges: :icons for the compact pager).",
          "Host paginates with kaminari, pagy (v43+), or will_paginate? Run " \
          "bin/rails g poetry:pagination (no argument = detect and install an adapter for " \
          "each loaded gem) and keep calling paginate / poetry_pagy_nav / " \
          "will_paginate(renderer: PoetryLinkRenderer) - never hand-wire poetry_pagination " \
          "around a paginator gem."
        ].freeze

        option :current, :integer, required: true
        option :total, :integer, required: true
        option :siblings, :integer, default: 1
        option :edges, :symbol, default: :labeled
        # pages: false drops the numbered links - the compact two-button
        # pager (upstream pagination-icons-only).
        option :pages, :boolean, default: true
        option :current_variant, :symbol, default: :outline
        option :label, :string, default: "pagination"
        option :previous_label, :string, default: "Previous"
        option :next_label, :string, default: "Next"

        validates :current_variant, inclusion: { in: CURRENT_VARIANTS }
        validates :edges, inclusion: { in: EDGES }

        # (pagination-link rides the composed Buttons, so those elements
        # belong to Button's anatomy, not this contract.)
        part "pagination", "The <nav> landmark (role=navigation, aria-label) around the page list"
        part "pagination-content", "The <ul> holding every entry as one horizontal row"
        part "pagination-item", "One <li> per entry - previous/next, a page link, or a gap"
        part "pagination-ellipsis", "The elided-pages marker between windows - aria-hidden with an " \
                                    "sr-only 'More pages'"

        def before_render
          return if pages || edges != :none

          raise ArgumentError, "pagination with pages: false needs edges (:labeled or :icons) - " \
                               "edges: :none would render an empty nav"
        end

        def show_edges? = edges != :none
        def icon_edges? = edges == :icons

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

        # ghost for other pages; the current page renders per
        # current_variant (:outline = upstream parity, :filled = primary).
        def page_variant(page)
          return :ghost unless current?(page)

          current_variant == :filled ? :default : :outline
        end

        # A numbered page link: outline+aria-current for the current page,
        # ghost otherwise; icon-sized. data-slot + data-active are the
        # source-exact hooks.
        def page_options(page)
          {
            tag: :a, href: path_for(page), size: :icon,
            # A descriptive accessible name that still contains the visible
            # number (WCAG label-in-name); the icon-sized Button requires it.
            label: "Go to page #{page}",
            variant: page_variant(page),
            "aria-current": current?(page) ? "page" : nil,
            data: { slot: "pagination-link", active: current?(page) }
          }.compact
        end

        # Prev/Next: default-sized ghost links with the edge padding tweak;
        # disabled (aria-disabled, no navigation) at the boundary.
        def edge_options(page, aria_label, padding)
          options = {
            tag: :a, href: path_for(page), variant: :ghost,
            disabled: page < 1 || page > total,
            data: { slot: "pagination-link" }
          }
          if icon_edges?
            # Icon-sized Buttons take label: (the accessible-name contract).
            options[:size] = :icon
            options[:label] = aria_label
          else
            options[:size] = :default
            options[:"aria-label"] = aria_label
            options[:class] = padding
          end
          options
        end

        def previous_options = edge_options(current - 1, "Go to previous page", css(:edge_previous))
        def next_options = edge_options(current + 1, "Go to next page", css(:edge_next))

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
