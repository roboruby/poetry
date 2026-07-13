import { Controller } from "@hotwired/stimulus"
import { enterPresence, exitPresence } from "@poetry/controllers/helpers/presence"
import { setState, stateOf } from "@poetry/controllers/helpers/state"

// The Popover controller (the popper-consumer trio's click-open member):
// the menu controller's #show/#hide + token-activated layer skeleton with
// ALL item machinery deleted - no typeahead, no roving, no subs, no
// collection. What remains is exactly the APG dialog-pattern-lite: the
// trigger toggles a role=dialog panel, focus MOVES INTO the content on open
// (focus-scope's mount default - deliberately NOT vetoed, the contrast with
// the menu family's data-open-reason contract) and RETURNS to the trigger on
// close; the trap is enforced only when modal (Radix Popover defaults
// modal: FALSE - the deliberate contrast with the menu family's true).
//
// STRUCTURAL RESOLUTION, no targets: the content is found via the trigger's
// aria-controls id (portal-safe - the menu-controller pattern verbatim);
// content-level listeners are wired programmatically in connect for the same
// reason.
//
// The layer stack is ACTIVATED on open: focus-scope + dismissable are
// appended to the content's data-controller (a statically-connected trap on
// hidden content would steal focus at page load; a static dismissable would
// swallow topmost-Esc), with trapped / disable-outside-pointer-events both
// set from modal. Close reverses: presence exit -> hidden -> tokens removed
// -> focus-scope's disconnect restores focus to the trigger (suppressed for
// outside-press when non-modal: focus follows the click, Radix semantics).
const TRIGGER_SELECTOR = '[data-slot="popover-trigger"]'

const EVENT_PREFIX = "poetry:popover"

const CONTENT_LAYER_CONTROLLERS = ["poetry--core--focus-scope", "poetry--core--dismissable"]

export default class PopoverController extends Controller {
  // The events this controller dispatches (manifest surface;
  // events_declaration.test.js enforces the list stays honest).
  static events = ["poetry:popover:closed", "poetry:popover:open"]

  static values = {
    open: { type: Boolean, default: false },
    modal: { type: Boolean, default: false }
  }

  #connected = false
  #wired = []
  #suppressRestore = false
  #cancelExit = null

  connect() {
    const content = this.#content()

    if (content) this.#wireContent(content)

    this.#connected = true

    // Reconcile-on-connect: the server may own the open state (Turbo Stream
    // re-render). DOM attributes win; the layer stack catches up.
    if (this.#isOpen()) {
      if (content) this.#activateLayers(content)
      this.openValue = true
    } else if (this.openValue) {
      this.#show()
    }
  }

