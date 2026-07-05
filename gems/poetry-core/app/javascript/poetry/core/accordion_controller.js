import { Controller } from "@hotwired/stimulus"
import { enterPresence, exitPresence, measurePresence } from "@poetry/controllers/helpers/presence"
import { setState, stateOf } from "@poetry/controllers/helpers/state"

// The accordion open-set machine (N2): single (optionally collapsible)
// or multiple. Composes with poetry--core--roving-focus (manageTabindex:
// false - APG keeps every trigger tabbable) attached separately on the
// same root. Panels ride the presence helper; the measured
// --accordion-panel-height var feeds the vendored accordion-down/up
// keyframes.
export default class extends Controller {
  static values = {
    type: { type: String, default: "single" },
    collapsible: { type: Boolean, default: false }
  }

  toggle(event) {
    const item = event.currentTarget.closest('[data-slot="accordion-item"]')
    if (!item) return

    if (stateOf(item) === "open") {
      if (this.typeValue === "single" && !this.collapsibleValue) return
      this.#close(item)
    } else {
      if (this.typeValue === "single") this.#openItems().forEach((other) => this.#close(other))
      this.#open(item)
    }
    this.#reflectDisabled()
    this.dispatch("change", { detail: { values: this.#openItems().map((i) => i.dataset.value) } })
  }

  connect() {
    this.#reflectDisabled()
    this.#reflectTriggers() // server-open items adopt data-panel-open on connect
  }

  // Base UI trigger parity for the server-rendered state (the #open/#close
  // paths carry it during interaction; this seeds it at connect so an
  // already-open item's trigger isn't missing data-panel-open until first
  // toggled).
  #reflectTriggers() {
    this.#items().forEach((item) => {
      const trigger = this.#triggerOf(item)
      if (trigger) setState(trigger, stateOf(item) === "open" ? "panel-open" : "panel-closed")
    })
  }

  #open(item) {
    const panel = this.#panelOf(item)
    const trigger = this.#triggerOf(item)
    setState(item, "open")
    trigger?.setAttribute("aria-expanded", "true")
    if (trigger) setState(trigger, "panel-open") // Base UI trigger parity (data-panel-open)
    if (!panel) return
    panel.hidden = false
    measurePresence(panel, { property: "--accordion-panel-height" })
    enterPresence(panel)
  }

  #close(item) {
    const panel = this.#panelOf(item)
    const trigger = this.#triggerOf(item)
    setState(item, "closed")
    trigger?.setAttribute("aria-expanded", "false")
    if (trigger) setState(trigger, "panel-closed")
    if (!panel) return
    measurePresence(panel, { property: "--accordion-panel-height" })
    exitPresence(panel, { onRemove: () => { panel.hidden = true } })
  }

  // Single non-collapsible: the open trigger is a no-op - expose that
  // to AT instead of silently ignoring the click (the contract's call).
  #reflectDisabled() {
    const lockOpen = this.typeValue === "single" && !this.collapsibleValue
    this.#items().forEach((item) => {
      const trigger = this.#triggerOf(item)
      if (!trigger) return
      if (lockOpen && stateOf(item) === "open") {
        trigger.setAttribute("aria-disabled", "true")
      } else {
        trigger.removeAttribute("aria-disabled")
      }
    })
  }

  #items() {
    return [...this.element.querySelectorAll('[data-slot="accordion-item"]')]
  }

  #openItems() {
    return this.#items().filter((item) => stateOf(item) === "open")
  }

  #triggerOf(item) {
    return item.querySelector('[data-slot="accordion-trigger"]')
  }

  #panelOf(item) {
    return item.querySelector('[data-slot="accordion-content"]')
  }
}
