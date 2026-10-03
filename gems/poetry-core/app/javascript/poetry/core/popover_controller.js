import { Controller } from "@hotwired/stimulus"
import { useLayers } from "@poetry/controllers/behaviors/layers"
import { useListen } from "@poetry/controllers/behaviors/listen"
import { usePortal } from "@poetry/controllers/behaviors/portal"
import { usePresence } from "@poetry/controllers/behaviors/presence"
import { resolvePortalContainer } from "@poetry/controllers/helpers/portal"
import { teardown } from "@poetry/controllers/helpers/scope"
import { setState, stateOf } from "@poetry/controllers/helpers/state"

const TRIGGER_SELECTOR = '[data-slot="popover-trigger"]'

const EVENT_PREFIX = "poetry:popover"

const CONTENT_LAYER_CONTROLLERS = ["poetry--core--focus-scope", "poetry--core--dismissable"]
const POPPER_STRATEGY = "data-poetry--core--popper-strategy-value"

/**
 * The Popover controller (the popper-consumer trio's click-open member):
 * the menu controller's #show/#hide + token-activated layer skeleton with
 * ALL item machinery deleted - no typeahead, no roving, no subs, no
 * collection. What remains is exactly the APG dialog-pattern-lite: the
 * trigger toggles a role=dialog panel, focus MOVES INTO the content on open
 * (focus-scope's mount default - deliberately NOT vetoed, the contrast with
 * the menu family's data-open-reason contract) and RETURNS to the trigger on
 * close; the trap is enforced only when modal (the default is
 * modal: FALSE - the deliberate contrast with the menu family's true).
 *
 * STRUCTURAL RESOLUTION, no targets: the content is found via the trigger's
 * aria-controls id (portal-safe - the menu-controller pattern verbatim);
 * content-level listeners are wired programmatically in connect for the same
 * reason.
 *
 * The layer stack is ACTIVATED on open: focus-scope + dismissable are
 * appended to the content's data-controller (a statically-connected trap on
 * hidden content would steal focus at page load; a static dismissable would
 * swallow topmost-Esc), with trapped / disable-outside-pointer-events both
 * set from modal. Close reverses: presence exit -> hidden -> tokens removed
 * -> focus-scope's disconnect restores focus to the trigger (suppressed for
 * outside-press when non-modal: focus follows the click).
 */
export default class PopoverController extends Controller {
  // The events this controller dispatches (manifest surface;
  // events_declaration.test.js enforces the list stays honest).
  static events = ["poetry:popover:closed", "poetry:popover:open"]

  static values = {
    // Whether the popover is open.
    open: { type: Boolean, default: false },
    // Whether the open popover traps focus and blocks outside pointer events.
    modal: { type: Boolean, default: false }
  }

  #connected = false
  #suppressRestore = false
  #presence = null
  #portal = null
  #layers = null

  /**
   * Wires the content listeners (programmatic - portal-safe) and
   * reconciles: server-open content adopts the layer stack and re-portals
   * one frame late (the body comments hold the rules).
   */
  connect() {
    this.#presence = usePresence(this)
    this.#portal = usePortal(this)
    this.#layers = useLayers(this)

    const content = this.#content()

    if (content) this.#wireContent(content)

    this.#connected = true

    // Reconcile-on-connect: the server may own the open state (Turbo Stream
    // re-render). DOM attributes win; the layer stack catches up.
    if (this.#isOpen()) {
      if (content) {
        this.#activateLayers(content)
        this.#portalPinned(content)
      }
      this.openValue = true
    } else if (this.openValue) {
      this.#show()
    }
  }

  /**
   * Tears the scope down: the content listeners, a pending exit, the
   * layer tokens and portaled content (restored home, or dropped when
   * the home is gone - never stranded).
   */
  disconnect() {
    this.#connected = false
    teardown(this)
  }

  /**
   * Stimulus value callback - controllable state: a host (outlet / Turbo
   * Stream / URL param) may own the open value; flipping the attribute
   * drives the same machine.
   *
   * @param {boolean} value
   */
  openValueChanged(value) {
    if (!this.#connected) return

    if (value && !this.#isOpen()) this.#show()
    else if (!value && this.#isOpen()) this.#hide("none")
  }

  /**
   * The trigger's click action (native button Enter/Space arrive as
   * click - no custom keydown map, the deliberate contrast with the menu
   * trigger).
   */
  toggle() {
    if (this.#isOpen()) this.#hide("trigger-press")
    else this.#show()
  }

  // --- programmatic API (the controllable-state surface) ---

  /** Programmatically opens. */
  open() {
    this.#show()
  }

  /**
   * Programmatically closes.
   *
   * @param {string | Event} [reason="none"] - a family reason string; an
   *   Event (data-action use) reads as "none"
   */
  close(reason = "none") {
    this.#hide(reason instanceof Event ? "none" : reason)
  }

  // --- open / close ---

  #show() {
    const content = this.#content()

    if (!content || this.#isOpen()) return

    this.#presence.cancel(content)
    this.#suppressRestore = false

    const trigger = this.#trigger()

    // Portal-on-open: move BEFORE the
    // enter presence (reparenting mid-animation restarts it), re-anchor
    // absolute - static under compositor scroll, transform-immune.
    this.#portal.portal(content, { container: resolvePortalContainer(this.element) })
    this.element.setAttribute(POPPER_STRATEGY, "absolute")

    content.hidden = false
    trigger?.setAttribute("aria-expanded", "true")
    if (trigger) setState(trigger, "popup-open")
    this.#presence.enter(content)
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
    // for outside interaction on a non-modal popover (non-modal
    // semantics: focus follows the click).
    this.#suppressRestore = reason === "outside-press" && !this.modalValue

    const trigger = this.#trigger()

    trigger?.setAttribute("aria-expanded", "false")
    if (trigger) setState(trigger, "popup-closed")
    this.openValue = false

    this.#presence.exit(content, {
      onRemove: () => {
        content.hidden = true
        // Home AFTER the exit finished and hidden landed; the
        // focus-scope teardown below restores focus by element ref,
        // indifferent to where the node sits.
        this.#portal.restore(content)
        this.element.setAttribute(POPPER_STRATEGY, "fixed")
        this.#layers.deactivate(content, CONTENT_LAYER_CONTROLLERS)
        this.dispatch("closed", { prefix: EVENT_PREFIX, detail: { reason } })
      }
    })
  }

  // The reconcile path portals ONE FRAME LATE: connect order within a boot
  // is unordered, and portaling before the sibling popper's connect would
  // rob it of its content target before it could cache the node.
  #portalPinned(content) {
    window.requestAnimationFrame(() => {
      if (!this.#connected || !this.#isOpen()) return

      this.#portal.portal(content, { container: resolvePortalContainer(this.element) })
      this.element.setAttribute(POPPER_STRATEGY, "absolute")
    })
  }

  // --- content wiring (programmatic: portal-safe, no data-action required) ---

  #wireContent(content) {
    useListen(this, content, "poetry--core--dismissable:dismiss", this.#onDismiss)
    useListen(this, content, "poetry--core--dismissable:interact-outside", this.#onInteractOutside)
    useListen(this, content, "poetry--core--focus-scope:unmount-auto-focus", this.#onUnmountAutoFocus)
  }

  // A press on the popover's OWN trigger is the toggle's job, not an
  // outside dismissal: without this veto the pointerdown closes and the
  // trailing click re-opens, so the popover appears to never close on
  // trigger press (the trigger-is-not-outside rule; iOS light-dismiss
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
    this.#layers.activate(content, CONTENT_LAYER_CONTROLLERS)
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
