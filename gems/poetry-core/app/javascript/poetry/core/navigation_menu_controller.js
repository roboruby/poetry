import { Controller } from "@hotwired/stimulus"
import { isImeKeydown } from "@poetry/controllers/helpers/escape"
import { setState } from "@poetry/controllers/helpers/state"
import { enterPresence, exitPresence, flushPendingExits } from "@poetry/controllers/helpers/presence"
import { onBeforeCache } from "@poetry/controllers/helpers/turbo_cache"

// The NavigationMenu coordinator (the viewport=false mode): a
// DISCLOSURE BAR, not a menu - Tab moves through triggers and links
// normally, arrows are convenience navigation, nothing traps. Each item's
// panel is its own popup positioned under the item; this controller owns
// what per-item popovers can't: ONE panel open at a time, hover intent
// (open/close delays so diagonal travel into a panel doesn't flicker),
// Esc + focus-out + outside-press closing, and the vocabulary writes
// (data-popup-open on the trigger - the chevron's rotation hook - and the
// presence-driven open/closed pair on the panel).
//
// THE VIEWPORT MODE: when the markup ships the shared
// positioner > popup > viewport shell (viewport: true), panels are
// lazily ADOPTED into the viewport on first activation (the Rails
// stand-in for Base UI's portal - server-rendered content stays in
// place until JS activates) and the composite MORPHS: the popper
// re-anchors to the active trigger (full floating-ui) while CSS
// transitions the positioner's insets, the popup's --popup-width/height
// pin old -> new across two frames so width/height transition, panels
// slide by data-activation-direction (new trigger vs old, recharts'
// travel semantics), and data-instant suppresses transitions on cold
// opens. Vars reset to auto after the animations finish (the Base UI
// auto-size reset via getAnimations().finished).
const TRIGGER_SELECTOR = '[data-slot="navigation-menu-trigger"]'
const PANEL_SELECTOR = '[data-slot="navigation-menu-content"]'
const ITEM_SELECTOR = '[data-slot="navigation-menu-item"]'
const POSITIONER_SELECTOR = '[data-slot="navigation-menu-positioner"]'
const POPUP_SELECTOR = '[data-slot="navigation-menu-popup"]'
const VIEWPORT_SELECTOR = '[data-slot="navigation-menu-viewport"]'

export default class NavigationMenuController extends Controller {
  static values = {
    openDelay: { type: Number, default: 50 },
    closeDelay: { type: Number, default: 150 }
  }

  #openValue = null
  #timer = null
  #cancelExit = new Map() // value -> abandon-this-panel's-exit (per panel, not global)
  #onOutsidePress = null
  #unsubscribeBeforeCache = null
  #sizeGeneration = 0

