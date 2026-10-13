# frozen_string_literal: true

module Poetry
  module Motion
    module Marquee
      # A row (or column) of items that scrolls in a loop, logos or
      # testimonials. The loop is CSS, so no engine loads. The server
      # renders the items once for readers and `repeat:` copies for the
      # loop, aria-hidden and inert. Hover and focus inside pause it, and a
      # pause control holds it still (WCAG 2.2.2). Under reduced motion it
      # stands still and only the readable copy shows.
      #
      # @example
      #   <%= poetry_marquee(label: "Our customers") do %>
      #     <% customers.each do |customer| %><%= image_tag customer.logo, alt: customer.name %><% end %>
      #   <% end %>
      class Component < Poetry::Core::Component
        include Poetry::Motion::Options

        requires_content "the items that scroll"

        # The directions the loop can travel.
        DIRECTIONS = %i[left right up down].freeze

        AGENT_RULES = [
          "Marquee items carry no ids and no focusable controls the reader needs: the loop copies them " \
          "(aria-hidden and inert), and the readable first copy is what assistive tech gets.",
          "Keep pausable: true. A loop that moves for more than five seconds needs a pause control " \
          "(WCAG 2.2.2); poetry check flags pausable: false."
        ].freeze

        use_stimulus do
          on :root do
            controller(:marquee) { register }
          end
          on :pause do
            controller(:marquee) do
              target :pause
              action :toggle, on: :click
            end
          end
        end

        motion_options
        option :label, :string, doc: "The region's accessible name, such as \"Our customers\"."
        option :direction, :symbol, default: :left, doc: "Which way the items travel: left, right, up or down."
        option :duration, :integer, default: 40, doc: "Seconds for one full loop."
        option :repeat, :integer, default: 2, doc: "How many copies make the loop, the readable one included."
        option :pausable, :boolean, default: true,
                                    doc: "Renders the pause control; required for a loop longer than five seconds."
        option :pause_label, :string, default: "Pause", doc: "The pause control's text."

        validates :direction, inclusion: { in: DIRECTIONS }

        part "marquee", "The looping region - pauses on hover, on focus inside, and while data-paused is set",
             states: {
               "data-direction" => { condition: "always - the travel direction", values: DIRECTIONS.map(&:to_s) },
               "data-paused" => "the pause control holds the loop still"
             },
             vars: { "--marquee-duration" => "seconds per loop (duration:)",
                     "--marquee-gap" => "the space between items and between copies" }
        part "marquee-track", "One copy of the items; every copy after the first is aria-hidden and inert"
        part "marquee-pause", "The pause control, a toggle button (aria-pressed)"

        def before_render
          ensure_content!
          ensure_within!(:repeat, 2..6)
          ensure_within!(:duration, 1..600)
        end

        def call
          tag.div(**root_attributes) do
            safe_join(Array.new(repeat) { |index| track(index) } + [pause_control].compact)
          end
        end

        def root_attributes
          attrs = { "role" => "region", "aria-label" => label.presence, "data-direction" => direction,
                    "style" => "--marquee-duration: #{duration}s" }
          attrs["data-animate"] = "false" unless animate
          super(attrs.compact)
        end

        private

        # One copy of the items; copies after the first are hidden from readers and focus.
        def track(index)
          attrs = { "data-slot" => "marquee-track", "class" => css(:track) }
          if index.positive?
            attrs["aria-hidden"] = "true"
            attrs["inert"] = ""
          end
          tag.div(content, **attrs)
        end

        # The pause toggle, unless pausable: false.
        def pause_control
          return unless pausable

          tag.button(pause_label, type: "button", "aria-pressed" => "false", "data-slot" => "marquee-pause",
                                  class: css(:pause), **stimulus_attributes_for(:pause))
        end
      end
    end
  end
end
