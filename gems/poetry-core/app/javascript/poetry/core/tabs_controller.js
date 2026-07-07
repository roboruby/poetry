import { Controller } from "@hotwired/stimulus"
import { setState } from "@poetry/controllers/helpers/state"

// The Tabs activation machine (N9 W2): this controller owns ONLY the
// active-value state + attribute writes; the shared poetry--core--roving-focus
// on the tablist owns the keyboard (default tabindex-managing mode - one Tab
// stop). Triggers are DUMB buttons (click -> tabs#activate; with automatic
// activation - the APG default for tabs - focusin activates too, so arrow
// keys both move focus AND switch panels).
//
// The Base UI vocabulary: the active trigger carries data-active
// (the styled token) + aria-selected; inactive panels carry the hidden
// property + data-hidden. data-activation-direction is deliberately NOT
// emitted - no shipped class consumes it (add it with the animated
// indicator, when something does).
//
// Panels are scoped to THIS root (a nested Tabs inside a panel owns its own
// triggers/panels - the DOM is the registry, same rule as roving-focus).
const TRIGGER_SELECTOR = '[data-slot="tabs-trigger"]'
const PANEL_SELECTOR = '[data-slot="tabs-content"]'

export default class TabsController extends Controller {
  // The events this controller dispatches (manifest surface;
  // events_declaration.test.js enforces the list stays honest).
  static events = ["poetry--core--tabs:change"]

  static values = {
    // false = manual activation (arrows only move focus; Enter/Space - the
    // native button click - activates). true is the APG-recommended default.
    activateOnFocus: { type: Boolean, default: true }
  }

  connect() {
    // Reconcile-on-connect: the server-rendered data-active trigger is the
    // truth; aria-selected/tabindex/hidden are (re)derived from it, so a
    // Turbo re-render can never leave mixed vocabularies. No data-active
    // anywhere -> the first enabled trigger becomes active.
    const active = this.#triggers().find((trigger) => trigger.hasAttribute("data-active"))
    const fallback = this.#triggers().find((trigger) => !this.#disabled(trigger))
    const value = (active ?? fallback)?.dataset.value

    if (value !== undefined) this.#apply(value, { silent: true })
  }

  // Action: click->poetry--core--tabs#activate on each trigger.
  activate(event) {
    const trigger = this.#triggerFrom(event)

    if (!trigger || this.#disabled(trigger)) return

    this.#apply(trigger.dataset.value)
  }

  // Action: poetry--core--roving-focus:entry->poetry--core--tabs#focusActivate
  // on the tablist - automatic activation follows the roving focus via the
  // roving controller's entry event (deterministic: never depends on the
  // platform firing focusin for a programmatic .focus()). A raw focusin
  // routes here too, so hand-wired hosts get the same behavior.
  focusActivate(event) {
    if (!this.activateOnFocusValue) return

    const trigger = (event.detail && event.detail.item) || this.#triggerFrom(event)

    if (!trigger || this.#disabled(trigger)) return
    if (trigger.hasAttribute("data-active")) return // already there - no re-fire

    this.#apply(trigger.dataset.value)
  }

  // The programmatic controllable-state surface: setValue("account").
  // Unknown values are ignored (the contract's guard).
  setValue(value) {
    const known = this.#triggers().some((trigger) => trigger.dataset.value === String(value))

    if (known) this.#apply(String(value))
  }

  #apply(value, { silent = false } = {}) {
    for (const trigger of this.#triggers()) {
      const active = trigger.dataset.value === value

      setState(trigger, active ? "active" : "inactive")
      trigger.setAttribute("aria-selected", active ? "true" : "false")
      // The active tab is the roving tab stop (re-entering the tablist
      // lands on the selection) - the stamp roving-focus adopts.
      trigger.setAttribute("tabindex", active ? "0" : "-1")
    }

    for (const panel of this.#panels()) {
      const active = panel.dataset.value === value

      panel.hidden = !active
      if (active) panel.removeAttribute("data-hidden")
      else panel.setAttribute("data-hidden", "")
    }

    if (!silent) this.dispatch("change", { detail: { value } })
  }

  #triggerFrom(event) {
    const origin = event.target instanceof Element ? event.target : null

    return origin?.closest(TRIGGER_SELECTOR) ?? null
  }

  #disabled(trigger) {
    return trigger.hasAttribute("disabled") || trigger.hasAttribute("data-disabled")
  }

  #triggers() {
    return [...this.element.querySelectorAll(TRIGGER_SELECTOR)].filter((el) => this.#owns(el))
  }

  #panels() {
    return [...this.element.querySelectorAll(PANEL_SELECTOR)].filter((el) => this.#owns(el))
  }

  #owns(el) {
    return el.closest(`[data-controller~="${this.identifier}"]`) === this.element
  }
}
