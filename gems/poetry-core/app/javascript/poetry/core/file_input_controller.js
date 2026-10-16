import { Controller } from "@hotwired/stimulus"
import { useAnnounce } from "@poetry/controllers/behaviors/announce"
import { loadDirectUpload, useDirectUpload, useDirectUploadEvents } from "@poetry/controllers/behaviors/direct_upload"
import { formatFileSize } from "@poetry/controllers/helpers/file_size"
import { teardown } from "@poetry/controllers/helpers/scope"

const EVENT_PREFIX = "poetry:file-input"
const DROP_IDENTIFIER = "poetry--core--file-drop"

// The queue's states as the Attachment chip spells them.
const CHIP_STATE = Object.freeze({ queued: "idle", uploading: "uploading", done: "done", error: "error" })

/**
 * The FileInput dropzone's reflection: the component renders a <label>
 * wrapping a visually-hidden native <input type=file>, so click-to-browse
 * and keyboard access are the PLATFORM's, and the file-drop controller
 * beside this one takes drops, pastes and picker selections through the
 * accept, size and count checks. This controller shows the result: one
 * Attachment chip per file, cloned from the server's template, with the
 * rejections, the populated state and the clear affordance; and it runs
 * the uploads the component asked for. With upload "immediate" every
 * file goes to Active Storage as it lands, with progress, cancel, retry
 * and remove, and the form posts the signed ids the queue leaves as
 * hidden inputs; with "on_submit" Rails uploads at submit time and the
 * chips follow its events; with "none" the native input posts the bytes.
 */
export default class FileInputController extends Controller {
  // The events this controller dispatches (manifest surface;
  // events_declaration.test.js enforces the list stays honest).
  static events = ["poetry:file-input:change", "poetry:file-input:upload"]

  // How the DirectUpload class is found: the host's importmap by default;
  // a host that bundles its own, or a test, assigns a loader of its own.
  static loadDirectUpload = loadDirectUpload

  static targets = ["input", "items", "template", "errors", "clear"]
  static values = {
    // Whether more than one file may be chosen; the file-drop controller enforces it.
    multiple: { type: Boolean, default: false },
    // none, on_submit (Rails uploads at submit) or immediate (the queue uploads as files land).
    upload: { type: String, default: "none" },
    // The field name the hidden signed-id inputs carry in immediate mode.
    name: { type: String, default: "" },
    // The direct uploads endpoint, in immediate mode.
    url: { type: String, default: "" },
    // Whether image files show a thumbnail in their chip.
    preview: { type: Boolean, default: false },
    // The upload messages: unavailable, failed and busy, with a {name} token.
    messages: { type: Object, default: {} }
  }

  #rows = new Map()
  #uploads = null
  #announce = null

