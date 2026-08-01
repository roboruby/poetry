import { Controller } from "@hotwired/stimulus"
import {
  IncompleteDate, PAGE_STEP, resolveHourCycle
} from "@poetry/controllers/helpers/incomplete_date"

// The segmented date/time editor (, the react-aria segment model -
// see react-aria §3). The component renders a real native
// <input type=date|time> that IS the form value (no JS = native pickers;
// its ISO value format is exactly the wire contract), plus an empty group.
// This controller builds per-segment role=spinbutton spans from
// Intl.DateTimeFormat.formatToParts - so the LOCALE decides segment order
// and literals - and syncs segments -> native input eagerly whenever the
// value is complete and valid, constraining on blur (February 31st is
// representable mid-edit; commit clamps).
//
// Hour is stored in the locale's hour cycle with a separate dayPeriod
// segment; the cycle itself is INFERRED by formatting (two Intl bugs make
// resolvedOptions() untrustworthy - helpers/incomplete_date.js).
//
// Latin-digit typing only (the NumberField documented divergence); the
// DISPLAY uses Intl.NumberFormat, so locales that render non-latin digits
// still see their own numerals.
const EVENT_PREFIX = "poetry:date-field"

// iPadOS 13+ reports as Mac; maxTouchPoints tells them apart.
const isApplePlatform = () => /iP(hone|ad|od)/.test(navigator.userAgent) ||
  (/Mac/.test(navigator.userAgent) && navigator.maxTouchPoints > 1)

const EDITABLE = {
  date: ["year", "month", "day"],
  time: ["hour", "minute", "second", "dayPeriod"]
}

export default class DateFieldController extends Controller {
  // The events this controller dispatches (manifest surface;
  // events_declaration.test.js enforces the list stays honest).
  static events = ["poetry:date-field:change"]

  static targets = ["input", "group"]
  static values = {
    locale: { type: String, default: "" },
    hourCycle: { type: String, default: "" }, // optional pin: h11|h12|h23|h24
    seconds: { type: Boolean, default: false },
    placeholder: { type: String, default: "" }, // ISO seed for arrow fills
    labels: { type: Object, default: {} }, // segment-name fallbacks (i18n)
    placeholders: { type: Object, default: {} } // segment placeholder text (i18n)
  }

  #value = null // IncompleteDate
  #segments = [] // [{ element, type }]
  #segmentDigits = {} // per-type display width, measured from the locale
  #entered = "" // digit accumulator for the focused segment
  #compositionSnapshot = null
  #dayPeriodNames = null // { am, pm }
  #onSelectionChange = () => this.#collapseSelectionInSegment()

