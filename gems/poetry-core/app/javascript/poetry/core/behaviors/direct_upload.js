// useDirectUpload: Active Storage direct uploads for one connect, Rails'
// own DirectUpload class behind a queue with progress, cancel, retry and
// remove. Each finished upload lands as a hidden input carrying the
// blob's signed id under the field's name, so the form posts ids, never
// bytes. The class loads through the host's importmap on first use, as a
// dynamic import: a static one would fail the whole module graph in a
// host without the pin, this fails one upload with a message. The form's
// submit is held while anything is in flight, and teardown aborts what
// is still running.
//
// useDirectUploadEvents is the other mode: Rails' own submit-time
// uploads, read from the direct-upload:* events the input dispatches, so
// a component can show the same rows while Rails does the work.
import { scopeOf } from "@poetry/controllers/helpers/scope"

const MODULE = "@rails/activestorage"

const UPLOAD_MESSAGES = Object.freeze({
  unavailable: "Uploads are unavailable: the page could not load Active Storage",
  failed: "{name} could not be uploaded",
  busy: "Wait for the uploads to finish"
})

let loader = null

/**
 * Rails' DirectUpload class, loaded once per page through the importmap
 * (`pin "@rails/activestorage"`); a host without the pin rejects here
 * and nowhere else.
 *
 * @returns {Promise<Function>} the DirectUpload constructor
 */
export function loadDirectUpload() {
  loader ??= import(/* @vite-ignore */ MODULE).then((module) => module.DirectUpload)

  return loader
}

/**
 * @typedef {Object} UploadEntry
 * @property {string} id - the queue's own id
 * @property {File} file - the file
 * @property {"queued" | "uploading" | "done" | "error" | "cancelled" | "removed"} state
 * @property {number} progress - 0 to 100, from the storage request
 * @property {Object | null} blob - the blob's attributes once stored (signed_id, filename, byte_size, content_type)
 * @property {string | null} error - the translated failure, in the error state
 * @property {string | null} detail - what Rails said, in the error state
 */

/**
 * An upload queue for the controller's current connect.
 *
 * @param {Object} controller - the Stimulus controller instance
 * @param {Object} options
 * @param {string} options.url - the direct uploads endpoint
 * @param {HTMLInputElement | null} [options.input] - the native file input; hidden inputs land before it
 * @param {string} [options.name] - the hidden inputs' field name; the input's name by default
 * @param {HTMLFormElement | null} [options.form] - the form whose submit waits; the input's form by default
 * @param {number} [options.concurrency] - how many uploads run at once
 * @param {Object<string, string>} [options.headers] - extra headers on the blob request
 * @param {boolean} [options.withCredentials] - whether both requests send credentials
 * @param {Object<string, string>} [options.messages] - unavailable, failed and busy, with a {name} token
 * @param {() => Promise<Function>} [options.load] - how the DirectUpload class is found; the importmap by default
 * @param {(entry: UploadEntry) => void} [options.onChange] - hears every change to an entry
 * @param {() => void} [options.onBlocked] - hears a submit held back by uploads in flight
 * @returns {{ enqueue: (files: File[]) => UploadEntry[], cancel: (id: string) => void, retry: (id: string) => void,
 *   remove: (id: string) => void, cancelAll: () => void, busy: () => boolean, entries: () => UploadEntry[],
 *   entry: (id: string) => UploadEntry | undefined }}
 */
