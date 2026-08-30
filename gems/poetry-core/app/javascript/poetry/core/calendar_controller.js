import { Controller } from "@hotwired/stimulus"

// The Calendar engine, decided OWN-THE-ENGINE: no date-picker library
// (a heavy JS dep). The month grid is SERVER-RENDERED (Ruby Date math) so a
// no-JS page shows a valid calendar; this controller adds month navigation
// (regenerating the 42-cell grid from plain Date math - reusing the day
// button DOM, no innerHTML churn), single-date selection (writing the
// hidden input + the data-selected/aria vocabulary), and roving arrow-key
// focus over the days. Selection is a real form value; the DatePicker
// composes this inside a Popover.
//
// Range mode: mode="range" swaps the click path for a
// transcription of react-day-picker's addToRange algorithm (MIT; see
// THIRD_PARTY_NOTICES.md) and the reflection
// for the range vocabulary (data-range-start/middle/end - dictionary
// classes that shipped inert until range mode). The form value is TWO
// hidden inputs (name[start]/name[end] - upstream has no form story; the
// wire shape is poetry's). Upstream semantics kept exactly: an incomplete
// start-only pick renders as a plain selected single day; the range
// vocabulary appears only once the range completes.
//
// Dropdown caption (caption_layout: :dropdown), the upstream overlay
// pattern: each [data-calendar-unit=month|year] wrapper holds a visible
// text label (calendar-dropdown-value) with the real select stretched
// invisibly over it - #jump reads the selects, #render reflects
// navigation back into both select values AND label text (no caption
// target in that mode). Week numbers: one role=rowheader per week; each
// row's Thursday decides the ISO number (matches Ruby Date#cweek under
// any week_start).
//
// Still deferred: multiple months.
const DAY_SELECTOR = '[data-slot="calendar-day"]'
const MS_PER_DAY = 86400000

// The component-facing event namespace (the poetry:<component> rule).
const EVENT_PREFIX = "poetry:calendar"

export default class CalendarController extends Controller {
  // The events this controller dispatches (manifest surface;
  // events_declaration.test.js enforces the list stays honest).
  static events = ["poetry:calendar:change"]

  static targets = ["grid", "caption", "input", "startInput", "endInput", "day"]
  static values = {
    month: String, // the visible month, "YYYY-MM"
    selected: String, // the chosen date, "YYYY-MM-DD" (or "")
    mode: { type: String, default: "single" }, // "single" | "range"
    rangeStart: String, // "YYYY-MM-DD" (or "")
    rangeEnd: String,
    weekStart: { type: Number, default: 0 }, // 0 = Sunday
    min: String,
    max: String,
    // The localized month names, handed down by the SERVER (Ruby I18n) so
    // the JS caption needs no Intl - correct under app locale AND in the
    // Intl-less dommy engine. English is the fallback.
    monthNames: {
      type: Array,
      default: ["January", "February", "March", "April", "May", "June",
                "July", "August", "September", "October", "November", "December"]
    }
  }

  #today = null
  #booted = false

  /** Syncs the selected/today vocabulary over the server-rendered grid. */
  connect() {
    // The server rendered the initial month correctly; just sync the
    // selected/today vocabulary in case selected was set programmatically.
    this.#reflectSelection()
    this.#booted = true
  }

  /** The previous-month button's click action. */
  previousMonth() {
    this.#goTo(this.#shiftMonth(-1))
  }

  /** The next-month button's click action. */
  nextMonth() {
    this.#goTo(this.#shiftMonth(1))
  }

  /**
   * The dropdown caption's change action (the month/year select
   * wrappers): navigates to the selects' month.
   */
  jump() {
    const read = (unit) => this.element.querySelector(`[data-calendar-unit="${unit}"] select`)?.value
    const month = read("month")
    const year = read("year")

    if (!month || !year) return

    this.#goTo(`${year}-${String(month).padStart(2, "0")}`)
  }

  /**
   * Each day button's click action: single mode writes the selection;
   * range mode runs the addToRange transcription. The change event
   * carries value (single) or start/end (range) as ISO strings.
   *
   * @param {MouseEvent} event
   */
  select(event) {
    const button = event.target.closest(DAY_SELECTOR)
    if (!button || button.disabled) return

    if (this.modeValue === "range") {
      this.#addToRange(button.dataset.date)
      this.#reflectSelection()
      this.dispatch("change", { prefix: EVENT_PREFIX, detail: { start: this.rangeStartValue, end: this.rangeEndValue } })
      return
    }

    this.selectedValue = button.dataset.date
    this.#reflectSelection()
    this.dispatch("change", { prefix: EVENT_PREFIX, detail: { value: this.selectedValue } })
  }

  // react-day-picker's addToRange algorithm, transcribed (ISO strings compare
  // lexicographically, so <,> are date order).
  #addToRange(clicked) {
    const start = this.rangeStartValue
    const end = this.rangeEndValue