  /** Wires the upload mode and reflects the input's current selection. */
  connect() {
    this.#announce = useAnnounce(this)
    if (this.uploadValue === "immediate") {
      // The hidden inputs carry the field name once a file is stored; the
      // native input posts nothing itself. Without JavaScript it keeps the
      // name and posts the bytes, the multipart fallback.
      this.inputTarget.removeAttribute("name")
      this.#uploads = useDirectUpload(this, {
        url: this.urlValue,
        input: this.inputTarget,
        name: this.nameValue,
        messages: this.messagesValue,
        load: this.constructor.loadDirectUpload,
        onChange: (entry) => this.#upload(entry),
        onBlocked: (message) => this.#announce(message, "assertive")
      })
    } else if (this.uploadValue === "on_submit") {
      useDirectUploadEvents(this, this.inputTarget, {
        messages: this.messagesValue,
        onChange: (entry) => this.#upload(entry)
      })
    }
    this.#reflect()
  }

  /** Unbinds the queue and the listeners; the chips' object URLs are released. */
  disconnect() {
    teardown(this)
    for (const row of this.#rows.values()) this.#release(row)
    this.#rows.clear()
    this.#uploads = null
  }

  /**
   * The file-drop controller's files action (drop, paste, picker and a
   * removal land here): reflects the selection as chips, shows the
   * rejections, starts the uploads in immediate mode and reports the
   * file names.
   *
   * @param {CustomEvent} event - detail holds accepted, rejected, source and files
   */
  files(event) {
    this.#reflect()
    this.#reject(event.detail?.rejected ?? [])
    const accepted = event.detail?.accepted ?? []

    if (this.#uploads && accepted.length > 0) {
      for (const entry of this.#uploads.enqueue(accepted)) {
        const row = this.#rows.get(entry.file)

        if (row) row.entry = entry
      }
    }
    this.dispatch("change", {
      prefix: EVENT_PREFIX,
      detail: { names: this.#files().map((file) => file.name) }
    })
  }

  /**
   * A chip's remove action: the upload is cancelled or its signed id
   * dropped, and the file leaves the selection through the file-drop
   * controller, which reports back into files.
   *
   * @param {MouseEvent} event
   */
  remove(event) {
    event.preventDefault()
    event.stopPropagation()
    const row = this.#rowOf(event.currentTarget)

    if (!row) return
    if (row.entry) this.#uploads?.remove(row.entry.id)
    const drop = this.#drop

    if (drop) drop.removeFile(row.file)
    else this.#forget(row)
  }

  /**
   * A chip's retry action: a failed upload goes back into the queue.
   *
   * @param {MouseEvent} event
   */
  retry(event) {
    event.preventDefault()
    event.stopPropagation()
    const row = this.#rowOf(event.currentTarget)

    if (row?.entry) this.#uploads?.retry(row.entry.id)
  }

  /**
   * The clear button's click action: cancels every upload, empties the
   * input and dispatches a real change, which the file-drop controller
   * hears as a cleared selection.
   *
   * @param {MouseEvent} event
   */
  clear(event) {
    // Without this, a clear button inside the label also re-opens the
    // file picker.
    event.preventDefault()
    event.stopPropagation()
    this.#uploads?.cancelAll()
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
   * The file-drop controller beside this one, when it is connected.
   *
   * @returns {Object | null}
   */
  get #drop() {
    return this.application.getControllerForElementAndIdentifier(this.element, DROP_IDENTIFIER) ?? null
  }

  /**
   * Keeps one chip per file in the selection: new files get a chip, gone
   * files lose theirs; data-populated on the root is the styling hook for
   * the empty/filled swap.
   */
  #reflect() {
    const files = this.#files()

    for (const row of [...this.#rows.values()]) {
      if (!files.includes(row.file)) this.#forget(row)
    }
    for (const file of files) {
      if (!this.#rows.has(file)) this.#add(file)
    }
    this.element.toggleAttribute("data-populated", files.length > 0)
    if (this.hasClearTarget) this.clearTarget.hidden = files.length === 0
  }

  /**
   * One chip, cloned from the server's template and filled (textContent,
   * never innerHTML: names are user input).
   *
   * @param {File} file
   */
  #add(file) {
    if (!this.hasTemplateTarget || !this.hasItemsTarget) return

    const element = this.templateTarget.content.firstElementChild?.cloneNode(true)

    if (!element) return

    const row = { file, element, entry: null, url: null }
    const title = element.querySelector("[data-slot=attachment-title]")
    const description = element.querySelector("[data-slot=attachment-description]")

    if (title) title.textContent = file.name
    if (description) description.textContent = formatFileSize(file.size)
    element.setAttribute("data-upload-state", this.#uploads ? "idle" : "done")
    this.#thumbnail(row)
    this.itemsTarget.append(element)
    this.#rows.set(file, row)
  }

  /**
   * An image file's thumbnail in the chip's media slot, from an object
   * URL released when the chip goes.
   *
   * @param {{ file: File, element: Element, url: string | null }} row
   */
  #thumbnail(row) {
    if (!this.previewValue || !row.file.type.startsWith("image/")) return
    if (typeof URL.createObjectURL !== "function") return

    const media = row.element.querySelector("[data-slot=attachment-media]")

    if (!media) return

    row.url = URL.createObjectURL(row.file)
    media.setAttribute("data-variant", "image")
    media.textContent = ""
    const image = document.createElement("img")

    image.src = row.url
    image.alt = ""
    media.append(image)
  }

  /**
   * Drops a chip: its upload if any, its object URL, its element.
   *
   * @param {{ file: File, element: Element, entry: Object | null, url: string | null }} row
   */
  #forget(row) {
    if (row.entry && this.#uploads) this.#uploads.remove(row.entry.id)
    this.#release(row)
    row.element.remove()
    this.#rows.delete(row.file)
  }

  /**
   * Releases a chip's object URL.
   *
   * @param {{ url: string | null }} row
   */
  #release(row) {
    if (row.url && typeof URL.revokeObjectURL === "function") URL.revokeObjectURL(row.url)
    row.url = null
  }

  /**
   * The chip a button inside it belongs to.
   *
   * @param {Element} button
   * @returns {Object | null}
   */
  #rowOf(button) {
    const element = button?.closest("[data-slot=attachment]")

    if (!element) return null
    for (const row of this.#rows.values()) {
      if (row.element === element) return row
    }

    return null
  }

  /**
   * An upload's change, drawn on its chip: the state, the progress bar,
   * the failure text and the retry affordance; reported to the host.
   *
   * @param {Object} entry - the queue's entry
   */
  #upload(entry) {
    const row = this.#rows.get(entry.file)

    if (!row) return
    if (entry.state === "cancelled" || entry.state === "removed") {
      row.entry = null
      return
    }
    row.entry = entry
    row.element.setAttribute("data-upload-state", CHIP_STATE[entry.state] ?? "done")
    const description = row.element.querySelector("[data-slot=attachment-description]")

    if (description) description.textContent = entry.state === "error" ? entry.error : formatFileSize(entry.file.size)
    const bar = row.element.querySelector("[data-slot=attachment-progress]")

    if (bar) {
      bar.hidden = entry.state !== "uploading"
      bar.setAttribute("aria-valuenow", String(entry.progress))
      const indicator = bar.querySelector("[data-slot=progress-indicator]")
      const readout = bar.querySelector("[data-slot=progress-value]")

      if (indicator) indicator.style.width = `${entry.progress}%`
      if (readout) readout.textContent = `${entry.progress}%`
    }
    const retry = row.element.querySelector("[data-upload-action=retry]")

    if (retry) retry.hidden = entry.state !== "error"
    this.dispatch("upload", {
      prefix: EVENT_PREFIX,
      detail: { state: entry.state, file: entry.file, blob: entry.blob, error: entry.error, progress: entry.progress }
    })
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
