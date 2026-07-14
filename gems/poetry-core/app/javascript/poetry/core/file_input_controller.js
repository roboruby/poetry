import { Controller } from "@hotwired/stimulus"

// The FileInput dropzone engine (the review wave): the
// component renders a <label> wrapping a visually-hidden native
// <input type=file>, so click-to-browse and keyboard access are the
// PLATFORM's - this controller adds only what HTML cannot: drag-and-drop
// onto the label, the selected-file list, and the clear affordance. The
// native input stays the single source of truth (its FileList is the
// form value; ActiveStorage direct upload rides it untouched).
//
// Drag state uses an enter/leave COUNTER: dragenter/dragleave fire per
// descendant crossed, so a boolean flickers over child elements - the
// counter nets out to zero only when the pointer truly leaves the zone.
const EVENT_PREFIX = "poetry:file-input"

const UNITS = ["B", "KB", "MB", "GB"]

export default class FileInputController extends Controller {
  // The events this controller dispatches (manifest surface;
  // events_declaration.test.js enforces the list stays honest).
  static events = ["poetry:file-input:change"]

  static targets = ["input", "list", "clear"]
  static values = {
    multiple: { type: Boolean, default: false }
  }

  #dragDepth = 0

  connect() {
    this.#reflect()
  }

  // Actions on the dropzone label: dragenter/dragover/dragleave/drop.
  dragenter(event) {
    if (!this.#accepting(event)) return

    event.preventDefault()
    this.#dragDepth += 1
    this.element.setAttribute("data-dragging", "")
  }

  dragover(event) {
    if (!this.#accepting(event)) return

    event.preventDefault() // required, or the browser navigates to the file
  }

  dragleave() {
    this.#dragDepth = Math.max(0, this.#dragDepth - 1)
    if (this.#dragDepth === 0) this.element.removeAttribute("data-dragging")
  }

  drop(event) {
    if (!this.#accepting(event)) return

    event.preventDefault()
    this.#dragDepth = 0
    this.element.removeAttribute("data-dragging")

    const files = event.dataTransfer?.files

    if (!files || files.length === 0) return

    this.inputTarget.files = this.#normalized(files)
    // The programmatic assignment fires no native change - dispatch it so
    // form frameworks (and this controller's own change action) see the
    // selection exactly as a picker selection.
    this.inputTarget.dispatchEvent(new Event("change", { bubbles: true }))
  }

  // Action: change->...#changed on the native input (picker AND drop land here).
  changed() {
    this.#reflect()
    this.dispatch("change", {
      prefix: EVENT_PREFIX,
      detail: { names: this.#files().map((file) => file.name) }
    })
  }

  // Action: click->...#clear on the clear button.
  clear(event) {
    // The clear button sits INSIDE the label: without this, the click
    // also re-opens the file picker.
    event.preventDefault()
    event.stopPropagation()
    this.inputTarget.value = ""
    this.inputTarget.dispatchEvent(new Event("change", { bubbles: true }))
  }

  #files() {
    return Array.from(this.inputTarget.files ?? [])
  }

  // A drag from another application may carry no files (text, links) -
  // only file drags flip the zone into its accepting state.
  #accepting(event) {
    if (this.inputTarget.disabled) return false

    const types = event.dataTransfer?.types

    return Boolean(types && Array.from(types).includes("Files"))
  }

  // Single-file zones take the FIRST dropped file (the native picker's
  // rule). Built through a fresh DataTransfer where the platform provides
  // one; without it (older engines, some test DOMs) the multi-drop falls
  // back to the full list rather than throwing.
  #normalized(files) {
    if (this.multipleValue || files.length <= 1) return files
    if (typeof DataTransfer !== "function") return files

    try {
      const transfer = new DataTransfer()
      transfer.items.add(files[0])
      return transfer.files
    } catch {
      return files
    }
  }

  // The selected-file list is BUILT, never innerHTML'd (names are user
  // input); data-populated on the root is the styling hook for the
  // empty/filled swap.
  #reflect() {
    const files = this.#files()

    this.element.toggleAttribute("data-populated", files.length > 0)
    if (this.hasClearTarget) this.clearTarget.hidden = files.length === 0
    if (!this.hasListTarget) return

    this.listTarget.textContent = ""
    for (const file of files) {
      const item = document.createElement("li")

      item.setAttribute("data-slot", "file-input-item")
      const name = document.createElement("span")

      name.setAttribute("data-slot", "file-input-item-name")
      name.textContent = file.name
      const size = document.createElement("span")

      size.setAttribute("data-slot", "file-input-item-size")
      size.textContent = this.#formatSize(file.size)
      item.append(name, size)
      this.listTarget.append(item)
    }
  }

  #formatSize(bytes) {
    if (!Number.isFinite(bytes) || bytes < 0) return ""

    let value = bytes
    let unit = 0

    while (value >= 1024 && unit < UNITS.length - 1) {
      value /= 1024
      unit += 1
    }
    return `${unit === 0 ? value : value.toFixed(1)} ${UNITS[unit]}`
  }
}