  connect() {
    if (!this.hasInputTarget || !this.hasGroupTarget) return

    this.#value = new IncompleteDate(this.#resolvedHourCycle())
    this.#readInput()
    this.#buildSegments()
    this.element.setAttribute("data-enhanced", "")
    // The native input leaves the tab order (segments are the surface)
    // but STAYS the form value and the constraint-validation carrier.
    this.inputTarget.setAttribute("tabindex", "-1")
    this.inputTarget.setAttribute("aria-hidden", "true")

    // Native required validation fires on the (visually hidden) input;
    // route the browser's focus request to the first empty segment.
    this.inputTarget.addEventListener("invalid", this.#onInvalid)
    document.addEventListener("selectionchange", this.#onSelectionChange)
  }

  disconnect() {
    this.inputTarget?.removeEventListener("invalid", this.#onInvalid)
    document.removeEventListener("selectionchange", this.#onSelectionChange)
    this.element.removeAttribute("data-enhanced")
    this.inputTarget?.removeAttribute("tabindex")
    this.inputTarget?.removeAttribute("aria-hidden")
    this.#segments = []
    this.#segmentDigits = {}
  }

  // Clicking the group's blank space lands on the earliest unfilled
  // segment (react-aria's focusLast heuristic, simplified: segments
  // themselves stop propagation by matching first).
  focusGap(event) {
    if (event.target !== this.groupTarget) return

    const target = this.#segments.find(({ element }) => element.hasAttribute("data-placeholder")) ??
      this.#segments[0]

    target?.element.focus()
  }

  // --- build ---

  get #kind() {
    return this.inputTarget.type === "time" ? "time" : "date"
  }

  #resolvedHourCycle() {
    return resolveHourCycle(this.#locale(), this.hourCycleValue || null)
  }

  #locale() {
    return this.localeValue || document.documentElement.lang || undefined
  }

  #formatterOptions() {
    if (this.#kind === "date") return { year: "numeric", month: "numeric", day: "numeric" }

    const options = { hour: "numeric", minute: "2-digit", hourCycle: this.#value.hourCycle }

    if (this.secondsValue) options.second = "2-digit"

    return options
  }

  #buildSegments() {
    const formatter = new Intl.DateTimeFormat(this.#locale(), this.#formatterOptions())
    // A SINGLE-DIGIT probe (March 3rd, 9:45:05): each part's rendered
    // length IS the locale's digit style - "3" under en-US, "03" under
    // en-CA - so the display padding below can mirror it. A two-digit
    // probe would read every locale as 2-digit.
    const parts = formatter.formatToParts(new Date(2020, 2, 3, 9, 45, 5))
    const editable = EDITABLE[this.#kind]
    const fragment = document.createDocumentFragment()

    this.#resolveDayPeriodNames()

    // RTL correctness: the time run is wrapped in LRI/PDI isolates so
    // minute:hour never renders reversed (harmless in LTR).
    if (this.#kind === "time") fragment.appendChild(this.#literal("⁦"))

    for (const part of parts) {
      const type = part.type === "dayperiod" ? "dayPeriod" : part.type

      if (editable.includes(type)) {
        const segment = this.#createSegment(type)

        // The locale's own width for the padded types (year stays
        // unpadded - "y" numeric everywhere real years are 4 digits).
        if (type === "month" || type === "day" || type === "hour") {
          this.#segmentDigits[type] = part.value.length
        }

        this.#segments.push({ element: segment, type })
        fragment.appendChild(segment)
      } else {
        fragment.appendChild(this.#literal(part.value))
      }
    }

    if (this.#kind === "time") fragment.appendChild(this.#literal("⁩"))

    this.groupTarget.replaceChildren(fragment)
    this.#labelSegments()
    this.#segments.forEach(({ element, type }) => this.#renderSegment(element, type))
  }

  #literal(text) {
    const span = document.createElement("span")

    span.setAttribute("aria-hidden", "true")
    span.setAttribute("data-slot", "date-field-literal")
    span.textContent = text
    return span
  }

  #createSegment(type) {
    const span = document.createElement("span")
    const disabled = this.inputTarget.disabled

    span.setAttribute("data-slot", "date-field-segment")
    span.setAttribute("data-type", type)

    // iOS VoiceOver cannot focus spinbuttons - segments fall back to
    // role=textbox there, with the aria-value* surface stripped.
    if (isApplePlatform() && navigator.maxTouchPoints > 0) span.setAttribute("role", "textbox")
    else span.setAttribute("role", "spinbutton")

    if (disabled) {
      span.setAttribute("aria-disabled", "true")
    } else {
      span.setAttribute("tabindex", "0")
      span.setAttribute("contenteditable", "true")
      span.setAttribute("spellcheck", "false")
      span.setAttribute("autocorrect", "off")
      span.setAttribute("autocapitalize", "off")
      span.setAttribute("enterkeyhint", "next")

      if (type !== "dayPeriod") span.setAttribute("inputmode", "numeric")
    }

    if (type !== "dayPeriod") {
      // The bidi algorithm treats placeholder text and digits differently;
      // without the embed, segments shift while deleting in RTL.
      span.style.unicodeBidi = "embed"
      span.style.direction = "ltr"
    }

    span.style.caretColor = "transparent"

    span.addEventListener("keydown", (event) => this.#onKeydown(event, span, type))
    span.addEventListener("beforeinput", (event) => this.#onBeforeinput(event, span, type))
    span.addEventListener("input", (event) => this.#onInput(event, span, type))
    span.addEventListener("focus", () => { this.#entered = "" })

    return span
  }

  // Segment names come from Intl.DisplayNames where available, the i18n
  // fallback table otherwise - with the FIELD's label appended, because
  // iOS VoiceOver does not announce group labels.
  #labelSegments() {
    let names = null

    try {
      names = new Intl.DisplayNames(this.#locale(), { type: "dateTimeField" })
    } catch { /* fallback table below */ }

    const fieldLabel = this.#fieldLabelText()

    this.#segments.forEach(({ element, type }, index) => {
      const key = type === "dayPeriod" ? "dayPeriod" : type
      let name = this.labelsValue[key] || key

      if (names && type !== "dayPeriod") {
        try { name = names.of(type) ?? name } catch { /* keep fallback */ }
      }

      element.setAttribute("aria-label", fieldLabel ? `${name}, ${fieldLabel}` : name)

      // Only the FIRST segment carries the description - anything more
      // re-announces on every arrow press.
      if (index === 0 && this.inputTarget.getAttribute("aria-describedby")) {
        element.setAttribute("aria-describedby", this.inputTarget.getAttribute("aria-describedby"))
      }
    })

    if (fieldLabel) this.groupTarget.setAttribute("aria-label", fieldLabel)
  }

  #fieldLabelText() {
    const id = this.inputTarget.id

    if (!id) return null

    const escaped = typeof CSS !== "undefined" && CSS.escape ? CSS.escape(id) : id

    return document.querySelector(`label[for="${escaped}"]`)?.textContent?.trim() ||
      this.inputTarget.getAttribute("aria-label") || null
  }

  #resolveDayPeriodNames() {
    if (this.#kind !== "time" || !this.#value.twelveHour) return

    const formatter = new Intl.DateTimeFormat(this.#locale(), { hour: "numeric", hourCycle: this.#value.hourCycle })
    const nameAt = (hour) =>
      formatter.formatToParts(new Date(2020, 0, 1, hour)).find((part) => part.type === "dayPeriod")?.value

    this.#dayPeriodNames = { am: nameAt(9) ?? "AM", pm: nameAt(21) ?? "PM" }
  }

  // --- input reflection ---

  #readInput() {
    const raw = this.inputTarget.value

    if (this.#kind === "date") this.#value.setFromISODate(raw)
    else this.#value.setFromISOTime(raw)
  }

  #placeholderFor(type) {
    const seed = new IncompleteDate(this.#value.hourCycle)
    const iso = this.placeholderValue

    if (this.#kind === "date") {
      if (!seed.setFromISODate(iso)) { seed.year = 2020; seed.month = 1; seed.day = 1 }
    } else if (!seed.setFromISOTime(iso)) {
      seed.setFromH23(12)
      seed.minute = 0
      seed.second = 0
    }

    return seed[type] ?? seed.limits(type).min
  }

  #renderSegment(element, type) {
    const value = this.#value[type]
    const filled = value !== null

    element.toggleAttribute("data-placeholder", !filled)

    if (type === "dayPeriod") {
      element.textContent = filled
        ? (value === 0 ? this.#dayPeriodNames.am : this.#dayPeriodNames.pm)
        : (this.placeholdersValue.dayPeriod || this.#dayPeriodNames?.am || "AM")
    } else if (filled) {
      element.textContent = this.#displayNumber(type, value)
    } else {
      element.textContent = this.placeholdersValue[type] || "––"
    }

    if (element.getAttribute("role") !== "spinbutton") return

    const { min, max } = this.#value.limits(type)

    element.setAttribute("aria-valuemin", String(min))
    element.setAttribute("aria-valuemax", String(max))

    if (filled) {
      element.setAttribute("aria-valuenow", String(value))
      element.setAttribute("aria-valuetext", this.#valueText(type, value))
    } else {
      element.removeAttribute("aria-valuenow")
      element.setAttribute("aria-valuetext", this.labelsValue.empty || "Empty")
    }
  }

  #displayNumber(type, value) {
    const digits = this.#segmentDigits[type] ?? (type === "minute" || type === "second" ? 2 : 1)

    return new Intl.NumberFormat(this.#locale(), {
      minimumIntegerDigits: digits, useGrouping: false
    }).format(value)
  }

  // Month announces "3 - March" (the react-aria enrichment).
  #valueText(type, value) {
    if (type === "month") {
      const name = new Intl.DateTimeFormat(this.#locale(), { month: "long" })
        .format(new Date(2020, value - 1, 1))

      return `${value} – ${name}`
    }

    return this.#displayNumber(type, value)
  }

  // --- keyboard ---

  #onKeydown(event, element, type) {
    if (event.isComposing || this.inputTarget.readOnly) return

    switch (event.key) {
      case "ArrowUp": this.#step(event, element, type, 1); break
      case "ArrowDown": this.#step(event, element, type, -1); break
      case "PageUp": this.#step(event, element, type, PAGE_STEP[type] ?? 1, { round: true }); break
      case "PageDown": this.#step(event, element, type, -(PAGE_STEP[type] ?? 1), { round: true }); break
      case "Home": this.#jump(event, element, type, "min"); break
      case "End": this.#jump(event, element, type, "max"); break
      case "ArrowLeft": event.preventDefault(); this.#moveGeometric(element, -1); break
      case "ArrowRight": event.preventDefault(); this.#moveGeometric(element, 1); break
      case "Backspace":
      case "Delete": event.preventDefault(); this.#erase(element, type); break
      case "Enter": event.preventDefault(); this.#advanceFrom(element); break
      default: this.#maybeDayPeriodKey(event, element, type)
    }
  }

  #step(event, element, type, amount, options = {}) {
    event.preventDefault()
    this.#entered = ""
    this.#value.cycle(type, amount, this.#placeholderFor(type), options)
    this.#renderSegment(element, type)
    this.#commitIfComplete()
  }

  #jump(event, element, type, edge) {
    event.preventDefault()
    this.#entered = ""
    this.#value.set(type, this.#value.limits(type)[edge])
    this.#renderSegment(element, type)
    this.#commitIfComplete()
  }

  #erase(element, type) {
    if (this.#value[type] === null) {
      this.#moveGeometric(element, -1)
      return
    }

    const chopped = this.#entered.length > 1
      ? this.#entered.slice(0, -1)
      : String(this.#value[type]).slice(0, -1)

    this.#entered = chopped

    if (chopped === "" || Number(chopped) === 0 || type === "dayPeriod") {
      this.#value.clear(type)
      this.#entered = ""
    } else {
      this.#value.set(type, Number(chopped))
    }

    this.#renderSegment(element, type)
    this.#syncInput() // an erase can make the value incomplete - clear the wire
  }

  #maybeDayPeriodKey(event, element, type) {
    if (type !== "dayPeriod" || !this.#dayPeriodNames) return
    if (event.key.length !== 1 || event.metaKey || event.ctrlKey || event.altKey) return

    const typed = event.key.toLowerCase()
    const { am, pm } = this.#dayPeriodNames

    if (am.toLowerCase().startsWith(typed)) this.#value.set("dayPeriod", 0)
    else if (pm.toLowerCase().startsWith(typed)) this.#value.set("dayPeriod", 1)
    else return

    event.preventDefault()
    this.#renderSegment(element, "dayPeriod")
    this.#commitIfComplete()
    this.#advanceFrom(element)
  }

  // --- text input (beforeinput is the interception point: mobile numeric
  // keyboards, swipe input, and per-segment paste all arrive here) ---

  #onBeforeinput(event, element, type) {
    if (this.inputTarget.readOnly) { event.preventDefault(); return }

    // insertCompositionText cannot be canceled - snapshot, restore on
    // input, then route the composed data (Android IME otherwise leaves
    // real text inside the segment and breaks the DOM).
    if (event.inputType === "insertCompositionText") {
      this.#compositionSnapshot = element.textContent
      return
    }

    event.preventDefault()

    if (event.inputType.startsWith("delete")) {
      this.#erase(element, type)
      return
    }

    this.#routeText(event.data, element, type)
  }

  #onInput(event, element, type) {
    if (this.#compositionSnapshot === null) return

    element.textContent = this.#compositionSnapshot
    this.#compositionSnapshot = null
    this.#routeText(event.data, element, type)
  }

  #routeText(text, element, type) {
    if (!text) return

    for (const char of text) {
      if (type === "dayPeriod") {
        this.#maybeDayPeriodKey(
          new KeyboardEvent("keydown", { key: char, cancelable: true }), element, type
        )
      } else if (/\d/.test(char)) {
        this.#applyDigit(char, element, type)
      }
    }
  }

  #applyDigit(digit, element, type) {
    const { min, max } = this.#value.limits(type)
    let candidate = this.#entered + digit

    // Typing past the maximum restarts from the last key (react-aria:
    // "3" then "5" in a month is 3, then 5 - never 35).
    if (Number(candidate) > max) candidate = digit

    this.#entered = candidate
    const number = Number(candidate)

    if (number >= min) this.#value.set(type, number)
    else this.#value.clear(type)

    this.#renderSegment(element, type)

    // A pending sub-minimum entry ("0" in a month) shows what was typed.
    if (number < min) element.textContent = candidate

    this.#commitIfComplete()

    // Auto-advance once no further digit can fit.
    if (Number(candidate + "0") > max || candidate.length >= String(max).length) {
      this.#advanceFrom(element)
    }
  }

  // --- segment navigation (GEOMETRIC, not DOM order: numeric runs are
  // LTR-embedded inside an RTL line, so arrows follow visual order) ---

  #moveGeometric(element, direction) {
    this.#entered = ""

    const ordered = this.#segments
      .map(({ element: seg }) => seg)
      .filter((seg) => seg.hasAttribute("tabindex"))
      .sort((a, b) => a.getBoundingClientRect().left - b.getBoundingClientRect().left)
    const index = ordered.indexOf(element)
    const next = ordered[index + direction]

    next?.focus()
  }

