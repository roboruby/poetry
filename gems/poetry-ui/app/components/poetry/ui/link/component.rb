# frozen_string_literal: true

module Poetry
  module Ui
    # A navigation link.
    module Link
      # A themed navigation link - a real <a>. Links navigate; buttons
      # act - reach for Button when the click performs an action.
      # current: true marks the active nav item via aria-current, and
      # external: true opens a new tab with the safe rel pairing.
      #
      # @example
      #   render Poetry::Ui::Link::Component.new(href: "/docs") { "Documentation" }
      class Component < Poetry::Core::Component
        # Projected into the registry, llms.txt, and the agent surface.
        AGENT_RULES = [
          "Use poetry_link for navigation - poetry_button for actions (never an <a> styled by hand).",
          "Mark the active nav item with current: true (aria-current), never with a bespoke class.",
          "external: true handles target/rel safely - never hand-write target=_blank."
        ].freeze

        # When the underline appears; :none suits links styled by their container.
        style :underline, default: :hover, variants: %i[hover always none]

        # The destination URL.
        option :href, :string, required: true
        # Opens in a new tab with rel="noopener noreferrer" - never hand-write target=_blank.
        option :external, :boolean, default: false
        # Marks this link as the current page via aria-current=page.
        option :current, :boolean, default: false

        part "link", "The rendered <a> - the whole component; current: marks it aria-current=page"

        # An empty link would be a focusable, invisible <a> - the visible
        # text is required.
        requires_content "the visible link text"

        # @api private
        def before_render
          ensure_content!
        end

        # @api private
        def call
          content_tag(:a, content, **root_attributes.to_attributes)
        end

        # @api private
        def root_attributes
          attrs = { "href" => href, "data-slot" => "link" }.merge(component_data_attributes)
          attrs["aria-current"] = "page" if current
          if external
            attrs["target"] = "_blank"
            attrs["rel"] = "noopener noreferrer"
          end
          html_attributes.merge_if_not_set(attrs)
        end
      end
    end
  end
end
