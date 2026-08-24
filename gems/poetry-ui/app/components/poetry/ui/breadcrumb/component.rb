# frozen_string_literal: true

module Poetry
  module Ui
    # Ancestor-trail navigation.
    module Breadcrumb
      # A navigation trail of ancestor links. Declare the trail (with_item
      # per crumb, with_ellipsis for a collapsed middle) and the component
      # owns the <nav>/<ol> chrome, the separators, and the current-page
      # semantics. An item with href: is a link; an item without href:
      # is the current page (aria-current="page").
      #
      # @example
      #   <%= poetry_breadcrumb do |crumb| %>
      #     <% crumb.with_item("Home", href: "/") %>
      #     <% crumb.with_ellipsis %>
      #     <% crumb.with_item("Breadcrumb") %>
      #   <% end %>
      class Component < Poetry::Core::Component
        # The caller's separator block, captured by with_separator.
        # @api private
        attr_reader :separator_block

        # Projected into the registry, llms.txt, and the agent surface.
        AGENT_RULES = [
          "Declare the trail with with_item(label, href:) - never hand-build the nav/ol/li chain.",
          "The current page is the item WITHOUT href: (it renders aria-current=page, not a link).",
          "Collapse a long middle with with_ellipsis - it announces 'More' to screen readers.",
          "A BLOCK item (with_item { ... }) renders your content inside the <li> - the seat for a " \
          "dropdown crumb or a custom-rendered link; you own its semantics (aria-current only " \
          "applies to label items).",
          "with_separator(icon: :dot) - or a block - replaces the chevron in EVERY gap; the default " \
          "chevron RTL-flips, a custom glyph is used as given."
        ].freeze

        # Slots the component cannot render without; static checks read this without rendering.
        REQUIRED_SLOTS = { item: "at least one item" }.freeze

        slot_doc :items, "The crumbs, in declaration order. A label with href: renders a link; without one, the " \
                         "current page. A block makes the <li>'s content caller-owned (a dropdown crumb, a " \
                         "custom-rendered link)."
        renders_many :items, lambda { |label = nil, href: nil, ellipsis: false, &block|
          entries << Entry.new(label: label, href: href, ellipsis: ellipsis, block: block)
          nil
        }

        slot_doc :separator, "Replaces the separator glyph in EVERY gap: an icon name, or a block for arbitrary " \
                             "content. Absent, the default chevron renders (with its RTL flip - a custom glyph is " \
                             "used as given)."
        renders_one :separator, lambda { |icon: nil, &block|
          @separator_block = icon ? proc { render Icon::Component.new(name: icon) } : block
          nil
        }

        part "breadcrumb", "The <nav> landmark (aria-label=breadcrumb) around the trail"
        part "breadcrumb-list", "The <ol> laying crumbs and separators out as one wrapping row"
        part "breadcrumb-item", "One <li> of the trail - wraps a link, the current page, the ellipsis, " \
                                "or a block item's own content (a dropdown crumb, a custom link)"
        part "breadcrumb-link", "A crumb with href: - a real <a> to an ancestor page"
        part "breadcrumb-page", "The current page (the item without href:) - aria-current=page, not a link"
        part "breadcrumb-separator", "The chevron <li> between crumbs - presentational, aria-hidden"
        part "breadcrumb-ellipsis", "The collapsed-middle glyph (with_ellipsis) - aria-hidden; a sibling " \
                                    "sr-only 'More' announces it"

        # Enforces the required item slot.
        # @api private
        def before_render
          # items? is the SLOT predicate: it forces the render block (which
          # populates entries) - reading @entries directly here would run
          # before the block ever executed.
          raise ArgumentError, "Breadcrumb requires at least one with_item" unless items?
        end

        # Adds a collapsed-middle marker to the trail; screen readers hear "More".
        def with_ellipsis
          with_item(ellipsis: true)
        end

        # The declared crumbs in order.
        # @api private
        def entries
          @entries ||= []
        end

        # @api private
        def root_attributes
          html_attributes.merge_if_not_set(
            { "aria-label" => "breadcrumb", "data-slot" => "breadcrumb" }.merge(component_data_attributes)
          )
        end

        # One declared crumb.
        # @api private
        Entry = Data.define(:label, :href, :ellipsis, :block)

        private :entries, :root_attributes
      end
    end
  end
end
