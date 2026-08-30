# frozen_string_literal: true

module Poetry
  module Core
    # Namespace of the generic tag-of-your-choice component.
    module Generic
      # Renders an arbitrary HTML element chosen at render time via
      # `html_tag:` - a void element emits a self-closing tag, anything
      # else wraps the content block.
      #
      # @example
      #   render Poetry::Core::Generic::Component.new(html_tag: "span") { "text" }
      class Component < Poetry::Core::Component
        # The HTML void elements, which emit a self-closing tag and take no
        # content block.
        SELF_CLOSING_TAGS = %w[
          area
          base
          br
          col
          embed
          hr
          img
          input
          link
          meta
          param
          source
          track
          wbr
        ].freeze

        # The tag name to render ("span", "hr", ...).
        attribute :html_tag, :string

        # Emits the chosen tag: self-closing for void elements, wrapping
        # the content block otherwise.
        #
        # @return [ActiveSupport::SafeBuffer]
        def call
          if self_closing_tag?(html_tag)
            tag(html_tag) # , html_attributes)
          else
            content_tag(html_tag, content) # , html_attributes)
          end
        end

        private

        def self_closing_tag?(html_tag)
          SELF_CLOSING_TAGS.include?(html_tag.to_s)
        end
      end
    end
  end
end
