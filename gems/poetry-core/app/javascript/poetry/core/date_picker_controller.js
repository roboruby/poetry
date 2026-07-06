import { Controller } from "@hotwired/stimulus"

// The DatePicker glue (N9 W6): the thin coordinator between a Popover and
// the Calendar it wraps. The Calendar owns selection + the form value (its
// name: hidden input); this controller only reacts to the calendar's change
// event to (a) write the human-formatted date into the trigger label and
// (b) close the popover so the pick feels complete. Everything hard is
// already done by poetry--core--calendar and poetry--core--popover.
export default class DatePickerController extends Controller {
  static targets = ["label"]
  static values = {
    placeholder: { type: String, default: "Pick a date" },
    mode: { type: String, default: "single" },
    locale: { type: String, default: "en-US" }
  }

  // Action: poetry--core--calendar:change->poetry--core--date-picker#picked
  // on the wrapper. Range mode (N9 D1): the label joins the pair, a
  // start-only pick shows one date, and the popover closes only once the
  // range COMPLETES (the shadcn convention - never mid-range).
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
    if (iso) this.#closePopover()
  }

  #format(iso) {
    // Parse as UTC noon so the local-timezone render never rolls the day.
    const date = new Date(`${iso}T12:00:00Z`)
    return date.toLocaleDateString(this.localeValue, {
      year: "numeric", month: "long", day: "numeric", timeZone: "UTC"
    })
  }

  #closePopover() {
    const popover = this.element.querySelector('[data-controller~="poetry--core--popover"]')
    if (!popover) return

    const controller =
      this.application.getControllerForElementAndIdentifier(popover, "poetry--core--popover")
    controller?.close("item-press")
  }
}
