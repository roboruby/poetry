import { Controller } from "@hotwired/stimulus"
import { portalContent, resolvePortalContainer, restoreContent } from "@poetry/controllers/helpers/portal"
import { exitPresence } from "@poetry/controllers/helpers/presence"
import { setState, stateOf } from "@poetry/controllers/helpers/state"

// The Tooltip controller (the popper-consumer trio's timing machine): open
// DELAYS (provider delay_duration, shadcn default 0), the provider-scoped
// WARM grace (one tooltip open - or closed less than skip_delay_duration ms
// ago - lets siblings in the same provider scope open instantly), ONE OPEN
// GLOBALLY (the document-level will-open event, Radix's tooltip.open port),
// close-on-scroll, and the pointer-vs-focus open paths with their latches.
//
// A11y is the strictest of the trio: the content is role=tooltip and the
// trigger's aria-describedby is set on open and REMOVED on close
// (describedby must never reference hidden content); focus-scope is NOT
// composed at all - focus never enters a tooltip; touch NEVER opens one
// (no long-press path, Radix-exact). Esc rides a token-activated
// dismissable layer while open, so a tooltip above a Dialog peels first.
//
// THE WARM REGISTRY (the provider mechanism): a module-level WeakMap keyed
// by the [data-slot=tooltip-provider] ancestor (document fallback) holding
// {openCount, warmUntil}. The DOM ancestor IS Radix's React context; the
// WeakMap lets morphed/replaced providers garbage-collect (no Turbo leaks).
const PROVIDER_SELECTOR = '[data-slot="tooltip-provider"]'
const CONTENT_SELECTOR = '[data-slot="tooltip-content"]'
const TRIGGER_SELECTOR = '[data-slot="tooltip-trigger"]'

const EVENT_PREFIX = "poetry:tooltip"
const WILL_OPEN_EVENT = "poetry:tooltip:will-open"

const DISMISSABLE = "poetry--core--dismissable"
const POPPER_STRATEGY = "data-poetry--core--popper-strategy-value"

// Provider defaults: delayDuration 0 is the shadcn provider override of
// Radix's 700 (kept, source-exact); skipDelayDuration 300 is Radix's.
const DEFAULT_DELAY_DURATION = 0
const DEFAULT_SKIP_DELAY_DURATION = 300

// Hoverable-content grace: the close-intent timer (entering the content
// cancels it) - the DropdownMenu grace-area reconciliation applied
// trio-wide; Radix's pointer-transit polygon is the shared fast-follow.
const HOVERABLE_CLOSE_DELAY = 300

// scope element -> { openCount, warmUntil } (module-level, shared by every
// tooltip instance; WeakMap so detached providers garbage-collect).
const warmScopes = new WeakMap()

const scopeFor = (element) => {
  if (!warmScopes.has(element)) warmScopes.set(element, { openCount: 0, warmUntil: 0 })

  return warmScopes.get(element)
}

export default class TooltipController extends Controller {
  // The events this controller dispatches (manifest surface;
  // events_declaration.test.js enforces the list stays honest).
  static events = ["poetry:tooltip:closed", "poetry:tooltip:open"]

  static values = {
    open: { type: Boolean, default: false },
    delayDuration: { type: Number, default: -1 }, // -1 = inherit the provider (default 0)
    disableHoverableContent: { type: Boolean, default: false } // unset = inherit the provider
  }

  #connected = false
  #wired = []
  #openTimer = null
  #closeTimer = null
  #cancelExit = null
  #hasPointerMoveOpened = false
  #isPointerDown = false
  #emittingWillOpen = false
  #scrollListening = false
  #onScroll = (event) => this.#handleScroll(event)
  #onWillOpen = (event) => this.#handleWillOpen(event)
  #onPointerup = () => { this.#isPointerDown = false }

