import { Controller } from "@hotwired/stimulus"

// NumberField: a formatted
// visible <input type=text> over a hidden <input type=number> that is the
// form/validation truth - the spinbutton ARIA pattern is deliberately
// not used. The controller owns stepping (arrows, steppers with
// press-and-hold, opt-in wheel), parse/clamp/format, and the two-input
// sync. Number | null value model: empty is null, never NaN.
//
// Deliberate v1 boundaries (documented in the component):
// no scrub area, Latin-digit parsing only (locale separators and
// currency/percent symbols ARE handled via Intl.formatToParts), and the
// server renders the raw number - the display formats on connect.
const START_AUTO_CHANGE_DELAY = 400
const CHANGE_VALUE_TICK_DELAY = 60

export default class extends Controller {
  static targets = ["input", "hidden", "increment", "decrement"]

  static values = {
    min: Number,
    max: Number,
    step: { type: Number, default: 1 },
    largeStep: { type: Number, default: 10 },
    smallStep: { type: Number, default: 0.1 },
    snap: Boolean,
    wheel: Boolean,
    format: Object,
    locale: String
  }

  static events = ["poetry:number-field:change", "poetry:number-field:commit"]

  #value = null
  #focusedOnce = false
  #holdTimer = null
  #holdInterval = null
  #holdChanged = false
  #pressTicked = false
  #onWheel = null
  #onRelease = null

