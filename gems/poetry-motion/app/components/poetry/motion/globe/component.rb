# frozen_string_literal: true

module Poetry
  module Motion
    module Globe
      # A dotted globe that turns slowly, with markers at the places you
      # give it - a decorative map of where something happens. It is drawn
      # by the cobe kernel with WebGL on a server-rendered canvas, turns only
      # while on screen, and stands still under reduced motion. Say what it
      # shows in text nearby or with label:; the canvas itself is a picture.
      #
      # @example
      #   <%= poetry_globe(markers: offices.map { [_1.lat, _1.lng] }, label: "Our offices") %>
      class Component < Poetry::Core::Component
        include Poetry::Motion::Options

        AGENT_RULES = [
          "The globe is a picture: give it label: or put the places in text beside it; the markers are " \
          "not readable on their own."
        ].freeze

        use_behavior :frame

        use_stimulus do
          on :root do
            controller :globe, if: :animate do
              register
              value :markers, from: :markers_json, if: -> { Array(markers).any? }
              value :speed
            end
          end
          on :canvas do
            controller(:globe, if: :animate) { target :canvas }
          end
        end

        motion_options
        option :markers, ActiveModel::Type::Value.new, default: [], doc: "[[latitude, longitude], ...]"
        option :speed, :float, default: 0.3, doc: "Radians per second it turns; 0 holds it still."
        option :label, :string, doc: "What the globe shows, for a screen reader."

        part "globe", "The square the globe fills"
        part "globe-canvas", "The canvas cobe draws on"

        def before_render
          ensure_within!(:speed, 0.0..3.0)
          bad = Array(markers).reject { |pair| pair.is_a?(Array) && pair.size == 2 && pair.all?(Numeric) }
          return unless bad.any?

          raise ArgumentError,
                "globe markers: takes [[latitude, longitude], ...] (got #{bad.first.inspect})"
        end

        def call
          tag.div(**root_attributes) do
            tag.canvas("data-slot" => "globe-canvas", class: css(:canvas), **canvas_attributes)
          end
        end

        private

        def canvas_attributes
          attrs = stimulus_attributes_for(:canvas)
          label.present? ? attrs.merge("role" => "img", "aria-label" => label) : attrs.merge("aria-hidden" => "true")
        end

        def markers_json = Array(markers).to_json
      end
    end
  end
end
