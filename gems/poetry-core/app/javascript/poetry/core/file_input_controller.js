import { Controller } from "@hotwired/stimulus"
import { formatFileSize } from "@poetry/controllers/helpers/file_size"

const EVENT_PREFIX = "poetry:file-input"

/**
 * The FileInput dropzone's reflection: the component renders a <label>
 * wrapping a visually-hidden native <input type=file>, so click-to-browse
 * and keyboard access are the PLATFORM's, and the file-drop controller
 * beside this one takes drops, pastes and picker selections through the
 * accept, size and count checks. This controller only shows the result:
 * the selected-file list, the rejections, the populated state and the
 * clear affordance. The native input stays the single source of truth
 * (its FileList is the form value; ActiveStorage direct upload rides it
 * untouched).
 */
export default class FileInputController extends Controller {
  // The events this controller dispatches (manifest surface;
  // events_declaration.test.js enforces the list stays honest).
  static events = ["poetry:file-input:change"]

  static targets = ["input", "list", "errors", "clear"]
  static values = {
    // Whether more than one file may be chosen; the file-drop controller enforces it.
    multiple: { type: Boolean, default: false }
  }

  /** Reflects the input's current FileList (list, clear, data-populated). */
  connect() {
    this.#reflect()
  }

  /**
   * The file-drop controller's files action (drop, paste and picker land
   * here): reflects the selection, shows the rejections and reports the
   * file names.
   *
   * @param {CustomEvent} event - detail holds accepted, rejected, source and files
   */
  files(event) {
    this.#reflect()
    this.#reject(event.detail?.rejected ?? [])
    this.dispatch("change", {
      prefix: EVENT_PREFIX,
      detail: { names: this.#files().map((file) => file.name) }
    })
  }

  /**
   * The clear button's click action: empties the input and dispatches a
   * real change, which the file-drop controller hears as a cleared
   * selection.
   *
   * @param {MouseEvent} event
   */
  clear(event) {
    // The clear button sits INSIDE the label: without this, the click
    // also re-opens the file picker.
    event.preventDefault()
    event.stopPropagation()
    this.inputTarget.value = ""
    this.inputTarget.dispatchEvent(new Event("change", { bubbles: true }))
    this.#reflect()
    this.#reject([])
  }

  /**
   * The input's current selection.
   *
   * @returns {File[]}
   */
  #files() {
    return Array.from(this.inputTarget.files ?? [])
  }

  /**
   * Rebuilds the selected-file list - BUILT, never innerHTML'd (names are
   * user input); data-populated on the root is the styling hook for the
   * empty/filled swap.
   */
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
      size.textContent = formatFileSize(file.size)
      item.append(name, size)
      this.listTarget.append(item)
    }
  }

  /**
   * Fills the rejections list (role=alert, so a screen reader hears it
   * fill), one line per file naming every reason; hidden when empty.
   *
   * @param {Array<{ file: File, errors: Array<{ message: string }> }>} rejections
   */
  #reject(rejections) {
    if (!this.hasErrorsTarget) return

    this.errorsTarget.textContent = ""
    for (const { file, errors } of rejections) {
      const item = document.createElement("li")

      item.setAttribute("data-slot", "file-input-error")
      item.textContent = errors.map((error) => error.message).join(" ") || file.name
      this.errorsTarget.append(item)
    }
    this.errorsTarget.hidden = rejections.length === 0
  }
}
