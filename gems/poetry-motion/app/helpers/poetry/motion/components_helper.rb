# frozen_string_literal: true

module Poetry
  module Motion
    # The view helpers for poetry-motion's effects, included into every
    # view by the engine.
    module ComponentsHelper
      # A looping marquee of the block's items.
      def poetry_marquee(**, &) = render(Poetry::Motion::Marquee::Component.new(**), &)

      # A passage whose words brighten as it scrolls into view.
      def poetry_text_reveal(text = nil, **) = render(Poetry::Motion::TextReveal::Component.new(text, **))

      # A number that counts up to its value.
      def poetry_number_ticker(**) = render(Poetry::Motion::NumberTicker::Component.new(**))

      # A surface that leans toward the pointer.
      def poetry_tilt_card(**, &) = render(Poetry::Motion::TiltCard::Component.new(**), &)
    end
  end
end
