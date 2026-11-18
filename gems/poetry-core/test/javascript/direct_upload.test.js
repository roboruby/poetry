import { beforeEach, describe, expect, it, vi } from "vitest"
import { useDirectUpload, useDirectUploadEvents } from "@poetry/controllers/behaviors/direct_upload"
import { hasScope, teardown } from "@poetry/controllers/helpers/scope"

// useDirectUpload JS-unit: the queue over Rails' DirectUpload - the
// concurrency cap, real progress from the storage request, the hidden
// signed-id input a finished upload leaves under the field name, failure
// with the translated message and retry, cancel through the kept request,
// remove, the submit held while anything is in flight, a loader that
// rejects (no pin), and teardown aborting what still runs. Then
// useDirectUploadEvents: Rails' submit-time events read as entries.

const settle = () => new Promise((resolve) => setTimeout(resolve, 0))

const file = (name, size = 10, type = "text/plain") => new File([new Uint8Array(size)], name, { type })

// A stand-in for @rails/activestorage's DirectUpload: the test drives the
// request it hands the delegate.
class FakeDirectUpload {
  static instances = []

  constructor(file, url, delegate, headers) {
    Object.assign(this, { file, url, delegate, headers, callback: null, xhr: null })
    FakeDirectUpload.instances.push(this)
  }

  create(callback) {
    this.callback = callback
    this.xhr = {
      withCredentials: false,
      aborted: false,
      upload: new EventTarget(),
      abort: () => {
        this.xhr.aborted = true
        callback("aborted", null)
      }
    }
    this.delegate?.directUploadWillCreateBlobWithXHR?.(this.xhr)
    this.delegate?.directUploadWillStoreFileWithXHR?.(this.xhr)
  }

  progress(loaded, total) {
    const event = new Event("progress")
    Object.assign(event, { lengthComputable: true, loaded, total })
    this.xhr.upload.dispatchEvent(event)
  }

  succeed(signedId = `sid-${this.file.name}`) {
    this.callback(null, { signed_id: signedId, filename: this.file.name, byte_size: this.file.size, content_type: this.file.type })
  }

  fail(message = "Error storing. Status: 500") {
    this.callback(message, null)
  }
}

const load = async () => FakeDirectUpload

