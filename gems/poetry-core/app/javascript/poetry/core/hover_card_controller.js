import { Controller } from "@hotwired/stimulus"
import { portalContent, resolvePortalContainer, restoreContent } from "@poetry/controllers/helpers/portal"
import { enterPresence, exitPresence } from "@poetry/controllers/helpers/presence"
import { setState, stateOf } from "@poetry/controllers/helpers/state"
import { tabbableWithin } from "@poetry/controllers/helpers/tabbable"

// The HoverCard controller (the popper-consumer trio's thinnest machine):
// pointer-only enrichment behind a LINK. Two timers (open 600 / close 300,
// Base UI PreviewCard's OPEN_DELAY/CLOSE_DELAY, over the trigger+content
// pair, re-enter cancels - the grace window, no polygon), the touch double-guard
// (pointerType 'touch' no-ops AND touchstart preventDefaults so a tap can
// never synthesize a focus-open - a tap just navigates the link), the focus
// mirror (trigger focus opens immediately / blur closes - a keyboard user
// SEES the card), the per-open TABINDEX STRIP (every tabbable inside is
// forced tabindex=-1: keyboard and touch users never reach inside,
// Radix-exact and intentional - the reachable-elsewhere rule), and the
// SELECTION HOLD (text selection started in the card keeps it open and
// suppresses body user-select while dragging, so previews are copyable).
//
// NO focus-scope anywhere in the lifecycle: focus never moves in, so there
// is nothing to trap or restore - the trio's simplest teardown. The
// token-activated dismissable delivers Esc (topmost-only) + outside press
// while open. No aria surface is added (no haspopup/expanded/describedby):
// advertising a keyboard-unreachable surface to AT is worse than silence.
const TRIGGER_SELECTOR = '[data-slot="hover-card-trigger"]'
const CONTENT_SELECTOR = '[data-slot="hover-card-content"]'

const EVENT_PREFIX = "poetry:hover-card"

const DISMISSABLE = "poetry--core--dismissable"
const POPPER_STRATEGY = "data-poetry--core--popper-strategy-value"

export default class HoverCardController extends Controller {
  // The events this controller dispatches (manifest surface;
  // events_declaration.test.js enforces the list stays honest).
  static events = ["poetry:hover-card:closed", "poetry:hover-card:open"]

  static values = {
    open: { type: Boolean, default: false },
    openDelay: { type: Number, default: 600 },
    closeDelay: { type: Number, default: 300 }
  }

  #connected = false
  #wired = []
  #openTimer = null
  #closeTimer = null
  #cancelExit = null
  #containSelection = false
  #hasSelection = false
  #previousBodyUserSelect = null
  #onPointerup = () => this.#handlePointerup()

  connect() {
    const content = this.#content()

    if (content) this.#wireContent(content)

    this.#connected = true

    // Reconcile-on-connect: a server-pinned card (open: true) activates the
    // layer + the tabindex strip; the DOM attributes win.
    if (this.#isOpen()) {
      this.#activate(content)
      this.openValue = true
    } else if (this.openValue) {
      this.#show()
    }
  }

