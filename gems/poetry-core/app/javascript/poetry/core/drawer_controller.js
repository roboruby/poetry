import DialogController from "@poetry/controllers/dialog_controller"
import { isImeKeydown } from "@poetry/controllers/helpers/escape"
import { enterPresence, exitPresence } from "@poetry/controllers/helpers/presence"

// The Drawer: the dialog machinery + the swipe-to-dismiss gesture.
// Everything hard about the OVERLAY is inherited (native <dialog> platform
// trap, backdrop-click discrimination, scroll lock, hotkey); this subclass
// adds the two things a drawer is:
//
//   * ANIMATED presence - the first consumer of the presence helpers:
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
    direction: { type: String, default: "down" },
    // Source parity: modal={false} opens with show() instead of
    // showModal() - no top layer, no ::backdrop, no focus trap, no
    // scroll lock. The page behind stays fully interactive.
    modal: { type: Boolean, default: true },
    // Source parity: snapPoints - preset resting heights for a bottom
    // sheet (direction down only), ascending: fractions of the full
    // height (0..1] or CSS lengths ("31rem", "400px"). The popup runs
    // full-height (the dictionary's data-snap-points sizing) and
    // --drawer-snap-point-offset hides the rest; opens at the first
    // point, drags move between points, below the first dismisses.
    snapPoints: { type: Array, default: [] }
  }

  #swipe = null
  #closing = false
  #snapIndex = 0

  /**
   * Opens per the modal value: showModal() plus the scroll lock, or the
   * non-modal show() (no top layer - the component pins the panel; the
   * body comment). The first snap offset lands BEFORE the enter
   * transition starts, then the animated entry runs.
   */
  open() {
    if (this.modalValue) {
      this.dialogTarget.showModal()
      this.lockScroll()
    } else {
      // show() skips the top layer, so the UA :modal positioning is
      // gone too - the component pins the panel with fixed/inset
      // classes instead. close() stays balanced: unlockScroll no-ops
      // through the instance #locked flag when nothing was locked.
      this.dialogTarget.show()
    }
    // The first snap offset must be in place BEFORE the enter transition
    // starts, so the sheet slides up to its compact peek, not to full.
    if (this.#snapping()) this.#applySnap(0)
    enterPresence(this.dialogTarget)
  }

  /**
   * The non-modal Escape exit (the component wires this keydown action
   * only when modal is false): a non-modal dialog never fires cancel, so
   * Esc needs its own path while focus is inside; modal drawers ride the
   * native cancel.
   *
   * @param {KeyboardEvent} event
   */
  escapeClose(event) {
    if (this.modalValue) return
    // isImeKeydown: an Escape canceling IME composition must never dismiss.
    if (event.key !== "Escape" || event.defaultPrevented || isImeKeydown(event)) return

    event.preventDefault()
    this.close()
  }

  /**
   * Closes through the animated exit (data-ending-style), then the
   * native close(), the unlock, and the swipe-var reset. The native
   * cancel event (Esc) routes through here so state stays in sync.
   *
   * @param {Event} [event] - the native cancel event, when Esc drove it
   */
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

  /**
   * The <dialog>'s pointerdown action: arms the swipe - always from the
   * handle; elsewhere only when the press is not on a control and no
   * scrollable child still scrolls toward the gesture.
   *
   * @param {PointerEvent} event
   */
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

  /**
   * The captured pointermove action: past the slop, tracks the drag -
   * writing the swipe CSS vars (the finger-following, duration-0 window)
   * and the release velocity.
   *
   * @param {PointerEvent} event
   */
  swipeMove(event) {
    const swipe = this.#swipe
    if (!swipe || event.pointerId !== swipe.pointerId) return

    const start = this.#axis() === "y" ? swipe.startY : swipe.startX
    // Snap-pointed sheets drag BOTH ways: negative movement (up to the
    // current offset) expands toward fuller points. Plain drawers keep
    // the toward-dismissal clamp.
    const floor = this.#snapping() ? -this.#currentSnapOffset() : 0
    const movement = Math.max(floor, this.#sign() * (this.#along(event) - start))

    if (!swipe.dragging) {
      if (Math.abs(movement) < SWIPE_SLOP) return

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

  /**
   * The pointerup action - release physics: dismiss past half the travel
   * or on a flick (exit duration scaled by the remaining travel), else
   * snap back; snap-pointed sheets settle between their points instead.
   *
   * @param {PointerEvent} event
   */
  swipeEnd(event) {
    const swipe = this.#swipe
    if (!swipe || event.pointerId !== swipe.pointerId) return

    this.#swipe = null
    if (!swipe.dragging) return
    if (this.#snapping()) return this.#settleSnap(swipe)

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

  /**
   * The pointercancel action: abandons the drag and snaps home.
   *
   * @param {PointerEvent} event
   */
  swipeCancel(event) {
    const swipe = this.#swipe
    if (!swipe || event.pointerId !== swipe.pointerId) return

    this.#swipe = null
    this.dialogTarget.removeAttribute("data-swiping")
    this.#writeSwipeVars(0)
  }

  // --- snap points -----------------------------------------------------------

  #snapping() {
    return this.directionValue === "down" && this.snapPointsValue.length > 0
  }

  // A point is a fraction of the full (100dvh) height, or a CSS length
  // in px/rem (the source's ["31rem", 1] vocabulary).
  #snapVisible(point, height) {
    if (typeof point === "number") return point * height

    const value = parseFloat(point)
    if (String(point).endsWith("rem")) {
      const rootSize = parseFloat(getComputedStyle(document.documentElement).fontSize) || 16
      return value * rootSize
    }
    return value
  }

  // Hidden-height offsets, one per point: index 0 (the compact peek)
  // hides the most; the last point shows the most.
  #snapOffsets() {
    const height = this.#size()
    return this.snapPointsValue.map((point) => {
      return Math.max(0, height - Math.min(height, this.#snapVisible(point, height)))
    })
  }

  #currentSnapOffset() {
    return parseFloat(this.dialogTarget.style.getPropertyValue("--drawer-snap-point-offset")) || 0
  }

  #applySnap(index) {
    this.#snapIndex = index
    this.dialogTarget.style.setProperty("--drawer-snap-point-offset", `${this.#snapOffsets()[index]}px`)
  }

  // Release physics between points: a flick moves one point in its
  // direction (past the first point -> dismiss); a slow release settles
  // on the nearest point, or dismisses once it sits past half the
  // compact peek's visible height (the plain drawer's threshold, taken
  // against the peek rather than the full sheet).
  #settleSnap(swipe) {
    const height = this.#size()
    const offsets = this.#snapOffsets()
    const position = this.#currentSnapOffset() + swipe.movement
    const peekVisible = Math.max(1, height - offsets[0])
    let target

    if (Math.abs(swipe.velocity) >= DISMISS_VELOCITY) {
      target = this.#snapIndex + (swipe.velocity > 0 ? -1 : 1)
    } else {
      target = offsets.reduce((best, offset, index) => {
        return Math.abs(position - offset) < Math.abs(position - offsets[best]) ? index : best
      }, 0)
      if (position - offsets[0] >= peekVisible * DISMISS_PROGRESS) target = -1
    }

    this.dialogTarget.removeAttribute("data-swiping")
    if (target < 0) {
      const progress = Math.min(1, Math.max(0, (position - offsets[0]) / peekVisible))
      const strength = Math.max(MIN_STRENGTH, Math.min(1, 1 - progress))
      this.dialogTarget.style.setProperty("--drawer-swipe-strength", String(strength))
      this.close()
    } else {
      const index = Math.min(target, offsets.length - 1)
      requestAnimationFrame(() => {
        this.#applySnap(index)
        this.#writeSwipeVars(0)
      })
    }
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
    // Progress measures travel toward DISMISSAL only: for snap-pointed
    // sheets that travel starts at the compact peek (expanded positions
    // clamp to 0, so the backdrop never fades while snapping fuller);
    // for plain drawers the base is 0 and this stays movement / size.
    const dismissBase = this.#snapping() ? this.#snapOffsets()[0] : 0
    const travel = Math.max(1, this.#size() - dismissBase)
    const progress = (this.#currentSnapOffset() + movement - dismissBase) / travel
    dialog.style.setProperty("--drawer-swipe-progress", String(Math.min(1, Math.max(0, progress))))
  }

  #resetSwipeVars() {
    const dialog = this.dialogTarget
    dialog.style.removeProperty("--drawer-swipe-movement-x")
    dialog.style.removeProperty("--drawer-swipe-movement-y")
    dialog.style.removeProperty("--drawer-swipe-progress")
    dialog.style.removeProperty("--drawer-swipe-strength")
    dialog.style.removeProperty("--drawer-snap-point-offset")
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
