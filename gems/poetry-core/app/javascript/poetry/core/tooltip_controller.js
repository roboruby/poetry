import { Controller } from "@hotwired/stimulus"
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

    // Reconcile-on-connect: a server-rendered pinned tooltip (any non-closed
    // data-state) activates describedby + the layer + the scope count.
    if (this.#isOpen()) {
      this.#activate(content)
      this.openValue = true
    } else if (this.openValue) {
      this.#open("instant-open")
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

    for (const [target, type, listener] of this.#wired) target.removeEventListener(type, listener)

    this.#wired = []
    document.removeEventListener("pointerup", this.#onPointerup)
  }

  // Controllable state: pinned tooltips (Turbo Stream / Outlet ownership).
  openValueChanged(value) {
    if (!this.#connected) return

    if (value && !this.#isOpen()) this.#open("instant-open")
    else if (!value && this.#isOpen()) this.#close("programmatic")
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
      this.#open("instant-open")
      return
    }

    const delay = this.#delayDuration()

    if (delay <= 0) {
      this.#hasPointerMoveOpened = true
      this.#open("delayed-open")
      return
    }

    this.#openTimer = window.setTimeout(() => {
      this.#openTimer = null
      this.#hasPointerMoveOpened = true
      this.#open("delayed-open")
    }, delay)
  }

  pointerLeave(event) {
    if (event?.pointerType === "touch") return

    this.#clearOpenTimer()
    this.#hasPointerMoveOpened = false

    if (!this.#isOpen()) return

    // Traveling into hoverable content gets the close-intent grace; with
    // hoverable content disabled the tooltip closes with the trigger leave.
    if (this.#hoverableContentDisabled()) this.#close("leave")
    else this.#scheduleClose()
  }

  // Activating the control dismisses its hint; the pointerdown latch also
  // suppresses the focus-open until pointerup (pointer users never get a
  // focus-opened tooltip - Radix-exact).
  pointerDown() {
    this.#isPointerDown = true
    document.addEventListener("pointerup", this.#onPointerup, { once: true })
    this.#clearOpenTimer()

    if (this.#isOpen()) this.#close("activate")
  }

  clickClose() {
    this.#clearOpenTimer()

    if (this.#isOpen()) this.#close("activate")
  }

  // --- trigger actions: the keyboard path ---

  // Focus opens INSTANTLY (skipping all delays) - unless the focus was
  // caused by a pointerdown (the isPointerDown latch).
  focusOpen() {
    if (this.#isPointerDown) return
    if (this.#isOpen()) return

    this.#open("instant-open")
  }

  blurClose() {
    this.#clearOpenTimer()

    if (this.#isOpen()) this.#close("blur")
  }

  // --- open / close ---

  #open(state) {
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

    const trigger = this.#trigger()

    content.hidden = false
    if (trigger) {
      setState(trigger, state)
      trigger.setAttribute("aria-describedby", content.id)
    }
    // The data-state triple rides through setState directly (presence's
    // enter helper only knows "open"; everything non-closed IS open here
    // and the enter animation classes are ungated anyway - source-exact).
    setState(content, state)

    // Token-activated dismissable only - NO focus-scope, focus never enters
    // a tooltip. Esc anywhere peels the tooltip first (topmost layer).
    content.setAttribute(`data-${DISMISSABLE}-disable-outside-pointer-events-value`, "false")
    this.#addControllers(content, [DISMISSABLE])
    this.#armScrollListener()
    this.openValue = true

    queueMicrotask(() => {
      if (!this.#isOpen()) return

      this.dispatch("open", { prefix: EVENT_PREFIX, detail: { state } })
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

    if (trigger) setState(trigger, "closed")
    this.openValue = false

    this.#cancelExit = exitPresence(content, {
      onRemove: () => {
        this.#cancelExit = null
        content.hidden = true
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
  }

  // --- the close-intent grace (hoverable content) ---

  #scheduleClose() {
    this.#clearCloseTimer()
    this.#closeTimer = window.setTimeout(() => {
      this.#closeTimer = null
      this.#close("leave")
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
    // UX anyway (contract note); it reports as "outside".
    this.#close(escaped ? "escape" : "outside")
  }

  // Another tooltip is about to open: one open page-wide.
  #handleWillOpen(event) {
    if (this.#emittingWillOpen) return
    if (event.target === this.element) return

    this.#clearOpenTimer()

    if (this.#isOpen()) this.#close("superseded")
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
