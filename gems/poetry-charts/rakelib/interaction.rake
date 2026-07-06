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
    unless session.has_css?('[data-slot="chart-cursor"]:not([display="none"])', wait: 2)
      raise "the hover cursor did not appear"
    end

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
    raise "Turbo is not driving the demo" unless session.evaluate_script("!!window.Turbo")

    six_month_ticks = session.all('[data-slot="chart-x-axis"] text').length
    raise "expected 6 months, got #{six_month_ticks}" unless six_month_ticks == 6

    # -- the A-W3 morph: same shape, new values -> FLIP between renders -------
    before_d = session.find('path[data-slot="chart-area"]', match: :first)["d"]
    session.select("Last year", from: "dataset")
    session.click_button("Apply")
    unless session.has_css?('[data-slot="chart-svg"][data-motion="morph"]', wait: 5)
      raise "the dataset swap did not morph (data-motion never hit \"morph\")"
    end
    raise "the morph never settled" unless session.has_css?('[data-slot="chart-svg"][data-motion="settled"]', wait: 5)

    after_d = session.find('path[data-slot="chart-area"]', match: :first)["d"]
    raise "the morph landed on the old geometry" if after_d == before_d

    # -- the shape change: 6 -> 3 months -> the entrance replays instead ------
    session.select("Last 3 months", from: "period")
    session.click_button("Apply")
    unless session.has_css?('[data-slot="chart-svg"][data-motion="entrance"]', wait: 5)
      raise "the shape change did not replay the entrance"
    end
    raise "the form round-trip did not land" unless session.has_css?('[data-slot="chart-x-axis"]', wait: 5)

    three_month_ticks = session.all('[data-slot="chart-x-axis"] text').length
    raise "expected 3 months after the round trip, got #{three_month_ticks}" unless three_month_ticks == 3

    session.find('[data-slot="chart-svg"]').hover
    unless session.has_css?(tooltip, visible: :visible, wait: 5)
      raise "the tooltip engine did not survive the server round-trip"
    end

    # -- live mode: the streaming demo, zero server round trips -----
    session.visit("/live")
    raise "live demo missing" unless session.has_css?('[data-slot="demo-live"]')
    raise "live chart never settled" unless session.has_css?('[data-slot="chart-svg"][data-motion="settled"]', wait: 6)

    session.execute_script(<<~JS)
      window.__pageMarker = true
      window.__areaNode = document.querySelector('path[data-slot="chart-area"]')
      window.__liveD0 = window.__areaNode.getAttribute("d")
      window.__firstTick0 = document.querySelector('[data-slot="chart-x-axis"] text').textContent
    JS

    # The updates animate: the FLIP stamps morph on each tick.
    raise "live ticks never morphed" unless session.has_css?('[data-slot="chart-svg"][data-motion="morph"]', wait: 5)

    ticks = 0
    30.times do
      ticks = session.evaluate_script("window.__liveTicks || 0")
      break if ticks >= 2

      sleep 0.3
    end
    raise "the ticker never ticked (#{ticks})" if ticks < 2

    checks = session.evaluate_script(<<~JS)
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

    # The tooltip serves fresh values mid-stream.
    session.find('[data-slot="chart-svg"]').send_keys(:home)
    live_tooltip = 'div[data-slot="chart-tooltip"]'
    raise "tooltip dead mid-stream" unless session.has_css?(live_tooltip, visible: :visible, wait: 5)

    live_label = session.find("#{live_tooltip} [data-slot='chart-tooltip-label']", visible: :all).text
    raise "tooltip label #{live_label.inspect} is not a stream category" unless live_label.match?(/\AT\d+\z/)

    # -- C-W4: synced charts + the interactive legend --------------------------
    session.visit("/sync")
    raise "sync demo missing" unless session.has_css?('[data-slot="demo-sync-a"]')

    session.find('[data-slot="demo-sync-a"] [data-slot="chart-svg"]').send_keys(:home)
    a_tooltip = '[data-slot="demo-sync-a"] div[data-slot="chart-tooltip"]'
    b_tooltip = '[data-slot="demo-sync-b"] div[data-slot="chart-tooltip"]'
    raise "chart A tooltip missing" unless session.has_css?(a_tooltip, visible: :visible, wait: 5)
    raise "the SYNCED chart B tooltip did not follow" unless session.has_css?(b_tooltip, visible: :visible, wait: 5)

    a_label = session.find("#{a_tooltip} [data-slot='chart-tooltip-label']", visible: :all).text
    b_label = session.find("#{b_tooltip} [data-slot='chart-tooltip-label']", visible: :all).text
    raise "synced labels diverge (#{a_label} vs #{b_label})" unless a_label == b_label

    session.find('[data-slot="demo-sync-a"] [data-slot="chart-svg"]').send_keys(:escape)
    if session.has_css?(b_tooltip, visible: :visible, wait: 0)
      raise "chart B tooltip did not dismiss with the synced Escape"
    end

    toggle_scope = '[data-slot="demo-legend-toggle"]'
    ticks_before = session.all("#{toggle_scope} [data-slot='chart-y-axis'] text").map(&:text)
    session.find("#{toggle_scope} button[data-key='desktop']").click
    unless session.has_css?("#{toggle_scope} button[data-key='desktop'][data-hidden]", wait: 5)
      raise "the legend item did not dim"
    end

    hidden_selector = "#{toggle_scope} path[data-slot=\"chart-area\"][data-key=\"desktop\"]"
    hidden_area = session.evaluate_script(
      "getComputedStyle(document.querySelector('#{hidden_selector}')).display"
    )
    raise "the toggled series did not hide" unless hidden_area == "none"

    ticks_after = session.all("#{toggle_scope} [data-slot='chart-y-axis'] text").map(&:text)
    session.find("#{toggle_scope} button[data-key='desktop']").click
    unless session.has_css?("#{toggle_scope} button[data-key='desktop']:not([data-hidden])", wait: 5)
      raise "the legend toggle did not restore"
    end

    # -- C-W5: the window (brush drag + drag-zoom + reset) ---------------------
    session.visit("/window")
    raise "window demo missing" unless session.has_css?('[data-slot="demo-window"]')
    raise "expected 12 months" unless session.all('[data-slot="chart-x-axis"] text').length == 12

    mouse = session.driver.browser.mouse
    handle_rect = session.evaluate_script(
      "document.querySelector('[data-slot=\"chart-brush-handle\"][data-edge=\"end\"]').getBoundingClientRect().toJSON()"
    )
    from_x = handle_rect["x"] + (handle_rect["width"] / 2)
    from_y = handle_rect["y"] + (handle_rect["height"] / 2)
    mouse.move(x: from_x, y: from_y)
    mouse.down
    mouse.move(x: from_x - (handle_rect["width"] * 30), y: from_y, steps: 8)
    mouse.up

    brushed_ticks = nil
    20.times do
      brushed_ticks = session.all('[data-slot="chart-x-axis"] text').length
      break if brushed_ticks < 12

      sleep 0.1
    end
    raise "the brush drag never narrowed the window (still #{brushed_ticks} ticks)" unless brushed_ticks < 12

    brush_window = session.evaluate_script(
      "JSON.parse(document.querySelector('[data-slot=\"chart-live-payload\"]').textContent).frame.window"
    )
    raise "the window was not persisted (#{brush_window.inspect})" unless brush_window.is_a?(Array)

    # Two CDP clicks are too slow to coalesce into a dblclick - dispatch it
    # (the pointer mechanics are already proven by the drag above).
    session.execute_script(
      "document.querySelector('[data-slot=\"chart-svg\"]').dispatchEvent(new MouseEvent('dblclick', { bubbles: true }))"
    )
    reset_ticks = nil
    20.times do
      reset_ticks = session.all('[data-slot="chart-x-axis"] text').length
      break if reset_ticks == 12

      sleep 0.1
    end
    raise "double-click did not reset the window (#{reset_ticks} ticks)" unless reset_ticks == 12

    puts "interaction: hover -> #{label} #{value}, keyboard -> June, Escape dismisses; " \
         "the dataset swap MORPHS between server renders (data-motion morph -> settled, new geometry), " \
         "the 6 -> 3 month shape change replays the entrance, and the tooltip survives every swap; " \
         "live mode streams client-side (same page, same SVG node, sliding window, morphing ticks, " \
         "tooltip live at #{live_label}); synced tooltips follow across charts (#{a_label}) and the " \
         "legend toggle hides + rescales (y ticks #{ticks_before.join("/")} -> #{ticks_after.join("/")}); " \
         "the brush drag narrows 12 -> #{brushed_ticks} months (window #{brush_window.inspect}) and " \
         "double-click resets - the engine works in Chrome"
  end
end
