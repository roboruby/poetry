import { Controller } from "@hotwired/stimulus"

// The chart tooltip engine: ZERO chart math in the
// browser. The server embeds per-category pixel centers, per-series pixel
// extents, and PRE-FORMATTED value strings in a JSON script; this
// controller bisects the pointer against those numbers, swaps text into
// the server-rendered TooltipContent chrome, positions the box, and
// reflects data-active onto the marked cells/dots. Keyboard access is the
// recharts accessibilityLayer floor: the SVG is focusable, arrows walk
// the categories, Escape dismisses.
export default class ChartTooltipController extends Controller {
  // The events this controller dispatches (manifest surface;
  // events_declaration.test.js enforces the list stays honest).
  static events = ["poetry--charts--tooltip:hide", "poetry--charts--tooltip:show"]

  static targets = ["svg", "tooltip", "data"]
  static values = { sync: String }

  connect() {
    const payload = JSON.parse(this.dataTarget.textContent)
    this.layout = payload.layout
    this.centers = (this.layout === "horizontal" ? payload.y : payload.x) ?? []
    this.categories = payload.categories
    this.values = payload.values ?? {}
    this.series = payload.series ?? {}
    // Polar charts (pie/radial): per-index anchors replace the bisect axis,
    // and per-index names/colors retint the single chrome row.
    this.anchors = payload.anchors ?? null
    this.names = payload.names ?? null
    this.colors = payload.colors ?? null
    // Band geometry (band-scale charts) for the hover cursor rect.
    this.band = payload.band ?? null
    this.activeIndex = null

    // Synced charts (recharts syncId): same-group tooltips follow
    // each other's active index over a window event.
    if (this.syncValue && !this.onSync) {
      this.onSync = (event) => this.#applySync(event)
      window.addEventListener("poetry-chart:sync", this.onSync)
    }
  }

  disconnect() {
    if (this.onSync) {
      window.removeEventListener("poetry-chart:sync", this.onSync)
      this.onSync = null
    }
  }

  get count() {
    return this.anchors ? this.anchors.length : this.centers.length
  }

  // Action: pointermove->...#move on the SVG (cartesian bisect).
  move(event) {
    if (this.layout === "polar") return

    const rect = this.svgTarget.getBoundingClientRect()
    if (!rect.width || !rect.height) return

    const [viewWidth, viewHeight] = this.#viewBox()
    const x = ((event.clientX - rect.left) * viewWidth) / rect.width
    const y = ((event.clientY - rect.top) * viewHeight) / rect.height
    this.show(this.#nearest(this.layout === "horizontal" ? y : x))
  }

  // Action: pointerover->...#enter on the SVG (polar: the hovered slice
  // carries its index - no geometry at all).
  enter(event) {
    const marked = event.target.closest?.("[data-index]")
    if (marked) this.show(Number(marked.dataset.index))
  }

  // Action: keydown->...#keydown on the SVG - the accessibilityLayer floor.
  keydown(event) {
    const max = this.count - 1
    let index = this.activeIndex ?? -1

    switch (event.key) {
      case "ArrowRight":
      case "ArrowDown":
        index = Math.min(max, index + 1)
        break
      case "ArrowLeft":
      case "ArrowUp":
        index = index < 0 ? max : Math.max(0, index - 1)
        break
      case "Home":
        index = 0
        break
      case "End":
        index = max
        break
      case "Escape":
        this.leave()
        return
      default:
        return
    }

    event.preventDefault()
    this.show(index)
  }

  // Action: poetry--charts--live:updated->...#refresh - the live renderer
  // rewrote the embedded coordinates; re-read them and keep serving the
  // active index if it still exists (the tooltip follows the stream).
  refresh() {
    const index = this.activeIndex
    this.connect()
    if (index != null && index < this.count) this.show(index)
    else if (index != null) this.leave()
  }

  focus() {
    if (this.activeIndex == null) this.show(0)
  }

  blur() {
    this.leave()
  }

  leave() {
    this.activeIndex = null
    this.tooltipTarget.hidden = true
    this.#reflect(null)
    this.#cursor(null)
    this.dispatch("hide")
    this.#broadcastSync(null)
  }

  show(index) {
    if (index == null || index < 0 || index >= this.count) return

    this.activeIndex = index
    const tooltip = this.tooltipTarget
    tooltip.hidden = false

    const label = tooltip.querySelector('[data-slot="chart-tooltip-label"]')
    if (label) label.textContent = String(this.categories[index])

    for (const row of tooltip.querySelectorAll('[data-slot="chart-tooltip-item"]')) {
      const value = this.values[row.dataset.key]?.[index]
      const valueElement = row.querySelector('[data-slot="chart-tooltip-value"]')
      if (valueElement) valueElement.textContent = value ?? ""
      row.style.display = value == null ? "none" : ""

      // Per-index chrome (pie/radial): the single row takes the slice's
      // name and indicator color.
      if (this.names) {
        const nameElement = row.querySelector('[data-slot="chart-tooltip-name"]')
        if (nameElement) nameElement.textContent = this.names[index] ?? ""
      }
      if (this.colors) {
        const indicator = row.querySelector('[data-slot="chart-tooltip-indicator"]')
        if (indicator) {
          indicator.style.setProperty("--color-bg", this.colors[index])
          indicator.style.setProperty("--color-border", this.colors[index])
        }
      }
    }

    this.#position(index)
    this.#reflect(index)
    this.#cursor(index)
    this.dispatch("show", { detail: { index } })
    this.#broadcastSync(index)
  }

  // The hover cursor (recharts Tooltip cursor): the server pre-renders a
  // hidden band rect (bars) or vertical rule (line/area/composed); this
  // positions it at the active index from embedded geometry.
  #cursor(index) {
    const cursor = this.element.querySelector('[data-slot="chart-cursor"]')
    if (!cursor) return
    if (index == null) {
      cursor.setAttribute("display", "none")
      return
    }

    if (cursor.tagName.toLowerCase() === "rect" && this.band) {
      if (this.layout === "horizontal") {
        cursor.setAttribute("y", String(this.band.x[index]))
        cursor.setAttribute("height", String(this.band.width))
      } else {
        cursor.setAttribute("x", String(this.band.x[index]))
        cursor.setAttribute("width", String(this.band.width))
      }
    } else {
      const center = this.centers[index]
      cursor.setAttribute("x1", String(center))
      cursor.setAttribute("x2", String(center))
    }
    cursor.removeAttribute("display")
  }

