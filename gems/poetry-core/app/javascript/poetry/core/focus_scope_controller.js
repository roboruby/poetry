import { Controller } from "@hotwired/stimulus"
import { tabbableWithin } from "@poetry/controllers/helpers/tabbable"
import { ensureFocusGuards, removeFocusGuards } from "@poetry/controllers/helpers/focus_guards"
import { logicallyContains } from "@poetry/controllers/helpers/portal"

// The overlay focus scope (Tier 2, P2): traps Tab/Shift+Tab within the
// subtree, loops at the edges, and - the part to get exact - snapshots
// document.activeElement on connect and RESTORES it on disconnect (focus
// return). Backs Dialog-family overlays, Popover, Menus, Select, Command.
//
// Listeners are wired here, not as data-actions: pause/resume must attach
// and detach them dynamically as scopes stack, which data-action cannot do.
export default class FocusScopeController extends Controller {
  // The events this controller dispatches (manifest surface;
  // events_declaration.test.js enforces the list stays honest).
  static events = [
    "poetry--core--focus-scope:mount-auto-focus", "poetry--core--focus-scope:unmount-auto-focus"
  ]

  // Nested scopes: only the TOP scope has live listeners. Opening a child
  // pauses the parent; closing it resumes the parent (Radix's module-level
  // stack, verbatim - class-level here so it is shared and inspectable).
  static stack = []

  static values = {
    trapped: { type: Boolean, default: true },
    loop: { type: Boolean, default: true }
  }

  #active = false
  #guarded = false
  #previouslyFocused = null
  #lastFocusedWithin = null
  #onKeydown = (event) => this.#handleKeydown(event)
  #onFocusin = (event) => this.#handleFocusin(event)

  connect() {
    // The container is the focus fallback when the scope has no tabbables.
    if (!this.element.hasAttribute("tabindex")) this.element.setAttribute("tabindex", "-1")

    // Snapshot BEFORE any focus moves: this is where focus RETURNS to.
    this.#previouslyFocused = document.activeElement

    FocusScopeController.stack.at(-1)?.#pause()
    FocusScopeController.stack.push(this)
    this.#resume()

    if (this.trappedValue) {
      ensureFocusGuards()
      this.#guarded = true
    }

    // Cancelable: a consumer preventDefault()s to own initial focus itself
    // (e.g. Select focusing the active option, not the first tabbable).
    const mount = this.dispatch("mount-auto-focus", { cancelable: true })

    if (!mount.defaultPrevented) this.#focus(tabbableWithin(this.element)[0] ?? this.element)
  }

  disconnect() {
    const wasTop = FocusScopeController.stack.at(-1) === this
    const index = FocusScopeController.stack.indexOf(this)

    if (index !== -1) FocusScopeController.stack.splice(index, 1)

    this.#pause()

    if (wasTop) FocusScopeController.stack.at(-1)?.#resume()

    if (this.#guarded) {
      removeFocusGuards()
      this.#guarded = false
    }

    // Focus return, cancelable so a consumer can send focus elsewhere
    // (e.g. a submenu handing focus back to its subtrigger).
    const unmount = this.dispatch("unmount-auto-focus", { cancelable: true })

    if (!unmount.defaultPrevented && this.#previouslyFocused?.isConnected) {
      this.#previouslyFocused.focus()
    }

    this.#previouslyFocused = null
    this.#lastFocusedWithin = null
  }

  // Paused = no listeners at all: a paused parent neither traps nor loops
  // while a child scope is on top of it.
  #pause() {
    if (!this.#active) return

    this.#active = false
    this.element.removeEventListener("keydown", this.#onKeydown)
    document.removeEventListener("focusin", this.#onFocusin)
  }

  #resume() {
    if (this.#active) return

    this.#active = true
    this.element.addEventListener("keydown", this.#onKeydown)

    if (this.trappedValue) document.addEventListener("focusin", this.#onFocusin)
  }

  // Tab at the EDGES only: wrap under loop, hard-stop under trapped. A
  // mid-list Tab is the browser's job (Radix intervenes the same way).
  #handleKeydown(event) {
    if (event.key !== "Tab") return
    // A Tab mid-IME-composition commits the candidate text, it does not
    // navigate - intercepting it eats the commit (react-aria's guard).
    if (event.isComposing) return
    if (!this.trappedValue && !this.loopValue) return

    const candidates = tabbableWithin(this.element)

    if (candidates.length === 0) {
      event.preventDefault() // nothing to land on; focus stays on the container
      return
    }

    const first = candidates[0]
    const last = candidates[candidates.length - 1]

    if (!event.shiftKey && document.activeElement === last) {
      event.preventDefault()
      if (this.loopValue) this.#focus(first)
    } else if (event.shiftKey && document.activeElement === first) {
      event.preventDefault()
      if (this.loopValue) this.#focus(last)
    }
  }

  // trapped: focus escaping the scope (a body-edge guard sentinel, a
  // programmatic move, a click outside) is yanked back to the last focused
  // element within the scope.
  #handleFocusin(event) {
    // Logical containment: a portaled sub level (menus portal each sub on
    // its own open) sits outside the scope's SUBTREE but inside its tree.
    if (logicallyContains(this.element, event.target)) {
      this.#lastFocusedWithin = event.target
      return
    }

    this.#focus(this.#lastFocusedWithin ?? tabbableWithin(this.element)[0] ?? this.element)
  }

  #focus(element) {
    element?.focus?.()
  }
}
