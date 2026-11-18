// useFileDrop: files arriving by drop, picker or paste for one connect,
// checked against accept, size and count before they reach the native
// input. The zone's drag listeners, the document guard, the overlay
// counter and the paste listener bind through the scope, so
// teardown(controller) unbinds them. The native input stays the form
// value: accepted files are mirrored into it through a DataTransfer and
// a real change event, so drop, paste and picker end in one pipeline and
// every listener on the input sees a picker-identical selection.
//
// Drag state uses an enter/leave COUNTER: dragenter and dragleave fire
// per descendant crossed, so a boolean flickers over child elements and
// Safari reported no relatedTarget for fifteen years; the counter nets
// out to zero only when the pointer truly leaves the zone.
import { formatFileSize } from "@poetry/controllers/helpers/file_size"
import { scopeOf } from "@poetry/controllers/helpers/scope"

/**
 * The rejection codes, react-dropzone's spelling, so a port's rulebook
 * maps them one to one.
 */
export const REJECTIONS = Object.freeze({
  type: "file-invalid-type",
  large: "file-too-large",
  small: "file-too-small",
  count: "too-many-files",
  invalid: "file-invalid"
})

// The English fallbacks; a component passes its translations as `messages`.
const REJECTION_MESSAGES = Object.freeze({
  [REJECTIONS.type]: "{name} is not an accepted file type",
  [REJECTIONS.large]: "{name} is larger than {size}",
  [REJECTIONS.small]: "{name} is smaller than {size}",
  [REJECTIONS.count]: "{name} was not added: at most {count} files",
  [REJECTIONS.invalid]: "{name}: {reason}"
})

// Files a folder walk leaves out.
const SKIPPED = new Set([".DS_Store", "Thumbs.db"])

/**
 * Whether a drag carries files: `types` holds "Files" (or Firefox's
 * legacy name), or an item is of kind file (some Chromium drags omit
 * the type and expose the item).
 *
 * @param {DataTransfer | null | undefined} transfer
 * @returns {boolean}
 */
export function carriesFiles(transfer) {
  if (!transfer) return false

  const types = Array.from(transfer.types ?? [])

  if (types.includes("Files") || types.includes("application/x-moz-file")) return true

  return Array.from(transfer.items ?? []).some((item) => item.kind === "file")
}

/**
 * A matcher for the native accept grammar: extensions (".pdf"), exact
 * types ("application/pdf") and wildcards ("image/*"), case-insensitive;
 * an empty accept, a bare "*" or the any-type wildcard takes everything.
 * A file without a type matches an extension, never a type.
 *
 * @param {string} accept - the comma-separated list
 * @returns {(type: string, name: string) => boolean}
 */
export function acceptMatcher(accept) {
  const tokens = String(accept ?? "").split(",").map((token) => token.trim().toLowerCase()).filter(Boolean)

  if (tokens.length === 0 || tokens.includes("*") || tokens.includes("*/*")) return () => true

  return (type, name) => {
    const lowerType = String(type ?? "").toLowerCase()
    const lowerName = String(name ?? "").toLowerCase()

    return tokens.some((token) => {
      if (token.startsWith(".")) return lowerName.endsWith(token)
      if (token.endsWith("/*")) return lowerType.startsWith(token.slice(0, -1))

      return lowerType === token
    })
  }
}

/**
 * The files under a dropped folder, walked through the entries API; a
 * plain file entry yields itself. Hidden housekeeping files are left out.
 *
 * @param {FileSystemEntry} entry
 * @returns {Promise<File[]>}
 */
async function filesOfEntry(entry) {
  if (!entry) return []
  if (entry.isFile) {
    if (SKIPPED.has(entry.name)) return []

    const file = await new Promise((resolve) => entry.file(resolve, () => resolve(null)))

    return file ? [file] : []
  }
  if (!entry.isDirectory) return []

  const reader = entry.createReader()
  const collected = []

  // readEntries returns a page at a time (Chromium: a hundred) and an
  // empty array once the folder is exhausted.
  for (;;) {
    const page = await new Promise((resolve) => reader.readEntries(resolve, () => resolve([])))

    if (page.length === 0) break
    for (const child of page) collected.push(...(await filesOfEntry(child)))
  }

  return collected
}

