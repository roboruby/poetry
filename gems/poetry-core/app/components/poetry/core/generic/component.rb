# frozen_string_literal: true

module Poetry
  module Core
    module Generic
      # Renders an arbitrary HTML element chosen at render time via
      # `html_tag:` - a void element emits a self-closing tag, anything
      # else wraps the content block.
      #
      # @example
      #   render Poetry::Core::Generic::Component.new(html_tag: "span") { "text" }
      class Component < Poetry::Core::Component
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

        attribute :html_tag, :string

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