  disconnect() {
    this.#connected = false
    this.#clearOpenTimer()
    this.#clearCloseTimer()
    this.#cancelExit?.()
    this.#cancelExit = null
    this.#restoreBodyUserSelect() // never strand suppressed selection (teardown contract)

    // Never leave content stranded at the container (drop-never-strand).
    const content = this.#content()

    if (content) restoreContent(content)

    for (const [target, type, listener] of this.#wired) target.removeEventListener(type, listener)

    this.#wired = []
    document.removeEventListener("pointerup", this.#onPointerup)
  }

  // Controllable state: pinned previews (Turbo Stream / Outlet ownership).
  openValueChanged(value) {
    if (!this.#connected) return

    if (value && !this.#isOpen()) this.#show()
    else if (!value && this.#isOpen()) this.#hide("none")
  }

  // --- trigger actions ---

  // pointerenter arms the open timer; touch pointerType is EXCLUDED
  // (Radix excludeTouch) - a tap navigates the link instead.
  pointerEnter(event) {
    if (event.pointerType === "touch") return

    this.#hasSelection = false // the next pointer cycle clears the hold
    this.#clearCloseTimer()

    if (this.#isOpen() || this.#openTimer !== null) return

    this.#openTimer = window.setTimeout(() => {
      this.#openTimer = null
      this.#show()
    }, this.openDelayValue)
  }

  pointerLeave(event) {
    if (event.pointerType === "touch") return

    this.#clearOpenTimer()

    const related = event.relatedTarget instanceof Element ? event.relatedTarget : null

    if (related && this.#content()?.contains(related)) return
    if (this.#isOpen()) this.#scheduleClose()
  }

  // Focus opens IMMEDIATELY (Radix composes onFocus straight to open) - a
  // keyboard user sees the preview even though they cannot enter it.
  focusOpen() {
    this.#clearCloseTimer()
    this.#show()
  }

  blurClose() {
    this.#clearOpenTimer()

    // Blur closes immediately - the selection hold defers only the
    // pointer-leave path. Base UI's blur-close reason: trigger-focus.
    if (this.#isOpen()) this.#hide("trigger-focus")
  }

  // The touch guard: preventDefault on touchstart so a tap can never
  // synthesize a focus event (Radix's 'prevent focus event on touch
  // devices' comment, ported). The tap still navigates the link.
  touchGuard(event) {
    event.preventDefault()
  }

  // --- open / close ---

  #show() {
    const content = this.#content()

    if (!content || this.#isOpen()) return

    this.#cancelExit?.()
    this.#cancelExit = null
    this.#clearCloseTimer()

    const trigger = this.#trigger()

    // Portal-on-open: move BEFORE the
    // enter presence (reparenting mid-animation restarts it), re-anchor
    // absolute - static under compositor scroll, transform-immune.
    portalContent(content, { container: resolvePortalContainer(this.element) })
    this.element.setAttribute(POPPER_STRATEGY, "absolute")

    content.hidden = false
    if (trigger) setState(trigger, "popup-open")
    enterPresence(content)
    this.#activateLayer(content)
    this.#stripTabbables(content)
    this.openValue = true

    queueMicrotask(() => {
      if (!this.#isOpen()) return

      this.dispatch("open", { prefix: EVENT_PREFIX, detail: {} })
    })
  }

  #hide(reason) {
    const content = this.#content()

    if (!content || !this.#isOpen()) return

    this.#clearOpenTimer()
    this.#clearCloseTimer()
    this.#hasSelection = false
    this.#restoreBodyUserSelect()

    const trigger = this.#trigger()

    if (trigger) setState(trigger, "popup-closed")
    this.openValue = false

    this.#cancelExit = exitPresence(content, {
      onRemove: () => {
        this.#cancelExit = null
        content.hidden = true
        // Home AFTER the exit finished and hidden landed (D4).
        restoreContent(content)
        this.element.setAttribute(POPPER_STRATEGY, "fixed")
        this.#removeControllers(content, [DISMISSABLE])
        this.dispatch("closed", { prefix: EVENT_PREFIX, detail: { reason } })
      }
    })
  }

  // Reconcile-on-connect for a server-pinned card: layer + strip catch up.
  #activate(content) {
    if (!content) return

    this.#activateLayer(content)
    this.#stripTabbables(content)

    // ONE FRAME LATE (the tooltip's reconcile rule): portaling before the
    // sibling popper's connect would rob it of its content target before
    // it could cache the node.
    window.requestAnimationFrame(() => {
      if (!this.#connected || !this.#isOpen()) return

      portalContent(content, { container: resolvePortalContainer(this.element) })
      this.element.setAttribute(POPPER_STRATEGY, "absolute")
    })
  }

  #activateLayer(content) {
    content.setAttribute(`data-${DISMISSABLE}-disable-outside-pointer-events-value`, "false")
    this.#addControllers(content, [DISMISSABLE])
  }

  // The tabindex strip (Radix-exact, per-open so stream-appended content
  // re-strips on the next open): the card is sighted-pointer-only BY
  // DESIGN - Tab passes straight over its contents. The shared tabbable
  // walk already skips disabled/hidden/-1 elements.
  #stripTabbables(content) {
    for (const element of tabbableWithin(content)) element.setAttribute("tabindex", "-1")
  }

  // --- the close grace (the trigger+content pair) ---

  #scheduleClose() {
    this.#clearCloseTimer()
    this.#closeTimer = window.setTimeout(() => {
      this.#closeTimer = null

      // The selection hold: while a selection made from the card exists,
      // pointer-leave does NOT close (the user is reading/copying).
      if (this.#hasSelection) return

      this.#hide("trigger-hover")
    }, this.closeDelayValue)
  }

  #clearOpenTimer() {
    if (this.#openTimer === null) return

    window.clearTimeout(this.#openTimer)
    this.#openTimer = null
  }

  #clearCloseTimer() {
    if (this.#closeTimer === null) return

    window.clearTimeout(this.#closeTimer)
    this.#closeTimer = null
  }

  // --- content wiring (programmatic: portal-safe) ---

  #wireContent(content) {
    this.#listen(content, "pointerenter", (event) => {
      if (event.pointerType === "touch") return

      this.#clearCloseTimer()
    })
    this.#listen(content, "pointerleave", (event) => {
      if (event.pointerType === "touch") return

      const related = event.relatedTarget instanceof Element ? event.relatedTarget : null

      if (related && (this.#trigger()?.contains(related) || content.contains(related))) return
      if (this.#isOpen()) this.#scheduleClose()
    })
    this.#listen(content, "pointerdown", (event) => this.#handleContentPointerdown(event))
    this.#listen(content, `${DISMISSABLE}:dismiss`, this.#onDismiss)
  }

  #listen(target, type, listener) {
    target.addEventListener(type, listener)
    this.#wired.push([target, type, listener])
  }

  // Esc (topmost-only) + pointerdown-outside arrive as the dismissable's
  // dismiss event. Esc/outside ALWAYS close - the selection hold defers
  // only the pointer-leave path. Focus never moved in, so there is nothing
  // to restore.
  #onDismiss = (event) => {
    if (event.target !== this.#content()) return

    const escaped = event.detail?.originalEvent?.type === "keydown"

    this.#hide(escaped ? "escape-key" : "outside-press")
  }

  // --- the selection hold (Radix's containSelection/hasSelection, ported) ---

  // pointerdown ON the content: suppress body user-select (webkit prefix
  // included) so the drag selects only card text; pointerup restores it
  // and, one frame later, records whether a selection exists.
  #handleContentPointerdown(event) {
    if (event.pointerType === "touch") return

    this.#containSelection = true
    this.#suppressBodyUserSelect()
    document.addEventListener("pointerup", this.#onPointerup, { once: true })
  }

  #handlePointerup() {
    if (!this.#containSelection) return

    this.#containSelection = false
    this.#restoreBodyUserSelect()

    window.setTimeout(() => {
      this.#hasSelection = (document.getSelection()?.toString() ?? "") !== ""
    }, 0)
  }

  #suppressBodyUserSelect() {
    if (this.#previousBodyUserSelect !== null) return

    const { body } = document

    this.#previousBodyUserSelect = {
      userSelect: body.style.userSelect ?? "",
      webkitUserSelect: body.style.webkitUserSelect ?? ""
    }
    body.style.userSelect = "none"
    body.style.webkitUserSelect = "none"
  }

  #restoreBodyUserSelect() {
    if (this.#previousBodyUserSelect === null) return

    const { body } = document

    body.style.userSelect = this.#previousBodyUserSelect.userSelect
    body.style.webkitUserSelect = this.#previousBodyUserSelect.webkitUserSelect
    this.#previousBodyUserSelect = null
    this.#containSelection = false
  }

  // --- structural resolution (the server id pair, portal-safe) ---

  #trigger() {
    return this.element.querySelector(TRIGGER_SELECTOR)
  }

  #content() {
    const triggerId = this.#trigger()?.id

    if (triggerId?.endsWith("-trigger")) {
      const byId = document.getElementById(triggerId.replace(/-trigger$/, "-content"))

      if (byId) return byId
    }

    return this.element.querySelector(CONTENT_SELECTOR)
  }

  #isOpen() {
    const content = this.#content()

    return Boolean(content) && stateOf(content) === "open"
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
}
