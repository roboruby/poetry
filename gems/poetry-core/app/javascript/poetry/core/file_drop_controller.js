import { Controller } from "@hotwired/stimulus"
import { useFileDrop } from "@poetry/controllers/behaviors/file_drop"
import { teardown } from "@poetry/controllers/helpers/scope"

const EVENT_PREFIX = "poetry:file-drop"

/**
 * The file-drop behavior's controller: files arrive on this element by
 * drop, picker or paste, are checked against accept, size and count, and
 * land in the native input inside it (the input target, or the first
 * file input below). Values only, zero actions: the behavior binds the
 * zone, the document and the paste listeners in connect, through the
 * scope. A component listens for the files event to reflect the
 * selection, and a trigger outside the label may call open.
 */
export default class FileDropController extends Controller {
  // The events this controller dispatches (manifest surface;
  // events_declaration.test.js enforces the list stays honest).
  static events = ["poetry:file-drop:files", "poetry:file-drop:drag"]

  static targets = ["input"]
  static values = {
    // The native accept list; empty takes everything.
    accept: { type: String, default: "" },
    // Whether the selection may hold several files; a single zone keeps the first.
    multiple: { type: Boolean, default: false },
    // The most files the selection may hold; 0 is unlimited.
    maxFiles: { type: Number, default: 0 },
    // The largest file in bytes; 0 is unlimited.
    maxSize: { type: Number, default: 0 },
    // The smallest file in bytes.
    minSize: { type: Number, default: 0 },
    // Whether a paste carrying files lands here.
    paste: { type: Boolean, default: false },
    // Whether the whole page is the drop target, with data-drag-global while files are over it.
    overlay: { type: Boolean, default: false },
    // Whether dropped folders are walked for their files.
    directory: { type: Boolean, default: false },
    // Whether a drop outside the zone is swallowed instead of navigating to the file.
    preventDocumentDrop: { type: Boolean, default: true },
    // Rejection messages by code, with {name}, {size}, {count} and {reason} tokens.
    messages: { type: Object, default: {} }
  }

  #drop = null

  /** Binds the intake for this connect. */
  connect() {
    this.#drop = useFileDrop(this, {
      input: this.#input,
      accept: this.acceptValue,
      multiple: this.multipleValue,
      maxFiles: this.maxFilesValue,
      maxSize: this.maxSizeValue,
      minSize: this.minSizeValue,
      paste: this.pasteValue,
      overlay: this.overlayValue,
      directory: this.directoryValue,
      preventDocumentDrop: this.preventDocumentDropValue,
      messages: this.messagesValue,
      onFiles: (report) => this.dispatch("files", { prefix: EVENT_PREFIX, detail: report }),
      onDrag: (verdict) => this.dispatch("drag", { prefix: EVENT_PREFIX, detail: { verdict } })
    })
  }

  /** Unbinds everything the connect bound. */
  disconnect() {
    teardown(this)
    this.#drop = null
  }

  /**
   * Opens the native picker: the action for a trigger that is not the
   * label (a button beside the zone).
   *
   * @param {Event} [event]
   */
  open(event) {
    event?.preventDefault()
    this.#drop?.open()
  }

  /**
   * Empties the selection.
   *
   * @param {Event} [event]
   */
  clear(event) {
    event?.preventDefault()
    this.#drop?.clear()
  }

  /**
   * The native input: the target when declared, else the first file
   * input below.
   *
   * @returns {HTMLInputElement | null}
   */
  get #input() {
    if (this.hasInputTarget) return this.inputTarget

    return this.element.querySelector("input[type=file]")
  }
}
