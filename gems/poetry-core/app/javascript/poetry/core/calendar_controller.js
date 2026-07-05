import { Controller } from "@hotwired/stimulus"

// The Calendar engine (N9 W6), decided OWN-THE-ENGINE: no react-day-picker
// (a heavy JS dep). The month grid is SERVER-RENDERED (Ruby Date math) so a
// no-JS page shows a valid calendar; this controller adds month navigation
// (regenerating the 42-cell grid from plain Date math - reusing the day
// button DOM, no innerHTML churn), single-date selection (writing the
// hidden input + the data-selected/aria vocabulary), and roving arrow-key
// focus over the days. Selection is a real form value; the DatePicker
// composes this inside a Popover.
//
// Deferred (v2): range selection (the range_start/middle/end classes ship
// in the dictionary but no controller path yet), dropdown caption, week
// numbers, multiple months.
const DAY_SELECTOR = '[data-slot="calendar-day"]'
const MS_PER_DAY = 86400000

export default class CalendarController extends Controller {
  static targets = ["grid", "caption", "input", "day"]
  static values = {
    month: String, // the visible month, "YYYY-MM"
    selected: String, // the chosen date, "YYYY-MM-DD" (or "")
    weekStart: { type: Number, default: 0 }, // 0 = Sunday
    min: String,
    max: String,
    locale: { type: String, default: "en-US" }
  }

  #today = null

  connect() {
    // The server rendered the initial month correctly; just sync the
    // selected/today vocabulary in case selected was set programmatically.
    this.#reflectSelection()
  }

  previousMonth() {
    this.#goTo(this.#shiftMonth(-1))
  }

  nextMonth() {
    this.#goTo(this.#shiftMonth(1))
  }

  // Action: click->poetry--core--calendar#select on each day button.
  select(event) {
    const button = event.target.closest(DAY_SELECTOR)
    if (!button || button.disabled) return

    this.selectedValue = button.dataset.date
    this.#reflectSelection()
    this.dispatch("change", { detail: { value: this.selectedValue } })
  }

  // Action: keydown->poetry--core--calendar#keydown on the grid - arrows
  // move focus by day/week, PageUp/Down by month, Home/End to week edges.
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
  #focusDate(date) {
    const iso = this.#iso(date)

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
    this.#reflectSelection()
  }

  #reflectSelection() {
    for (const button of this.dayTargets) {
      const selected = button.dataset.date === this.selectedValue && this.selectedValue !== ""

      this.#toggle(button, "data-selected", selected)
      button.setAttribute("aria-selected", selected ? "true" : "false")
      if (button.dataset.date === this.#todayIso()) button.setAttribute("aria-current", "date")
      else button.removeAttribute("aria-current")
    }
    if (this.hasInputTarget) this.inputTarget.value = this.selectedValue ?? ""
  }

  // Exactly one day is the tab stop (the roving contract): the selected
  // day, else today in view, else the first enabled day.
  #rovingStop(preferred) {
    const stop = preferred
      || this.dayTargets.find((d) => d.dataset.date === this.selectedValue)
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
    return new Date(Date.UTC(year, month - 1, 1))
      .toLocaleDateString(this.localeValue, { month: "long", year: "numeric", timeZone: "UTC" })
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