/**
 * The files a drop carries: a folder walk when asked for and the entries
 * API is there, else the plain file list.
 *
 * @param {DataTransfer | null | undefined} transfer
 * @param {boolean} directory - whether to walk folders
 * @returns {Promise<File[]>}
 */
async function filesOfDrop(transfer, directory) {
  const items = Array.from(transfer?.items ?? [])
  const entries = directory ? items.map((item) => item.webkitGetAsEntry?.()).filter(Boolean) : []

  if (entries.length > 0) {
    const walked = []

    for (const entry of entries) walked.push(...(await filesOfEntry(entry)))

    return walked
  }

  return Array.from(transfer?.files ?? [])
}

const sameFile = (a, b) => a.name === b.name && a.size === b.size && a.lastModified === b.lastModified

/**
 * @typedef {Object} FileRejection
 * @property {File} file - the file that did not pass
 * @property {Array<{ code: string, message: string }>} errors - why, in the REJECTIONS codes
 */

/**
 * @typedef {Object} FileDropReport
 * @property {File[]} accepted - the files that passed, in arrival order
 * @property {FileRejection[]} rejected - the files that did not
 * @property {"drop" | "paste" | "picker" | "clear" | "remove"} source - how they arrived, or that one left
 * @property {File[]} files - the whole selection the input now holds
 */

/**
 * Files for the controller's current connect: drop onto the zone (or the
 * whole page with `overlay`), the native picker, and paste when asked.
 * Accepted files land in the input; the report names both lists.
 *
 * @param {Object} controller - the Stimulus controller instance
 * @param {Object} [options]
 * @param {Element} [options.zone] - the drop target; the controller's element by default
 * @param {HTMLInputElement | null} [options.input] - the native file input the selection mirrors into
 * @param {Element} [options.state] - where data-dragging, data-drag-reject and data-drag-global are written; the zone by default
 * @param {string} [options.accept] - the native accept list; empty takes everything
 * @param {boolean} [options.multiple] - whether the selection may hold several files; a single zone keeps the first
 * @param {number} [options.maxFiles] - the most files the selection may hold; 0 is unlimited
 * @param {number} [options.maxSize] - the largest file, in bytes; 0 is unlimited
 * @param {number} [options.minSize] - the smallest file, in bytes
 * @param {boolean} [options.append] - whether new files join the selection or replace it; follows `multiple`
 * @param {((file: File) => string | null) | null} [options.validate] - a custom check returning the reason a file fails
 * @param {boolean} [options.paste] - whether a paste carrying files lands in the zone
 * @param {EventTarget} [options.pasteTarget] - where the paste listener binds; the zone by default
 * @param {boolean} [options.overlay] - whether the whole document is the drop target, with data-drag-global while files are over the window
 * @param {boolean} [options.directory] - whether dropped folders are walked for their files
 * @param {boolean} [options.preventDocumentDrop] - whether a drop outside the zone is swallowed instead of navigating to the file
 * @param {Object<string, string>} [options.messages] - rejection messages by code, with {name}, {size}, {count} and {reason} tokens
 * @param {(report: FileDropReport) => void} [options.onFiles] - hears every change to the selection
 * @param {(verdict: "none" | "accept" | "reject" | "unknown") => void} [options.onDrag] - hears the drag state as the pointer moves
 * @returns {{ open: () => void, clear: () => void, take: (files: File[], source: string) => void,
 *   remove: (file: File) => void, files: () => File[], dragging: () => boolean }}
 */
