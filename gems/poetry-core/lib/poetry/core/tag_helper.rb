# frozen_string_literal: true

module Poetry
  module Core
    # The view-helper seam: included into ActionView by the engine
    # (initializer "poetry_core.tag_helper") and into every component, so a
    # view and a component's template build an element the same way.
    module TagHelper
      # The elements that take no content and no closing tag: {#element_tag}
      # renders these through `tag` and every other name through
      # `content_tag`.
      VOID_ELEMENTS = %w[area base br col embed hr img input link meta source track wbr].freeze

      # An element from a tag name and its attributes: where a component's
      # template spends what `root_attributes` and `element_attributes`
      # build. It takes what `content_tag` takes and renders what
      # `content_tag` renders; a void element renders the way `tag.input`
      # does.
      #
      # A component's template builds every element through this method,
      # and never through `content_tag` or `tag.div` themselves. A host may
      # compile its templates with Herb's slots, and that compile resolves
      # Action View's own tag helpers into markup ahead of the render: a
      # splat or a tag name held in a variable is more than it can read,
      # and the element comes out without its attributes, or the template
      # stops compiling. A method it does not know stays a call, so the
      # element reaches the page as it was built. `tag.attributes` is the
      # one helper a template still calls itself, for attributes written
      # inside a literal tag, and it takes its hash as an argument, never as
      # a splat. A view holds to the same rule wherever it hands a tag
      # helper a splat.
      #
      # @param name [Symbol, String] the tag name
      # @param arguments [Array] the content, when no block gives it, and
      #   the attributes when they arrive as a Hash
      # @param attributes [Hash] what `root_attributes` or a part builder
      #   returned, splatted, or the attributes written out as keywords
      # @return [ActiveSupport::SafeBuffer] the element
      # @example A root, a part and a void element
      #   <%= element_tag(:button, **root_attributes) do %>
      #     <%= element_tag(:span, label, **element_attributes(:label)) %>
      #     <%= element_tag(:input, **input_attributes) %>
      #   <% end %>
      def element_tag(name, *arguments, **attributes, &)
        return content_tag(name, *arguments, **attributes, &) unless VOID_ELEMENTS.include?(name.to_s)

        given = arguments.last.is_a?(Hash) ? arguments.last : {}
        tag.public_send(name, **given, **attributes)
      end
    end
  end
end
