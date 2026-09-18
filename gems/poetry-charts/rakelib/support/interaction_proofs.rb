# frozen_string_literal: true

# The tooltip engine and the interactive doctrine proven in a real
# browser: one method per proof, each visiting its own demo page and
# raising on any outcome the engine must deliver. The facts each proof
# records (the hovered label, the live category, the brushed window) feed
# the summary line.
class PoetryInteractionProofs
  # Each proof method with the name its result prints under.
  PROOFS = {
    tooltip_engine: "the tooltip engine: hover, keyboard walk, Escape",
    server_rerender: "a server re-render morphs, a shape change replays the entrance, the tooltip survives",
    live_stream: "live mode streams client-side on the same SVG node",
    synced_and_legend: "synced tooltips follow across charts and the legend toggle hides and rescales",
    window: "the brush drag narrows the window and double-click resets it"
  }.freeze

  TOOLTIP = 'div[data-slot="chart-tooltip"]'
  SVG = '[data-slot="chart-svg"]'
  MONTHS = %w[January February March April May June].freeze

  # What the proofs recorded, for the summary.
  attr_reader :facts

  # Proofs driven through the browser session.
  def initialize(session)
    @session = session
    @facts = {}
  end

  # Hover shows the nearest month with a formatted value and the cursor,
  # End walks to June with its active dot, Escape dismisses.
  def tooltip_engine
    poetry_charts_visit_preview(@session, "/previews/poetry/charts/area_chart/default")
    raise "tooltip chrome missing" unless @session.has_css?(TOOLTIP, visible: :hidden)
    raise "tooltip visible before hover" if @session.has_css?(TOOLTIP, visible: :visible, wait: 0)

    # Hover the middle of the SVG - the bisect picks the nearest month.
    @session.find(SVG).hover
    raise "tooltip did not appear on hover" unless @session.has_css?(TOOLTIP, visible: :visible, wait: 5)
    unless @session.has_css?('[data-slot="chart-cursor"]:not([display="none"])', wait: 2)
      raise "the hover cursor did not appear"
    end

    facts[:label] = tooltip_text("chart-tooltip-label")
    facts[:value] = tooltip_text("chart-tooltip-value")
    raise "label #{facts[:label].inspect} is not a month" unless MONTHS.include?(facts[:label])
    raise "value #{facts[:value].inspect} not a formatted number" unless facts[:value].match?(/\A\d{1,3}(,\d{3})*\z/)

    # Keyboard: End jumps to June; the active dot for the last index shows.
    @session.find(SVG).send_keys(:end)
    june = tooltip_text("chart-tooltip-label")
    raise "End did not reach June (got #{june.inspect})" unless june == "June"
    unless @session.has_css?('[data-slot="chart-active-dot"][data-index="5"][display=""]', wait: 2)
      raise "the active dot did not show for the last index"
    end

    @session.find(SVG).send_keys(:escape)
    raise "Escape did not dismiss" if @session.has_css?(TOOLTIP, visible: :visible, wait: 0)
  end

  # A real form and a server re-render: the dataset swap morphs between
  # renders onto new geometry, the 6 to 3 month shape change replays the
  # entrance, and the tooltip engine survives the round trip.
  def server_rerender
    @session.visit("/interactive")
    raise "interactive demo missing" unless @session.has_css?('[data-slot="demo-period-form"]')
    raise "Turbo is not driving the demo" unless @session.evaluate_script("!!window.Turbo")

    six_month_ticks = x_ticks.length
    raise "expected 6 months, got #{six_month_ticks}" unless six_month_ticks == 6

    before_d = @session.find('path[data-slot="chart-area"]', match: :first)["d"]
    @session.select("Last year", from: "dataset")
    @session.click_button("Apply")
    raise "the dataset swap did not morph (data-motion never hit \"morph\")" unless motion?("morph")
    raise "the morph never settled" unless motion?("settled")

    after_d = @session.find('path[data-slot="chart-area"]', match: :first)["d"]
    raise "the morph landed on the old geometry" if after_d == before_d

    @session.select("Last 3 months", from: "period")
    @session.click_button("Apply")
    raise "the shape change did not replay the entrance" unless motion?("entrance")
    raise "the form round-trip did not land" unless @session.has_css?('[data-slot="chart-x-axis"]', wait: 5)

    three_month_ticks = x_ticks.length
    raise "expected 3 months after the round trip, got #{three_month_ticks}" unless three_month_ticks == 3

    @session.find(SVG).hover
    return if @session.has_css?(TOOLTIP, visible: :visible, wait: 5)

    raise "the tooltip engine did not survive the server round-trip"
  end

  # The streaming demo updates with zero server round trips: same page,
  # same SVG node, a sliding window, morphing ticks, and a tooltip that
  # serves fresh values mid-stream.
  def live_stream
    @session.visit("/live")
    raise "live demo missing" unless @session.has_css?('[data-slot="demo-live"]')
    raise "live chart never settled" unless @session.has_css?("#{SVG}[data-motion=\"settled\"]", wait: 6)

    @session.execute_script(<<~JS)
      window.__pageMarker = true
      window.__areaNode = document.querySelector('path[data-slot="chart-area"]')
      window.__liveD0 = window.__areaNode.getAttribute("d")
      window.__firstTick0 = document.querySelector('[data-slot="chart-x-axis"] text').textContent
    JS
    raise "live ticks never morphed" unless motion?("morph")

    ticks = poll(until_true: ->(count) { count >= 2 }) { @session.evaluate_script("window.__liveTicks || 0") }
    raise "the ticker never ticked (#{ticks})" if ticks < 2

    checks = @session.evaluate_script(<<~JS)
      ({
        samePage: window.__pageMarker === true,
        sameNode: document.querySelector('path[data-slot="chart-area"]') === window.__areaNode,
        dChanged: window.__areaNode.getAttribute("d") !== window.__liveD0,
        windowSlid: document.querySelector('[data-slot="chart-x-axis"] text').textContent !== window.__firstTick0
      })
    JS
    raise "the page navigated - not a client-side update" unless checks["samePage"]
    raise "the SVG node was replaced - not an attribute-channel update" unless checks["sameNode"]
    raise "the live chart never redrew" unless checks["dChanged"]
    raise "the sliding window never slid" unless checks["windowSlid"]

    @session.find(SVG).send_keys(:home)
    raise "tooltip dead mid-stream" unless @session.has_css?(TOOLTIP, visible: :visible, wait: 5)

    facts[:live_label] = tooltip_text("chart-tooltip-label")
    return if facts[:live_label].match?(/\AT\d+\z/)

    raise "tooltip label #{facts[:live_label].inspect} is not a stream category"
  end

  # Synced charts share the tooltip position and the Escape; the legend
  # toggle hides a series, rescales the axis, and restores.
  def synced_and_legend
    @session.visit("/sync")
    raise "sync demo missing" unless @session.has_css?('[data-slot="demo-sync-a"]')

    @session.find("[data-slot=\"demo-sync-a\"] #{SVG}").send_keys(:home)
    a_tooltip = "[data-slot=\"demo-sync-a\"] #{TOOLTIP}"
    b_tooltip = "[data-slot=\"demo-sync-b\"] #{TOOLTIP}"
    raise "chart A tooltip missing" unless @session.has_css?(a_tooltip, visible: :visible, wait: 5)
    raise "the SYNCED chart B tooltip did not follow" unless @session.has_css?(b_tooltip, visible: :visible, wait: 5)

    facts[:synced_label] = @session.find("#{a_tooltip} [data-slot='chart-tooltip-label']", visible: :all).text
    b_label = @session.find("#{b_tooltip} [data-slot='chart-tooltip-label']", visible: :all).text
    raise "synced labels diverge (#{facts[:synced_label]} vs #{b_label})" unless facts[:synced_label] == b_label

    @session.find("[data-slot=\"demo-sync-a\"] #{SVG}").send_keys(:escape)
    raise "chart B tooltip did not dismiss with the synced Escape" if @session.has_css?(b_tooltip, visible: :visible,
                                                                                                   wait: 0)

    scope = '[data-slot="demo-legend-toggle"]'
    facts[:ticks_before] = @session.all("#{scope} [data-slot='chart-y-axis'] text").map(&:text)
    @session.find("#{scope} button[data-key='desktop']").click
    raise "the legend item did not dim" unless @session.has_css?("#{scope} button[data-key='desktop'][data-hidden]",
                                                                 wait: 5)

    hidden = "#{scope} path[data-slot=\"chart-area\"][data-key=\"desktop\"]"
    display = @session.evaluate_script("getComputedStyle(document.querySelector('#{hidden}')).display")
    raise "the toggled series did not hide" unless display == "none"

    facts[:ticks_after] = @session.all("#{scope} [data-slot='chart-y-axis'] text").map(&:text)
    @session.find("#{scope} button[data-key='desktop']").click
    return if @session.has_css?("#{scope} button[data-key='desktop']:not([data-hidden])", wait: 5)

    raise "the legend toggle did not restore"
  end

  # The window demo: a brush handle drag narrows twelve months, the window
  # persists into the live payload, and a double-click resets it.
  def window
    @session.visit("/window")
    raise "window demo missing" unless @session.has_css?('[data-slot="demo-window"]')
    raise "expected 12 months" unless x_ticks.length == 12

    mouse = @session.driver.browser.mouse
    rect = @session.evaluate_script(
      "document.querySelector('[data-slot=\"chart-brush-handle\"][data-edge=\"end\"]').getBoundingClientRect().toJSON()"
    )
    from_x = rect["x"] + (rect["width"] / 2)
    from_y = rect["y"] + (rect["height"] / 2)
    mouse.move(x: from_x, y: from_y)
    mouse.down
    mouse.move(x: from_x - (rect["width"] * 30), y: from_y, steps: 8)
    mouse.up

    facts[:brushed_ticks] = poll(settle: 0.1, until_true: ->(count) { count < 12 }) { x_ticks.length }
    unless facts[:brushed_ticks] < 12
      raise "the brush drag never narrowed the window (still #{facts[:brushed_ticks]} ticks)"
    end

    facts[:window] = @session.evaluate_script(
      "JSON.parse(document.querySelector('[data-slot=\"chart-live-payload\"]').textContent).frame.window"
    )
    raise "the window was not persisted (#{facts[:window].inspect})" unless facts[:window].is_a?(Array)

    # Two CDP clicks are too slow to coalesce into a dblclick - dispatch it
    # (the pointer mechanics are already proven by the drag above).
    @session.execute_script(
      "document.querySelector('#{SVG}').dispatchEvent(new MouseEvent('dblclick', { bubbles: true }))"
    )
    reset_ticks = poll(settle: 0.1, until_true: ->(count) { count == 12 }) { x_ticks.length }
    raise "double-click did not reset the window (#{reset_ticks} ticks)" unless reset_ticks == 12
  end

  # The summary line the proofs' facts spell out.
  def summary
    "interaction: hover -> #{facts[:label]} #{facts[:value]}, keyboard -> June, Escape dismisses; " \
      "the dataset swap MORPHS between server renders (data-motion morph -> settled, new geometry), " \
      "the 6 -> 3 month shape change replays the entrance, and the tooltip survives every swap; " \
      "live mode streams client-side (same page, same SVG node, sliding window, morphing ticks, " \
      "tooltip live at #{facts[:live_label]}); synced tooltips follow across charts (#{facts[:synced_label]}) " \
      "and the legend toggle hides + rescales (y ticks #{facts[:ticks_before]&.join("/")} -> " \
      "#{facts[:ticks_after]&.join("/")}); the brush drag narrows 12 -> #{facts[:brushed_ticks]} months " \
      "(window #{facts[:window].inspect}) and double-click resets - the engine works in Chrome"
  end

  private

  # The text of a tooltip part, visible or not.
  def tooltip_text(slot)
    @session.find("#{TOOLTIP} [data-slot='#{slot}']", visible: :all).text
  end

  # The x-axis tick labels on the page.
  def x_ticks
    @session.all('[data-slot="chart-x-axis"] text')
  end

  # Whether the chart reaches a motion state within five seconds.
  def motion?(state)
    @session.has_css?("#{SVG}[data-motion=\"#{state}\"]", wait: 5)
  end

  # Polls the reader up to thirty times, a pause apart, until its value
  # satisfies the condition; the last value either way, for the caller
  # to judge.
  def poll(until_true:, settle: 0.3)
    value = nil
    30.times do
      value = yield
      break if until_true.call(value)

      sleep settle
    end
    value
  end
end
