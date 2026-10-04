import { Controller } from "@hotwired/stimulus"
import { useOverlay } from "@poetry/controllers/behaviors/overlay"
import { teardown } from "@poetry/controllers/helpers/scope"

const TRIGGER_SELECTOR = '[data-slot="popover-trigger"]'

const EVENT_PREFIX = "poetry:popover"

const CONTENT_LAYER_CONTROLLERS = ["poetry--core--focus-scope", "poetry--core--dismissable"]

/**
 * The Popover controller (the popper-consumer trio's click-open member):
 * the shared overlay machine with ALL item machinery deleted - no
 * typeahead, no roving, no subs, no collection. What remains is exactly
 * the APG dialog-pattern-lite: the trigger toggles a role=dialog panel,
 * focus MOVES INTO the content on open (focus-scope's mount default -
 * deliberately NOT vetoed, the contrast with the menu family's
 * data-open-reason contract) and RETURNS to the trigger on close; the
 * trap is enforced only when modal (the default is modal: FALSE - the
 * deliberate contrast with the menu family's true).
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

  #overlay = null

  /**
   * Builds the overlay machine, wires the content listeners
   * (programmatic - portal-safe) and reconciles: server-open content
   * adopts the layer stack and re-portals one frame late.
   */
  connect() {
    this.#overlay = useOverlay(this, {
      content: () => this.#content(),
      trigger: () => this.#trigger(),
      layers: CONTENT_LAYER_CONTROLLERS,
      eventPrefix: EVENT_PREFIX,
      modal: () => this.modalValue,
      activateLayers: (content) => this.#activateLayers(content),
      openDetail: () => ({})
    })
    this.#overlay.wire()
    this.#overlay.connect()
  }

  /**
   * Tears the scope down: the content listeners, a pending exit, the
   * layer tokens and portaled content (restored home, or dropped when
   * the home is gone - never stranded).
   */
  disconnect() {
    this.#overlay?.disconnect()
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
    if (!this.#overlay?.connected()) return

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

  // --- open / close: the shared machine, no reason attributes, an
  // empty open detail (the popover has no open-reason contract) ---

  #show() {
    this.#overlay.show("trigger-press")
  }

  #hide(reason) {
    this.#overlay.hide(reason)
  }

  // --- the layer stack ---

  #activateLayers(content) {
    content.setAttribute("data-poetry--core--focus-scope-trapped-value", String(this.modalValue))
    content.setAttribute(
      "data-poetry--core--dismissable-disable-outside-pointer-events-value", String(this.modalValue)
    )
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
    return this.#overlay.isOpen()
  }
}
