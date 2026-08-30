# frozen_string_literal: true

module Poetry
  module Core
    # Namespace of the Box primitive.
    module Box
      # The polymorphic-tag primitive: one element, any tag, the full
      # poetry attribute machinery. Box exists for the bare styled
      # element a real component would be too much for - a spacer, a
      # semantic wrapper, a grid cell - while keeping the class merger,
      # Stimulus `data:` merging, and self-identification that a raw
      # `content_tag` skips. Void elements (`br`, `hr`, `img`, ...)
      # self-close and take no content block.
      #
      # @example A semantic wrapper
      #   render Poetry::Core::Box::Component.new(html_tag: "section", class: "grid gap-4") do
      #     "content"
      #   end
      #
      # @example A void element
      #   render Poetry::Core::Box::Component.new(html_tag: "hr", class: "my-6")
      class Component < Poetry::Core::Component
        # The HTML void elements: they emit a self-closing tag and take
        # no content block.
        VOID_TAGS = %w[
          area base br col embed hr img input link meta param source track wbr
        ].freeze

        # Tag names: letters, digits, and dashes (custom elements),
        # starting with a letter.
        TAG_NAME = /\A[a-z][a-z0-9-]*\z/i

        option :html_tag, :string, default: "div",
                                   doc: "The element to render ('div', 'section', 'span', ...); void elements " \
                                        "(br, hr, img, ...) self-close and take no content block."

        part "box", "The rendered element itself - the whole component is one part"

        # Enforces the tag-name contract with teaching messages.
        # @api private
        def before_render
          raise ArgumentError, "Box requires html_tag: (the element to render)" if html_tag.blank?
          raise ArgumentError, "Box html_tag: #{html_tag.inspect} is not a tag name" unless html_tag.match?(TAG_NAME)
        end

        # Emits the chosen tag: self-closing for void elements, wrapping
        # the content block otherwise. A void element with a content
        # block raises - the content would be silently unrenderable.
        #
        # @return [ActiveSupport::SafeBuffer]
        def call
          if void?
            raise ArgumentError, "Box html_tag: #{html_tag} is a void element - it takes no content block" if content?

            tag(html_tag, box_attributes.to_attributes)
          else
            content_tag(html_tag, content, **box_attributes.to_attributes)
          end
        end

        # The element's attributes: caller HTML attributes (class merged,
        # Stimulus keys concatenated) over the self-identification pair.
        #
        # @return [Poetry::Core::HTML::Attributes]
        def box_attributes
          html_attributes.merge_if_not_set(
            { "data-slot" => "box" }.merge(component_data_attributes)
          )
        end

        private

        # Whether the chosen tag is a void element.
        def void?
          VOID_TAGS.include?(html_tag.to_s.downcase)
        end

        private :box_attributes
      end
    end
  end
end
