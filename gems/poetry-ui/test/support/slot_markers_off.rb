# frozen_string_literal: true

# The ReActionView legs hold a component to the same assertions in a host
# that compiles with slots as in a plain one. What a slot compile writes
# around the markup is the host's, not the component's, so every render in
# the suite hands its assertions the markup with the markers off: the
# attributes, the structure and the text have to be what they always were.
#
# The behaviour tier does not load this. There the markers stay in the
# page, where the controllers meet them.
module SlotMarkersOff
  # A component's own render, and every render nested in it.
  module Component
    # The component's markup without what the slot compile added.
    def render_in(...) = Poetry::Core::SlotMarkers.strip(super)
  end

  # A view, a partial or an inline template.
  module Template
    # The template's markup without what the slot compile added.
    def render(...) = Poetry::Core::SlotMarkers.strip(super)
  end
end

Poetry::Core::Component.prepend(SlotMarkersOff::Component)
ActionView::Template.prepend(SlotMarkersOff::Template)
