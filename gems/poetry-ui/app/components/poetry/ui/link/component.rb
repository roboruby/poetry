# frozen_string_literal: true

module Poetry
  module Ui
    module Link
      # Navigation, as poetry's own contract (shadcn ships no Link - its
      # docs still say "links for navigation, buttons for actions", so
      # poetry makes the navigation half real). Renders a real <a>;
      # `current: true` marks the active nav item via aria-current.
      #
      # @example
      #   render Poetry::Ui::Link::Component.new(href: "/docs") { "Documentation" }
      class Component < Poetry::Core::Component
        AGENT_RULES = [
          "Use poetry_link for navigation - poetry_button for actions (never an <a> styled by hand).",
          "Mark the active nav item with current: true (aria-current), never with a bespoke class.",
          "external: true handles target/rel safely - never hand-write target=_blank."
        ].freeze

        style :underline, default: :hover, variants: %i[hover always none]

        option :href, :string, required: true
        option :external, :boolean, default: false
        option :current, :boolean, default: false

        part "link", "The rendered <a> - the whole component; current: marks it aria-current=page"

        # An empty link is a focusable, invisible <a> - the worst of the
        # floating crash class.
        requires_content "the visible link text"

        def before_render
          ensure_content!
        end

        def call
          content_tag(:a, content, **root_attributes.to_attributes)
        end

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
