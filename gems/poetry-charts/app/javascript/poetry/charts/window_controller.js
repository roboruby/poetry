import { Controller } from "@hotwired/stimulus"

// The window controller: brush + zoom over the live
// renderer. One concept drives both - frame.window = [start, end]
// (inclusive indices into the FULL data) slices the data before the
// kernel computes. The brush drags the window (handles resize it, the
// body shifts it); zoom drag-selects a range on the plot; double-click
// resets. Window changes go through the live controller's setWindow
// (instant renders - no tween mid-drag), and this controller repaints
// the strip visuals from index fractions of the server-computed rects
// (its Stimulus values) - no chart math.
export default class ChartWindowController extends Controller {
  static values = {
    zoom: Boolean,
    plot: Array, // [left, right, top, bottom] in viewBox units
    brush: Array, // [x, y, width, height] in viewBox units
  }

  connect() {
    this.svg = this.element.querySelector('[data-slot="chart-svg"]')
    this.selection = this.element.querySelector('[data-slot="chart-zoom-selection"]')
    this.#paintBrush()
  }

  disconnect() {
    this.#unbind()
  }

  // -- the brush ------------------------------------------------------------

  // Action: pointerdown->poetry--charts--window#startBrush on the strip.
  startBrush(event) {
    if (!this.hasBrushValue) return
    event.preventDefault()
    const handle = event.target.closest("[data-edge]")
    this.drag = {
      mode: handle ? handle.dataset.edge : "shift",
      startX: this.#viewBoxX(event),
      window: this.#window(),
    }
    this.#bind()
  }

  // -- zoom -----------------------------------------------------------------

  // Action: pointerdown->...#startZoom on the SVG (skips brush drags).
  startZoom(event) {
    if (!this.zoomValue || event.target.closest('[data-slot="chart-brush"]')) return
    const x = this.#viewBoxX(event)
    const [left, right] = this.plotValue
    if (x < left || x > right) return
    this.drag = { mode: "zoom", startX: x, window: this.#window() }
    this.#bind()
  }

  // Action: dblclick->...#reset on the SVG.
  reset() {
    this.#apply([0, this.#fullLength() - 1])
  }

  // -- drag machinery ---------------------------------------------------------

  #bind() {
    // A second gesture before pointerup (multi-touch, programmatic events)
    // would overwrite the handler refs and strand the first pair forever.
    this.#unbind()
    this.onMove = (event) => this.#move(event)
    this.onUp = (event) => this.#up(event)
    window.addEventListener("pointermove", this.onMove)
    window.addEventListener("pointerup", this.onUp)
  }

  #unbind() {
    if (this.onMove) window.removeEventListener("pointermove", this.onMove)
    if (this.onUp) window.removeEventListener("pointerup", this.onUp)
    this.onMove = this.onUp = null
  }

  #move(event) {
    if (!this.drag) return
    if (this.drag.mode === "zoom") {
      this.#paintSelection(this.drag.startX, this.#viewBoxX(event))
      return
    }

    const length = this.#fullLength()
    const [, , brushWidth] = [this.brushValue[0], this.brushValue[1], this.brushValue[2]]
    const deltaIndex = Math.round(((this.#viewBoxX(event) - this.drag.startX) / brushWidth) * (length - 1))
    let [start, end] = this.drag.window

    if (this.drag.mode === "start") {
      start = Math.min(Math.max(0, this.drag.window[0] + deltaIndex), end)
    } else if (this.drag.mode === "end") {
      end = Math.max(Math.min(length - 1, this.drag.window[1] + deltaIndex), start)
    } else {
      const span = end - start
      start = Math.min(Math.max(0, this.drag.window[0] + deltaIndex), length - 1 - span)
      end = start + span
    }
    this.#apply([start, end])
  }

  #up(event) {
    const drag = this.drag
    this.drag = null
    this.#unbind()
    if (!drag || drag.mode !== "zoom") return

    if (this.selection) this.selection.setAttribute("display", "none")
    const from = drag.startX
    const to = this.#viewBoxX(event)
    if (Math.abs(to - from) < 3) return // a click, not a selection

    const [left, right] = this.plotValue
    const [start, end] = drag.window
    const span = end - start
    const index = (x) => start + Math.round(((Math.min(Math.max(x, left), right) - left) / (right - left)) * span)
    const i1 = index(Math.min(from, to))
    const i2 = index(Math.max(from, to))
    if (i1 === i2) return
    this.#apply([i1, i2])
  }

  // -- shared -----------------------------------------------------------------

  #apply(window) {
    this.#live()?.setWindow(window)
    this.#paintBrush(window)
  }

  // The strip visuals: window + handles at index fractions of the track.
  #paintBrush(window = this.#window()) {
    if (!this.hasBrushValue) return
    const [x, , width] = this.brushValue
    const length = this.#fullLength()
    if (length < 2) return
    const px = (index) => x + (index / (length - 1)) * width

    const startX = px(window[0])
    const endX = px(window[1])
    const windowRect = this.element.querySelector('[data-slot="chart-brush-window"]')
    windowRect?.setAttribute("x", String(startX))
    windowRect?.setAttribute("width", String(Math.max(0, endX - startX)))
    this.element.querySelector('[data-slot="chart-brush-handle"][data-edge="start"]')
      ?.setAttribute("x", String(startX - 3))
    this.element.querySelector('[data-slot="chart-brush-handle"][data-edge="end"]')
      ?.setAttribute("x", String(endX - 3))
  }

  #paintSelection(fromX, toX) {
    if (!this.selection) return
    const [left, right] = this.plotValue
    const x1 = Math.min(Math.max(Math.min(fromX, toX), left), right)
    const x2 = Math.min(Math.max(Math.max(fromX, toX), left), right)
    this.selection.setAttribute("x", String(x1))
    this.selection.setAttribute("width", String(x2 - x1))
    this.selection.removeAttribute("display")
  }

  #live() {
    return this.application.getControllerForElementAndIdentifier(this.element, "poetry--charts--live")
  }

  #payload() {
    return JSON.parse(this.element.querySelector('[data-slot="chart-live-payload"]').textContent)
  }

  #fullLength() {
    return this.#payload().spec.data.length
  }

  #window() {
    return this.#payload().frame.window ?? [0, this.#fullLength() - 1]
  }

  // Pointer px -> viewBox x (the tooltip's conversion).
  #viewBoxX(event) {
    const rect = this.svg.getBoundingClientRect()
    if (!rect.width) return 0
    const parts = (this.svg.getAttribute("viewBox") ?? "0 0 1 1").split(/\s+/).map(Number)
    return ((event.clientX - rect.left) * (parts[2] || 1)) / rect.width
  }
}
