import { Controller } from "@hotwired/stimulus"
import { setState } from "@poetry/controllers/helpers/state"

// The RadioGroup checked-value machine (the Accordion composition shape):
// this controller owns ONLY the value + attribute/input writes - ZERO
// keyboard code. The shared poetry--core--roving-focus runs on the same
// root in its DEFAULT tabindex-managing mode (one Tab stop) with the
// orientation: "both" extension (all four arrows, APG radio), and this
// controller consumes its cancelable entry event to implement SELECTION
// FOLLOWS FOCUS: entry fires only on arrow/Home/End navigation - never on
// Tab or click-focus - so checking on entry is exactly the APG contract
// (Tab into the group never changes the value; Radix-exact).
//
// The form story is the hidden-native-input rule: one <input type=radio>
// per item, shared name (aria-hidden, tabindex=-1) - native radio
// serialization, byte-identical to collection_radio_buttons. check() writes
// every item's aria-checked/checked pair/indicator, sets the hidden input's
// .checked (the native group unchecks siblings; written explicitly anyway -
// belt and braces), moves the roving tab stop to the checked item, and
// dispatches poetry:radio-group:change + native input/change on the newly
// checked hidden input (Rails autosave/change-tracking listeners fire).
const ITEM_SELECTOR = '[data-slot="radio-group-item"]'
const INDICATOR_SELECTOR = '[data-slot="radio-group-indicator"]'

export default class RadioGroupController extends Controller {
  // The events this controller dispatches (manifest surface;
  // events_declaration.test.js enforces the list stays honest).
  static events = ["poetry:radio-group:change"]

  static values = {
    value: { type: String, default: "" }
  }

  static targets = ["input"]

  #connected = false

  connect() {
    // Reconcile-on-connect: the server renders the checked state (aria +
    // the checked pair + input checked + the tab stop); adopt it into the Value
    // when the Value was not given, else normalize the DOM to the Value.
    if (this.valueValue === "") {
      const checked = this.#items().find((item) => item.getAttribute("aria-checked") === "true")

      if (checked) this.valueValue = checked.dataset.value ?? ""
    } else {
      this.#write(this.valueValue)
    }

    this.#connected = true
  }

  // --- actions ---

  // Item click (also Space via native button activation).
  check(event) {
    const origin = event.currentTarget instanceof Element ? event.currentTarget : event.target
    const item = origin instanceof Element ? origin.closest(ITEM_SELECTOR) : null

    if (item) this.#check(item)
  }

  // roving-focus:entry - fires ONLY on arrow/Home/End navigation (never on
  // Tab), so this IS selection-follows-focus.
  entryCheck(event) {
    const item = event.detail?.item

    if (item instanceof Element && item.matches(ITEM_SELECTOR)) this.#check(item)
  }

  // --- the programmatic controllable-state surface ---

  setValue(value) {
    const item = this.#itemFor(value)

    if (!item) {
      console.debug(`poetry--core--radio-group: unknown value "${value}"`)
      return
    }

    this.#check(item)
  }

  valueValueChanged(value, previous) {
    if (!this.#connected || value === previous) return

    this.#write(value)
  }

  // --- the checked-value machine ---

  #check(item) {
    if (this.#disabled(item)) return

    const value = item.dataset.value ?? ""

    if (value === this.valueValue) return // re-check no-ops (radios never uncheck)

    const previous = this.valueValue

    // Write synchronously (the Value's changed callback arrives on the
    // MutationObserver microtask - too late for the machine); the Value is
    // updated for the controllable-state surface and re-writes idempotently.
    this.valueValue = value
    this.#write(value)
    this.dispatch("change", { prefix: "poetry:radio-group", detail: { value, previous } })

    // The native mirror on the newly checked hidden input - the Rails
    // ecosystem's change/input listeners work with zero shims.
    const input = this.#inputFor(item)

    input?.dispatchEvent(new Event("input", { bubbles: true }))
    input?.dispatchEvent(new Event("change", { bubbles: true }))
  }

  // The one write path: aria-checked + the checked pair written together on every
  // item, indicator visibility, hidden input .checked, and the roving tab
  // stop moved to the checked item.
  #write(value) {
    const items = this.#items()
    const checkedItem = items.find((item) => (item.dataset.value ?? "") === value) ?? null

    for (const item of items) {
      const checked = item === checkedItem

      item.setAttribute("aria-checked", String(checked))
      setState(item, checked ? "checked" : "unchecked")
      item.querySelector(INDICATOR_SELECTOR)?.toggleAttribute("hidden", !checked)

      const input = this.#inputFor(item)

      if (input) input.checked = checked
    }

    this.#moveTabStop(items, checkedItem)
  }

  // One tabindex=0 - the checked item (or the first enabled when nothing is
  // checked); roving-focus adopts the stamp (its current-stop scan reads
  // tabindex="0").
  #moveTabStop(items, checkedItem) {
    const target = (checkedItem && !this.#disabled(checkedItem) ? checkedItem : null) ??
      items.find((item) => !this.#disabled(item))

    if (!target) return

    for (const item of items) item.setAttribute("tabindex", item === target ? "0" : "-1")
  }

  #items() {
    return Array.from(this.element.querySelectorAll(ITEM_SELECTOR))
  }

  #itemFor(value) {
    return this.#items().find((item) => (item.dataset.value ?? "") === value) ?? null
  }

  // The hidden native radio rides inside its item (the skeleton's shape);
  // the target scope is the fallback for hosts that render inputs elsewhere.
  #inputFor(item) {
    return item.querySelector('input[type="radio"]') ??
      this.inputTargets.find((input) => input.value === item.dataset.value) ?? null
  }

  #disabled(item) {
    return item.hasAttribute("disabled") || item.hasAttribute("data-disabled") ||
      this.element.hasAttribute("data-disabled")
  }
}