  /**
   * Subscribes the before-cache close (the body comment holds the zombie
   * rules).
   */
  connect() {
    // Close before Turbo snapshots: an open panel serialized into the
    // cache restores with data-open (viewport-mode panels also serialize
    // adopted into the shared viewport). The explicit flush completes the
    // exit THIS close just started, regardless of listener order (the
    // dismissable layer's pattern).
    this.#unsubscribeBeforeCache = onBeforeCache(() => {
      if (this.#openValue === null) return
      this.#clearTimer()
      this.#close()
      flushPendingExits()
    })
  }

  /**
   * Clears the timer and unwires the outside-press and before-cache
   * listeners.
   */
  disconnect() {
    this.#clearTimer()
    this.#unbindOutsidePress()
    this.#unsubscribeBeforeCache?.()
    this.#unsubscribeBeforeCache = null
  }

  /**
   * Each trigger's click action - immediate, cancels hover intent.
   *
   * @param {MouseEvent} event
   */
  toggle(event) {
    const value = this.#valueFrom(event)
    if (value === null) return

    this.#clearTimer()
    if (this.#openValue === value) this.#close()
    else this.#open(value)
  }

  /**
   * Each ITEM's pointerenter action (the panel lives inside its item, so
   * moving into the panel never schedules a close): arms hover intent -
   * instant switch while the bar is already open, the open delay on cold
   * entry. Touch is click's job.
   *
   * @param {PointerEvent} event
   */
  scheduleOpen(event) {
    if (event.pointerType === "touch") return // touch is click's job

    const value = this.#valueFrom(event)
    if (value === null) return
    if (value === this.#openValue) {
      this.#clearTimer() // re-entering the open item cancels a pending close
      return
    }

    // Instant switch while the bar is already open (the mega-menu feel);
    // intent delay only on cold entry.
    this.#schedule(() => this.#open(value), this.#openValue === null ? this.openDelayValue : 0)
  }

  /**
   * Each ITEM's pointerleave action: arms the close grace.
   *
   * @param {PointerEvent} event
   */
  scheduleClose(event) {
    if (event.pointerType === "touch") return
    if (this.#openValue === null) return

    this.#schedule(() => this.#close(), this.closeDelayValue)
  }

  /**
   * The shared positioner's pointerenter action - in viewport mode the
   * panel no longer lives inside its item, so entering the popup must
   * cancel a pending close.
   */
  cancelClose() {
    this.#clearTimer()
  }

  /**
   * The root's keydown action: Escape closes and refocuses the trigger;
   * ArrowLeft/Right move between the bar's stops (triggers and top-level
   * links).
   *
   * @param {KeyboardEvent} event
   */
  keydown(event) {
    if (event.key === "Escape") {
      if (isImeKeydown(event)) return
      if (this.#openValue === null) return

      const trigger = this.#triggerFor(this.#openValue)
      this.#close()
      trigger?.focus()
      event.preventDefault()
      return
    }

    if (event.key !== "ArrowLeft" && event.key !== "ArrowRight") return

    const stops = this.#arrowStops()
    const index = stops.indexOf(event.target)
    if (index === -1) return

    const next = stops[index + (event.key === "ArrowRight" ? 1 : -1)]
    if (!next) return

    event.preventDefault()
    next.focus()
  }

  /**
   * The root's focusout action - a disclosure closes when focus leaves it
   * entirely (never traps).
   *
   * @param {FocusEvent} event
   */
  focusLeft(event) {
    const next = event.relatedTarget

    if (next instanceof Element && this.element.contains(next)) return

    this.#clearTimer()
    this.#close()
  }

  #open(value) {
    if (this.#openValue === value) return

    const previous = this.#openValue
    if (this.#viewport() && previous !== null) this.#stampDirection(previous, value)
    if (previous !== null) this.#hidePanel(previous)

    this.#openValue = value
    const trigger = this.#triggerFor(value)
    const panel = this.#panelFor(value)

    if (trigger) {
      trigger.setAttribute("aria-expanded", "true")
      setState(trigger, "popup-open")
      setState(trigger, "open")
    }
    if (panel) {
      // Re-opening THIS panel mid-close: abandon only its own exit (a
      // sibling's pending exit must still run onRemove and hide it).
      this.#cancelExit.get(value)?.()
      this.#cancelExit.delete(value)
      if (this.#viewport()) {
        this.#showInViewport(panel, trigger, previous)
      } else {
        panel.hidden = false
        enterPresence(panel)
      }
    }
    this.#bindOutsidePress()
  }

  #close() {
    if (this.#openValue === null) return

    this.#hidePanel(this.#openValue)
    this.#openValue = null
    this.#unbindOutsidePress()
    this.#closeViewport()
  }

  // -- the morphing viewport -----------------------------------------------

  #viewport() {
    return this.element.querySelector(VIEWPORT_SELECTOR)
  }

  #showInViewport(panel, trigger, previous) {
    const viewport = this.#viewport()
    const positioner = this.element.querySelector(POSITIONER_SELECTOR)
    const popup = this.element.querySelector(POPUP_SELECTOR)
    const cold = previous === null

    // Lazy adoption: the server-rendered panel moves from its item into
    // the shared viewport on FIRST activation (the portal's Rails
    // stand-in - no-JS content stays in place until JS activates).
    if (panel.parentElement !== viewport) {
      panel.setAttribute("data-viewport-panel", "")
      viewport.appendChild(panel)
    }

    // The size choreography (Base UI setSharedFixedSize): pin the popup
    // to the OLD size, reveal the new panel, measure its natural size
    // (panels are absolutely stacked, so they size intrinsically), then
    // pin the NEW size a frame later so width/height transition.
    const oldWidth = popup.offsetWidth
    const oldHeight = popup.offsetHeight

    panel.hidden = false
    const nextWidth = panel.offsetWidth
    const nextHeight = panel.offsetHeight

    if (cold) {
      this.#stampInstant(positioner, popup) // no transition on a cold open
      this.#pinSize(positioner, popup, nextWidth, nextHeight)
      this.#scheduleSizeReset(positioner, popup)
    } else {
      // Pin old, pin new a frame later (the width/height transition), and
      // only THEN arm the settle reset - armed alongside the OLD pin it
      // samples getAnimations before the transition exists, resets to auto
      // synchronously, and the late new-size pin sticks forever (the D3
      // Chrome-proof catch: the morph never ran).
      this.#pinSize(positioner, popup, oldWidth, oldHeight)
      this.#nextFrame(() => {
        this.#pinSize(positioner, popup, nextWidth, nextHeight)
        this.#nextFrame(() => this.#scheduleSizeReset(positioner, popup))
      })
    }

    positioner.hidden = false
    setState(popup, "open")
    enterPresence(panel)
    this.#anchorPopper(trigger)
  }

  #closeViewport() {
    const positioner = this.element.querySelector(POSITIONER_SELECTOR)
    const popup = this.element.querySelector(POPUP_SELECTOR)
    if (!positioner || positioner.hidden) return

    setState(popup, "closed")
    positioner.hidden = true
  }

  // The popper (full floating-ui) re-anchors to the active
  // trigger; the positioner's inset transition gives the slide.
  #anchorPopper(trigger) {
    if (!trigger) return

    const popper =
      this.application.getControllerForElementAndIdentifier(this.element, "poetry--core--popper")
    popper?.setAnchorElement(trigger)
  }

  // data-activation-direction: which way the activation traveled (the new
  // trigger relative to the old); outgoing AND incoming panels wear it so
  // the starting/ending-style slides read one direction.
  #stampDirection(previousValue, nextValue) {
    const previous = this.#triggerFor(previousValue)
    const next = this.#triggerFor(nextValue)
    if (!previous || !next) return

    const delta = next.getBoundingClientRect().left - previous.getBoundingClientRect().left
    if (delta === 0) return

    const direction = delta > 0 ? "right" : "left"
    for (const panel of [this.#panelFor(previousValue), this.#panelFor(nextValue)]) {
      panel?.setAttribute("data-activation-direction", direction)
    }
  }

  // Pin the shared size vars (popup + positioner, Base UI's pairing).
  #pinSize(positioner, popup, width, height) {
    popup.style.setProperty("--popup-width", `${width}px`)
    popup.style.setProperty("--popup-height", `${height}px`)
    positioner.style.setProperty("--positioner-width", `${width}px`)
    positioner.style.setProperty("--positioner-height", `${height}px`)
  }

  // The Base UI auto-size reset: once the morph settles the vars return
  // to auto, so later content growth isn't clipped. A newer activation
  // cancels a stale reset (the generation counter).
  #scheduleSizeReset(positioner, popup) {
    const generation = ++this.#sizeGeneration
    const reset = () => {
      if (generation !== this.#sizeGeneration) return

      this.#pinAuto(positioner, popup)
    }

    if (typeof popup.getAnimations === "function") {
      const animations = popup.getAnimations()
      if (animations.length > 0) {
        Promise.allSettled(animations.map((animation) => animation.finished)).then(reset)
        return
      }
    }
    reset()
  }

  #pinAuto(positioner, popup) {
    popup.style.setProperty("--popup-width", "auto")
    popup.style.setProperty("--popup-height", "auto")
    positioner.style.setProperty("--positioner-width", "auto")
    positioner.style.setProperty("--positioner-height", "auto")
  }

  // data-instant suppresses the positioner/popup transitions for one
  // painted frame (cold opens - a Base UI instant reason).
  #stampInstant(positioner, popup) {
    positioner.setAttribute("data-instant", "")
    popup.setAttribute("data-instant", "")
    this.#nextFrame(() => this.#nextFrame(() => {
      positioner.removeAttribute("data-instant")
      popup.removeAttribute("data-instant")
    }))
  }

  #nextFrame(callback) {
    if (typeof requestAnimationFrame === "function") requestAnimationFrame(callback)
    else callback()
  }

  #hidePanel(value) {
    const trigger = this.#triggerFor(value)
    const panel = this.#panelFor(value)

    if (trigger) {
      trigger.setAttribute("aria-expanded", "false")
      setState(trigger, "popup-closed")
      setState(trigger, "closed")
    }
    if (panel) {
      this.#cancelExit.set(value, exitPresence(panel, {
        onRemove: () => {
          panel.hidden = true
          this.#cancelExit.delete(value)
        }
      }))
    }
  }

  // Outside press closes - bound only while open (no idle listener).
  #bindOutsidePress() {
    if (this.#onOutsidePress) return

    this.#onOutsidePress = (event) => {
      // The dismissable layer's press rules: a disconnected target says
      // nothing about WHERE the press landed (the false-dismiss class);
      // composedPath is fixed at dispatch, so a press on a node an inner
      // handler removed still counts as inside; and the top layer
      // (toasts) sits above every dismissal surface by fiat.
      if (!(event.target instanceof Element) || !event.target.isConnected) return
      if (event.composedPath().includes(this.element)) return
      if (event.target.closest("[data-poetry-top-layer]")) return

      this.#clearTimer()
      this.#close()
    }
    document.addEventListener("pointerdown", this.#onOutsidePress)
  }

  #unbindOutsidePress() {
    if (!this.#onOutsidePress) return

    document.removeEventListener("pointerdown", this.#onOutsidePress)
    this.#onOutsidePress = null
  }

  #schedule(action, delay) {
    this.#clearTimer()
    this.#timer = window.setTimeout(() => {
      this.#timer = null
      action()
    }, delay)
  }

  #clearTimer() {
    if (this.#timer === null) return

    window.clearTimeout(this.#timer)
    this.#timer = null
  }

  #valueFrom(event) {
    const origin = event.target instanceof Element ? event.target : null
    const item = origin?.closest(ITEM_SELECTOR)

    return item?.dataset.value ?? null
  }

  #triggerFor(value) {
    return this.#itemFor(value)?.querySelector(TRIGGER_SELECTOR) ?? null
  }

  // An adopted panel (viewport mode) no longer lives inside its item -
  // the trigger's aria-controls id finds it wherever it moved.
  #panelFor(value) {
    const inItem = this.#itemFor(value)?.querySelector(PANEL_SELECTOR)
    if (inItem) return inItem

    const id = this.#triggerFor(value)?.getAttribute("aria-controls")
    return id ? document.getElementById(id) : null
  }

  #itemFor(value) {
    return [...this.element.querySelectorAll(ITEM_SELECTOR)]
      .find((item) => item.dataset.value === value) ?? null
  }

  // Arrow stops: every trigger and top-level link in the bar, DOM order.
  #arrowStops() {
    return [...this.element.querySelectorAll(
      `${TRIGGER_SELECTOR}, [data-slot="navigation-menu-list"] > ${ITEM_SELECTOR} > a`
    )]
  }
}
