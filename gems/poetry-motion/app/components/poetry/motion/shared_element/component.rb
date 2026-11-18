# frozen_string_literal: true

module Poetry
  module Motion
    module SharedElement
      # One element on two pages: give it the same name on both, and a Turbo
      # visit between them morphs it from one place to the other (a card
      # into its detail page, a thumbnail into the hero). It is a
      # view-transition-name and needs Turbo's page view transitions, the
      # view-transition meta tag in your layout. Reduced motion swaps the
      # pages without the morph. No script.
      #
      # @example
      #   <%= poetry_shared_element(name: "product-#{product.id}") do %>
      #     <%= image_tag product.photo %>
      #   <% end %>
      class Component < Poetry::Core::Component
        requires_content "the element both pages share"

        # A name that is a valid CSS identifier.
        NAME = /\A[a-z][a-z0-9_-]*\z/i

        AGENT_RULES = [
          "Use one name per element per page: two elements with the same name on one page cancel the " \
          "transition. Build names from the record, such as product-42.",
          "Shared elements need <meta name=\"view-transition\" content=\"same-origin\"> in the layout; " \
          "without it the visit swaps the page with no morph."
        ].freeze

        option :name, :string, required: true, doc: "The view-transition name both pages give the element."
        option :as, :symbol, default: :div, doc: "The element it renders as."

        part "shared-element", "The element the visit morphs between pages; carries view-transition-name"

        def before_render
          ensure_content!
          return if name.to_s.match?(NAME)

          raise ArgumentError, "shared_element name: #{name.inspect} must be a CSS identifier, such as product-42"
        end

        def call
          content_tag(as, content, **root_attributes)
        end

        def root_attributes
          super("style" => "view-transition-name: #{name}")
        end
      end
    end
  end
end
