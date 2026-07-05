# frozen_string_literal: true

# The real-browser interaction proof (N10 W5): hover the area-default
# preview in headless Chrome and assert the tooltip engine end to end -
# controller boots off the importmap, bisects the embedded coordinates,
# swaps the pre-formatted values into the chrome, keyboard walks, Escape
# dismisses. Not in the default gate - needs Chrome.
namespace :test do
  desc "Prove the tooltip engine in a real browser (hover + keyboard + dismiss)"
  task interaction: :"browser:assets" do
    session = poetry_charts_browser_session

    poetry_charts_visit_preview(session, "/previews/poetry/charts/area_chart/default")

    tooltip = 'div[data-slot="chart-tooltip"]'
    raise "tooltip chrome missing" unless session.has_css?(tooltip, visible: :hidden)
    raise "tooltip visible before hover" if session.has_css?(tooltip, visible: :visible, wait: 0)

    # Hover the middle of the SVG - the bisect picks the nearest month.
    session.find('[data-slot="chart-svg"]').hover
    raise "tooltip did not appear on hover" unless session.has_css?(tooltip, visible: :visible, wait: 5)

    label = session.find("#{tooltip} [data-slot='chart-tooltip-label']", visible: :all).text
    value = session.find("#{tooltip} [data-slot='chart-tooltip-value']", visible: :all).text
    months = %w[January February March April May June]
    raise "label #{label.inspect} is not a month" unless months.include?(label)
    raise "value #{value.inspect} not a formatted number" unless value.match?(/\A\d{1,3}(,\d{3})*\z/)

    # Keyboard: End jumps to June; the active dot for the last index shows.
    session.find('[data-slot="chart-svg"]').send_keys(:end)
    june = session.find("#{tooltip} [data-slot='chart-tooltip-label']", visible: :all).text
    raise "End did not reach June (got #{june.inspect})" unless june == "June"
    unless session.has_css?('[data-slot="chart-active-dot"][data-index="5"][display=""]', wait: 2)
      raise "the active dot did not show for the last index"
    end

    # Escape dismisses.
    session.find('[data-slot="chart-svg"]').send_keys(:escape)
    raise "Escape did not dismiss" if session.has_css?(tooltip, visible: :visible, wait: 0)

    # -- the interactive doctrine: a real form, a server re-render ------------
    session.visit("/interactive")
    raise "interactive demo missing" unless session.has_css?('[data-slot="demo-period-form"]')

    six_month_ticks = session.all('[data-slot="chart-x-axis"] text').length
    raise "expected 6 months, got #{six_month_ticks}" unless six_month_ticks == 6

    session.select("Last 3 months", from: "period")
    session.click_button("Apply")
    raise "the form round-trip did not land" unless session.has_css?('[data-slot="chart-x-axis"]', wait: 5)

    three_month_ticks = session.all('[data-slot="chart-x-axis"] text').length
    raise "expected 3 months after the round trip, got #{three_month_ticks}" unless three_month_ticks == 3

    session.find('[data-slot="chart-svg"]').hover
    unless session.has_css?(tooltip, visible: :visible, wait: 5)
      raise "the tooltip engine did not survive the server round-trip"
    end

    puts "interaction: hover -> #{label} #{value}, keyboard -> June, Escape dismisses; " \
         "the interactive form round-trips server-side (6 -> 3 months) with the tooltip live - " \
         "the engine works in Chrome"
  end
end