  // -- synced charts --------------------------------------------------------

  #broadcastSync(index) {
    if (!this.syncValue || this.applyingSync) return
    window.dispatchEvent(new CustomEvent("poetry-chart:sync", {
      detail: { syncId: this.syncValue, index, source: this },
    }))
  }

  #applySync(event) {
    const { syncId, index, source } = event.detail
    if (source === this || syncId !== this.syncValue) return
    this.applyingSync = true
    try {
      if (index == null) this.leave()
      else this.show(index)
    } finally {
      this.applyingSync = false
    }
  }

  // Place the box near the active category: beside the column (vertical)
  // or beside the bar (horizontal), clamped inside the container and
  // flipped when it would overflow the right edge.
  #position(index) {
    const rect = this.svgTarget.getBoundingClientRect()
    if (!rect.width || !rect.height) return

    const [viewWidth, viewHeight] = this.#viewBox()
    const scaleX = rect.width / viewWidth
    const scaleY = rect.height / viewHeight
    const container = this.element.closest("[data-chart]") ?? this.element
    const containerRect = container.getBoundingClientRect()
    const tooltip = this.tooltipTarget

    const tops = Object.values(this.series)
      .map((extents) => extents[index])
      .filter((value) => value != null)

    let left
    let top
    if (this.anchors) {
      // Polar: the server embedded the recharts tooltipPosition (the
      // mid-angle point at the middle radius).
      left = this.anchors[index][0] * scaleX + 12
      top = this.anchors[index][1] * scaleY
    } else if (this.layout === "horizontal") {
      left = (tops.length ? Math.max(...tops) : viewWidth / 2) * scaleX + 12
      top = this.centers[index] * scaleY
    } else {
      left = this.centers[index] * scaleX + 12
      top = (tops.length ? Math.min(...tops) : viewHeight / 2) * scaleY
    }

    left += rect.left - containerRect.left
    top += rect.top - containerRect.top

    const width = tooltip.offsetWidth
    const height = tooltip.offsetHeight
    if (left + width > containerRect.width) left = left - width - 24
    left = Math.max(0, left)
    top = Math.max(0, Math.min(top - height / 2, containerRect.height - height))

    tooltip.style.left = `${Math.round(left)}px`
    tooltip.style.top = `${Math.round(top)}px`
  }

  // data-active rides every [data-index] mark (bars) and the pre-rendered
  // hidden active dots (lines/areas) - the Base UI presence vocabulary.
  #reflect(index) {
    for (const marked of this.element.querySelectorAll("[data-index]")) {
      if (index != null && Number(marked.dataset.index) === index) marked.setAttribute("data-active", "")
      else marked.removeAttribute("data-active")
    }
    for (const dot of this.element.querySelectorAll('[data-slot="chart-active-dot"]')) {
      const active = index != null && Number(dot.dataset.index) === index
      dot.setAttribute("display", active ? "" : "none")
    }
  }

  #nearest(position) {
    let best = 0
    let distance = Infinity
    this.centers.forEach((center, i) => {
      const d = Math.abs(center - position)
      if (d < distance) {
        distance = d
        best = i
      }
    })
    return best
  }

  // jsdom has no SVGAnimatedRect - parse the attribute, not .viewBox.
  #viewBox() {
    const parts = (this.svgTarget.getAttribute("viewBox") ?? "0 0 1 1").split(/\s+/).map(Number)
    return [parts[2] || 1, parts[3] || 1]
  }
}
