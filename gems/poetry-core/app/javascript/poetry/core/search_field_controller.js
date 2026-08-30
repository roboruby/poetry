import { Controller } from "@hotwired/stimulus"
import { isImeKeydown } from "@poetry/controllers/helpers/escape"

// The SearchField seams: Escape CLEARS a
// non-empty field and is consumed - the NEXT press reaches the dismissal
// layer and closes a parent overlay; an already-empty field lets Escape
// propagate untouched. Emptiness is checked against the RAW input value
// (autofill and scripts poke the DOM directly). The clear button keeps
// focus in the input by preventing the press's focus steal at
// pointerdown - on mobile that is what keeps the virtual keyboard up.
// Enter is never intercepted: native form submission is the Rails path.
const EVENT_PREFIX = "poetry:search-field"

export default class SearchFieldController extends Controller {
  // The events this controller dispatches (manifest surface;
  // events_declaration.test.js enforces the list stays honest).
  static events = ["poetry:search-field:clear"]

  static targets = ["input", "clear"]

  /** Reflects the initial emptiness (data-empty + the clear affordance). */
  connect() {
    this.#reflect()
  }

  /** The input action: keeps data-empty and the clear affordance honest. */
  changed() {
    this.#reflect()
  }

  /**
   * The input's keydown action: Escape CLEARS a non-empty field and is
   * consumed; an already-empty field lets it propagate to the dismissal
   * layer (the seam the header documents).
   *
   * @param {KeyboardEvent} event
   */
  keydown(event) {
    if (event.key !== "Escape" || isImeKeydown(event)) return
    if (this.inputTarget.disabled || this.inputTarget.readOnly) return
    if (this.inputTarget.value === "") return // propagate: the dismissal layer's turn

    event.preventDefault()
    event.stopPropagation()
    this.#clear()
  }

  /**
   * The clear button's pointerdown action: keeps focus (and the mobile
   * keyboard) in the input - the later click acts.
   *
   * @param {PointerEvent} event
   */
  holdFocus(event) {
    event.preventDefault()
    this.inputTarget.focus()
  }

  /**
   * The clear button's click action: empties the field (dispatching a
   * REAL input event so live-search listeners react) and refocuses it.
   * No-op while disabled or readonly.
   *
   * @param {MouseEvent} event
   */
  clear(event) {
    event.preventDefault()
    if (this.inputTarget.disabled || this.inputTarget.readOnly) return

    this.#clear()
    this.inputTarget.focus()
  }

  #clear() {
    if (this.inputTarget.value !== "") {
      this.inputTarget.value = ""
      // A REAL input event: live-search listeners (and Turbo forms) react
      // to programmatic clearing exactly like typing.
      this.inputTarget.dispatchEvent(new Event("input", { bubbles: true }))
    }

    this.#reflect()
    this.dispatch("clear", { prefix: EVENT_PREFIX })
  }

  #reflect() {
    const empty = this.inputTarget.value === ""

    this.element.toggleAttribute("data-empty", empty)

    if (this.hasClearTarget) {
      this.clearTarget.hidden = empty || this.inputTarget.readOnly || this.inputTarget.disabled
    }
  }
}
