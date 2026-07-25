import DialogController from "@poetry/controllers/dialog_controller"
import { enterPresence, exitPresence } from "@poetry/controllers/helpers/presence"
import { showModalPreservingScroll } from "@poetry/controllers/helpers/scroll_lock"

// The Drawer (N9 W3b): the dialog machinery + the swipe-to-dismiss gesture.
// Everything hard about the OVERLAY is inherited (native <dialog> platform
// trap, backdrop-click discrimination, scroll lock, hotkey); this subclass
// adds the two things a drawer is:
//
//   * ANIMATED presence - the first consumer of the N6 presence helpers:
//     enter rides the data-starting-style two-frame trick (a transition
//     from --closed-transform), exit HOLDS the dialog through the
//     data-ending-style transition before the native close() (the
//     presence-hold close the Sheet dictionary was waiting on).
//   * The SWIPE - pointer-captured drag along the dismiss direction,
//     writing the Base UI CSS-var contract onto the <dialog> (::backdrop
//     inherits from its originating element, so the overlay fade rides the
//     same vars): --drawer-swipe-movement-x/y (px toward dismissal),
//     --drawer-swipe-progress (0..1), data-swiping while tracking
//     (duration-0 - the drawer follows the finger), and on release either
//     a snap-back or a dismissal whose exit duration scales with
//     --drawer-swipe-strength (mostly-swiped closes fast).
//
// Deferred with the rest of the stack machinery (see the Drawer style):
// snap points, nested-drawer stacking, and bleed.
const SWIPE_SLOP = 4 // px before a drag counts (clicks stay clicks)
const DISMISS_PROGRESS = 0.5 // released past halfway -> dismiss
const DISMISS_VELOCITY = 0.5 // px/ms toward dismissal -> flick-dismiss
const MIN_STRENGTH = 0.25 // even a full swipe animates the remainder briefly

const INTERACTIVE = "button, a[href], input, select, textarea, [contenteditable], [role=button]"
const HANDLE = '[data-slot="drawer-swipe-handle"]'

export default class DrawerController extends DialogController {
  static values = {
    // The dismissal direction (matches the Base UI swipeDirection).
    direction: { type: String, default: "down" }
  }

  #swipe = null
  #closing = false

  open() {
    showModalPreservingScroll(this.dialogTarget)
    enterPresence(this.dialogTarget)
    this.lockScroll()
  }

