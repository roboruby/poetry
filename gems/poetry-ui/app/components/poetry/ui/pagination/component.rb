# frozen_string_literal: true

module Poetry
  module Ui
    # Numbered page navigation.
    module Pagination
      # Numbered page navigation, data-driven: give it current + total
      # and a path: callable (page -> url) and it owns the truncation
      # math instead of making you compose every <li> - first and last
      # always shown, a window of siblings around the current page,
      # ellipses for the gaps. Renders a <nav> landmark of Button-styled
      # links with the current page marked aria-current=page.
      #
      # @example Paginating a product list
      #   render Poetry::Ui::Pagination::Component.new(current: 3, total: 12,
      #                                                path: ->(page) { products_path(page: page) })
      class Component < Poetry::Core::Component
        # The closed vocabulary for the current_variant axis - how the
        # current page link renders.
        CURRENT_VARIANTS = %i[outline filled].freeze

        # The closed vocabulary for the edges axis - the Previous/Next
        # treatment.
        EDGES = %i[labeled icons none].freeze

        # Projected into the registry, llms.txt, and the agent surface.
        AGENT_RULES = [
          "poetry_pagination(current:, total:, path:) - never hand-build the <nav>/<ul>/<li> list.",
          "path: is a callable ->(page) { url } (e.g. ->(p) { products_path(page: p) }).",
          "The current page is aria-current=page; current_variant: :outline (the " \
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

        option :current, :integer, required: true, doc: "The current page number (1-based)."
        option :total, :integer, required: true, doc: "The total page count."
        option :siblings, :integer, default: 1,
                                    doc: "How many page links flank the current page before gaps elide to ellipses."
        option :edges, :symbol, default: :labeled,
                                doc: "The Previous/Next treatment: :labeled (chevron + responsive text), :icons " \
                                     "(chevron only - table footers), :none (no edge links)."
        option :pages, :boolean, default: true,
                                 doc: "Set false to drop the numbered links - the compact two-button pager (pair " \
                                      "with edges: :icons)."
        option :current_variant, :symbol, default: :outline,
                                          doc: "How the current page link renders: :outline, or :filled for the " \
                                               "primary Button treatment (an unambiguous active state)."
        option :label, :string, default: "pagination", doc: "The nav landmark's accessible name."
        option :previous_label, :string, default: "Previous",
                                         doc: "The Previous link's visible text (hidden on narrow viewports)."
        option :next_label, :string, default: "Next", doc: "The Next link's visible text (hidden on narrow viewports)."

        validates :current_variant, inclusion: { in: CURRENT_VARIANTS }
        validates :edges, inclusion: { in: EDGES }

        # (pagination-link rides the composed Buttons, so those elements
        # belong to Button's anatomy, not this contract.)
        part "pagination", "The <nav> landmark (role=navigation, aria-label) around the page list"
        part "pagination-content", "The <ul> holding every entry as one horizontal row"
        part "pagination-item", "One <li> per entry - previous/next, a page link, or a gap"
        part "pagination-ellipsis", "The elided-pages marker between windows - aria-hidden with an " \
                                    "sr-only 'More pages'"

        # Rejects the empty-nav combination.
        # @api private
        def before_render
          return if pages || edges != :none

          raise ArgumentError, "pagination with pages: false needs edges (:labeled or :icons) - " \
                               "edges: :none would render an empty nav"
        end

        # @api private
        def show_edges? = edges != :none
        # @api private
        def icon_edges? = edges == :icons

        # The page sequence with :gap markers where pages are elided. Small
        # ranges show every page; larger ones show first, last, and a window
        # of +/- siblings around current.
        # @api private
        def items
          return (1..total).to_a if total <= 5 + (siblings * 2)

          window = ((current - siblings)..(current + siblings)).select { |page| page > 1 && page < total }
          with_gaps([1, *window, total])
        end

        # @api private
        def current?(page) = page == current
        # @api private
        def path_for(page) = @path.call(page)

        # Ghost for other pages; the current page renders per
        # current_variant (:outline, or :filled for the primary Button).
        # @api private
        def page_variant(page)
          return :ghost unless current?(page)

          current_variant == :filled ? :default : :outline
        end

        # A numbered page link: aria-current for the current page, ghost
        # otherwise; icon-sized. data-slot + data-active are the restyle hooks.
        # @api private
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
        # @api private
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

        # @api private
        def previous_options = edge_options(current - 1, "Go to previous page", css(:edge_previous))
        # @api private
        def next_options = edge_options(current + 1, "Go to next page", css(:edge_next))

        # @api private
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

        private :show_edges?, :icon_edges?, :current?, :path_for, :page_variant, :page_options, :edge_options
        private :previous_options, :next_options, :root_attributes
      end
    end
  end
end
