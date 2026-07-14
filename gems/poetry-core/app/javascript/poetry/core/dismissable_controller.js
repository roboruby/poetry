import { Controller } from "@hotwired/stimulus"
import { onEscapeKeydown } from "@poetry/controllers/helpers/escape"

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

  #unsubscribeEscape = null
  #onPointerdown = (event) => this.#handlePointerdown(event)

  connect() {
    DismissableController.stack.push(this)

    // Both capture-phase: the layer must see the interaction before any
    // inner handler can swallow it (the escape helper defaults to capture).
    this.#unsubscribeEscape = onEscapeKeydown((event) => this.#handleEscape(event))
    document.addEventListener("pointerdown", this.#onPointerdown, { capture: true })

    if (this.disableOutsidePointerEventsValue) this.#enableScrim()
  }

  disconnect() {
    const index = DismissableController.stack.indexOf(this)

    if (index !== -1) DismissableController.stack.splice(index, 1)

    this.#unsubscribeEscape?.()
    this.#unsubscribeEscape = null
    document.removeEventListener("pointerdown", this.#onPointerdown, { capture: true })

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

  #enableScrim() {
    if (DismissableController.#scrimCount === 0) {
      DismissableController.#previousBodyPointerEvents = document.body.style.pointerEvents
      document.body.style.pointerEvents = "none"
    }

    DismissableController.#scrimCount += 1
    this.element.style.pointerEvents = "auto"
  }

  #disableScrim() {
    DismissableController.#scrimCount -= 1
    this.element.style.pointerEvents = ""

    if (DismissableController.#scrimCount === 0) {
      document.body.style.pointerEvents = DismissableController.#previousBodyPointerEvents ?? ""
      DismissableController.#previousBodyPointerEvents = null
    }
  }
}
