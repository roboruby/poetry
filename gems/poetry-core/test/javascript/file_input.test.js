import { beforeEach, describe, expect, it, vi } from "vitest"
import { Application } from "@hotwired/stimulus"
import { registerPoetryControllers } from "@poetry/controllers"
import FileInputController from "@poetry/controllers/file_input_controller"

// poetry--core--file-input JS-unit: the dropzone's reflection beside the
// file-drop controller - a selection (picker or drop) becomes one chip per
// file cloned from the server's template (textContent, never innerHTML),
// flips data-populated and reveals clear; the rejections fill the
// role=alert list; remove drops a chip through the file-drop controller;
// clear empties everything and never re-opens the picker; image previews
// ride object URLs released with the chip; immediate mode runs the queue
// and draws its states, on-submit mode follows Rails' events. Click-to-
// browse is the <label>'s platform behavior - not JS, not here.

const nextFrame = () => new Promise((resolve) => setTimeout(resolve, 0))

const el = (id) => document.getElementById(id)

const file = (name, size = 10, type = "text/plain") => new File([new Uint8Array(size)], name, { type, lastModified: 0 })

// jsdom's input.files is not assignable with a plain array - swap it for
// a writable data property so the controllers' assignments land.
const writableFiles = (input) => {
  Object.defineProperty(input, "files", { writable: true, configurable: true, value: [] })
}

const drag = (type, files = [], types = ["Files"]) => {
  const event = new Event(type, { bubbles: true, cancelable: true })
  event.dataTransfer = { files, types, items: files.map((f) => ({ kind: "file", type: f.type })) }
  return event
}

const chips = () => Array.from(el("items").querySelectorAll("[data-slot=attachment]"))

const markup = ({ multiple = false, disabled = false, accept = "", upload = "none", preview = false } = {}) => `
  <form id="form">
  <div id="zone" data-slot="file-input" data-component="file-input"
       data-controller="poetry--core--file-drop poetry--core--file-input"
       data-poetry--core--file-drop-multiple-value="${multiple}"
       data-poetry--core--file-drop-accept-value="${accept}"
       data-poetry--core--file-input-multiple-value="${multiple}"
       data-poetry--core--file-input-upload-value="${upload}"
       data-poetry--core--file-input-name-value="post[files][]"
       data-poetry--core--file-input-url-value="/rails/active_storage/direct_uploads"
       data-poetry--core--file-input-preview-value="${preview}"
       data-poetry--core--file-input-messages-value='{"failed":"{name} failed","busy":"Hold on"}'
       data-action="poetry:file-drop:files->poetry--core--file-input#files">
    <label>
      <input id="input" type="file" name="post[files][]" ${multiple ? "multiple" : ""} ${disabled ? "disabled" : ""}
             data-poetry--core--file-drop-target="input"
             data-poetry--core--file-input-target="input">
      <span data-slot="file-input-prompt">Drag and drop</span>
    </label>
    <div id="items" data-poetry--core--file-input-target="items"></div>
    <ul id="errors" role="alert" hidden data-poetry--core--file-input-target="errors"></ul>
    <button id="clear" type="button" data-poetry--core--file-input-target="clear"
            data-action="click->poetry--core--file-input#clear">Clear</button>
    <template data-poetry--core--file-input-target="template">
      <div data-slot="attachment" data-upload-state="done">
        <div data-slot="attachment-media">F</div>
        <span data-slot="attachment-title"></span>
        <span data-slot="attachment-description"></span>
        <div data-slot="attachment-progress" role="progressbar" aria-valuenow="0" hidden>
          <div data-slot="progress-indicator"></div><span data-slot="progress-value"></span>
        </div>
        <button type="button" data-upload-action="retry" hidden data-action="click->poetry--core--file-input#retry">retry</button>
        <button type="button" data-upload-action="remove" data-action="click->poetry--core--file-input#remove">remove</button>
      </div>
    </template>
  </div>
  </form>`

// The stand-in for Rails' DirectUpload the immediate tests drive.
class FakeDirectUpload {
  static instances = []

  constructor(file, url, delegate) {
    Object.assign(this, { file, url, delegate, callback: null })
    FakeDirectUpload.instances.push(this)
  }

