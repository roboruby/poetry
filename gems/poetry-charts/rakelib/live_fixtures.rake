# frozen_string_literal: true

# The live-renderer parity fixtures: render each streaming-trio
# case TWICE on the server (dataset A and dataset B) and commit both. The
# vitest suite loads render A, applies the client renderer with dataset B,
# and compares every geometry attribute against render B - so the kernel
# renderer is proven byte-equal to the Ruby engine, the same discipline as
# the geometry fixtures.
LIVE_DATA_A = [
  { month: "January", desktop: 186, mobile: 80 },
  { month: "February", desktop: 305, mobile: 200 },
  { month: "March", desktop: 237, mobile: 120 },
  { month: "April", desktop: 73, mobile: 190 },
  { month: "May", desktop: 209, mobile: 130 },
  { month: "June", desktop: 214, mobile: 140 }
].freeze

LIVE_DATA_B = [
  { month: "January", desktop: 94.5, mobile: 170 },
  { month: "February", desktop: 168, mobile: 60 },
  { month: "March", desktop: 312, mobile: 220 },
  { month: "April", desktop: 141, mobile: 90.25 },
  { month: "May", desktop: 88, mobile: 210 },
  { month: "June", desktop: 260, mobile: 100 }
].freeze

# The line case's B set grows the window and drops a point - exercises
# the reconcile-by-clone path (ticks, dots, active dots) and the gap.
LIVE_LINE_B = (LIVE_DATA_B.map(&:dup).tap { |rows| rows[2][:mobile] = nil } +
               [{ month: "July", desktop: 199, mobile: 155 }]).freeze

LIVE_CONFIG = {
  desktop: { label: "Desktop", color: "var(--chart-1)" },
  mobile: { label: "Mobile", color: "var(--chart-2)" }
}.freeze

namespace :live do
  desc "Regenerate test/fixtures/live_fixtures.json from the Ruby engine"
  task :fixtures do
    poetry_charts_boot!
    require "json"
    require "nokogiri"

    view = ApplicationController.new.view_context

    build = lambda do |component, &slots|
      html = view.render(component, &slots)
      doc = Nokogiri::HTML5.fragment(html)
      frame = doc.at_css("div[data-chart] > div")
      payload = frame.at_css('script[data-slot="chart-live-payload"]')
      { "frame" => frame.to_html, "payload" => payload && JSON.parse(payload.text) }
    end

    area = lambda do |data|
      build.call(Poetry::Charts::AreaChart::Component.new(
                   data: data, config: LIVE_CONFIG, id: "live-a", live: true,
                   margin: { left: 12, right: 12 }
                 )) do |chart|
        chart.with_grid
        chart.with_x_axis(data_key: :month)
        chart.with_area(data_key: :mobile, stack: :a)
        chart.with_area(data_key: :desktop, stack: :a)
        chart.with_tooltip
      end
    end

    line = lambda do |data|
      build.call(Poetry::Charts::LineChart::Component.new(
                   data: data, config: LIVE_CONFIG, id: "live-l", live: true
                 )) do |chart|
        chart.with_grid
        chart.with_x_axis(data_key: :month)
        chart.with_y_axis(tick_count: 3)
        chart.with_line(data_key: :desktop, curve: :monotone_x, dots: true)
        chart.with_line(data_key: :mobile, curve: :linear, dots: true)
        chart.with_tooltip
      end
    end

    bar = lambda do |data|
      build.call(Poetry::Charts::BarChart::Component.new(
                   data: data, config: LIVE_CONFIG, id: "live-b", live: true
                 )) do |chart|
        chart.with_grid
        chart.with_x_axis(data_key: :month)
        chart.with_y_axis(tick_count: 3)
        chart.with_bar(data_key: :desktop, radius: 4)
        chart.with_bar(data_key: :mobile, radius: 4)
        chart.with_tooltip
      end
    end

    bar_horizontal = lambda do |data|
      build.call(Poetry::Charts::BarChart::Component.new(
                   data: data, config: LIVE_CONFIG, id: "live-bh", live: true,
                   orientation: :horizontal
                 )) do |chart|
        chart.with_grid(vertical: true, horizontal: false)
        chart.with_y_axis(data_key: :month)
        chart.with_bar(data_key: :desktop, radius: [0, 4, 4, 0])
        chart.with_tooltip
      end
    end

    cases = [
      ["area_stacked", area, LIVE_DATA_B],
      ["line_dots_window", line, LIVE_LINE_B],
      ["bar_grouped", bar, LIVE_DATA_B],
      ["bar_horizontal", bar_horizontal, LIVE_DATA_B]
    ].map do |name, builder, data_b|
      a = builder.call(LIVE_DATA_A)
      b = builder.call(data_b)
      {
        "name" => name,
        "frame_a" => a["frame"],
        "payload" => a["payload"],
        "data_b" => data_b.map { |row| row.transform_keys(&:to_s) },
        "frame_b" => b["frame"]
      }
    end

    path = Poetry::Charts.root.join("test/fixtures/live_fixtures.json")
    File.write(path, JSON.pretty_generate({ "cases" => cases }))
    puts "live fixtures written: #{cases.map { |c| c["name"] }.join(", ")}"
  end
end
