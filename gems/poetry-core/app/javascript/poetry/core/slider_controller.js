import { Controller } from "@hotwired/stimulus"
import { directionOf } from "@poetry/controllers/helpers/direction"

// The Slider machine - the only form control with real math. Three concerns,
// nothing else:
//
// 1. THE VALUE MATH (the pure core, unit-tested exhaustively): snap to the
//    step grid with decimal-precision rounding (a 0.1 grid lands on
//    0.3, never 0.30000000000000004), clamp to
//    [min, max], and clamp against neighbor thumbs +- the min gap
//    (minStepsBetweenThumbs * step) so range thumbs can never cross.
//
// 2. TWO INPUT PATHS feeding it: the APG keyboard map per thumb (arrows
//    +-step, Shift+Arrow / PageUp / PageDown +-step*10, Home/End to the
//    thumb's EFFECTIVE min/max) with the orientation x RTL x inverted
//    resolution - horizontal RTL swaps Left/Right only, inverted flips the
//    whole axis, both compose (rtl + inverted = ltr math); and pointer
//    capture on the root - pointerdown jumps the NEAREST thumb (ties to
//    the later index, so stacked thumbs stay separable), the track
//    box is read ONCE at pointerdown (no per-frame layout), pointermove
//    projects the value ABSOLUTELY from the pointer position (overshoot
//    past a neighbor clamps, never swaps), pointerup commits.
//
// 3. THE DOM PROJECTION: aria-valuemin/max/now per role=slider thumb - the
//    range bounds are DYNAMIC (neighbor-clamped, rewritten on every
//    neighbor move: APG multithumb), the --slider-start/--slider-end
//    geometry vars consumed by the calc() rules, and one hidden native
//    input per thumb. poetry:slider:change fires per mutation; commit
//    (pointerup / each keydown) syncs the
//    hidden inputs + dispatches native input/change so Rails listeners get
//    one event per gesture, not per frame.
const LARGE_STEP_MULTIPLIER = 10

export default class SliderController extends Controller {
  // The events this controller dispatches (manifest surface;
  // events_declaration.test.js enforces the list stays honest).
  static events = ["poetry:slider:change", "poetry:slider:commit"]

  static values = {
    min: { type: Number, default: 0 },
    max: { type: Number, default: 100 },
    step: { type: Number, default: 1 },
    value: { type: Array, default: [] },
    minStepsBetweenThumbs: { type: Number, default: 0 },
    orientation: { type: String, default: "horizontal" },
    inverted: { type: Boolean, default: false }
  }

  static targets = ["track", "range", "thumb", "input"]

  #values = []
  #connected = false
  #dragIndex = null
  #trackRect = null
  #gestureChanged = false

  /**
   * Adopts the value (the Value, else the server-rendered aria-valuenow),
   * projects, and primes the hidden inputs silently.
   */
  connect() {
    this.#values = this.valueValue.length > 0
      ? this.valueValue.map(Number)
      : this.#serverValues()

    this.#project()
    this.#syncInputs({ dispatch: false })
    this.#connected = true
  }

  /** Ends any in-flight gesture without committing. */
  disconnect() {
    this.#connected = false
    this.#endGesture({ commit: false })
  }

