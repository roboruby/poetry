import { Controller } from "@hotwired/stimulus"
import { announce } from "@poetry/controllers/helpers/announce"

// ClipboardText (the kumo contract): a read-only value with one
// copy affordance. navigator.clipboard is the primary path; the
// execCommand fallback SAVES AND RESTORES the user's own selection and
// focus (copying a field must never eat a selection made elsewhere on the
// page - the guard kumo's version carries). Success stamps data-copied on
// the root for a beat (CSS swaps the copy/check glyphs off it), announces
// through the live-region singleton, and dispatches the copied event.
const EVENT_PREFIX = "poetry:clipboard-text"
const COPIED_MS = 1500

export default class ClipboardTextController extends Controller {
  // The events this controller dispatches (manifest surface;
  // events_declaration.test.js enforces the list stays honest).
  static events = ["poetry:clipboard-text:copied"]

  static targets = ["input"]

  static values = {
    // Copy override: the full value when the display truncates (kumo's
    // textToCopy). Empty means "copy what the input shows".
    text: String,
    // The announcement, localized server-side.
    message: String
  }

  disconnect() {
    clearTimeout(this.#timer)
  }

  async copy() {
    const text = this.textValue !== "" ? this.textValue : this.inputTarget.value
    if (!(await this.#write(text))) return

    this.element.toggleAttribute("data-copied", true)
    clearTimeout(this.#timer)
    this.#timer = setTimeout(() => this.element.removeAttribute("data-copied"), COPIED_MS)

    if (this.messageValue !== "") announce(this.messageValue)
    this.dispatch("copied", { prefix: EVENT_PREFIX, detail: { text } })
  }

  #timer

  async #write(text) {
    try {
      await navigator.clipboard.writeText(text)
      return true
    } catch {
      return this.#execCommandFallback(text)
    }
  }

  // Legacy path: an offscreen textarea receives the value and the
  // selection, execCommand copies the LIVE selection - so the user's own
  // selection is cloned first and restored after, and focus goes back
  // where it was.
  #execCommandFallback(text) {
    const selection = document.getSelection()
    const savedRanges = []
    for (let index = 0; index < selection.rangeCount; index += 1) {
      savedRanges.push(selection.getRangeAt(index).cloneRange())
    }
    const savedFocus = document.activeElement

    const textarea = document.createElement("textarea")
    textarea.value = text
    textarea.setAttribute("readonly", "")
    textarea.setAttribute("aria-hidden", "true")
    textarea.style.position = "fixed"
    textarea.style.opacity = "0"
    this.element.appendChild(textarea)
    textarea.select()

    let copied = false
    try {
      copied = document.execCommand("copy")
    } catch {
      copied = false
    }

    textarea.remove()
    selection.removeAllRanges()
    for (const range of savedRanges) selection.addRange(range)
    if (savedFocus && savedFocus.isConnected) savedFocus.focus()

    return copied
  }
}