  close(event) {
    if (event?.type === "cancel") event.preventDefault() // route Esc through the animated path
    if (this.#closing) return

    this.#closing = true
    exitPresence(this.dialogTarget, {
      onRemove: () => {
        this.#closing = false
        this.#resetSwipeVars()
        this.dialogTarget.close()
        this.unlockScroll()
      }
    })
  }

  // --- the swipe -----------------------------------------------------------

  // Action: pointerdown->poetry--core--drawer#swipeStart on the <dialog>.
  swipeStart(event) {
    if (event.button !== 0 && event.pointerType === "mouse") return
    if (this.#closing) return

    const target = event.target instanceof Element ? event.target : null
    if (!target) return

    // A drag may start on the handle ALWAYS; elsewhere it must not steal
    // from controls or from content that still scrolls toward the gesture.
    if (!target.closest(HANDLE)) {
      if (target.closest(INTERACTIVE)) return
      if (this.#scrollBlocks(target)) return
    }

    this.#swipe = {
      pointerId: event.pointerId,
      startX: event.clientX, startY: event.clientY,
      lastPosition: this.#along(event), lastTime: event.timeStamp,
      velocity: 0, movement: 0, dragging: false
    }
    this.dialogTarget.setPointerCapture(event.pointerId)
  }

  swipeMove(event) {
    const swipe = this.#swipe
    if (!swipe || event.pointerId !== swipe.pointerId) return

    const start = this.#axis() === "y" ? swipe.startY : swipe.startX
    const movement = Math.max(0, this.#sign() * (this.#along(event) - start))

    if (!swipe.dragging) {
      if (movement < SWIPE_SLOP) return

      swipe.dragging = true
      this.dialogTarget.setAttribute("data-swiping", "")
    }

    const elapsed = event.timeStamp - swipe.lastTime
    if (elapsed > 0) {
      swipe.velocity = (this.#sign() * (this.#along(event) - swipe.lastPosition)) / elapsed
      swipe.lastPosition = this.#along(event)
      swipe.lastTime = event.timeStamp
    }

    swipe.movement = movement
    this.#writeSwipeVars(movement)
  }

  swipeEnd(event) {
    const swipe = this.#swipe
    if (!swipe || event.pointerId !== swipe.pointerId) return

    this.#swipe = null
    if (!swipe.dragging) return

    const progress = swipe.movement / this.#size()

    if (progress >= DISMISS_PROGRESS || swipe.velocity >= DISMISS_VELOCITY) {
      // The exit transition covers the REMAINING travel - scale it so a
      // mostly-swiped drawer closes fast (the source's strength contract).
      const strength = Math.max(MIN_STRENGTH, Math.min(1, 1 - progress))
      this.dialogTarget.style.setProperty("--drawer-swipe-strength", String(strength))
      this.dialogTarget.removeAttribute("data-swiping")
      this.close()
    } else {
      // Snap back: re-enable the transition FIRST, then move home.
      this.dialogTarget.removeAttribute("data-swiping")
      requestAnimationFrame(() => this.#writeSwipeVars(0))
    }
  }

  swipeCancel(event) {
    const swipe = this.#swipe
    if (!swipe || event.pointerId !== swipe.pointerId) return

    this.#swipe = null
    this.dialogTarget.removeAttribute("data-swiping")
    this.#writeSwipeVars(0)
  }

  // --- geometry --------------------------------------------------------------

  #axis() {
    return this.directionValue === "left" || this.directionValue === "right" ? "x" : "y"
  }

  // +1 when dismissal increases the coordinate (down/right), -1 otherwise.
  #sign() {
    return this.directionValue === "down" || this.directionValue === "right" ? 1 : -1
  }

  #along(event) {
    return this.#axis() === "y" ? event.clientY : event.clientX
  }

  #size() {
    const dialog = this.dialogTarget
    return Math.max(1, this.#axis() === "y" ? dialog.offsetHeight : dialog.offsetWidth)
  }

  #writeSwipeVars(movement) {
    const dialog = this.dialogTarget
    dialog.style.setProperty(`--drawer-swipe-movement-${this.#axis()}`, `${movement}px`)
    dialog.style.setProperty("--drawer-swipe-progress", String(movement / this.#size()))
  }

  #resetSwipeVars() {
    const dialog = this.dialogTarget
    dialog.style.removeProperty("--drawer-swipe-movement-x")
    dialog.style.removeProperty("--drawer-swipe-movement-y")
    dialog.style.removeProperty("--drawer-swipe-progress")
    dialog.style.removeProperty("--drawer-swipe-strength")
    dialog.removeAttribute("data-swiping")
  }

  // Content that can still scroll TOWARD the gesture owns the pointer: a
  // down-swipe must not fire while a scrollable child is scrolled down
  // (the user is scrolling back up), and symmetrically for the others.
  #scrollBlocks(target) {
    for (let node = target; node && node !== this.dialogTarget; node = node.parentElement) {
      if (this.#axis() === "y") {
        if (node.scrollHeight > node.clientHeight) {
          if (this.directionValue === "down" && node.scrollTop > 0) return true
          if (this.directionValue === "up" &&
              node.scrollTop + node.clientHeight < node.scrollHeight) return true
        }
      } else if (node.scrollWidth > node.clientWidth) {
        if (this.directionValue === "right" && node.scrollLeft > 0) return true
        if (this.directionValue === "left" &&
            node.scrollLeft + node.clientWidth < node.scrollWidth) return true
      }
    }
    return false
  }
}