  #advanceFrom(element) {
    this.#entered = ""
    this.#moveGeometric(element, 1)
  }

  // --- commit ---

  // Focusout that leaves the whole group constrains (Feb 31 -> Feb 29)
  // and commits; wired as a data-action on the group.
  settle(event) {
    if (this.groupTarget.contains(event.relatedTarget)) return

    this.#entered = ""
    this.#value.constrain(EDITABLE[this.#kind])
    this.#segments.forEach(({ element, type }) => this.#renderSegment(element, type))
    this.#commitIfComplete()
  }

  #commitIfComplete() {
    if (this.#kind === "date" && this.#value.isComplete(["year", "month", "day"]) &&
        !this.#value.isValidDate()) return // Feb 31 mid-edit: hold the wire

    this.#syncInput()
  }

  #syncInput() {
    const iso = this.#kind === "date"
      ? this.#value.toISODate()
      : this.#value.toISOTime(this.secondsValue)
    const next = iso ?? ""

    if (this.inputTarget.value === next) return

    this.inputTarget.value = next
    this.inputTarget.dispatchEvent(new Event("change", { bubbles: true }))
    this.dispatch("change", { prefix: EVENT_PREFIX, detail: { value: next } })
  }

  #onInvalid = (event) => {
    event.preventDefault()
    const target = this.#segments.find(({ element }) => element.hasAttribute("data-placeholder")) ??
      this.#segments[0]

    target?.element.focus()
  }

  // Android Chrome composition breaks if a selection RANGE lives inside a
  // segment - collapse any selection that lands in one.
  #collapseSelectionInSegment() {
    const selection = document.getSelection?.()

    if (!selection || selection.isCollapsed || selection.rangeCount === 0) return

    const anchor = selection.anchorNode
    const inSegment = anchor && this.#segments.some(({ element }) => element.contains(anchor))

    if (inSegment) selection.collapseToStart()
  }
}
