import { Controller } from "@hotwired/stimulus"
import { directionOf } from "@poetry/controllers/helpers/direction"
import { setState } from "@poetry/controllers/helpers/state"

// The Menubar cross-menu COORDINATOR (Menubar) - kept
// deliberately anorexic: ONE piece of state (`value`, which menu is open)
// plus the three behaviors no other layer can own. The ownership split:
// - roving-focus (horizontal, manageTabindex TRUE) owns which trigger is
//   tabbable/focused on the bar - it knows nothing about menus.
// - poetry--core--menu (one instance per menu, modal: false) owns
//   everything inside an open menu - it knows nothing about siblings.
// - this controller owns:
//   1. TOGGLE - pointerdown opens (closing any sibling) / closes the open
//      menu. Keyboard open (ArrowDown/Enter/Space -> first item; ArrowUp ->
//      last item) rides the family's open-reason contract; pointer-open
//      leaves focus on the trigger (Radix parity).
//   2. HOVER-SLIDE - pointerenter on a sibling trigger is a no-op from cold;
//      once ANY menu is open it swaps to the hovered menu (the gated-hover
//      rule) and focus moves to the new trigger.
//   3. EDGE-NAVIGATE - the family menu controller fires a cancelable
//      poetry:menu:edge-navigate when ArrowLeft/Right has no submenu
//      meaning; this coordinator consumes it (loop-aware, RTL-aware,
//      disabled-skipping) and opens the adjacent menu with its FIRST item
//      focused (both directions - APG menubar). Standalone DropdownMenu
//      leaves the event unconsumed.
// Dismiss (Esc/outside) and select arrive as the family's poetry:menu:closed
// - the coordinator nulls value; focus return to the trigger is the family
// focus-scope's job (its connect snapshot IS the trigger, because every
// open path here puts focus there first).
//
// A press on a sibling trigger must be TOGGLE's, not the open menu's
// dismissable layer's: the coordinator vetoes interact-outside for presses
// landing on this bar's triggers (otherwise dismiss-then-toggle would
// close-and-reopen in the same pointerdown).
const TRIGGER_SELECTOR = '[data-slot="menubar-trigger"]'
const MENU = "poetry--core--menu"
const MENU_SCOPE_SELECTOR = `[data-controller~="${MENU}"]`
const EVENT_PREFIX = "poetry:menubar"

export default class MenubarController extends Controller {
  static values = {
    value: { type: String, default: "" },
    loop: { type: Boolean, default: false }
  }

  #connected = false
  #swapping = false
  #onInteractOutside = (event) => {
    const target = event.detail?.originalEvent?.target
    const trigger = target instanceof Element ? target.closest(TRIGGER_SELECTOR) : null