  disconnect() {
    this.#connected = false

    for (const [target, type, listener] of this.#wired) target.removeEventListener(type, listener)

    this.#wired = []
    this.#cancelExit?.()
    this.#cancelExit = null
  }

  // Controllable state: a host (outlet / Turbo Stream / URL param) may own
  // the open value; flipping the attribute drives the same machine.
  openValueChanged(value) {
    if (!this.#connected) return

    if (value && !this.#isOpen()) this.#show()
    else if (!value && this.#isOpen()) this.#hide("none")
  }

  // --- trigger action (native button Enter/Space arrive as click - no
  //     custom keydown map, the deliberate contrast with the menu trigger) ---

  toggle() {
    if (this.#isOpen()) this.#hide("trigger-press")
    else this.#show()
  }

  // --- programmatic API (the controllable-state surface) ---

  open() {
    this.#show()
  }

  close(reason = "none") {
    this.#hide(reason instanceof Event ? "none" : reason)
  }

  // --- open / close ---

  #show() {
    const content = this.#content()

    if (!content || this.#isOpen()) return

    this.#cancelExit?.()
    this.#cancelExit = null
    this.#suppressRestore = false

    const trigger = this.#trigger()

    content.hidden = false
    trigger?.setAttribute("aria-expanded", "true")
    if (trigger) setState(trigger, "popup-open")
    enterPresence(content)
    this.#activateLayers(content)
    this.openValue = true

    // The layer controllers connect on the attribute-mutation microtask;
    // focus-scope's mount-auto-focus (first tabbable, else the content) is
    // NOT vetoed here - the dialog pattern. The open event rides one
    // microtask behind so it fires after initial focus applied.
    queueMicrotask(() => {
      if (!this.#isOpen()) return

      this.dispatch("open", { prefix: EVENT_PREFIX, detail: {} })
    })
  }

  #hide(reason) {
    const content = this.#content()

    if (!content || !this.#isOpen()) return

    // Focus return to the trigger is focus-scope's disconnect job - vetoed
    // for outside interaction on a non-modal popover (Radix's non-modal
    // semantics: focus follows the click).
    this.#suppressRestore = reason === "outside-press" && !this.modalValue

    const trigger = this.#trigger()

    trigger?.setAttribute("aria-expanded", "false")
    if (trigger) setState(trigger, "popup-closed")
    this.openValue = false

    this.#cancelExit = exitPresence(content, {
      onRemove: () => {
        this.#cancelExit = null
        content.hidden = true
        this.#removeControllers(content, CONTENT_LAYER_CONTROLLERS)
        this.dispatch("closed", { prefix: EVENT_PREFIX, detail: { reason } })
      }
    })
  }

  // --- content wiring (programmatic: portal-safe, no data-action required) ---

  #wireContent(content) {
    this.#listen(content, "poetry--core--dismissable:dismiss", this.#onDismiss)
    this.#listen(content, "poetry--core--dismissable:interact-outside", this.#onInteractOutside)
    this.#listen(content, "poetry--core--focus-scope:unmount-auto-focus", this.#onUnmountAutoFocus)
  }

  #listen(target, type, listener) {
    target.addEventListener(type, listener)
    this.#wired.push([target, type, listener])
  }

  // A press on the popover's OWN trigger is the toggle's job, not an
  // outside dismissal: without this veto the pointerdown closes and the
  // trailing click re-opens, so the popover appears to never close on
  // trigger press (Radix's targetIsTrigger rule; iOS light-dismiss
  // double-fires arrive through the same seam and are covered by it).
  #onInteractOutside = (event) => {
    if (event.target !== this.#content()) return

    const origin = event.detail?.originalEvent?.target

    if (origin instanceof Element && this.#trigger()?.contains(origin)) event.preventDefault()
  }

  // Esc / outside-press arrive as the dismissable layer's dismiss event
  // (topmost-only via the class-level stack).
  #onDismiss = (event) => {
    if (event.target !== this.#content()) return

    const escaped = event.detail?.originalEvent?.type === "keydown"

    this.#hide(escaped ? "escape-key" : "outside-press")
  }

  #onUnmountAutoFocus = (event) => {
    if (event.target === this.#content() && this.#suppressRestore) event.preventDefault()
  }

  // --- the layer stack ---

  #activateLayers(content) {
    content.setAttribute("data-poetry--core--focus-scope-trapped-value", String(this.modalValue))
    content.setAttribute(
      "data-poetry--core--dismissable-disable-outside-pointer-events-value", String(this.modalValue)
    )
    this.#addControllers(content, CONTENT_LAYER_CONTROLLERS)
  }

  #addControllers(element, identifiers) {
    const tokens = (element.getAttribute("data-controller") ?? "").split(/\s+/).filter(Boolean)

    for (const identifier of identifiers) {
      if (!tokens.includes(identifier)) tokens.push(identifier)
    }

    element.setAttribute("data-controller", tokens.join(" "))
  }

  #removeControllers(element, identifiers) {
    const tokens = (element.getAttribute("data-controller") ?? "")
      .split(/\s+/)
      .filter((token) => token && !identifiers.includes(token))

    element.setAttribute("data-controller", tokens.join(" "))
  }

  // --- structural resolution (the DOM is the registry; ids are the seams) ---

  #trigger() {
    return this.element.querySelector(TRIGGER_SELECTOR)
  }

  #content() {
    const id = this.#trigger()?.getAttribute("aria-controls")

    return id ? document.getElementById(id) : null
  }

  #isOpen() {
    const content = this.#content()

    return Boolean(content) && stateOf(content) === "open"
  }
}