export function useDirectUpload(controller, {
  url,
  input = null,
  name = input?.name ?? "",
  form = input?.form ?? null,
  concurrency = 3,
  headers = {},
  withCredentials = false,
  messages = {},
  load = loadDirectUpload,
  onChange = () => {},
  onBlocked = () => {}
} = {}) {
  const scope = scopeOf(controller)
  const entries = new Map()
  let counter = 0
  let active = 0

  const message = (key, entry) =>
    (messages[key] ?? UPLOAD_MESSAGES[key] ?? key).replace("{name}", entry?.file?.name ?? "")

  const busy = () => [...entries.values()].some((entry) => entry.state === "queued" || entry.state === "uploading")

  const land = (entry, blob) => {
    entry.blob = blob
    entry.state = "done"
    entry.progress = 100
    if (!name) return

    const hidden = document.createElement("input")

    hidden.type = "hidden"
    hidden.name = name
    hidden.value = blob.signed_id
    hidden.setAttribute("data-poetry-upload", entry.id)
    if (input) input.insertAdjacentElement("beforebegin", hidden)
    else form?.append(hidden)
    entry.hidden = hidden
  }

  const fail = (entry, key, error = null) => {
    entry.state = "error"
    entry.progress = 0
    entry.error = message(key, entry)
    entry.detail = error ? String(error) : null
  }

  const pump = () => {
    for (const entry of entries.values()) {
      if (active >= concurrency) return
      if (entry.state === "queued") start(entry)
    }
  }

  const finish = (entry) => {
    active -= 1
    onChange(entry)
    pump()
  }

  const delegate = (entry) => ({
    directUploadWillCreateBlobWithXHR(xhr) {
      entry.xhr = xhr
      if (withCredentials) xhr.withCredentials = true
    },
    directUploadWillStoreFileWithXHR(xhr) {
      entry.xhr = xhr
      if (withCredentials) xhr.withCredentials = true
      xhr.upload?.addEventListener("progress", (event) => {
        if (!event.lengthComputable || entry.state !== "uploading") return

        entry.progress = Math.round((event.loaded / event.total) * 100)
        onChange(entry)
      })
    }
  })

  // The body runs synchronously up to the first await, so the active count
  // and the uploading state land before pump looks again.
  const start = async (entry) => {
    entry.state = "uploading"
    entry.progress = 0
    entry.error = null
    entry.detail = null
    active += 1
    onChange(entry)

    let DirectUpload

    try {
      DirectUpload = await load()
    } catch (error) {
      if (entry.state !== "uploading") return

      fail(entry, "unavailable", error)
      finish(entry)
      return
    }
    if (entry.state !== "uploading") return // cancelled while the class loaded

    new DirectUpload(entry.file, url, delegate(entry), headers).create((error, blob) => {
      entry.xhr = null
      if (entry.state !== "uploading") return // cancelled mid-flight: cancel settled the count

      if (error) fail(entry, "failed", error)
      else land(entry, blob)
      finish(entry)
    })
  }

  const enqueue = (files) => {
    const added = []

    for (const file of files) {
      counter += 1
      const entry = {
        id: `upload-${counter}`, file, state: "queued", progress: 0, blob: null, error: null, detail: null,
        hidden: null, xhr: null
      }

      entries.set(entry.id, entry)
      added.push(entry)
      onChange(entry)
    }
    pump()

    return added
  }

  const drop = (entry, state) => {
    if (entry.state === "uploading") {
      entry.state = state
      active -= 1
      entry.xhr?.abort()
    } else {
      entry.state = state
    }
    entry.hidden?.remove()
    entry.hidden = null
    entries.delete(entry.id)
    onChange(entry)
    pump()
  }

  const cancel = (id) => {
    const entry = entries.get(id)

    if (entry) drop(entry, "cancelled")
  }

  const remove = (id) => {
    const entry = entries.get(id)

    if (!entry) return
    if (entry.state === "queued" || entry.state === "uploading") drop(entry, "cancelled")
    else drop(entry, "removed")
  }

  const retry = (id) => {
    const entry = entries.get(id)

    if (!entry || entry.state !== "error") return

    entry.state = "queued"
    entry.error = null
    entry.detail = null
    onChange(entry)
    pump()
  }

  const cancelAll = () => {
    for (const entry of [...entries.values()]) drop(entry, "cancelled")
  }

  if (form) {
    scope.listen(form, "submit", (event) => {
      if (!busy()) return

      event.preventDefault()
      event.stopImmediatePropagation()
      onBlocked(message("busy"))
    }, { capture: true })
  }

  scope.defer(() => {
    for (const entry of entries.values()) {
      if (entry.state !== "uploading") continue

      entry.state = "cancelled"
      entry.xhr?.abort()
    }
  })

  return {
    enqueue, cancel, retry, remove, cancelAll, busy,
    entries: () => [...entries.values()],
    entry: (id) => entries.get(id)
  }
}

// Rails' events on the input, as the queue's own vocabulary.
const RAILS_EVENTS = Object.freeze({
  "direct-upload:initialize": "queued",
  "direct-upload:start": "uploading",
  "direct-upload:progress": "uploading",
  "direct-upload:error": "error",
  "direct-upload:end": "done"
})

/**
 * Rails' submit-time direct uploads on `input`, reported as entries in
 * the queue's vocabulary (queued, uploading with progress, error, done),
 * for the controller's current connect. The error alert Rails would show
 * is cancelled; the message goes to the entry instead.
 *
 * @param {Object} controller - the Stimulus controller instance
 * @param {HTMLInputElement} input - the native input Rails uploads from
 * @param {Object} [options]
 * @param {Object<string, string>} [options.messages] - failed, with a {name} token
 * @param {(entry: UploadEntry) => void} [options.onChange] - hears every change
 * @returns {() => void} stops listening early; teardown stops otherwise
 */
export function useDirectUploadEvents(controller, input, { messages = {}, onChange = () => {} } = {}) {
  const scope = scopeOf(controller)
  const entries = new Map()
  const stops = Object.entries(RAILS_EVENTS).map(([type, state]) => scope.listen(input, type, (event) => {
    const { id, file, progress, error } = event.detail ?? {}
    const entry = entries.get(id) ?? { id: `rails-${id}`, file, state: "queued", progress: 0, blob: null, error: null,
      detail: null }

    entries.set(id, entry)
    entry.state = state
    if (state === "uploading" && typeof progress === "number") entry.progress = Math.round(progress)
    if (state === "done") entry.progress = 100
    if (state === "error") {
      event.preventDefault() // Rails alerts otherwise
      entry.error = (messages.failed ?? UPLOAD_MESSAGES.failed).replace("{name}", file?.name ?? "")
      entry.detail = error ? String(error) : null
    }
    onChange(entry)
  }))

  return () => stops.forEach((stop) => stop())
}
