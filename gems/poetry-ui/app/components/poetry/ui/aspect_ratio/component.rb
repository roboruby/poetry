# frozen_string_literal: true

module Poetry
  module Ui
    module AspectRatio
      # The AspectRatio - a container that locks its width:height ratio
      # (CSS aspect-ratio via the --ratio custom property). The content is
      # whatever should keep the shape: an image, an embed, a placeholder.
      class Component < Poetry::Core::Component
        AGENT_RULES = [
          "Pass ratio: as a string fraction ('16/9', '1/1') - Ruby's 16/9 is integer division (1).",
          "The child fills the box itself (size-full object-cover on an image)."
        ].freeze

        # A CSS <ratio>: "16/9", "1", "1.5" - kept a string so the fraction
        # survives verbatim into the --ratio custom property.
        option :ratio, :string, required: true

        RATIO = %r{\A\d+(\.\d+)?(\s*/\s*\d+(\.\d+)?)?\z}

        def before_render
          return if ratio.present? && ratio.match?(RATIO)

          raise ArgumentError,
                "AspectRatio ratio: must be a CSS ratio ('16/9', '1', '1.5') - got #{ratio.inspect}"
        end

        def call
          content_tag(:div, content, **root_attributes.to_attributes)
        end

        def root_attributes
          html_attributes.merge_if_not_set(
            {
              "data-slot" => "aspect-ratio",
              "style" => "--ratio: #{ratio}"
            }.merge(component_data_attributes)
          )
        end
      end
    end
  end
end
