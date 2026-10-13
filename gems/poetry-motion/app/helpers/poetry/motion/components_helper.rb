# frozen_string_literal: true

module Poetry
  module Motion
    # The view helpers for poetry-motion's effects, included into every
    # view by the engine.
    module ComponentsHelper
      # A list whose Turbo Stream changes animate.
      def poetry_animated_list(**, &) = render(Poetry::Motion::AnimatedList::Component.new(**), &)

      # A region whose data-layout-id elements move between places.
      def poetry_layout_group(**, &) = render(Poetry::Motion::LayoutGroup::Component.new(**), &)

      # An element a Turbo visit morphs between two pages.
      def poetry_shared_element(**, &) = render(Poetry::Motion::SharedElement::Component.new(**), &)

      # A row of items that swell toward the pointer.
      def poetry_dock(**, &) = render(Poetry::Motion::Dock::Component.new(**), &)

      # A wrapper that pulls its control toward the pointer.
      def poetry_magnetic(**, &) = render(Poetry::Motion::Magnetic::Component.new(**), &)

      # A surface with a glow that follows the pointer.
      def poetry_spotlight_card(**, &) = render(Poetry::Motion::SpotlightCard::Component.new(**), &)

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
