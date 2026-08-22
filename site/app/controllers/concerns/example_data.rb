# frozen_string_literal: true

# The two example sets that are NOT self-contained partials: the
# pagination guide (three live adapter navs off one collection) and the
# interactive demo (server-round-trip filter). Shared by the pages that
# host them and the standalone example view, so the data prep can never
# fork.
module ExampleData
  DEMO_DATASETS = {
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

  DEMO_PERIODS = { "6m" => 6, "3m" => 3 }.freeze

  private

  def prepare_chat_replay
    @replay_cursor = ChatReplay.cursor(params)
    @replay_decision = ChatReplay.decision(params)
  end

  def prepare_interactive_demo
    @period = ExampleData::DEMO_PERIODS.key?(params[:period]) ? params[:period] : "6m"
    @dataset = ExampleData::DEMO_DATASETS.key?(params[:dataset]) ? params[:dataset] : "current"
    @data = ExampleData::DEMO_DATASETS[@dataset].last(ExampleData::DEMO_PERIODS[@period])
  end

  # One shared collection drives all three live pagination navs: every gem
  # reads the same ?page= param, so clicking any nav pages them together.
  def prepare_pagination_examples
    page = params.fetch(:page, 3).to_i.clamp(1, 12)
    items = (1..120).to_a
    @kaminari_items = Kaminari.paginate_array(items).page(page).per(10)
    @pagy, _pagy_items = pagy(:offset, items, page: page, limit: 10)
    @will_paginate_items = WillPaginate::Collection.create(page, 10, items.size) do |pager|
      pager.replace(items[pager.offset, pager.per_page])
    end
  end
end
