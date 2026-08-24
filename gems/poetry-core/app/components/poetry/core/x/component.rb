# frozen_string_literal: true

module Poetry
  module Core
    # Namespace of the X demo component - legacy reference code exercising
    # the style machinery.
    module X
      # Renders one X-shaped SVG glyph, styled through the sidecar Style
      # dictionary (color x mode x size x shape). Retained as legacy
      # reference code exercising the style machinery - not a pattern for
      # new components.
      #
      # @example
      #   render Poetry::Core::X::Component.new(color: :red, size: :large)
      class Component < Poetry::Core::Component
        style :mode, default: :light, required: true, variants: %i[
          light
          dark
        ], doc: "The color-scheme axis the compound dark strokes key on."

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
        ], doc: "The stroke color family."

        style :size, default: :medium, required: true, variants: %i[
          small
          medium
          large
        ], doc: "The rendered glyph size."

        style :shape, default: :square, required: true, variants: %i[
          square
          round
        ], doc: "The outline shape (visual no-op in the shipped dictionary)."

        part "icon", "The demo SVG itself - the whole component is one part"

        # Emits the styled <svg> with its X-path.
        def call
          content_tag(:svg, **svg_attributes.to_attributes) do
            tag.path(d: "M4 4l6 6m0-6l-6 6")
          end
        end

        # The root <svg> attributes: caller HTML attributes over the SVG
        # defaults (namespace, viewbox, data-slot).
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
