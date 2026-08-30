import { Controller } from "@hotwired/stimulus"
import { setState, stateOf } from "@poetry/controllers/helpers/state"

// The toggle family's checked-state owner (Checkbox introduces it; Switch
// reuses it VERBATIM - zero fork, CI-asserted). The architecture is the
// STORE INVERSION: the hidden native <input type=checkbox> is the form
// participant AND the store - the visual button[role=checkbox|switch] only
// REFLECTS it (aria-checked incl. "mixed" + the data-checked/data-unchecked/
// data-indeterminate attributes on the control and every part that carries
// them: the checkbox indicator, the switch thumb). Every transition writes the input FIRST, dispatches a REAL
// bubbling change event (no synthetic prototype-setter dance - Radix's
// BubbleInput direction inverted), then reflects attributes.
//
// The three states: checked / unchecked / indeterminate. Indeterminate is
// server/programmatic only (aria-checked=mixed, input.indeterminate - a
// JS-only property re-derived from the checked attributes on connect); the first user
// toggle resolves it to CHECKED (Radix-exact). A Switch never renders it
// (ArgumentError upstream), so that branch is simply dormant there.
//
// Enter is suppressed on role=checkbox ONLY (WAI-ARIA: checkboxes activate
// on Space alone - Radix's onKeyDown guard); role=switch has no keydown
// handler, so Enter toggles via the native button click (Radix-exact
// asymmetry, keyed off the role - no controller fork).
//
// No inputId value -> pure visual mode: state lives on the button's
// checked attributes alone (controlled-UI cases like DataTable row selection).
// The component-flavored prefixes the dynamic dispatch below emits under
// (data-component on the host: checkbox / switch, with the bare fallback) -
// the events declaration, the portal bridge, and the manifest enumerate
// these REAL names; the identifier-default name never fires here.
const EVENT_PREFIXES = ["poetry:checkbox", "poetry:switch", "poetry:checked"]

export default class CheckedController extends Controller {
  // The events this controller dispatches (manifest surface;
  // events_declaration.test.js enforces the list stays honest).
  static events = EVENT_PREFIXES.map((prefix) => `${prefix}:change`)

  static values = {
    inputId: { type: String, default: "" }
  }

  #keydown = null
  #reset = null
  #form = null
  #initialIndeterminate = false

  /**
   * Reconcile-on-connect: derives input.checked/indeterminate from the
   * checked attributes (the server truth), arms the form-reset restore,
   * and installs the role-keyed Enter suppression.
   */
  connect() {
    const input = this.#input()

    // Reconcile-on-connect: the checked attributes are the server truth
    // (Turbo Stream re-render safe); input.indeterminate has no attribute -
    // derive it.
    if (input) {
      const state = this.#state()

      this.#initialIndeterminate = state === "indeterminate"
      input.checked = state === "checked"
      input.indeterminate = this.#initialIndeterminate

      // Native form reset restores the server-rendered checked attribute -
      // initial-state restore for free (vs Radix's manual ref); rAF because
      // reset fires BEFORE the browser restores input values.
      this.#form = input.form

      if (this.#form) {
        this.#reset = () => window.requestAnimationFrame(() => {
          input.indeterminate = this.#initialIndeterminate
          this.#reflect(input.indeterminate ? "indeterminate" : (input.checked ? "checked" : "unchecked"))
        })
        this.#form.addEventListener("reset", this.#reset)
      }
    }

    // WAI-ARIA: a checkbox does not activate on Enter (Space only - the
    // form's Enter-to-submit is unaffected). Keyed off the role so the
    // Switch reuse keeps its native Enter-toggles behavior.
    if (this.element.getAttribute("role") === "checkbox") {
      this.#keydown = (event) => {
        if (event.key === "Enter") event.preventDefault()
      }
      this.element.addEventListener("keydown", this.#keydown)
    }
  }

  /** Unwires the keydown and form-reset listeners. */
  disconnect() {
    if (this.#keydown) this.element.removeEventListener("keydown", this.#keydown)
    if (this.#reset && this.#form) this.#form.removeEventListener("reset", this.#reset)

    this.#keydown = null
    this.#reset = null
    this.#form = null
  }

  /**
   * Control activation (click / Space / label-for): indeterminate
   * resolves to checked (Radix-exact), else flip.
   */
  toggle() {
    if (this.#disabled()) return

    const state = this.#state()
    const wasIndeterminate = state === "indeterminate"

    this.#commit(wasIndeterminate ? true : state !== "checked", { wasIndeterminate })
  }

  // --- the programmatic controllable-state surface ---

  /** Programmatically checks (see set). */
  check() {
    this.set(true)
  }

  /** Programmatically unchecks (see set). */
  uncheck() {
    this.set(false)
  }

  /**
   * The programmatic controllable-state surface: set(true | false |
   * "indeterminate") reaches all three states (the select-all recipe -
   * checkbox_group_controller - re-enters indeterminate this way).
   *
   * @param {boolean | "indeterminate"} state
   */
  set(state) {
    if (this.#disabled()) return

    if (state === "indeterminate") this.#commitIndeterminate()
    else this.#commit(Boolean(state), { wasIndeterminate: this.#state() === "indeterminate" })
  }

  // --- the one write path: input first, real change event, then reflect ---

  #commit(checked, { wasIndeterminate = false } = {}) {
    const input = this.#input()

    if (input) {
      input.indeterminate = false
      input.checked = checked
      input.dispatchEvent(new Event("change", { bubbles: true }))
    }

    this.#reflect(checked ? "checked" : "unchecked")

    // The component-flavored observe surface (poetry:checkbox:change /
    // poetry:switch:change) without forking the shared controller: the
    // prefix derives from the host's data-component self-id.
    this.dispatch("change", {
      prefix: `poetry:${this.element.dataset.component ?? "checked"}`,
      detail: { checked, was_indeterminate: wasIndeterminate }
    })
  }

  #commitIndeterminate() {
    const input = this.#input()

    if (input) {
      input.checked = false
      input.indeterminate = true
      input.dispatchEvent(new Event("change", { bubbles: true }))
    }

    this.#reflect("indeterminate")
    this.dispatch("change", {
      prefix: `poetry:${this.element.dataset.component ?? "checked"}`,
      detail: { checked: false, was_indeterminate: false, indeterminate: true }
    })
  }

  // aria-checked (mixed mapping) and the checked attributes are written
  // TOGETHER, on the control AND every part that mirrors the checked state
  // (indicator / thumb) - recognized by wearing any of the family's pair
  // attributes (data-checked / data-unchecked / data-indeterminate).
  #reflect(state) {
    this.element.setAttribute("aria-checked", state === "indeterminate" ? "mixed" : String(state === "checked"))
    setState(this.element, state)

    const parts = this.element.querySelectorAll("[data-checked], [data-unchecked], [data-indeterminate]")

    for (const part of parts) setState(part, state)
  }

  #state() {
    const state = stateOf(this.element)

    if (state) return state

    const aria = this.element.getAttribute("aria-checked")

    return aria === "mixed" ? "indeterminate" : (aria === "true" ? "checked" : "unchecked")
  }

  #input() {
    return this.inputIdValue ? document.getElementById(this.inputIdValue) : null
  }

  #disabled() {
    return this.element.hasAttribute("disabled") || this.element.getAttribute("aria-disabled") === "true"
  }
}