  create(callback) {
    this.callback = callback
    this.xhr = { upload: new EventTarget(), abort: () => callback("aborted", null) }
    this.delegate?.directUploadWillStoreFileWithXHR?.(this.xhr)
  }

  progress(loaded, total) {
    const event = new Event("progress")
    Object.assign(event, { lengthComputable: true, loaded, total })
    this.xhr.upload.dispatchEvent(event)
  }

  succeed() {
    this.callback(null, { signed_id: `sid-${this.file.name}`, filename: this.file.name })
  }

  fail() {
    this.callback("Status: 500", null)
  }
}

describe("poetry--core--file-input", () => {
  let application

  beforeEach(async () => {
    document.body.innerHTML = `<div id="host"></div>`
    application = Application.start()
    registerPoetryControllers(application)
    FakeDirectUpload.instances = []
    FileInputController.loadDirectUpload = async () => FakeDirectUpload
    await nextFrame()
    // The zone leaves the document before the application stops, so the
    // file-drop controller's document listeners go with it.
    return async () => {
      el("zone")?.remove()
      await nextFrame()
      application.stop()
    }
  })

  async function mount(options = {}) {
    el("host").innerHTML = markup(options)
    await nextFrame()
    writableFiles(el("input"))
  }

  const pick = async (...files) => {
    el("input").files = files
    el("input").dispatchEvent(new Event("change", { bubbles: true }))
    await nextFrame()
  }

  it("a picker change clones one chip per file (name + size), flips data-populated, reveals clear, dispatches", async () => {
    await mount()
    const seen = []
    el("zone").addEventListener("poetry:file-input:change", (event) => seen.push(event.detail.names))

    await pick(file("report.pdf", 2048))

    expect(chips().length).toBe(1)
    expect(chips()[0].querySelector("[data-slot=attachment-title]").textContent).toBe("report.pdf")
    expect(chips()[0].querySelector("[data-slot=attachment-description]").textContent).toBe("2.0 KB")
    expect(chips()[0].getAttribute("data-upload-state")).toBe("done")
    expect(el("zone").hasAttribute("data-populated")).toBe(true)
    expect(el("clear").hidden).toBe(false)
    expect(seen).toEqual([["report.pdf"]])
    expect(el("items").querySelector("template")).toBeNull()
  })

  it("the drag styling rides the root: two enters + one leave stay dragging; the second clears", async () => {
    await mount()

    el("zone").dispatchEvent(drag("dragenter"))
    el("zone").dispatchEvent(drag("dragenter")) // crossing INTO a child fires again

    expect(el("zone").hasAttribute("data-dragging")).toBe(true)

    el("zone").dispatchEvent(drag("dragleave"))

    expect(el("zone").hasAttribute("data-dragging")).toBe(true)

    el("zone").dispatchEvent(drag("dragleave"))

    expect(el("zone").hasAttribute("data-dragging")).toBe(false)
  })

  it("drop assigns the files to the native input and the chips follow; a later drop appends", async () => {
    await mount({ multiple: true })

    el("zone").dispatchEvent(drag("drop", [file("a.txt"), file("b.txt")]))
    await nextFrame()

    expect(Array.from(el("input").files).map((f) => f.name)).toEqual(["a.txt", "b.txt"])
    expect(chips().length).toBe(2)
    expect(el("errors").hidden).toBe(true)

    el("zone").dispatchEvent(drag("drop", [file("c.txt")]))
    await nextFrame()

    expect(chips().map((chip) => chip.querySelector("[data-slot=attachment-title]").textContent)).toEqual(["a.txt", "b.txt", "c.txt"])
  })

  it("a rejected file fills the role=alert list with its message, and the next clean drop empties it", async () => {
    await mount({ multiple: true, accept: ".txt" })

    el("zone").dispatchEvent(drag("drop", [file("a.txt"), file("b.png", 10, "image/png")]))
    await nextFrame()

    expect(chips().length).toBe(1)
    expect(el("errors").hidden).toBe(false)
    expect(el("errors").children.length).toBe(1)
    expect(el("errors").textContent).toContain("b.png")

    el("zone").dispatchEvent(drag("drop", [file("c.txt")]))
    await nextFrame()

    expect(el("errors").hidden).toBe(true)
    expect(chips().length).toBe(2)
  })

  it("a chip's remove button drops the file from the selection through the file-drop controller", async () => {
    await mount({ multiple: true })
    await pick(file("a.txt"), file("b.txt"))

    expect(chips().length).toBe(2)

    chips()[0].querySelector("[data-upload-action=remove]").click()
    await nextFrame()

    expect(Array.from(el("input").files).map((f) => f.name)).toEqual(["b.txt"])
    expect(chips().length).toBe(1)
    expect(chips()[0].querySelector("[data-slot=attachment-title]").textContent).toBe("b.txt")
  })

  it("image previews ride object URLs, released when the chip goes", async () => {
    const created = vi.fn(() => "blob:preview")
    const revoked = vi.fn()
    URL.createObjectURL = created
    URL.revokeObjectURL = revoked
    try {
      await mount({ multiple: true, preview: true })
      await pick(file("shot.png", 10, "image/png"), file("notes.txt"))

      const media = chips().map((chip) => chip.querySelector("[data-slot=attachment-media]"))

      expect(media[0].getAttribute("data-variant")).toBe("image")
      expect(media[0].querySelector("img").getAttribute("src")).toBe("blob:preview")
      expect(media[1].getAttribute("data-variant")).toBeNull()
      expect(created).toHaveBeenCalledTimes(1)

      chips()[0].querySelector("[data-upload-action=remove]").click()
      await nextFrame()

      expect(revoked).toHaveBeenCalledWith("blob:preview")
    } finally {
      delete URL.createObjectURL
      delete URL.revokeObjectURL
    }
  })

  it("clear empties the input, the chips, and the populated state - and never re-opens the picker", async () => {
    await mount()
    await pick(file("a.txt"))

    expect(el("zone").hasAttribute("data-populated")).toBe(true)

    const click = new MouseEvent("click", { bubbles: true, cancelable: true })
    el("input").files = []
    el("clear").dispatchEvent(click)
    await nextFrame()

    expect(click.defaultPrevented).toBe(true) // the label must not re-open the picker
    expect(el("zone").hasAttribute("data-populated")).toBe(false)
    expect(chips().length).toBe(0)
    expect(el("clear").hidden).toBe(true)
  })

  it("a disabled input keeps the zone inert (no dragging state, no drop assignment)", async () => {
    await mount({ disabled: true })

    el("zone").dispatchEvent(drag("dragenter"))

    expect(el("zone").hasAttribute("data-dragging")).toBe(false)

    el("zone").dispatchEvent(drag("drop", [file("a.txt")]))
    await nextFrame()

    expect(Array.from(el("input").files)).toEqual([])
    expect(chips().length).toBe(0)
  })

  describe("upload: immediate", () => {
    it("strips the input's name, uploads each file as it lands and draws the queue on the chips", async () => {
      await mount({ multiple: true, upload: "immediate" })
      const seen = []
      el("zone").addEventListener("poetry:file-input:upload", (event) => seen.push(`${event.detail.file.name}:${event.detail.state}`))

      expect(el("input").hasAttribute("name")).toBe(false)

      el("zone").dispatchEvent(drag("drop", [file("a.txt"), file("b.txt")]))
      await nextFrame()
      await nextFrame()

      expect(FakeDirectUpload.instances.map((u) => u.file.name)).toEqual(["a.txt", "b.txt"])
      expect(chips().map((chip) => chip.getAttribute("data-upload-state"))).toEqual(["uploading", "uploading"])
      const bar = chips()[0].querySelector("[data-slot=attachment-progress]")

      expect(bar.hidden).toBe(false)

      FakeDirectUpload.instances[0].progress(3, 4)

      expect(bar.getAttribute("aria-valuenow")).toBe("75")
      expect(bar.querySelector("[data-slot=progress-indicator]").style.width).toBe("75%")
      expect(bar.querySelector("[data-slot=progress-value]").textContent).toBe("75%")

      FakeDirectUpload.instances[0].succeed()

      expect(chips()[0].getAttribute("data-upload-state")).toBe("done")
      expect(bar.hidden).toBe(true)
      const hidden = el("form").querySelector("input[type=hidden]")

      expect(hidden.name).toBe("post[files][]")
      expect(hidden.value).toBe("sid-a.txt")

      FakeDirectUpload.instances[1].fail()

      expect(chips()[1].getAttribute("data-upload-state")).toBe("error")
      expect(chips()[1].querySelector("[data-slot=attachment-description]").textContent).toBe("b.txt failed")
      expect(chips()[1].querySelector("[data-upload-action=retry]").hidden).toBe(false)
      expect(seen).toEqual(["a.txt:queued", "b.txt:queued", "a.txt:uploading", "b.txt:uploading", "a.txt:uploading", "a.txt:done", "b.txt:error"])

      chips()[1].querySelector("[data-upload-action=retry]").click()
      await nextFrame()

      expect(chips()[1].getAttribute("data-upload-state")).toBe("uploading")
      expect(chips()[1].querySelector("[data-upload-action=retry]").hidden).toBe(true)
    })

    it("remove drops the chip, the file and the hidden input; the submit is held while uploads run", async () => {
      await mount({ multiple: true, upload: "immediate" })

      el("zone").dispatchEvent(drag("drop", [file("a.txt"), file("b.txt")]))
      await nextFrame()
      await nextFrame()
      FakeDirectUpload.instances[0].succeed()

      expect(el("form").querySelectorAll("input[type=hidden]").length).toBe(1)

      const held = new Event("submit", { bubbles: true, cancelable: true })
      el("form").dispatchEvent(held)

      expect(held.defaultPrevented).toBe(true) // b.txt is still in flight

      chips()[0].querySelector("[data-upload-action=remove]").click()
      await nextFrame()

      expect(el("form").querySelectorAll("input[type=hidden]").length).toBe(0)
      expect(Array.from(el("input").files).map((f) => f.name)).toEqual(["b.txt"])
      expect(chips().length).toBe(1)

      FakeDirectUpload.instances[1].succeed()
      const free = new Event("submit", { bubbles: true, cancelable: true })
      el("form").dispatchEvent(free)

      expect(free.defaultPrevented).toBe(false)
    })

    it("clear cancels the queue and drops every signed id", async () => {
      await mount({ multiple: true, upload: "immediate" })

      el("zone").dispatchEvent(drag("drop", [file("a.txt"), file("b.txt")]))
      await nextFrame()
      await nextFrame()
      FakeDirectUpload.instances[0].succeed()
      el("input").files = []
      el("clear").dispatchEvent(new MouseEvent("click", { bubbles: true, cancelable: true }))
      await nextFrame()

      expect(el("form").querySelectorAll("input[type=hidden]").length).toBe(0)
      expect(chips().length).toBe(0)
      expect(el("zone").hasAttribute("data-populated")).toBe(false)
    })
  })

  describe("upload: on_submit", () => {
    it("follows Rails' direct-upload events on the input, chip by chip, and cancels the alert", async () => {
      await mount({ multiple: true, upload: "on_submit" })
      const a = file("a.txt")
      const b = file("b.txt")
      await pick(a, b)

      expect(el("input").getAttribute("name")).toBe("post[files][]")
      expect(chips().map((chip) => chip.getAttribute("data-upload-state"))).toEqual(["done", "done"])

      const rails = (type, detail) => {
        const event = new CustomEvent(type, { bubbles: true, cancelable: true, detail })
        el("input").dispatchEvent(event)
        return event
      }
      rails("direct-upload:initialize", { id: 1, file: a })
      rails("direct-upload:start", { id: 1, file: a })

      expect(chips()[0].getAttribute("data-upload-state")).toBe("uploading")

      rails("direct-upload:progress", { id: 1, file: a, progress: 40 })

      expect(chips()[0].querySelector("[data-slot=attachment-progress]").getAttribute("aria-valuenow")).toBe("40")

      rails("direct-upload:end", { id: 1, file: a })
      rails("direct-upload:initialize", { id: 2, file: b })
      const error = rails("direct-upload:error", { id: 2, file: b, error: "Status: 500" })

      expect(error.defaultPrevented).toBe(true)
      expect(chips().map((chip) => chip.getAttribute("data-upload-state"))).toEqual(["done", "error"])
      expect(chips()[1].querySelector("[data-slot=attachment-description]").textContent).toBe("b.txt failed")
    })
  })
})
