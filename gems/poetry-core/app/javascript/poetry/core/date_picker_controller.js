import { Controller } from "@hotwired/stimulus"

// The DatePicker glue: the thin coordinator between a Popover and
// the Calendar it wraps. The Calendar owns selection + the form value (its
// name: hidden input); this controller only reacts to the calendar's change
// event to (a) write the human-formatted date into the trigger label and
// (b) close the popover so the pick feels complete. Everything hard is
// already done by poetry--core--calendar and poetry--core--popover.
export default class DatePickerController extends Controller {
  static targets = ["label", "input"]
  static values = {
    placeholder: { type: String, default: "Pick a date" },
    mode: { type: String, default: "single" },
    locale: { type: String, default: "en-US" }
  }

  /**
   * The calendar-change action on the wrapper: writes the formatted date
   * into the trigger label (and input, when present) and closes the
   * popover so the pick feels complete. Range mode: the label joins the
   * pair, a start-only pick shows one date, and the popover closes only
   * once the range COMPLETES (the upstream convention - never mid-range).
   *
   * @param {CustomEvent} event - detail carries value (single) or
   *   start/end (range) as ISO strings
   */
  picked(event) {
    if (this.modeValue === "range") {
      const { start, end } = event.detail ?? {}
      if (this.hasLabelTarget) {
        this.labelTarget.textContent = start
          ? [start, end].filter(Boolean).map((iso) => this.#format(iso)).join(" – ")
          : this.placeholderValue
      }
      if (start && end) this.#closePopover()
      return
    }

    const iso = event.detail?.value

    if (this.hasLabelTarget) {
      this.labelTarget.textContent = iso ? this.#format(iso) : this.placeholderValue
    }
    if (this.hasInputTarget && iso) this.inputTarget.value = this.#format(iso)
    if (iso) this.#closePopover()
  }

  // --- the input variant (upstream's date-picker-input recipe) ---

  /**
   * The input's change action: a parseable date re-selects and re-months
   * the calendar through its reactive values (the DOM is the store), and
   * the calendar's own render refreshes the hidden ISO form value.
   * Unparseable text changes nothing - exactly upstream's isValidDate.
   */
  inputChanged() {
    if (!this.hasInputTarget) return

    const parsed = new Date(this.inputTarget.value)

    if (Number.isNaN(parsed.getTime())) return

    const pad = (n) => String(n).padStart(2, "0")
    const iso = `${parsed.getFullYear()}-${pad(parsed.getMonth() + 1)}-${pad(parsed.getDate())}`
    const calendar = this.#calendar()

    if (!calendar) return

    calendar.monthValue = iso.slice(0, 7)
    calendar.selectedValue = iso
  }

  /**
   * The input's keydown action: ArrowDown opens the calendar (upstream's
   * affordance).
   *
   * @param {KeyboardEvent} event
   */
  inputKeydown(event) {
    if (event.key !== "ArrowDown") return

    event.preventDefault()
    this.#popover()?.open()
  }

  #calendar() {
    const root = this.element.querySelector('[data-controller~="poetry--core--calendar"]')

    return root && this.application.getControllerForElementAndIdentifier(root, "poetry--core--calendar")
  }

  #popover() {
    const root = this.element.querySelector('[data-controller~="poetry--core--popover"]')

    return root && this.application.getControllerForElementAndIdentifier(root, "poetry--core--popover")
  }

  #format(iso) {
    // Parse as UTC noon so the local-timezone render never rolls the day.
    // Range labels use SHORT month names (the server formats %b for the
    // same reason: two long-month dates outgrow the trigger).
    const date = new Date(`${iso}T12:00:00Z`)
    return date.toLocaleDateString(this.localeValue, {
      year: "numeric", month: this.modeValue === "range" ? "short" : "long",
      day: "numeric", timeZone: "UTC"
    })
  }

  #closePopover() {
    this.#popover()?.close("item-press")
  }
}
