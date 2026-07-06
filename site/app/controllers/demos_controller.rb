# The interaction demos. Three of the four pages are self-contained
# partials; "interactive" is the exception BY DESIGN - its whole point is
# that the filter is a real form and the data comes back from the server,
# so the controller owns the datasets and reads the params.
class DemosController < ApplicationController
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

  def show
    @entry = DocsCatalog.find("demos", params[:slug])
    raise ActionController::RoutingError, "unknown demo #{params[:slug]}" unless @entry

    prepare_interactive if @entry.slug == "interactive"
    @examples = helpers.docs_examples_for("demos", @entry.slug)
    render template: "docs/page"
  end

  private

  def prepare_interactive
    @period = PERIODS.key?(params[:period]) ? params[:period] : "6m"
    @dataset = DATASETS.key?(params[:dataset]) ? params[:dataset] : "current"
    @data = DATASETS[@dataset].last(PERIODS[@period])
  end
end
