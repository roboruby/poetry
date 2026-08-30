import { Controller } from "@hotwired/stimulus"
import { onEscapeKeydown } from "@poetry/controllers/helpers/escape"
import { onBeforeCache } from "@poetry/controllers/helpers/turbo_cache"
import { flushPendingExits } from "@poetry/controllers/helpers/presence"

// The dismissal layer (Tier 2, P2): Escape + pointerdown-outside for every
// overlay. This controller NEVER removes DOM - it dispatches "dismiss" and
// the consumer closes itself (removes the node, collapses a disclosure,
// navigates a frame). The class-level stack makes Esc topmost-only, so
// stacked overlays peel one at a time.
export default class DismissableController extends Controller {
  // The events this controller dispatches (manifest surface;
  // events_declaration.test.js enforces the list stays honest).
  static events = [
    "poetry--core--dismissable:dismiss", "poetry--core--dismissable:interact-outside"
  ]

  static stack = []

  // The body pointer-events scrim (the CSS-only modal): refcounted across
  // layers that request it, each such layer opting its own element back in.
  static #scrimCount = 0
  static #previousBodyPointerEvents = null

  static values = {
    disableOutsidePointerEvents: { type: Boolean, default: false }
  }

  // Pages cached BEFORE the before-cache teardown shipped carry a poisoned
  // body (inline pointer-events:none serialized with no live scrim behind
  // it) - and no layer connects on the restored page to release it. Heal
  // on every Turbo render: with zero scrim holders, the style can only be
  // a serialized leftover.
  static {
    if (typeof document !== "undefined") {
      document.addEventListener("turbo:load", () => {
        if (DismissableController.#scrimCount === 0 && document.body?.style.pointerEvents === "none") {
          document.body.style.pointerEvents = ""
        }
      })
    }
  }

  #unsubscribeEscape = null
  #unsubscribeBeforeCache = null
  #onPointerdown = (event) => this.#handlePointerdown(event)

  /**
   * Registers on the layer stack, wires the capture-phase Escape and
   * pointerdown listeners, subscribes the before-cache dismissal, and
   * takes the body scrim when configured.
   */
  connect() {
    DismissableController.stack.push(this)

    // Both capture-phase: the layer must see the interaction before any
    // inner handler can swallow it (the escape helper defaults to capture).
    this.#unsubscribeEscape = onEscapeKeydown((event) => this.#handleEscape(event))
    document.addEventListener("pointerdown", this.#onPointerdown, { capture: true })
    // A layer still open when Turbo snapshots serializes its scrim's
    // inline body pointer-events into the cache - a restored page is
    // click-dead. Dismiss synchronously so the snapshot is clean, and
    // release the scrim HERE too: the owner's close resets its own
    // attributes in the same tick, but its unmount (which normally
    // releases the scrim via disconnect) can ride an exit transition -
    // after the snapshot is already taken.
    this.#unsubscribeBeforeCache = onBeforeCache(() => {
      this.#dismiss(null)
      // The dismiss just started the owner's exit presence - flush it in
      // the same tick so hidden + layer-controller removal land BEFORE
      // the snapshot (a serialized live layer resurrects on restore).
      flushPendingExits()
      this.#disableScrim()
    })

    if (this.disableOutsidePointerEventsValue) this.#enableScrim()
  }

  /**
   * Leaves the stack and unwires everything, releasing the scrim when
   * held.
   */
  disconnect() {
    const index = DismissableController.stack.indexOf(this)

    if (index !== -1) DismissableController.stack.splice(index, 1)

    this.#unsubscribeEscape?.()
    this.#unsubscribeEscape = null
    document.removeEventListener("pointerdown", this.#onPointerdown, { capture: true })
    this.#unsubscribeBeforeCache?.()
    this.#unsubscribeBeforeCache = null

    if (this.disableOutsidePointerEventsValue) this.#disableScrim()
  }

  #handleEscape(event) {
    if (!this.#topmost()) return

    this.#dismiss(event)
  }

  // pointerdown, not click: dismissal happens on press (Radix), so a drag
  // that starts inside can never end up counting as outside.
  #handlePointerdown(event) {
    // A target already unhooked from the document (a Turbo morph or an
    // earlier handler removed it mid-gesture) says nothing about WHERE the
    // press landed - dismissing on it is the false-dismiss class.
    if (!(event.target instanceof Element) || !event.target.isConnected) return

    // composedPath, not contains(): the path is fixed at dispatch, so a
    // press on a node an inner handler removes (a chip, a swapped row)
    // still counts as inside - and shadow-DOM retargeting can't hide it.
    const path = event.composedPath()

    if (path.includes(this.element)) return
    // A press inside a HIGHER layer (a nested overlay, often portaled out
    // of this subtree) is inside the stack, not "outside" this layer.
    if (this.#layersAbove().some((layer) => path.includes(layer.element))) return
    // The top layer (toasts) sits above EVERY dismissal layer by fiat:
    // pressing a toast must never dismiss the overlay under it.
    if (event.target.closest("[data-poetry-top-layer]")) return

    const interactOutside = this.dispatch("interact-outside", {
      detail: { originalEvent: event },
      cancelable: true
    })

    if (interactOutside.defaultPrevented) return // consumer veto: no dismiss

    this.#dismiss(event)
  }

  #dismiss(originalEvent) {
    this.dispatch("dismiss", { detail: { originalEvent } })
  }

  #topmost() {
    return DismissableController.stack.at(-1) === this
  }

  #layersAbove() {
    return DismissableController.stack.slice(DismissableController.stack.indexOf(this) + 1)
  }

  // Per-instance flag so enable/disable pair exactly once: the
  // before-cache release and the later disconnect (after the owner's
  // deferred unmount) must not double-decrement.
  #scrimEnabled = false

  #enableScrim() {
    if (this.#scrimEnabled) return

    this.#scrimEnabled = true

    if (DismissableController.#scrimCount === 0) {
      // Never save a value this scrim itself writes: a page restored from
      // a cached snapshot arrives with the serialized "none" already on
      // the body, and saving it would make every later restore re-freeze
      // the page (the poisoned-previous restore class).
      const current = document.body.style.pointerEvents
      DismissableController.#previousBodyPointerEvents = current === "none" ? "" : current
      document.body.style.pointerEvents = "none"
    }

    DismissableController.#scrimCount += 1
    this.element.style.pointerEvents = "auto"
  }

  #disableScrim() {
    if (!this.#scrimEnabled) return

    this.#scrimEnabled = false
    DismissableController.#scrimCount -= 1
    this.element.style.pointerEvents = ""

    if (DismissableController.#scrimCount === 0) {
      document.body.style.pointerEvents = DismissableController.#previousBodyPointerEvents ?? ""
      DismissableController.#previousBodyPointerEvents = null
    }
  }
}
