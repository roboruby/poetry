import { Controller } from "@hotwired/stimulus"

// The Resizable engine (N9 W4), decided NATIVE: no react-resizable-panels -
// panels are flex children whose flex-grow IS the percentage, and this
// controller implements the APG window-splitter on the handles: pointer
// drag redistributes the two adjacent panels (clamped to each panel's
// min/max), arrows step, Home/End jump the range, and every move writes
// aria-valuenow (the preceding panel's size - the upstream convention).
// Deferred with the library's machinery: persistence (autoSaveId),
// collapsible panels, and the imperative API.
const PANEL_SELECTOR = '[data-slot="resizable-panel"]'
const HANDLE_SELECTOR = '[data-slot="resizable-handle"]'

const KEY_STEP = 5 // percent per arrow press (the APG "larger than one pixel" step)
const DEFAULT_MIN = 10
const DEFAULT_MAX = 90

export default class ResizableController extends Controller {
  static values = {
    orientation: { type: String, default: "horizontal" }
  }

  #drag = null

  connect() {
    this.#reflectAll()
  }

  // Action: pointerdown->poetry--core--resizable#dragStart on each handle.
  dragStart(event) {
    if (event.button !== 0 && event.pointerType === "mouse") return

    const handle = this.#handleFrom(event)
    if (!handle) return

    const [before, after] = this.#panelsAround(handle)
    if (!before || !after) return

    this.#drag = {
      pointerId: event.pointerId, handle, before, after,
      start: this.#along(event),
      beforeSize: this.#sizeOf(before), afterSize: this.#sizeOf(after)
    }
    handle.setPointerCapture(event.pointerId)
  }

  dragMove(event) {
    const drag = this.#drag
    if (!drag || event.pointerId !== drag.pointerId) return

    const groupSize = this.#groupSize()
    const deltaPercent = ((this.#along(event) - drag.start) / groupSize) * 100

    this.#apply(drag.before, drag.after, drag.beforeSize + deltaPercent, drag.beforeSize + drag.afterSize)
    this.#reflect(drag.handle)
  }

  dragEnd(event) {
    if (!this.#drag || event.pointerId !== this.#drag.pointerId) return

    this.#drag = null
  }

  // Action: keydown->poetry--core--resizable#keydown on each handle (the
  // APG window splitter: arrows step, Home/End jump).
  keydown(event) {
    const handle = this.#handleFrom(event)
    if (!handle) return

    const [before, after] = this.#panelsAround(handle)
    if (!before || !after) return

    const [decrease, increase] = this.orientationValue === "vertical"
      ? ["ArrowUp", "ArrowDown"]
      : ["ArrowLeft", "ArrowRight"]
    const pool = this.#sizeOf(before) + this.#sizeOf(after)
    let target = null

    if (event.key === decrease) target = this.#sizeOf(before) - KEY_STEP
    else if (event.key === increase) target = this.#sizeOf(before) + KEY_STEP
    else if (event.key === "Home") target = this.#minOf(before)
    else if (event.key === "End") target = pool - this.#minOf(after)
    else return

    event.preventDefault()
    this.#apply(before, after, target, pool)
    this.#reflect(handle)
  }

  // Redistribute the shared pool between two adjacent panels, honoring
  // BOTH panels' min/max.
  #apply(before, after, requestedBefore, pool) {
    const beforeSize = Math.min(
      Math.max(requestedBefore, this.#minOf(before), pool - this.#maxOf(after)),
      this.#maxOf(before), pool - this.#minOf(after)
    )

    this.#write(before, beforeSize)
    this.#write(after, pool - beforeSize)
    this.dispatch("resize", { detail: { sizes: this.#panels().map((panel) => this.#sizeOf(panel)) } })
  }

  #write(panel, size) {
    panel.style.flexGrow = String(Math.round(size * 100) / 100)
    panel.style.flexShrink = "1"
    panel.style.flexBasis = "0px"
  }

  // aria-valuenow = the PRECEDING panel's size (the upstream convention).
  #reflect(handle) {
    const [before] = this.#panelsAround(handle)
    if (!before) return

    handle.setAttribute("aria-valuenow", String(Math.round(this.#sizeOf(before))))
    handle.setAttribute("aria-valuemin", String(Math.round(this.#minOf(before))))
    handle.setAttribute("aria-valuemax", String(Math.round(this.#maxOf(before))))
  }

  #reflectAll() {
    for (const handle of this.#handles()) this.#reflect(handle)
  }

  #handleFrom(event) {
    const origin = event.target instanceof Element ? event.target : null
    const handle = origin?.closest(HANDLE_SELECTOR)

    return handle && this.#owns(handle) ? handle : null
  }

  // The panels immediately around a handle, in DOM order.
  #panelsAround(handle) {
    let before = handle.previousElementSibling
    while (before && !before.matches(PANEL_SELECTOR)) before = before.previousElementSibling
    let after = handle.nextElementSibling
    while (after && !after.matches(PANEL_SELECTOR)) after = after.nextElementSibling

    return [before, after]
  }

  #sizeOf(panel) {
    return parseFloat(panel.style.flexGrow || "1") || 1
  }

  #minOf(panel) {
    return parseFloat(panel.dataset.minSize ?? "") || DEFAULT_MIN
  }

  #maxOf(panel) {
    return parseFloat(panel.dataset.maxSize ?? "") || DEFAULT_MAX
  }

  #along(event) {
    return this.orientationValue === "vertical" ? event.clientY : event.clientX
  }

  #groupSize() {
    const rect = this.element.getBoundingClientRect()

    return Math.max(1, this.orientationValue === "vertical" ? rect.height : rect.width)
  }

  #panels() {
    return [...this.element.querySelectorAll(PANEL_SELECTOR)].filter((el) => this.#owns(el))
  }

  #handles() {
    return [...this.element.querySelectorAll(HANDLE_SELECTOR)].filter((el) => this.#owns(el))
  }

  // Nested groups self-scope (the DOM is the registry).
  #owns(el) {
    return el.closest(`[data-controller~="${this.identifier}"]`) === this.element
  }
}
