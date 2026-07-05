import { Controller } from "@hotwired/stimulus"
import { setState } from "@poetry/controllers/helpers/state"
import { enterPresence, exitPresence } from "@poetry/controllers/helpers/presence"

// The NavigationMenu coordinator (N9 W4c, the viewport=false mode): a
// DISCLOSURE BAR, not a menu - Tab moves through triggers and links
// normally, arrows are convenience navigation, nothing traps. Each item's
// panel is its own popup positioned under the item; this controller owns
// what per-item popovers can't: ONE panel open at a time, hover intent
// (open/close delays so diagonal travel into a panel doesn't flicker),
// Esc + focus-out + outside-press closing, and the vocabulary writes
// (data-popup-open on the trigger - the chevron's rotation hook - and the
// presence-driven open/closed pair on the panel).
//
// Deferred with the Base UI viewport machinery: the morphing shared
// popup (--positioner-* size/position transitions) and data-motion
// direction slides (the classes ship inert until it lands).
const TRIGGER_SELECTOR = '[data-slot="navigation-menu-trigger"]'
const PANEL_SELECTOR = '[data-slot="navigation-menu-content"]'
const ITEM_SELECTOR = '[data-slot="navigation-menu-item"]'

export default class NavigationMenuController extends Controller {
  static values = {
    openDelay: { type: Number, default: 50 },
    closeDelay: { type: Number, default: 150 }
  }

  #openValue = null
  #timer = null
  #cancelExit = null
  #onOutsidePress = null

  disconnect() {
    this.#clearTimer()
    this.#unbindOutsidePress()
  }

  // Action: click->...#toggle on each trigger - immediate, cancels intent.
  toggle(event) {
    const value = this.#valueFrom(event)
    if (value === null) return

    this.#clearTimer()
    if (this.#openValue === value) this.#close()
    else this.#open(value)
  }

  // Actions: pointerenter/pointerleave->...#scheduleOpen/#scheduleClose on
  // each ITEM (the panel lives inside it, so moving into the panel never
  // schedules a close).
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

  scheduleClose(event) {
    if (event.pointerType === "touch") return
    if (this.#openValue === null) return

    this.#schedule(() => this.#close(), this.closeDelayValue)
  }

  // Action: keydown->...#keydown on the root.
  keydown(event) {
    if (event.key === "Escape") {
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

  // Action: focusout->...#focusLeft on the root - a disclosure closes when
  // focus leaves it entirely (never traps).
  focusLeft(event) {
    const next = event.relatedTarget

    if (next instanceof Element && this.element.contains(next)) return

    this.#clearTimer()
    this.#close()
  }

  #open(value) {
    if (this.#openValue === value) return
    if (this.#openValue !== null) this.#hidePanel(this.#openValue)

    this.#openValue = value
    const trigger = this.#triggerFor(value)
    const panel = this.#panelFor(value)

    if (trigger) {
      trigger.setAttribute("aria-expanded", "true")
      setState(trigger, "popup-open")
      setState(trigger, "open")
    }
    if (panel) {
      this.#cancelExit?.()
      this.#cancelExit = null
      panel.hidden = false
      enterPresence(panel)
    }
    this.#bindOutsidePress()
  }

  #close() {
    if (this.#openValue === null) return

    this.#hidePanel(this.#openValue)
    this.#openValue = null
    this.#unbindOutsidePress()
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
      this.#cancelExit = exitPresence(panel, { onRemove: () => { panel.hidden = true } })
    }
  }

  // Outside press closes - bound only while open (no idle listener).
  #bindOutsidePress() {
    if (this.#onOutsidePress) return

    this.#onOutsidePress = (event) => {
      if (event.target instanceof Element && this.element.contains(event.target)) return

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

  #panelFor(value) {
    return this.#itemFor(value)?.querySelector(PANEL_SELECTOR) ?? null
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
