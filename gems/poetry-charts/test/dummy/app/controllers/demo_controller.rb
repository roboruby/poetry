# frozen_string_literal: true

# The interactive-chart doctrine demo (N10 W9): upstream's "interactive"
# blocks are useState filters; in poetry the filter is a real form and the
# chart re-renders ON THE SERVER - a plain GET round trip (Turbo makes it
# smooth in real apps; the mechanics need no JS at all).
class DemoController < ApplicationController
  DATA = [
    { month: "January", desktop: 186, mobile: 80 },
    { month: "February", desktop: 305, mobile: 200 },
    { month: "March", desktop: 237, mobile: 120 },
    { month: "April", desktop: 73, mobile: 190 },
    { month: "May", desktop: 209, mobile: 130 },
    { month: "June", desktop: 214, mobile: 140 }
  ].freeze

  PERIODS = { "6m" => 6, "3m" => 3 }.freeze

  def interactive
    @period = PERIODS.key?(params[:period]) ? params[:period] : "6m"
    @data = DATA.last(PERIODS[@period])
    render layout: "component_preview"
  end
end