    if (trigger && this.element.contains(trigger)) event.preventDefault()
  }

  connect() {
    this.element.addEventListener("poetry--core--dismissable:interact-outside", this.#onInteractOutside)
    this.#connected = true

    // Reconcile-on-connect (controllable state): a server-rendered value
    // may already mark a menu open; the DOM wins, the coordinator catches
    // up. One microtask behind: the per-menu controllers connect in the
    // same tree pass, AFTER the bar.
    queueMicrotask(() => {
      if (this.#connected) this.#reconcile(this.valueValue)
    })
  }

  disconnect() {
    this.element.removeEventListener("poetry--core--dismissable:interact-outside", this.#onInteractOutside)
    this.#connected = false
  }

  // A host (outlet / Turbo Stream / URL param) may own the value; flipping
  // the attribute drives the same machine.
  valueValueChanged(value, previous) {
    if (!this.#connected || value === previous) return

    this.#reconcile(value)
  }

  // --- the three behaviors ---

  toggle(event) {
    const trigger = event.currentTarget

    if (this.#isDisabled(trigger)) return
    if (event.button !== undefined && event.button !== 0) return // left button only (Radix)
    if (event.ctrlKey) return // macOS ctrl-click is a context menu, not a toggle

    if (trigger.hasAttribute("data-popup-open")) this.#menuFor(trigger)?.close("trigger-press")
    else this.#activate(trigger, "trigger-press", { openReason: "trigger-press", focus: false })
  }

  hoverSlide(event) {
    const trigger = event.currentTarget

    if (!this.valueValue) return // gated hover: never opens from cold
    if (this.#isDisabled(trigger) || trigger.hasAttribute("data-popup-open")) return

    this.#activate(trigger, "trigger-hover", { openReason: "trigger-press", focus: false })
  }

  triggerKeydown(event) {
    const trigger = event.currentTarget

    if (this.#isDisabled(trigger) || trigger.hasAttribute("data-popup-open")) return

    if (event.key === "Enter" || event.key === " " || event.key === "ArrowDown") {
      event.preventDefault() // also suppresses the button's synthetic click
      this.#activate(trigger, "list-navigation", { openReason: "list-navigation", openSeed: "first", focus: true })
    } else if (event.key === "ArrowUp") {
      event.preventDefault()
      this.#activate(trigger, "list-navigation", { openReason: "list-navigation", openSeed: "last", focus: true })
    }
  }

  // poetry:menu:edge-navigate (cancelable, bubbling from the open menu's
  // ROOT content). direction is the PHYSICAL arrow; RTL maps it here.
  // ALWAYS consumed once the menu belongs to this bar - an unconsumed edge
  // would fall through to the bar's roving-focus and move trigger focus
  // while the menu stays open (bar arrows are inert while open, Radix
  // parity). At a no-loop boundary that means: consumed, no move.
  slideAdjacent(event) {
    const trigger = this.#triggerFrom(event.target)

    if (!trigger) return

    event.preventDefault()

    const rtl = directionOf(this.element) === "rtl"
    const delta = (event.detail?.direction === "right") === !rtl ? 1 : -1
    const destination = this.#adjacentTrigger(trigger, delta)

    if (!destination || destination === trigger) return

    this.#activate(destination, "list-navigation", { openReason: "list-navigation", openSeed: "first", focus: true })
  }

  // poetry:menu:closed from any of the bar's menus: null the value unless
  // the close is one half of an in-flight swap.
  onMenuClosed(event) {
    if (this.#swapping) return

    const trigger = this.#triggerFrom(event.target)

    if (!trigger) return
    if (!this.valueValue || this.#valueOf(trigger) !== this.valueValue) return

    const previous = this.valueValue

    this.valueValue = ""
    setState(this.element, "closed")
    // The menu's close reason passes through verbatim (Base UI vocabulary:
    // escape-key / outside-press / item-press / trigger-press / none).
    this.dispatch("value-changed", {
      prefix: EVENT_PREFIX,
      detail: { value: null, previous, reason: event.detail?.reason ?? "trigger-press" }
    })
  }

  // --- the swap ---

  // Close whatever is open (no focus restore, no value-changed spam), put
  // focus + the bar tab stop on the destination trigger BEFORE opening (so
  // the family focus-scope snapshots IT as the Esc return target), open.
  #activate(trigger, reason, { openReason, openSeed = null, focus }) {
    const previous = this.valueValue || null
    const current = this.#openTrigger()

    if (current && current !== trigger) {
      this.#swapping = true
      this.#menuFor(current)?.close("sibling-open", { restoreFocus: false })
      this.#swapping = false
    }

    this.#stampTabStop(trigger)
    trigger.focus()
    this.#menuFor(trigger)?.open(openReason, { focus, seed: openSeed })

    this.valueValue = this.#valueOf(trigger)
    setState(this.element, "open")
    this.dispatch("value-changed", {
      prefix: EVENT_PREFIX,
      detail: { value: this.valueValue, previous, reason }
    })
  }

  #reconcile(value) {
    const open = this.#openTrigger()

    if (!value) {
      if (open) this.#menuFor(open)?.close("none")

      setState(this.element, "closed")
      return
    }

    const trigger = this.#triggers().find((candidate) => this.#valueOf(candidate) === value)

    if (!trigger || trigger === open) return

    if (open) {
      this.#swapping = true
      this.#menuFor(open)?.close("sibling-open", { restoreFocus: false })
      this.#swapping = false
    }

    this.#stampTabStop(trigger)
    this.#menuFor(trigger)?.open("trigger-press", { focus: false })
    setState(this.element, "open")
  }

  // --- the bar (DOM is the registry) ---

  #triggers() {
    return Array.from(this.element.querySelectorAll(TRIGGER_SELECTOR))
  }

  #enabledTriggers() {
    return this.#triggers().filter((trigger) => !this.#isDisabled(trigger))
  }

  #openTrigger() {
    return this.#triggers().find((trigger) => trigger.hasAttribute("data-popup-open")) ?? null
  }

  #adjacentTrigger(trigger, delta) {
    const triggers = this.#enabledTriggers()
    const index = triggers.indexOf(trigger)

    if (index === -1 || triggers.length === 0) return null

    const next = index + delta

    if (this.loopValue) return triggers[(next + triggers.length) % triggers.length]
    if (next < 0 || next >= triggers.length) return null // no loop: the edges hold

    return triggers[next]
  }

  // One 0, rest -1 - the bar-level roving tab stop follows the open menu
  // (roving-focus stamps on its own focus moves; coordinator-driven moves
  // stamp here).
  #stampTabStop(current) {
    for (const trigger of this.#triggers()) {
      trigger.setAttribute("tabindex", trigger === current ? "0" : "-1")
    }
  }

  #valueOf(trigger) {
    return trigger.dataset.value ?? ""
  }

  #isDisabled(trigger) {
    return trigger.hasAttribute("data-disabled") || trigger.hasAttribute("disabled") ||
      trigger.getAttribute("aria-disabled") === "true"
  }

  #menuFor(trigger) {
    const scope = trigger.closest(MENU_SCOPE_SELECTOR)

    return scope ? this.application.getControllerForElementAndIdentifier(scope, MENU) : null
  }

  // Resolve the owning trigger from any of a menu's event targets: the
  // trigger itself, the content (edge-navigate dispatches from it - matched
  // via the aria-controls pair), or the menu's controller scope (the family
  // open/closed events dispatch from it - it wraps exactly one trigger).
  #triggerFrom(target) {
    if (!(target instanceof Element)) return null
    if (target.matches(TRIGGER_SELECTOR)) return this.element.contains(target) ? target : null

    if (target.id) {
      const byControls = this.#triggers().find(
        (trigger) => trigger.getAttribute("aria-controls") === target.id
      )

      if (byControls) return byControls
    }

    const nested = target.querySelector(TRIGGER_SELECTOR)

    return nested && this.element.contains(nested) ? nested : null
  }
}
