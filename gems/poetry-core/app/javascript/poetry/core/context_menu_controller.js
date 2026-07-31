import { Controller } from "@hotwired/stimulus"

// The ContextMenu DELTA layer (ContextMenu): trigger
// acquisition + pointer-point capture ONLY. Everything menu-shaped (open
// state machine, items, typeahead, submenus, dismissal, the layer stack)
// stays with poetry--core--menu on the same root; positioning stays with
// poetry--core--popper, driven here through its VIRTUAL-ANCHOR attribute
// (data-poetry--core--popper-anchor-point-value="x,y" - the DOM is the
// store, so the write works whether or not popper has connected yet).
//
// Input paths (Radix parity):
// - contextmenu (mouse right-click, or Shift+F10 / the ContextMenu key on a
//   focused surface): preventDefault, capture the point, open. A
//   keyboard-synthesized event carries no usable point (0,0) - the anchor
//   attribute is CLEARED so popper falls back to the trigger surface rect
//   (a deliberate improvement over Radix's 0,0 + dev-warning).
// - long-press (touch/pen ONLY - mouse never long-presses): pointerdown
//   starts a longPressDelay timer (Radix's 700ms constant, exposed as a
//   Value); ANY pointermove/pointerup/pointercancel cancels (no slop radius
//   - the platform's own touch slop absorbs jitter); a second pointerdown
//   restarts (multi-touch guard); the contextmenu handler itself clears the
//   timer (Android synthesizes contextmenu from long-press - clearing there
//   prevents double-open). data-pressing on the surface is the styleable
//   long-press feedback window (poetry addition).
// - disabled STANDS THE HANDLERS DOWN (no preventDefault): the
//   browser-native context menu returns - never a dead right-click.
const TRIGGER_SELECTOR = '[data-slot$="menu-trigger"]'
const MENU = "poetry--core--menu"
const ANCHOR_POINT_ATTRIBUTE = "data-poetry--core--popper-anchor-point-value"
const EVENT_PREFIX = "poetry:context-menu"

export default class ContextMenuController extends Controller {
  // The events this controller dispatches (manifest surface;
  // events_declaration.test.js enforces the list stays honest).
  static events = ["poetry:context-menu:open"]

  static values = {
    longPressDelay: { type: Number, default: 700 },
    disabled: { type: Boolean, default: false }
  }

  #timer = null
  #suppressNative = null
  #onMenuClosed = null

  disconnect() {
    this.#clearLongPress()
    this.#stopSuppressingNative()
  }

  disabledValueChanged(disabled) {
    if (disabled) this.#clearLongPress()
  }

  // contextmenu on the trigger surface. Re-invoking on an already-open menu
  // re-captures the point and repositions (popper's anchorPoint value is
  // reactive; autoUpdate re-reads the stored point).
  open(event) {
    if (this.disabledValue) return // native menu passthrough - do NOT preventDefault

    event.preventDefault()
    this.#clearLongPress()

    const point = this.#pointOf(event)

    this.#openAt(point, point ? "pointer" : "keyboard")
  }

  // Touch/pen long-press. While open, a press on the surface closes first
  // (press-again-to-dismiss), then the timer arms for a fresh open.
  pressStart(event) {
    if (this.disabledValue || event.pointerType === "mouse") return

    this.#clearLongPress()

    if (this.#isOpen()) this.#menu()?.close("outside-press")

    const point = { x: event.clientX, y: event.clientY }

    this.#trigger()?.setAttribute("data-pressing", "")
    this.#timer = window.setTimeout(() => {
      this.#timer = null
      this.#clearPressing()
      this.#openAt(point, "long-press")
    }, this.longPressDelayValue)
  }

  // pointermove / pointerup / pointercancel - any of them cancels the press.
  pressCancel() {
    this.#clearLongPress()
  }

  // --- the anchor contract ---

  #openAt(point, input) {
    // The attribute is canonical (inspectable, server-settable, testable);
    // an empty value returns popper to element anchoring - the trigger
    // surface rect (the positionless-open / keyboard fallback).
    this.element.setAttribute(ANCHOR_POINT_ATTRIBUTE, point ? `${point.x},${point.y}` : "")

    if (input === "keyboard") this.#menu()?.open("list-navigation", { seed: "first" })
    else this.#menu()?.open("trigger-press")
    this.#suppressNativeWhileOpen()
    this.dispatch("open", {
      prefix: EVENT_PREFIX,
      detail: { x: point?.x ?? null, y: point?.y ?? null, input }
    })
  }

  // --- native-menu suppression while open ---

  // Base UI parity: ContextMenuTrigger keeps a document-level contextmenu
  // listener while open - its viewport-covering backdrop swallows the
  // native menu everywhere outside the popup. poetry renders no backdrop
  // element, so the document listener IS the backdrop here; it deliberately
  // covers the popup itself too (upstream's measured gap: right-clicking an
  // item of the OPEN menu still spawns the native menu over it). Second
  // right-clicks on the surface stay live - the trigger's own handler runs
  // first and re-captures the point.
  #suppressNativeWhileOpen() {
    if (this.#suppressNative) return

    this.#suppressNative = (event) => {
      if (this.#isOpen()) event.preventDefault()
    }
    this.#onMenuClosed = () => {
      // A reopen during the previous close's exit presence keeps the
      // suppressor - the eventual real close dispatches closed again.
      if (!this.#isOpen()) this.#stopSuppressingNative()
    }
    document.addEventListener("contextmenu", this.#suppressNative)
    this.element.addEventListener("poetry:menu:closed", this.#onMenuClosed)
  }

  #stopSuppressingNative() {
    if (!this.#suppressNative) return

    document.removeEventListener("contextmenu", this.#suppressNative)
    this.element.removeEventListener("poetry:menu:closed", this.#onMenuClosed)
    this.#suppressNative = null
    this.#onMenuClosed = null
  }

  // A keyboard-synthesized contextmenu carries unreliable coordinates
  // (0,0 per browser) - treat the origin as "no usable point".
  #pointOf(event) {
    const x = event.clientX
    const y = event.clientY

    if (!Number.isFinite(x) || !Number.isFinite(y)) return null
    if (x === 0 && y === 0) return null

    return { x, y }
  }

  // --- long-press bookkeeping ---

  #clearLongPress() {
    if (this.#timer !== null) {
      window.clearTimeout(this.#timer)
      this.#timer = null
    }

    this.#clearPressing()
  }

  #clearPressing() {
    this.#trigger()?.removeAttribute("data-pressing")
  }

  // --- structural resolution (shared-root composition, no outlets) ---

  #menu() {
    return this.application.getControllerForElementAndIdentifier(this.element, MENU)
  }

  #trigger() {
    return this.element.querySelector(TRIGGER_SELECTOR)
  }

  #isOpen() {
    const trigger = this.#trigger()

    return Boolean(trigger) && trigger.hasAttribute("data-popup-open")
  }
}