  /**
   * Adopts the hidden value, paints the formatted display, reflects the
   * boundaries, and wires the opt-in wheel plus the window-level release
   * listeners.
   */
  connect() {
    this.#value = this.#fromHidden()
    if (this.#value !== null) this.inputTarget.value = this.#format(this.#value)
    this.#reflect()
    if (this.wheelValue) {
      this.#onWheel = (event) => this.#wheel(event)
      this.inputTarget.addEventListener("wheel", this.#onWheel, { passive: false })
    }
    // Releases outside the button (or after a boundary disables it) must
    // still stop the repeat and commit - window-level, like slider drags.
    this.#onRelease = () => this.#endHold()
    window.addEventListener("pointerup", this.#onRelease)
    window.addEventListener("pointercancel", this.#onRelease)
  }

  /** Unwires the wheel/release listeners and stops any repeat. */
  disconnect() {
    if (this.#onWheel) this.inputTarget.removeEventListener("wheel", this.#onWheel)
    window.removeEventListener("pointerup", this.#onRelease)
    window.removeEventListener("pointercancel", this.#onRelease)
    this.#stopRepeat()
  }

  // --- input events -------------------------------------------------------

  /**
   * The visible input's keydown action: ArrowUp/Down step (Shift = large
   * step, Alt = small), Home/End jump to the bounds, and printable keys
   * pass the character gate.
   *
   * @param {KeyboardEvent} event
   */
  keydown(event) {
    if (this.inputTarget.readOnly) return

    switch (event.key) {
      case "ArrowUp":
      case "ArrowDown":
        event.preventDefault()
        this.#step(event.key === "ArrowUp" ? 1 : -1, event)
        this.#commit()
        return
      case "Home":
        if (!this.hasMinValue) return
        event.preventDefault()
        this.#apply(this.minValue, { display: true })
        this.#commit()
        return
      case "End":
        if (!this.hasMaxValue) return
        event.preventDefault()
        this.#apply(this.maxValue, { display: true })
        this.#commit()
        return
      default:
        this.#gate(event)
    }
  }

  /**
   * The input action: text updates freely; the value goes live only
   * while parseable. The display is NEVER rewritten mid-typing
   * (dirty-text authority).
   */
  input() {
    const text = this.inputTarget.value
    if (text.trim() === "") {
      this.#apply(null, { display: false })
      return
    }
    const parsed = this.#parse(text)
    if (parsed !== null) this.#apply(parsed, { display: false })
  }

  /** The focus action: the first focus parks the caret at the end. */
  focus() {
    if (this.#focusedOnce) return

    this.#focusedOnce = true
    const end = this.inputTarget.value.length
    this.inputTarget.setSelectionRange(end, end)
  }

  /**
   * The blur action - the text commit point: empty clears, unparseable
   * text is left as typed with no commit, parseable text clamps and
   * normalizes to the canonical formatted display (never snapped to
   * step - blur is not a correction gesture).
   */
  blur() {
    const text = this.inputTarget.value
    if (text.trim() === "") {
      if (this.#value !== null || text !== "") this.#apply(null, { display: true })
      this.#commit()
      return
    }
    const parsed = this.#parse(text)
    if (parsed === null) return

    this.#apply(this.#clamp(parsed), { display: true })
    this.#commit()
  }

  // --- steppers -----------------------------------------------------------

  /**
   * Each stepper's pointerdown action: steps once, then repeats after the
   * hold delay (mouse focuses the input; touch would pop the software
   * keyboard).
   *
   * @param {PointerEvent} event
   */
  press(event) {
    if (event.button !== 0 || this.inputTarget.readOnly) return

    // Mouse focuses the input (touch would pop the software keyboard).
    if (event.pointerType !== "touch") this.inputTarget.focus()
    this.#pressTicked = true
    this.#holdChanged = false
    const direction = this.#directionFor(event.currentTarget)
    if (!this.#tick(direction, event)) return

    this.#holdTimer = setTimeout(() => {
      this.#holdInterval = setInterval(() => {
        if (!this.#tick(direction, event)) this.#stopRepeat()
      }, CHANGE_VALUE_TICK_DELAY)
    }, START_AUTO_CHANGE_DELAY)
  }

  /**
   * The stepper's click action: quick touch taps synthesize click
   * without a held pointer - step once, but never double-step after a
   * handled pointerdown.
   *
   * @param {MouseEvent} event
   */
  tap(event) {
    if (this.#pressTicked) {
      this.#pressTicked = false
      return
    }
    if (this.inputTarget.readOnly) return

    this.#step(this.#directionFor(event.currentTarget), event)
    this.#commit()
  }

  /** The stepper's pointerleave action: stops the repeat. */
  leave() {
    this.#stopRepeat()
  }

  // --- mechanics ----------------------------------------------------------

  #endHold() {
    this.#stopRepeat()
    if (this.#holdChanged) this.#commit()
    this.#holdChanged = false
  }

  #stopRepeat() {
    clearTimeout(this.#holdTimer)
    clearInterval(this.#holdInterval)
    this.#holdTimer = null
    this.#holdInterval = null
  }

  #tick(direction, event) {
    // Disabled/readonly mid-hold (a server morph can do this): stop the
    // repeat rather than mutating a control the user can no longer reach.
    if (this.inputTarget.disabled || this.inputTarget.readOnly) return false

    const before = this.#value
    this.#step(direction, event)
    const changed = this.#value !== before
    this.#holdChanged ||= changed
    return changed
  }

  #directionFor(button) {
    return this.hasIncrementTarget && button === this.incrementTarget ? 1 : -1
  }

  #step(direction, event) {
    const amount = event.shiftKey ? this.largeStepValue : (event.altKey ? this.smallStepValue : this.stepValue)
    // Stepping starts from the dirty typed text when parseable (what the
    // user sees), else the committed value, else seeds 0 clamped in range
    // (an all-negative range seeds at max - the nearest representable).
    const base = this.#parse(this.inputTarget.value) ?? this.#value
    const candidate = base === null
      ? this.#clamp(0)
      : this.#clamp(this.#maybeSnap(this.#clean(base + direction * amount), direction, event))
    this.#apply(candidate, { display: true })
  }

  #wheel(event) {
    if (event.ctrlKey || document.activeElement !== this.inputTarget) return

    event.preventDefault()
    if (event.deltaY === 0) return

    this.#step(event.deltaY > 0 ? -1 : 1, event)
    this.#commit()
  }

  // Snap to step multiples from base min (or 0): directional for normal /
  // large steps, nearest for the Alt small step.
  #maybeSnap(value, direction, event) {
    if (!this.snapValue) return value

    const base = this.hasMinValue ? this.minValue : 0
    const steps = (value - base) / this.stepValue
    const snapped = event.altKey
      ? Math.round(steps)
      : (direction > 0 ? Math.floor(steps) : Math.ceil(steps))
    return this.#clean(base + snapped * this.stepValue)
  }

  #clamp(value) {
    let clamped = value
    if (this.hasMinValue) clamped = Math.max(clamped, this.minValue)
    if (this.hasMaxValue) clamped = Math.min(clamped, this.maxValue)
    return clamped
  }

  // Binary float noise cleanup (0.1 + 0.2 -> 0.3), bounded so genuine
  // digits in large values are never rewritten (toPrecision(15) plus an
  // absolute 1e-10 delta cap).
  #clean(value) {
    const cleaned = Number(value.toPrecision(15))
    return Math.abs(cleaned - value) < 1e-10 ? cleaned : value
  }

  #apply(value, { display }) {
    const changed = value !== this.#value
    this.#value = value
    if (display) this.inputTarget.value = value === null ? "" : this.#format(value)
    this.hiddenTarget.value = value === null ? "" : String(value)
    this.#reflect()
    if (changed) {
      this.dispatch("change", { prefix: "poetry:number-field", detail: { value } })
    }
  }

