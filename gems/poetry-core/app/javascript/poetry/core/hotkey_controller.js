import { Controller } from "@hotwired/stimulus"
import { isEditingTarget, matchesHotkey } from "@poetry/controllers/helpers/hotkey"

// Declarative global shortcut (the upstream library use-hotkeys borrow, 2026-07-12):
// put the controller on any clickable element and declare the descriptor -
//
//   <a href="/inbox" data-controller="poetry--core--hotkey"
//      data-poetry--core--hotkey-keys-value="g+i">
//
// On match the controller dispatches a cancelable poetry--core--hotkey:pressed
// event, then clicks the host element (buttons, links, summary - anything
// click-activatable). Unmodified single-key descriptors stay inert while
// the user is typing in an input/textarea/select/contentEditable; combos
// carrying meta/ctrl/alt fire everywhere (the ⌘K convention).
export default class extends Controller {
  static values = {
    keys: { type: String, default: "" }
  }

  static events = ["poetry--core--hotkey:pressed"]

  #onKeydown = null

  connect() {
    if (this.keysValue === "") return

    this.#onKeydown = (event) => {
      if (!matchesHotkey(event, this.keysValue)) return
      if (isEditingTarget(event) && !this.#modified(event)) return

      event.preventDefault()
      const pressed = this.dispatch("pressed", { cancelable: true })
      if (!pressed.defaultPrevented) this.element.click()
    }
    window.addEventListener("keydown", this.#onKeydown)
  }

  disconnect() {
    if (!this.#onKeydown) return

    window.removeEventListener("keydown", this.#onKeydown)
    this.#onKeydown = null
  }

  #modified(event) {
    return event.metaKey || event.ctrlKey || event.altKey
  }
}