describe("useDirectUpload", () => {
  let controller
  let form
  let input
  let changes

  beforeEach(() => {
    document.body.innerHTML = `<form id="form"><input id="input" type="file" name="post[files][]"></form>`
    form = document.getElementById("form")
    input = document.getElementById("input")
    controller = { element: form }
    changes = []
    FakeDirectUpload.instances = []
    return () => teardown(controller)
  })

  const queue = (options = {}) => useDirectUpload(controller, {
    url: "/rails/active_storage/direct_uploads", input, load,
    onChange: (entry) => changes.push(`${entry.file.name}:${entry.state}:${entry.progress}`),
    ...options
  })

  it("runs uploads up to the concurrency cap, reports real progress and lands a hidden signed id under the field name", async () => {
    const uploads = queue({ concurrency: 2 })

    uploads.enqueue([file("a.txt"), file("b.txt"), file("c.txt")])
    await settle()

    expect(FakeDirectUpload.instances.map((u) => u.file.name)).toEqual(["a.txt", "b.txt"])
    expect(uploads.busy()).toBe(true)
    expect(FakeDirectUpload.instances[0].url).toBe("/rails/active_storage/direct_uploads")

    FakeDirectUpload.instances[0].progress(5, 10)

    expect(changes.at(-1)).toBe("a.txt:uploading:50")

    FakeDirectUpload.instances[0].succeed("sid-a")
    await settle()

    const hidden = form.querySelector("input[type=hidden]")

    expect(hidden.name).toBe("post[files][]")
    expect(hidden.value).toBe("sid-a")
    expect(hidden.nextElementSibling).toBe(input)
    expect(uploads.entry(uploads.entries()[0].id).blob.signed_id).toBe("sid-a")
    expect(FakeDirectUpload.instances.map((u) => u.file.name)).toEqual(["a.txt", "b.txt", "c.txt"]) // the third started
  })

  it("a failure reads as an error with the translated message; retry queues it again", async () => {
    const uploads = queue({ messages: { failed: "{name} did not make it" } })
    const [entry] = uploads.enqueue([file("a.txt")])
    await settle()

    FakeDirectUpload.instances[0].fail("Status: 422")

    expect(entry.state).toBe("error")
    expect(entry.error).toBe("a.txt did not make it")
    expect(entry.detail).toBe("Status: 422")
    expect(form.querySelector("input[type=hidden]")).toBeNull()
    expect(uploads.busy()).toBe(false)

    uploads.retry(entry.id)
    await settle()

    expect(entry.state).toBe("uploading")
    FakeDirectUpload.instances[1].succeed()
    expect(entry.state).toBe("done")
    expect(form.querySelectorAll("input[type=hidden]").length).toBe(1)
  })

  it("cancel aborts the request and drops the entry; remove drops a finished entry's hidden input", async () => {
    const uploads = queue({ concurrency: 1 })
    const [first, second] = uploads.enqueue([file("a.txt"), file("b.txt")])
    await settle()

    uploads.cancel(first.id)

    expect(FakeDirectUpload.instances[0].xhr.aborted).toBe(true)
    expect(first.state).toBe("cancelled")
    expect(uploads.entries().map((e) => e.file.name)).toEqual(["b.txt"])
    await settle()

    expect(FakeDirectUpload.instances.map((u) => u.file.name)).toEqual(["a.txt", "b.txt"]) // the cancel freed the slot

    FakeDirectUpload.instances[1].succeed()

    expect(form.querySelectorAll("input[type=hidden]").length).toBe(1)

    uploads.remove(second.id)

    expect(form.querySelectorAll("input[type=hidden]").length).toBe(0)
    expect(second.state).toBe("removed")
    expect(uploads.entries()).toEqual([])
  })

  it("holds the form's submit while anything is in flight and lets it through after", async () => {
    const blocked = []
    const uploads = queue({ onBlocked: (message) => blocked.push(message) })
    uploads.enqueue([file("a.txt")])
    await settle()

    const held = new Event("submit", { bubbles: true, cancelable: true })
    form.dispatchEvent(held)

    expect(held.defaultPrevented).toBe(true)
    expect(blocked).toEqual(["Wait for the uploads to finish"])

    FakeDirectUpload.instances[0].succeed()
    const free = new Event("submit", { bubbles: true, cancelable: true })
    form.dispatchEvent(free)

    expect(free.defaultPrevented).toBe(false)
  })

  it("a loader that rejects (no pin) fails the entry with the unavailable message", async () => {
    const uploads = queue({ load: async () => { throw new Error("no pin") } })
    const [entry] = uploads.enqueue([file("a.txt")])
    await settle()

    expect(entry.state).toBe("error")
    expect(entry.error).toBe("Uploads are unavailable: the page could not load Active Storage")
    expect(entry.detail).toBe("Error: no pin")
    expect(uploads.busy()).toBe(false)
  })

  it("passes headers and credentials to both requests", async () => {
    queue({ headers: { "X-Thing": "1" }, withCredentials: true }).enqueue([file("a.txt")])
    await settle()

    expect(FakeDirectUpload.instances[0].headers).toEqual({ "X-Thing": "1" })
    expect(FakeDirectUpload.instances[0].xhr.withCredentials).toBe(true)
  })

  it("teardown aborts what is still running and drops the scope", async () => {
    const uploads = queue()
    const [entry] = uploads.enqueue([file("a.txt")])
    await settle()

    expect(hasScope(controller)).toBe(true)

    teardown(controller)

    expect(FakeDirectUpload.instances[0].xhr.aborted).toBe(true)
    expect(entry.state).toBe("cancelled")
    expect(hasScope(controller)).toBe(false)
  })

  it("without a field name no hidden input lands; without a form no submit guard binds", async () => {
    const lone = document.createElement("input")
    lone.type = "file"
    document.body.append(lone)
    const uploads = useDirectUpload(controller, { url: "/u", input: lone, load })
    uploads.enqueue([file("a.txt")])
    await settle()
    FakeDirectUpload.instances[0].succeed()

    expect(document.querySelector("input[type=hidden]")).toBeNull()
    expect(uploads.entries()[0].state).toBe("done")
  })
})

describe("useDirectUploadEvents", () => {
  it("reads Rails' submit-time events as entries and cancels the error alert", () => {
    document.body.innerHTML = `<form><input id="input" type="file"></form>`
    const input = document.getElementById("input")
    const controller = { element: input }
    const seen = []
    const chosen = file("a.txt")
    useDirectUploadEvents(controller, input, {
      messages: { failed: "{name} failed" },
      onChange: (entry) => seen.push([entry.state, entry.progress, entry.error])
    })
    const rails = (type, detail) => {
      const event = new CustomEvent(type, { bubbles: true, cancelable: true, detail })
      input.dispatchEvent(event)
      return event
    }

    rails("direct-upload:initialize", { id: 1, file: chosen })
    rails("direct-upload:start", { id: 1, file: chosen })
    rails("direct-upload:progress", { id: 1, file: chosen, progress: 33.3 })
    const error = rails("direct-upload:error", { id: 1, file: chosen, error: "Status: 500" })
    rails("direct-upload:end", { id: 1, file: chosen })

    expect(error.defaultPrevented).toBe(true)
    expect(seen).toEqual([
      ["queued", 0, null], ["uploading", 0, null], ["uploading", 33, null], ["error", 33, "a.txt failed"], ["done", 100, "a.txt failed"]
    ])
    teardown(controller)
    const after = vi.fn()
    seen.length = 0
    rails("direct-upload:start", { id: 2, file: chosen })

    expect(seen).toEqual([])
    expect(after).not.toHaveBeenCalled()
  })
})
