import { Controller } from "@hotwired/stimulus"
import { setState, stateOf } from "@poetry/controllers/helpers/state"

// The ToggleGroup value-set machine (the Accordion composition, second
// consumer): this controller owns ONLY the pressed-values set + attribute
// writes; the shared poetry--core--roving-focus on the same root owns the
// keyboard (default tabindex-managing mode - one Tab stop). Items are DUMB
// buttons (data-action -> group#toggle; poetry--core--pressed is NOT
// attached in group context - one owner, no event soup).
//
// The source-verified role/vocabulary split, enforced here: type=single is
// RADIO semantics - items carry aria-checked (aria-pressed stripped) and
// re-pressing the sole pressed item deselects to EMPTY (Radix setValue(''));
// type=multiple is toolbar semantics - independent aria-pressed items. The
// controller reads type once and never mixes vocabularies; the bare
// data-pressed presence boolean styles both types identically (Toggle's
// classes just work).
//
// After every transition the PRESSED item becomes the roving tab stop
// (Radix active=pressed: re-entering the group lands on the selection) -
// written directly as the tabindex stamp roving-focus adopts.
const ITEM_SELECTOR = '[data-slot="toggle-group-item"]'

export default class ToggleGroupController extends Controller {
  static values = {
    type: { type: String, default: "single" }
  }

  connect() {
    // Reconcile-on-connect: server-rendered data-pressed is the truth; the
    // type-correct aria attribute is (re)derived from it, so a Turbo Stream
    // re-render (or a hand-patched item) can never mix vocabularies.
    for (const item of this.#items()) this.#write(item, stateOf(item) === "pressed")

    this.#preferPressedTabStop()
  }

  // --- item activation (click / Space / Enter via native button click) ---

  toggle(event) {
    const origin = event.currentTarget instanceof Element ? event.currentTarget : event.target
    const item = origin instanceof Element ? origin.closest(ITEM_SELECTOR) : null

    if (!item || this.#disabled(item)) return

    const value = item.dataset.value

    if (this.#single()) this.#toggleSingle(value)
    else this.#toggleMultiple(value)
  }

  // --- the programmatic controllable-state surface ---

  // setValue("b") in single mode ("" / null clears); setValue(["a", "b"])
  // in multiple mode. Validated against type; unknown values are ignored
  // (logged in dev - the contract's guard).
  setValue(value) {
    const values = this.#known(Array.isArray(value) ? value : (value ? [value] : []))

    if (this.#single()) {
      if (Array.isArray(value) && value.length > 1) {
        console.warn("poetry--core--toggle-group: setValue(array) is invalid with type=single")
        return
      }

      this.#apply(new Set(values.slice(0, 1)))
    } else {
      if (!Array.isArray(value) && value != null && value !== "") {
        console.warn("poetry--core--toggle-group: setValue expects an array with type=multiple")
        return
      }

      this.#apply(new Set(values))
    }
  }

  // --- the set machine ---

  // single: S == {v} -> {} (deselect-to-empty, Radix-exact), else -> {v}.
  #toggleSingle(value) {
    const pressed = this.#pressedValues()

    this.#apply(new Set(pressed.has(value) ? [] : [value]))
  }

  // multiple: S -> S XOR {v}.
  #toggleMultiple(value) {
    const pressed = this.#pressedValues()

    if (pressed.has(value)) pressed.delete(value)
    else pressed.add(value)

    this.#apply(pressed)
  }

  #apply(next) {
    const pressed = []
    const unpressed = []

    for (const item of this.#items()) {
      const on = next.has(item.dataset.value)
      const was = stateOf(item) === "pressed"

      this.#write(item, on)

      if (on && !was) pressed.push(item.dataset.value)
      if (!on && was) unpressed.push(item.dataset.value)
    }

    if (pressed.length === 0 && unpressed.length === 0) return

    this.#preferPressedTabStop()

    const values = [...next]

    this.dispatch("change", {
      prefix: "poetry:toggle-group",
      detail: {
        type: this.typeValue,
        ...(this.#single() ? { value: values[0] ?? null } : { values }),
        pressed,
        unpressed
      }
    })
  }

  // data-pressed and the TYPE-CORRECT aria attribute, written together:
  // single items are radios (aria-checked, aria-pressed stripped - the Radix
  // {'aria-pressed': undefined} strip); multiple items are toggle buttons.
  #write(item, on) {
    setState(item, on ? "pressed" : "unpressed")

    if (this.#single()) {
      item.setAttribute("aria-checked", String(on))
      item.removeAttribute("aria-pressed")
    } else {
      item.setAttribute("aria-pressed", String(on))
      item.removeAttribute("aria-checked")
    }
  }

  // active=pressed (Radix): the pressed item is the preferred tab stop.
  // Written as the tabindex stamp the roving-focus controller adopts (its
  // current-stop scan reads tabindex="0"); only when roving already manages
  // tabindex here (the stamp exists), so a manage-tabindex:false host is
  // left untouched.
  #preferPressedTabStop() {
    const items = this.#items()

    if (!items.some((item) => item.hasAttribute("tabindex"))) return

    const target = items.find((item) => stateOf(item) === "pressed" && !this.#disabled(item)) ??
      items.find((item) => !this.#disabled(item))

    if (!target) return

    for (const item of items) item.setAttribute("tabindex", item === target ? "0" : "-1")
  }

  #pressedValues() {
    return new Set(this.#items().filter((item) => stateOf(item) === "pressed").map((item) => item.dataset.value))
  }

  #known(values) {
    const valid = new Set(this.#items().map((item) => item.dataset.value))
    const unknown = values.filter((value) => !valid.has(value))

    if (unknown.length > 0) console.debug(`poetry--core--toggle-group: unknown value(s) ${unknown.join(", ")}`)

    return values.filter((value) => valid.has(value))
  }

  #items() {
    return Array.from(this.element.querySelectorAll(ITEM_SELECTOR))
  }

  #single() {
    return this.typeValue !== "multiple"
  }

  #disabled(item) {
    return item.hasAttribute("disabled") || item.hasAttribute("data-disabled") ||
      this.element.hasAttribute("data-disabled")
  }
}
