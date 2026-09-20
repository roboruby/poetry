# frozen_string_literal: true

# The interactive-chart doctrine demo: upstream's "interactive"
# blocks are useState filters; in poetry the filter is a real form and the
# chart re-renders ON THE SERVER - a GET round trip Turbo turns into a
# same-context body swap. The cross-render morph rides that swap: the dataset
# toggle keeps the shape (same months, same series) so the chart MORPHS
# between renders; the period toggle changes the shape, so the entrance
# replays instead.
class DemoController < ApplicationController
  DATASETS = {
    "current" => [
      { month: "January", desktop: 186, mobile: 80 },
      { month: "February", desktop: 305, mobile: 200 },
      { month: "March", desktop: 237, mobile: 120 },
      { month: "April", desktop: 73, mobile: 190 },
      { month: "May", desktop: 209, mobile: 130 },
      { month: "June", desktop: 214, mobile: 140 }
    ].freeze,
    "previous" => [
      { month: "January", desktop: 94, mobile: 170 },
      { month: "February", desktop: 168, mobile: 60 },
      { month: "March", desktop: 312, mobile: 220 },
      { month: "April", desktop: 141, mobile: 90 },
      { month: "May", desktop: 88, mobile: 210 },
      { month: "June", desktop: 260, mobile: 100 }
    ].freeze
  }.freeze

  PERIODS = { "6m" => 6, "3m" => 3 }.freeze

  def interactive
    @period = PERIODS.key?(params[:period]) ? params[:period] : "6m"
    @dataset = DATASETS.key?(params[:dataset]) ? params[:dataset] : "current"
    @data = DATASETS[@dataset].last(PERIODS[@period])
    render layout: "component_preview"
  end

  # The sync demo: two charts in one sync group (hover either, both
  # tooltips follow) + a live chart with the interactive legend.
  def sync
    @data = DATASETS["current"]
    render layout: "component_preview"
  end

  # The window demo: a year of data behind a brush strip + drag-zoom.
  def window
    @data = Array.new(12) do |i|
      { month: Date::ABBR_MONTHNAMES[i + 1],
        desktop: (200 + (Math.sin(i / 1.8) * 120) + (i * 8)).round }
    end
    render layout: "component_preview"
  end

  # The live-mode demo: the server renders the first window;
  # the page's ticker streams new points through the payload-script
  # channel and the chart re-renders client-side.
  def live
    @data = Array.new(8) do |i|
      { t: "T#{i + 1}",
        desktop: (180 + (Math.sin(i / 1.5) * 90)).round,
        mobile: (110 + (Math.cos(i / 2.0) * 60)).round }
    end
    render layout: "component_preview"
  end
end