    if (!start) {
      this.rangeStartValue = clicked
      this.rangeEndValue = ""
      return
    }
    if (!end) {
      if (clicked === start) this.rangeEndValue = clicked // re-click completes the single-day range
      else if (clicked < start) {
        this.rangeStartValue = clicked
        this.rangeEndValue = start
      } else this.rangeEndValue = clicked
      return
    }
    // A complete range:
    if (clicked === start && clicked === end) {
      this.rangeStartValue = "" // re-click the single-day range clears it
      this.rangeEndValue = ""
    } else if (clicked === start) {
      this.rangeEndValue = clicked // collapse onto the start
    } else if (clicked === end) {
      this.rangeStartValue = clicked // restart from the end
      this.rangeEndValue = ""
    } else if (clicked < start) {
      this.rangeStartValue = clicked // extend backward
    } else {
      this.rangeEndValue = clicked // move the end
    }
  }

  /**
   * The grid's keydown action: arrows move focus by day/week, PageUp/Down
   * by month, Home/End to the week edges.
   *
   * @param {KeyboardEvent} event
   */
  keydown(event) {
    const current = event.target.closest(DAY_SELECTOR)
    if (!current) return

    const delta = {
      ArrowLeft: -1, ArrowRight: 1, ArrowUp: -7, ArrowDown: 7,
      Home: "week-start", End: "week-end"
    }[event.key]

    if (event.key === "PageUp") { event.preventDefault(); return this.previousMonth() }
    if (event.key === "PageDown") { event.preventDefault(); return this.nextMonth() }
    if (delta === undefined) return

    event.preventDefault()
    const date = this.#parse(current.dataset.date)

    let target
    if (delta === "week-start") target = this.#addDays(date, -this.#weekdayIndex(date))
    else if (delta === "week-end") target = this.#addDays(date, 6 - this.#weekdayIndex(date))
    else target = this.#addDays(date, delta)

    this.#focusDate(target)
  }

  // Move focus to a date, crossing a month boundary by re-rendering first.
  // A disabled (out-of-range) target is a WALL, not a landing spot: min/max
  // is the only disabled source and it is contiguous, so navigation simply
  // refuses - focus() on a disabled button is a silent no-op, and stamping
  // it as the roving stop would leave the grid with no working Tab entry.
  #focusDate(date) {
    const iso = this.#iso(date)

    if (this.#outOfRange(iso)) return

    if (this.#monthOf(date) !== this.monthValue) {
      this.monthValue = this.#monthOf(date)
      this.#render()
    }
    const button = this.dayTargets.find((day) => day.dataset.date === iso)
    button?.focus()
    this.#rovingStop(button)
  }

  #goTo(month) {
    this.monthValue = month
    this.#render()
  }

  /**
   * Stimulus value callback. The DOM is the store (the anchor-point
   * precedent): external writes to selected/month - the DatePicker input
   * variant syncs typed dates this way - re-render on change. The booted
   * gate skips the init echo (the server's own paint - Stimulus fires
   * initial value callbacks BEFORE connect, and a connect-era render
   * would restamp data-today with the client clock over the server's
   * pinned one). Internal writes re-render once more; the in-place cell
   * diff makes that free.
   */
  selectedValueChanged() {
    if (this.#booted) this.#render()
  }

  /** Stimulus value callback: re-renders on external month writes (see above). */
  monthValueChanged() {
    if (this.#booted) this.#render()
  }

  // Rewrite the day buttons for the visible month IN PLACE (42 cells,
  // stable layout) - date/label/outside/today/disabled/selected. Reuses
  // the existing button DOM; only cells that changed are touched.
  #render() {
    const cells = this.#buildMonth()

    this.dayTargets.forEach((button, index) => {
      const cell = cells[index]
      const iso = this.#iso(cell.date)

      button.dataset.date = iso
      button.querySelector("[data-slot=calendar-day-label]").textContent = String(cell.date.getUTCDate())
      this.#toggle(button, "data-outside", cell.outside)
      this.#toggle(button, "data-today", iso === this.#todayIso())
      button.disabled = this.#outOfRange(iso)
    })

    if (this.hasCaptionTarget) this.captionTarget.textContent = this.#captionText()
    this.#reflectDropdowns()
    this.#reflectWeekNumbers(cells)
    this.#reflectSelection()
  }

  // The dropdown caption follows navigation (prev/next must move the
  // selects too, not just the grid). The visible label span mirrors the
  // select (the overlay pattern: the select is invisible on top).
  #reflectDropdowns() {
    const [year, month] = this.monthValue.split("-").map(Number)

    for (const wrapper of this.element.querySelectorAll("[data-calendar-unit]")) {
      const monthly = wrapper.dataset.calendarUnit === "month"
      const select = wrapper.querySelector("select")
      const label = wrapper.querySelector("[data-slot=\"calendar-dropdown-value\"]")

      if (select) select.value = String(monthly ? month : year)
      if (label) label.textContent = monthly ? this.monthNamesValue[month - 1] : String(year)
    }
  }

  // One rowheader per week; the row's Thursday decides the ISO number
  // (mirrors Ruby's Date#cweek, stable under any week_start).
  #reflectWeekNumbers(cells) {
    const numbers = this.element.querySelectorAll('[role="rowheader"][data-slot="calendar-week-number"]')

    numbers.forEach((cell, row) => {
      const thursday = cells.slice(row * 7, row * 7 + 7).find((c) => c.date.getUTCDay() === 4)

      cell.textContent = String(this.#isoWeek(thursday.date))
    })
  }

  #isoWeek(thursday) {
    const yearStart = Date.UTC(thursday.getUTCFullYear(), 0, 1)
    const dayOfYear = (thursday.getTime() - yearStart) / MS_PER_DAY + 1

    return Math.ceil(dayOfYear / 7)
  }

  #reflectSelection() {
    if (this.modeValue === "range") {
      this.#reflectRange()
      return
    }
    for (const button of this.dayTargets) {
      const selected = button.dataset.date === this.selectedValue && this.selectedValue !== ""

      this.#toggle(button, "data-selected", selected)
      // aria-selected belongs on the role=gridcell parent, not the button
      // (the ARIA grid contract; a plain button can't carry aria-selected).
      button.closest('[role="gridcell"]')?.setAttribute("aria-selected", selected ? "true" : "false")
      this.#reflectToday(button)
    }
    if (this.hasInputTarget) this.inputTarget.value = this.selectedValue ?? ""
  }

  // The range vocabulary (the upstream range modifiers): the span wears range-start /
  // range-middle / range-end only once COMPLETE; a start-only pick is a
  // plain selected single day. Survives month nav because it re-derives
  // from every visible button's date (a span may extend offscreen).
  #reflectRange() {
    const start = this.rangeStartValue || ""
    const end = this.rangeEndValue || ""
    const complete = start !== "" && end !== ""

    for (const button of this.dayTargets) {
      const iso = button.dataset.date
      const inSpan = complete ? iso >= start && iso <= end : start !== "" && iso === start

      this.#toggle(button, "data-selected", !complete && start !== "" && iso === start)
      this.#toggle(button, "data-range-start", complete && iso === start)
      this.#toggle(button, "data-range-end", complete && iso === end)
      this.#toggle(button, "data-range-middle", complete && iso > start && iso < end)
      button.closest('[role="gridcell"]')?.setAttribute("aria-selected", inSpan ? "true" : "false")
      this.#reflectToday(button)
    }
    if (this.hasStartInputTarget) this.startInputTarget.value = start
    if (this.hasEndInputTarget) this.endInputTarget.value = end
  }

  #reflectToday(button) {
    if (button.dataset.date === this.#todayIso()) button.setAttribute("aria-current", "date")
    else button.removeAttribute("aria-current")
  }

  // Exactly one day is the tab stop (the roving contract): the selected
  // day, else today in view, else the first enabled day.
  #rovingStop(preferred) {
    const anchor = this.modeValue === "range" ? this.rangeStartValue : this.selectedValue
    const stop = preferred
      || this.dayTargets.find((d) => d.dataset.date === anchor)
      || this.dayTargets.find((d) => d.dataset.date === this.#todayIso())
      || this.dayTargets.find((d) => !d.disabled)

    for (const day of this.dayTargets) day.setAttribute("tabindex", day === stop ? "0" : "-1")
  }

  // --- date math (UTC, so DST never shifts a day) --------------------------

  #buildMonth() {
    const [year, month] = this.monthValue.split("-").map(Number)
    const first = new Date(Date.UTC(year, month - 1, 1))
    const lead = (first.getUTCDay() - this.weekStartValue + 7) % 7
    const start = this.#addDays(first, -lead)

    return Array.from({ length: 42 }, (_, index) => {
      const date = this.#addDays(start, index)
      return { date, outside: date.getUTCMonth() !== month - 1 }
    })
  }

  #captionText() {
    const [year, month] = this.monthValue.split("-").map(Number)
    return `${this.monthNamesValue[month - 1]} ${year}`
  }

  #shiftMonth(by) {
    const [year, month] = this.monthValue.split("-").map(Number)
    const date = new Date(Date.UTC(year, month - 1 + by, 1))
    return this.#monthOf(date)
  }

  #outOfRange(iso) {
    if (this.minValue && iso < this.minValue) return true
    if (this.maxValue && iso > this.maxValue) return true
    return false
  }

  #addDays(date, days) {
    return new Date(date.getTime() + days * MS_PER_DAY)
  }

  #weekdayIndex(date) {
    return (date.getUTCDay() - this.weekStartValue + 7) % 7
  }

  #parse(iso) {
    const [year, month, day] = iso.split("-").map(Number)
    return new Date(Date.UTC(year, month - 1, day))
  }

  #iso(date) {
    return date.toISOString().slice(0, 10)
  }

  #monthOf(date) {
    return this.#iso(date).slice(0, 7)
  }

  #todayIso() {
    this.#today ??= this.#iso(new Date())
    return this.#today
  }

  #toggle(element, attribute, on) {
    if (on) element.setAttribute(attribute, "")
    else element.removeAttribute(attribute)
  }
}