  #commit() {
    this.dispatch("commit", { prefix: "poetry:number-field", detail: { value: this.#value } })
  }

  // Boundary + filled reflection: steppers disable at their bound (native
  // disabled + data-disabled, written together); the root mirrors filled.
  #reflect() {
    const filled = this.#value !== null
    this.element.toggleAttribute("data-filled", filled)
    this.#reflectButton(this.hasIncrementTarget && this.incrementTarget,
                        filled && this.hasMaxValue && this.#value >= this.maxValue)
    this.#reflectButton(this.hasDecrementTarget && this.decrementTarget,
                        filled && this.hasMinValue && this.#value <= this.minValue)
  }

  #reflectButton(button, atBoundary) {
    if (!button) return

    const off = atBoundary || this.element.hasAttribute("data-disabled")
    button.disabled = off
    button.toggleAttribute("data-disabled", off)
  }

  // --- parse / format -----------------------------------------------------

  #fromHidden() {
    const raw = this.hiddenTarget.value.trim()
    if (raw === "") return null

    const parsed = Number(raw)
    return Number.isFinite(parsed) ? parsed : null
  }

  #formatter() {
    if (!this.hasFormatValue || Object.keys(this.formatValue).length === 0) return null

    this.cachedFormatter ||= new Intl.NumberFormat(
      this.hasLocaleValue && this.localeValue !== "" ? this.localeValue : undefined,
      this.formatValue
    )
    return this.cachedFormatter
  }

  #format(value) {
    const formatter = this.#formatter()
    return formatter ? formatter.format(value) : String(value)
  }

  // The format's own emitted characters (group/decimal separators,
  // currency/percent symbols) - derived once from formatToParts so parsing
  // and keydown gating accept exactly what formatting produces.
  #formatChars() {
    if (this.cachedFormatChars) return this.cachedFormatChars

    const chars = { group: new Set(), decimal: ".", symbols: new Set(), percent: false }
    const formatter = this.#formatter()
    if (formatter) {
      chars.percent = this.formatValue.style === "percent"
      for (const sample of [-11222333.45, 11222333.45]) {
        for (const part of formatter.formatToParts(sample)) {
          if (part.type === "group") [...part.value].forEach((c) => chars.group.add(c))
          if (part.type === "decimal") chars.decimal = part.value
          if (["currency", "percentSign", "literal", "unit"].includes(part.type)) {
            [...part.value].forEach((c) => chars.symbols.add(c))
          }
        }
      }
    }
    this.cachedFormatChars = chars
    return chars
  }

  #parse(text) {
    const chars = this.#formatChars()
    let cleaned = ""
    for (const c of text.trim()) {
      if (chars.group.has(c) || chars.symbols.has(c)) continue
      cleaned += c === chars.decimal ? "." : c
    }
    cleaned = cleaned.replace(/[−‒–]/g, "-").replace(/\s/g, "")
    if (cleaned === "" || cleaned === "-") return null

    const parsed = Number(cleaned)
    if (!Number.isFinite(parsed)) return null

    return chars.percent ? this.#clean(parsed / 100) : parsed
  }

  // Keydown character gate: digits, the format's own symbols, minus only
  // when the range admits negatives, one decimal separator. Navigation
  // keys, shortcuts, and IME (229) always pass.
  #gate(event) {
    if (event.key.length !== 1 || event.ctrlKey || event.metaKey || event.altKey || event.which === 229) return

    const c = event.key
    const chars = this.#formatChars()
    if (/[0-9]/.test(c) || chars.group.has(c) || chars.symbols.has(c)) return
    if ((c === chars.decimal || c === ".") && !this.inputTarget.value.includes(chars.decimal)) return
    if (c === "-" && (!this.hasMinValue || this.minValue < 0) && !this.inputTarget.value.includes("-")) return

    event.preventDefault()
  }

  /**
   * The hidden input's change action: browser autofill lands there -
   * adopt, clamp, commit.
   */
  hiddenChanged() {
    const adopted = this.#fromHidden()
    this.#apply(adopted === null ? null : this.#clamp(adopted), { display: true })
    this.#commit()
  }
}