  /**
   * Stimulus value callback - controllable state: a host (outlet / Turbo
   * Stream) may own the value.
   *
   * @param {number[]} value
   */
  valueValueChanged(value) {
    if (!this.#connected || this.#same(value)) return

    this.#values = value.map(Number)
    this.#project()
    this.#syncInputs({ dispatch: false })
  }

  // --- the keyboard path (action: keydown->...#keydown on each thumb) ---

  /**
   * Each thumb's keydown action: the APG map (arrows step, Shift/Page =
   * large step, Home/End to the thumb's EFFECTIVE bounds) under the
   * orientation x RTL x inverted resolution; every keyboard change
   * commits.
   *
   * @param {KeyboardEvent} event
   */
  keydown(event) {
    if (this.#disabled()) return

    const index = this.thumbTargets.indexOf(event.currentTarget)

    if (index === -1) return

    const candidate = this.#candidateFor(event, index)

    if (candidate === null) return

    event.preventDefault() // handled keys must not scroll the page

    const changed = this.#update(index, candidate)

    if (changed) this.#commit() // keyboard commits per keydown, contractual
  }

  // The APG map with the orientation x RTL x inverted resolution.
  #candidateFor(event, index) {
    switch (event.key) {
      case "Home":
        return this.#lowerBound(index)
      case "End":
        return this.#upperBound(index)
      case "ArrowRight":
      case "ArrowLeft":
      case "ArrowUp":
      case "ArrowDown":
      case "PageUp":
      case "PageDown": {
        let sign = (event.key === "ArrowRight" || event.key === "ArrowUp" || event.key === "PageUp") ? 1 : -1

        // Horizontal RTL swaps ONLY the Left/Right pair.
        const horizontalPair = event.key === "ArrowRight" || event.key === "ArrowLeft"

        if (horizontalPair && this.orientationValue === "horizontal" && directionOf(this.element) === "rtl") {
          sign = -sign
        }

        // inverted flips the whole axis (increment keys decrement);
        // composed with the RTL swap above, rtl + inverted cancels.
        if (this.invertedValue) sign = -sign

        const page = event.key === "PageUp" || event.key === "PageDown"
        const multiplier = (page || event.shiftKey) ? LARGE_STEP_MULTIPLIER : 1

        return this.#values[index] + sign * this.stepValue * multiplier
      }
      default:
        return null
    }
  }

  // --- the pointer path (action: pointerdown->...#pointerdown on the root) ---

  /**
   * The root's pointerdown action: jumps the NEAREST thumb to the pointer
   * (ties to the later index), reads the track box once, and starts the
   * window-level drag; pointerup commits.
   *
   * @param {PointerEvent} event
   */
  pointerdown(event) {
    if (this.#disabled() || this.thumbTargets.length === 0) return

    // The track box is read ONCE per gesture - no per-frame layout.
    this.#trackRect = this.trackTarget.getBoundingClientRect()

    const candidate = this.#valueAtPointer(event)
    const index = this.#nearestThumb(candidate)

    this.#dragIndex = index
    this.#gestureChanged = false
    this.element.setAttribute("data-dragging", "")
    this.thumbTargets[index].setAttribute("data-dragging", "")
    this.thumbTargets[index].focus() // drags announce on the focused thumb

    if (typeof this.element.setPointerCapture === "function" && event.pointerId !== undefined) {
      // NotFoundError when the pointer is already gone (fast-tap touch race:
      // pointerup can beat the pointerdown action) - capture is an
      // enhancement, the window listeners below carry the drag without it.
      try { this.element.setPointerCapture(event.pointerId) } catch { /* stale pointerId */ }
    }

    window.addEventListener("pointermove", this.#onPointermove)
    window.addEventListener("pointerup", this.#onPointerup)

    event.preventDefault()

    if (this.#update(index, candidate)) this.#gestureChanged = true
  }

  #onPointermove = (event) => {
    if (this.#dragIndex === null) return

    // Absolute projection each frame (no delta accumulation): overshooting
    // a neighbor clamps at the gap and never swaps thumbs.
    if (this.#update(this.#dragIndex, this.#valueAtPointer(event))) this.#gestureChanged = true
  }

  #onPointerup = () => {
    this.#endGesture({ commit: true })
  }

  #endGesture({ commit }) {
    window.removeEventListener("pointermove", this.#onPointermove)
    window.removeEventListener("pointerup", this.#onPointerup)

    if (this.#dragIndex === null) return

    this.element.removeAttribute("data-dragging")
    this.thumbTargets[this.#dragIndex]?.removeAttribute("data-dragging")

    const changed = this.#gestureChanged

    this.#dragIndex = null
    this.#trackRect = null
    this.#gestureChanged = false

    if (commit && changed) this.#commit()
  }

  // Value at the pointer position: axis + direction + inversion aware.
  #valueAtPointer(event) {
    const rect = this.#trackRect ?? this.trackTarget.getBoundingClientRect()
    let ratio

    if (this.orientationValue === "vertical") {
      // Vertical grows BOTTOM-up (APG); direction-neutral.
      ratio = rect.height > 0 ? (rect.bottom - event.clientY) / rect.height : 0
    } else {
      ratio = rect.width > 0 ? (event.clientX - rect.left) / rect.width : 0
      if (directionOf(this.element) === "rtl") ratio = 1 - ratio
    }

    if (this.invertedValue) ratio = 1 - ratio

    ratio = Math.min(Math.max(ratio, 0), 1)

    return this.minValue + ratio * (this.maxValue - this.minValue)
  }

  // Nearest thumb; ties resolve to the LATER index (contractual - two
  // thumbs stacked at min can both be picked up).
  #nearestThumb(value) {
    let nearest = 0

    for (let index = 1; index < this.#values.length; index++) {
      if (Math.abs(this.#values[index] - value) <= Math.abs(this.#values[nearest] - value)) nearest = index
    }

    return nearest
  }

  // --- the programmatic controllable-state surface ---

  /**
   * The programmatic controllable-state surface: must keep the thumb
   * count; changes commit.
   *
   * @param {number | number[]} value
   */
  setValue(value) {
    const values = (Array.isArray(value) ? value : [value]).map(Number)

    if (values.length !== this.#values.length) {
      console.warn("poetry--core--slider: setValue must keep the thumb count")
      return
    }

    let changed = false

    for (let index = 0; index < values.length; index++) {
      if (this.#update(index, values[index])) changed = true
    }

    if (changed) this.#commit()
  }

  // --- the pure math core ---

  // snap -> clamp [min, max] -> clamp against neighbors +- the min gap.
  #update(index, candidate) {
    const next = this.#clampToBounds(index, this.#snap(candidate))

    if (next === this.#values[index]) return false

    this.#values[index] = next
    this.#project()
    this.dispatch("change", { prefix: "poetry:slider", detail: { value: [...this.#values], index } })

    return true
  }

  // Snap to the step grid anchored at min, with decimal-precision
  // rounding: count the step's decimals, round to
  // that precision - floating-point accumulation never reaches the DOM.
  #snap(value) {
    const steps = Math.round((value - this.minValue) / this.stepValue)

    return this.#round(this.minValue + steps * this.stepValue)
  }

  #round(value) {
    return Number(value.toFixed(this.#precision()))
  }

  #precision() {
    return Math.max(this.#decimals(this.stepValue), this.#decimals(this.minValue))
  }

  #decimals(value) {
    const text = String(value)
    const point = text.indexOf(".")

    return point === -1 ? 0 : text.length - point - 1
  }

  #clampToBounds(index, value) {
    return Math.min(Math.max(value, this.#lowerBound(index)), this.#upperBound(index))
  }

  // The thumb's EFFECTIVE bounds (APG multithumb: the high thumb's min is
  // the low thumb's value + the gap).
  #lowerBound(index) {
    if (index === 0) return this.minValue

    return this.#round(this.#values[index - 1] + this.#gap())
  }

  #upperBound(index) {
    if (index === this.#values.length - 1) return this.maxValue

    return this.#round(this.#values[index + 1] - this.#gap())
  }

  #gap() {
    return this.minStepsBetweenThumbsValue * this.stepValue
  }

  // --- the DOM projection ---

  // aria-value* per thumb (range bounds neighbor-clamped, rewritten on
  // EVERY move - the cross-thumb rewrite AT depends on) + the geometry vars.
  #project() {
    this.thumbTargets.forEach((thumb, index) => {
      if (index >= this.#values.length) return

      thumb.setAttribute("aria-valuemin", String(this.#lowerBound(index)))
      thumb.setAttribute("aria-valuemax", String(this.#upperBound(index)))
      thumb.setAttribute("aria-valuenow", String(this.#values[index]))
    })

    const start = this.#values.length > 1 ? this.#percent(this.#values[0]) : 0
    const end = this.#percent(this.#values[this.#values.length - 1])

    this.element.style.setProperty("--slider-start", `${start}%`)
    this.element.style.setProperty("--slider-end", `${end}%`)

    // Middle thumbs (N-thumb sliders) position via their own anchor var.
    const anchors = this.element.querySelectorAll('[data-slot="slider-anchor"]')
    this.#values.forEach((value, index) => {
      if (index === 0 || index === this.#values.length - 1) return

      anchors[index]?.style.setProperty("--slider-mid", `${this.#percent(value)}%`)
    })
  }

  #percent(value) {
    const span = this.maxValue - this.minValue

    return span > 0 ? ((value - this.minValue) / span) * 100 : 0
  }

  // Commit (once per gesture / per keydown): hidden inputs sync + native
  // input/change dispatch + the commit event; the Value mirrors for the
  // controllable-state surface.
  #commit() {
    this.#syncInputs({ dispatch: true })
    this.valueValue = [...this.#values] // #same() guards the changed callback
    this.dispatch("commit", { prefix: "poetry:slider", detail: { value: [...this.#values] } })
  }

  #syncInputs({ dispatch }) {
    this.inputTargets.forEach((input, index) => {
      if (index >= this.#values.length) return

      const next = String(this.#values[index])

      if (input.value === next) return

      input.value = next

      if (dispatch) {
        input.dispatchEvent(new Event("input", { bubbles: true }))
        input.dispatchEvent(new Event("change", { bubbles: true }))
      }
    })
  }

  // Server-rendered fallback: thumbs carry aria-valuenow; else one thumb at min.
  #serverValues() {
    const values = this.thumbTargets
      .map((thumb) => Number(thumb.getAttribute("aria-valuenow")))
      .filter((value) => !Number.isNaN(value))

    return values.length > 0 ? values : [this.minValue]
  }

  #same(values) {
    return values.length === this.#values.length &&
      values.every((value, index) => Number(value) === this.#values[index])
  }

  #disabled() {
    return this.element.hasAttribute("data-disabled")
  }
}
