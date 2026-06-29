# frozen_string_literal: true

module Poetry
  module Core
    module X
      class Component < Poetry::Core::Component
        style :mode, default: :light, required: true, variants: %i[
          light
          dark
        ]

        style :color, default: :indigo, required: true, variants: %i[
          slate
          gray
          zinc
          neutral
          stone
          red
          orange
          amber
          yellow
          lime
          green
          emerald
          teal
          cyan
          sky
          blue
          indigo
          violet
          purple
          fuchsia
          pink
          rose
        ]

        style :size, default: :medium, required: true, variants: %i[
          small
          medium
          large
        ]

        style :shape, default: :square, required: true, variants: %i[
          square
          round
        ]

        def call
          content_tag(:svg, **svg_attributes.to_attributes) do
            tag.path(d: "M4 4l6 6m0-6l-6 6")
          end
        end

        def svg_attributes
          html_attributes.merge_if_not_set(default_svg_attributes)
        end

        private

        def default_svg_attributes
          {}.tap do |attrs|
            attrs["xmlns"] = "http://www.w3.org/2000/svg"
            attrs["viewbox"] = "0 0 14 14"
            attrs["data-slot"] = "icon"
          end
        end
      end
    end
  end
end