  connect() {
    const content = this.#content()

    if (content) this.#wireContent(content)

    this.#listen(document, WILL_OPEN_EVENT, this.#onWillOpen)

    this.#connected = true

    // Reconcile-on-connect: a server-rendered pinned tooltip (data-open on
    // the content) activates describedby + the layer + the scope count.
    if (this.#isOpen()) {
      this.#activate(content)
      this.openValue = true
    } else if (this.openValue) {
      this.#open({ instant: "delay" })
    }
  }

  disconnect() {
    this.#connected = false
    this.#clearOpenTimer()
    this.#clearCloseTimer()
    this.#cancelExit?.()
    this.#cancelExit = null

    // An open tooltip disconnecting must not strand the scope count.
    if (this.#isOpen()) {
      const scope = this.#scope()

      scope.openCount = Math.max(0, scope.openCount - 1)
      scope.warmUntil = Date.now() + this.#skipDelayDuration()
    }

    this.#dropScrollListener()

    // Never leave content stranded at the container: if the root subtree
    // was removed the placeholder is gone and restore DROPS the node.
    const content = this.#content()

    if (content) restoreContent(content)

    for (const [target, type, listener] of this.#wired) target.removeEventListener(type, listener)

    this.#wired = []
    document.removeEventListener("pointerup", this.#onPointerup)
  }

  // Controllable state: pinned tooltips (Turbo Stream / Outlet ownership).
  openValueChanged(value) {
    if (!this.#connected) return

    if (value && !this.#isOpen()) this.#open({ instant: "delay" })
    else if (!value && this.#isOpen()) this.#close("none")
  }

  // --- trigger actions: the pointer path (Radix's handlers, ported) ---

  // pointermove, not pointerenter (Radix): opens once per hover via the
  // hasPointerMoveOpened latch; touch pointerType is EXCLUDED entirely.
  pointerMove(event) {
    if (event.pointerType === "touch") return

    this.#clearCloseTimer() // re-entering the trigger cancels a close intent

    if (this.#hasPointerMoveOpened || this.#isOpen() || this.#openTimer !== null) return
    if (this.#isPointerDown) return

    if (this.#isWarm()) {
      this.#hasPointerMoveOpened = true
      this.#open({ instant: "delay" })
      return
    }

    const delay = this.#delayDuration()

    if (delay <= 0) {
      this.#hasPointerMoveOpened = true
      this.#open()
      return
    }

    this.#openTimer = window.setTimeout(() => {
      this.#openTimer = null
      this.#hasPointerMoveOpened = true
      this.#open()
    }, delay)
  }

  pointerLeave(event) {
    if (event?.pointerType === "touch") return

    this.#clearOpenTimer()
    this.#hasPointerMoveOpened = false

    if (!this.#isOpen()) return

    // Traveling into hoverable content gets the close-intent grace; with
    // hoverable content disabled the tooltip closes with the trigger leave.
    if (this.#hoverableContentDisabled()) this.#close("trigger-hover")
    else this.#scheduleClose()
  }

  // Activating the control dismisses its hint; the pointerdown latch also
  // suppresses the focus-open until pointerup (pointer users never get a
  // focus-opened tooltip - Radix-exact).
  pointerDown() {
    this.#isPointerDown = true
    document.addEventListener("pointerup", this.#onPointerup, { once: true })
    this.#clearOpenTimer()

    if (this.#isOpen()) this.#close("trigger-press")
  }

  clickClose() {
    this.#clearOpenTimer()

    if (this.#isOpen()) this.#close("trigger-press")
  }

  // --- trigger actions: the keyboard path ---

  // Focus opens INSTANTLY (skipping all delays) - unless the focus was
  // caused by a pointerdown (the isPointerDown latch).
  focusOpen() {
    if (this.#isPointerDown) return
    if (this.#isOpen()) return

    this.#open({ instant: "focus" })
  }

  blurClose() {
    this.#clearOpenTimer()

    // Base UI's blur-close reason: trigger-focus (the focus interaction).
    if (this.#isOpen()) this.#close("trigger-focus")
  }

  // --- open / close ---

  // instant: null (a delayed pointer open) | "delay" (warm registry /
  // programmatic - the provider delay was skipped) | "focus" (keyboard) -
  // the Base UI data-instant reason vocabulary (contract §2).
  #open({ instant = null } = {}) {
    const content = this.#content()

    if (!content || this.#isOpen()) return

    this.#cancelExit?.()
    this.#cancelExit = null
    this.#clearCloseTimer()

    // One tooltip page-wide: every other open tooltip hears this and closes
    // (reason: superseded). Dispatched BEFORE this one opens.
    this.#emittingWillOpen = true
    document.dispatchEvent(new CustomEvent(WILL_OPEN_EVENT, { detail: {} }))
    this.#emittingWillOpen = false

    this.#scope().openCount += 1

    // Portal-on-open (docs/portal-on-open.md D1/D3): move BEFORE any
    // visual state lands (reparenting later would restart the enter
    // animation), then re-anchor absolute - static under compositor
    // scroll, transformed-ancestor immune. The strategy attribute write
    // re-arms popper's autoUpdate against the new ancestors.
    portalContent(content, { container: resolvePortalContainer(this.element) })
    this.element.setAttribute(POPPER_STRATEGY, "absolute")

    const trigger = this.#trigger()

    content.hidden = false
    if (trigger) {
      setState(trigger, "popup-open")
      trigger.setAttribute("aria-describedby", content.id)
    }
    // The Radix triple becomes the pair + a reason: data-open via setState,
    // plus data-instant="delay|focus" on the content when the open skipped
    // the delay (absent on a delayed open) - Base UI vocabulary/N6.
    setState(content, "open")
    if (instant) content.setAttribute("data-instant", instant)
    else content.removeAttribute("data-instant")

    // Token-activated dismissable only - NO focus-scope, focus never enters
    // a tooltip. Esc anywhere peels the tooltip first (topmost layer).
    content.setAttribute(`data-${DISMISSABLE}-disable-outside-pointer-events-value`, "false")
    this.#addControllers(content, [DISMISSABLE])
    this.#armScrollListener()
    this.openValue = true

    queueMicrotask(() => {
      if (!this.#isOpen()) return

      this.dispatch("open", { prefix: EVENT_PREFIX, detail: { state: "open", instant } })
    })
  }

  #close(reason) {
    const content = this.#content()

    if (!content || !this.#isOpen()) return

    this.#clearOpenTimer()
    this.#clearCloseTimer()
    this.#hasPointerMoveOpened = false

    const scope = this.#scope()

    scope.openCount = Math.max(0, scope.openCount - 1)
    scope.warmUntil = Date.now() + this.#skipDelayDuration()

    const trigger = this.#trigger()

    if (trigger) setState(trigger, "popup-closed")
    content.removeAttribute("data-instant")
    this.openValue = false

    this.#cancelExit = exitPresence(content, {
      onRemove: () => {
        this.#cancelExit = null
        content.hidden = true
        // Home AFTER the exit finished and hidden landed - never
        // mid-animation, never a visible flash (D4).
        restoreContent(content)
        this.element.setAttribute(POPPER_STRATEGY, "fixed")
        trigger?.removeAttribute("aria-describedby")
        this.#removeControllers(content, [DISMISSABLE])
        this.#dropScrollListener()
        this.dispatch("closed", { prefix: EVENT_PREFIX, detail: { reason } })
      }
    })
  }

  // Reconcile-on-connect for a server-rendered open tooltip: the DOM already
  // says open; describedby, the layer, the scroll listener and the scope
  // count catch up without re-running the open path.
  #activate(content) {
    if (!content) return

    const trigger = this.#trigger()

    if (trigger && content.id) trigger.setAttribute("aria-describedby", content.id)

    content.setAttribute(`data-${DISMISSABLE}-disable-outside-pointer-events-value`, "false")
    this.#addControllers(content, [DISMISSABLE])
    this.#armScrollListener()
    this.#scope().openCount += 1
    this.#portalPinned(content)
  }

  // The reconcile path portals ONE FRAME LATE: connect order within a boot
  // is unordered, and portaling before the sibling popper's connect would
  // rob it of its content target before it could cache the node.
  #portalPinned(content) {
    window.requestAnimationFrame(() => {
      if (!this.#connected || !this.#isOpen()) return

      portalContent(content, { container: resolvePortalContainer(this.element) })
      this.element.setAttribute(POPPER_STRATEGY, "absolute")
    })
  }

  // --- the close-intent grace (hoverable content) ---

  #scheduleClose() {
    this.#clearCloseTimer()
    this.#closeTimer = window.setTimeout(() => {
      this.#closeTimer = null
      this.#close("trigger-hover")
    }, HOVERABLE_CLOSE_DELAY)
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
    this.#listen(content, "pointerenter", () => this.#clearCloseTimer())
    this.#listen(content, "pointerleave", () => {
      if (this.#isOpen()) this.#scheduleClose()
    })
    this.#listen(content, `${DISMISSABLE}:dismiss`, this.#onDismiss)
  }

  #listen(target, type, listener) {
    target.addEventListener(type, listener)
    this.#wired.push([target, type, listener])
  }

  #onDismiss = (event) => {
    if (event.target !== this.#content()) return

    const escaped = event.detail?.originalEvent?.type === "keydown"

    // The outside-press close the dismissable brings along matches tooltip
    // UX anyway (contract note); it reports as "outside-press".
    this.#close(escaped ? "escape-key" : "outside-press")
  }

  // Another tooltip is about to open: one open page-wide.
  #handleWillOpen(event) {
    if (this.#emittingWillOpen) return
    if (event.target === this.element) return

    this.#clearOpenTimer()

    // A sibling tooltip opening closes this one (Base UI: sibling-open).
    if (this.#isOpen()) this.#close("sibling-open")
  }

  // --- close-on-scroll (capture-phase, armed only while open - Radix-exact) ---

  #armScrollListener() {
    if (this.#scrollListening) return

    window.addEventListener("scroll", this.#onScroll, { capture: true })
    this.#scrollListening = true
  }

  #dropScrollListener() {
    if (!this.#scrollListening) return

    window.removeEventListener("scroll", this.#onScroll, { capture: true })
    this.#scrollListening = false
  }

  #handleScroll(event) {
    const trigger = this.#trigger()
    const target = event.target

    if (!trigger || !target || typeof target.contains !== "function") return
    if (target.contains(trigger)) this.#close("scroll")
  }

  // --- the warm scope (the provider mechanism) ---

  #provider() {
    return this.element.closest(PROVIDER_SELECTOR)
  }

  #scope() {
    return scopeFor(this.#provider() ?? document)
  }

  #isWarm() {
    const scope = this.#scope()

    return scope.openCount > 0 || Date.now() < scope.warmUntil
  }

  #providerNumber(attribute, fallback) {
    const raw = this.#provider()?.getAttribute(attribute)
    const parsed = raw === null || raw === undefined || raw === "" ? NaN : Number(raw)

    return Number.isNaN(parsed) ? fallback : parsed
  }

  #delayDuration() {
    if (this.delayDurationValue >= 0) return this.delayDurationValue

    return this.#providerNumber("data-delay-duration", DEFAULT_DELAY_DURATION)
  }

  #skipDelayDuration() {
    return this.#providerNumber("data-skip-delay-duration", DEFAULT_SKIP_DELAY_DURATION)
  }

  #hoverableContentDisabled() {
    // Attribute presence, not hasDisableHoverableContentValue: an unset
    // per-tooltip value INHERITS the provider setting.
    const attribute = "data-poetry--core--tooltip-disable-hoverable-content-value"

    if (this.element.hasAttribute(attribute)) return this.disableHoverableContentValue

    return this.#provider()?.getAttribute("data-disable-hoverable-content") === "true"
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
    const state = content ? stateOf(content) : undefined

    return Boolean(state) && state !== "closed"
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