export function useFileDrop(controller, {
  zone = controller.element,
  input = null,
  state = zone,
  accept = "",
  multiple = false,
  maxFiles = 0,
  maxSize = 0,
  minSize = 0,
  append = multiple,
  validate = null,
  paste = false,
  pasteTarget = zone,
  overlay = false,
  directory = false,
  preventDocumentDrop = true,
  messages = {},
  onFiles = () => {},
  onDrag = () => {}
} = {}) {
  const scope = scopeOf(controller)
  const matches = acceptMatcher(accept)
  const limit = multiple ? Math.max(0, maxFiles) : 1
  let held = input ? Array.from(input.files ?? []) : []
  let depth = 0
  let globalDepth = 0
  let mirroring = false

  const disabled = () => Boolean(input?.disabled)

  const message = (code, file, extra = {}) => {
    const template = messages[code] ?? REJECTION_MESSAGES[code] ?? code
    const tokens = { name: file.name, size: formatFileSize(code === REJECTIONS.small ? minSize : maxSize),
      count: String(limit), ...extra }

    return template.replace(/\{(\w+)\}/g, (match, token) => (token in tokens ? tokens[token] : match))
  }

  const errorsOf = (file) => {
    const errors = []

    if (!matches(file.type, file.name)) errors.push({ code: REJECTIONS.type, message: message(REJECTIONS.type, file) })
    if (maxSize > 0 && file.size > maxSize) errors.push({ code: REJECTIONS.large, message: message(REJECTIONS.large, file) })
    if (minSize > 0 && file.size < minSize) errors.push({ code: REJECTIONS.small, message: message(REJECTIONS.small, file) })
    const reason = errors.length === 0 && validate ? validate(file) : null

    if (reason) errors.push({ code: REJECTIONS.invalid, message: message(REJECTIONS.invalid, file, { reason }) })

    return errors
  }

  // Rebuilds the input's FileList from `files` where the platform lets us
  // (DataTransfer, Safari 14.1 and up); without it the input keeps what
  // the platform put there. The synthetic change is marked so the picker
  // listener below ignores it.
  const mirror = (files) => {
    held = files

    if (!input) return

    try {
      if (typeof DataTransfer === "function") {
        const transfer = new DataTransfer()

        for (const file of files) transfer.items.add(file)
        input.files = transfer.files
      } else {
        input.files = files
      }
    } catch {
      // The engine has no constructible DataTransfer and no writable
      // files: the input stands as the platform left it.
    }
    mirroring = true
    try {
      input.dispatchEvent(new Event("change", { bubbles: true }))
    } finally {
      mirroring = false
    }
  }

  const report = (accepted, rejected, source) => onFiles({ accepted, rejected, source, files: held.slice() })

  /**
   * Runs `files` through the checks and lands the accepted ones.
   *
   * @param {File[]} files
   * @param {string} source - drop, paste or picker
   * @param {boolean} [fromInput] - whether the input already holds `files` (a picker selection)
   */
  const take = (files, source, fromInput = false) => {
    if (disabled()) return

    const base = append ? held.filter((kept) => !files.some((file) => sameFile(file, kept))) : []
    const accepted = []
    const rejected = []

    for (const file of files) {
      const errors = errorsOf(file)

      if (errors.length === 0 && limit > 0 && base.length + accepted.length >= limit) {
        errors.push({ code: REJECTIONS.count, message: message(REJECTIONS.count, file) })
      }
      if (errors.length > 0) rejected.push({ file, errors })
      else accepted.push(file)
    }

    const next = [...base, ...accepted]
    const untouched = fromInput && rejected.length === 0 && base.length === 0

    if (untouched) held = next
    else mirror(next)
    report(accepted, rejected, source)
  }

  const clearDrag = () => {
    depth = 0
    state.removeAttribute("data-dragging")
    state.removeAttribute("data-drag-reject")
  }

  // What the drag would do, from what a drag exposes: item types and the
  // count. Sizes are unreadable until the drop, and Safari exposes no
  // items mid-drag, hence "unknown".
  const verdict = (transfer) => {
    const items = Array.from(transfer?.items ?? []).filter((item) => item.kind === "file")

    if (items.length === 0) return "unknown"
    if (limit > 0 && multiple && items.length + (append ? held.length : 0) > limit) return "reject"
    if (items.every((item) => item.type && !matches(item.type, ""))) return "reject"

    return "accept"
  }

  const enter = (event) => {
    if (disabled() || !carriesFiles(event.dataTransfer)) return

    event.preventDefault()
    depth += 1
    if (depth > 1) return

    const judged = verdict(event.dataTransfer)

    state.setAttribute("data-dragging", "")
    state.toggleAttribute("data-drag-reject", judged === "reject")
    onDrag(judged)
  }

  const over = (event) => {
    if (disabled() || !carriesFiles(event.dataTransfer)) return

    event.preventDefault() // required, or the browser navigates to the file
    if (event.dataTransfer) event.dataTransfer.dropEffect = "copy"
  }

  const leave = () => {
    if (depth === 0) return

    depth -= 1
    if (depth > 0) return

    clearDrag()
    onDrag("none")
  }

  const drop = async (event) => {
    if (disabled() || !carriesFiles(event.dataTransfer)) return

    event.preventDefault()
    clearDrag()
    onDrag("none")
    take(await filesOfDrop(event.dataTransfer, directory), "drop")
  }

  scope.listen(zone, "dragenter", enter)
  scope.listen(zone, "dragover", over)
  scope.listen(zone, "dragleave", leave)
  scope.listen(zone, "drop", drop)

  if (input) {
    scope.listen(input, "change", () => {
      if (mirroring) return

      const chosen = Array.from(input.files ?? [])

      // The platform empties the selection on a cancelled re-pick and on
      // the component's own clear: nothing to check, nothing held.
      if (chosen.length === 0) {
        held = []
        report([], [], "clear")
        return
      }
      take(chosen, "picker", true)
    })
  }

  if (paste) {
    scope.listen(pasteTarget, "paste", (event) => {
      const files = Array.from(event.clipboardData?.files ?? [])

      // A text paste goes where it was going; only files are taken.
      if (files.length === 0 || disabled()) return

      event.preventDefault()
      take(files, "paste")
    })
  }

  const outside = (event) => !zone.contains(event.target)

  if (preventDocumentDrop || overlay) {
    scope.listen(document, "dragover", (event) => {
      if (outside(event) && carriesFiles(event.dataTransfer)) event.preventDefault()
    })
    scope.listen(document, "drop", (event) => {
      if (!outside(event) || !carriesFiles(event.dataTransfer)) return

      event.preventDefault()
      if (!overlay || disabled()) return

      globalDepth = 0
      state.removeAttribute("data-drag-global")
      filesOfDrop(event.dataTransfer, directory).then((files) => take(files, "drop"))
    })
  }

  if (overlay) {
    scope.listen(document, "dragenter", (event) => {
      if (disabled() || !carriesFiles(event.dataTransfer)) return

      globalDepth += 1
      state.setAttribute("data-drag-global", "")
    })
    scope.listen(document, "dragleave", () => {
      if (globalDepth === 0) return

      globalDepth -= 1
      if (globalDepth === 0) state.removeAttribute("data-drag-global")
    })
    // A drop anywhere (the zone's own handler runs first for drops on it)
    // ends the global drag.
    scope.listen(document, "drop", () => {
      globalDepth = 0
      state.removeAttribute("data-drag-global")
    })
  }

  scope.defer(() => {
    clearDrag()
    globalDepth = 0
    state.removeAttribute("data-drag-global")
  })

  return {
    /** Opens the native picker; call it from a user gesture. */
    open: () => {
      if (!disabled()) input?.click()
    },
    /** Empties the selection and reports it. */
    clear: () => {
      if (!input) {
        held = []
        report([], [], "clear")
        return
      }
      input.value = ""
      mirror([])
      report([], [], "clear")
    },
    take: (files, source = "drop") => take(Array.from(files), source),
    /**
     * Drops one file from the selection and reports it.
     *
     * @param {File} file
     */
    remove: (file) => {
      if (!held.includes(file)) return

      mirror(held.filter((kept) => kept !== file))
      report([], [], "remove")
    },
    files: () => held.slice(),
    dragging: () => depth > 0
  }
}
