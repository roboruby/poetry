import { beforeEach, describe, expect, it } from "vitest"
import { Application } from "@hotwired/stimulus"
import { registerPoetryControllers } from "@poetry/controllers"

// poetry--core--file-input JS-unit: the dropzone's reflection beside the
// file-drop controller - a selection (picker or drop) builds the list
// (never innerHTML'd), flips data-populated and reveals clear; the
// rejections fill the role=alert list; clear empties everything and never
// re-opens the picker; the drag styling rides the root the file-drop
// controller writes. Click-to-browse is the <label>'s platform behavior -
// not JS, not here.

const nextFrame = () => new Promise((resolve) => setTimeout(resolve, 0))

const el = (id) => document.getElementById(id)

const file = (name, size = 10, type = "text/plain") => new File([new Uint8Array(size)], name, { type })

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

const markup = ({ multiple = false, disabled = false, accept = "" } = {}) => `
  <div id="zone" data-slot="file-input" data-component="file-input"
       data-controller="poetry--core--file-drop poetry--core--file-input"
       data-poetry--core--file-drop-multiple-value="${multiple}"
       data-poetry--core--file-drop-accept-value="${accept}"
       data-poetry--core--file-input-multiple-value="${multiple}"
       data-action="poetry:file-drop:files->poetry--core--file-input#files">
    <label>
      <input id="input" type="file" ${multiple ? "multiple" : ""} ${disabled ? "disabled" : ""}
             data-poetry--core--file-drop-target="input"
             data-poetry--core--file-input-target="input">
      <span data-slot="file-input-prompt">Drag and drop</span>
      <button id="clear" type="button" data-poetry--core--file-input-target="clear"
              data-action="click->poetry--core--file-input#clear">Clear</button>
    </label>
    <ul id="list" data-poetry--core--file-input-target="list"></ul>
    <ul id="errors" role="alert" hidden data-poetry--core--file-input-target="errors"></ul>
  </div>`

describe("poetry--core--file-input", () => {
  let application

  beforeEach(async () => {
    document.body.innerHTML = `<div id="host"></div>`
    application = Application.start()
    registerPoetryControllers(application)
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

  it("a picker change builds the list (name + size), flips data-populated, reveals clear, dispatches", async () => {
    await mount()
    const seen = []
    el("zone").addEventListener("poetry:file-input:change", (event) => seen.push(event.detail.names))

    el("input").files = [file("report.pdf", 2048)]
    el("input").dispatchEvent(new Event("change", { bubbles: true }))
    await nextFrame()

    const items = el("list").querySelectorAll("[data-slot=file-input-item]")

    expect(items.length).toBe(1)
    expect(items[0].querySelector("[data-slot=file-input-item-name]").textContent).toBe("report.pdf")
    expect(items[0].querySelector("[data-slot=file-input-item-size]").textContent).toBe("2.0 KB")
    expect(el("zone").hasAttribute("data-populated")).toBe(true)
    expect(el("clear").hidden).toBe(false)
    expect(seen).toEqual([["report.pdf"]])
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

  it("drop assigns the files to the native input and the list follows", async () => {
    await mount({ multiple: true })

    el("zone").dispatchEvent(drag("dragenter"))
    el("zone").dispatchEvent(drag("drop", [file("a.txt"), file("b.txt")]))
    await nextFrame()

    expect(Array.from(el("input").files).map((f) => f.name)).toEqual(["a.txt", "b.txt"])
    expect(el("zone").hasAttribute("data-dragging")).toBe(false)
    expect(el("list").children.length).toBe(2)
    expect(el("errors").hidden).toBe(true)
  })

  it("a rejected file fills the role=alert list with its message, and the next clean drop empties it", async () => {
    await mount({ multiple: true, accept: ".txt" })

    el("zone").dispatchEvent(drag("drop", [file("a.txt"), file("b.png", 10, "image/png")]))
    await nextFrame()

    expect(el("list").children.length).toBe(1)
    expect(el("errors").hidden).toBe(false)
    expect(el("errors").children.length).toBe(1)
    expect(el("errors").textContent).toContain("b.png")

    el("zone").dispatchEvent(drag("drop", [file("c.txt")]))
    await nextFrame()

    expect(el("errors").hidden).toBe(true)
    expect(el("list").children.length).toBe(2)
  })

  it("a single-file zone lists the FIRST dropped file (built through the platform's DataTransfer)", async () => {
    await mount()
    // The stub DataTransfer the mirror builds through.
    class StubTransfer {
      constructor() {
        this.stored = []
        this.items = { add: (added) => this.stored.push(added) }
      }

      get files() {
        return this.stored
      }
    }
    globalThis.DataTransfer = StubTransfer

    try {
      el("zone").dispatchEvent(drag("drop", [file("first.png"), file("second.png")]))
      await nextFrame()

      expect(Array.from(el("input").files).map((f) => f.name)).toEqual(["first.png"])
      expect(el("list").children.length).toBe(1)
    } finally {
      delete globalThis.DataTransfer
    }
  })

  it("clear empties the input, the list, and the populated state - and never re-opens the picker", async () => {
    await mount()
    el("input").files = [file("a.txt")]
    el("input").dispatchEvent(new Event("change", { bubbles: true }))
    await nextFrame()

    expect(el("zone").hasAttribute("data-populated")).toBe(true)

    const click = new MouseEvent("click", { bubbles: true, cancelable: true })
    el("input").files = []
    el("clear").dispatchEvent(click)
    await nextFrame()

    expect(click.defaultPrevented).toBe(true) // the label must not re-open the picker
    expect(el("zone").hasAttribute("data-populated")).toBe(false)
    expect(el("list").children.length).toBe(0)
    expect(el("clear").hidden).toBe(true)
  })

  it("a disabled input keeps the zone inert (no dragging state, no drop assignment)", async () => {
    await mount({ disabled: true })

    el("zone").dispatchEvent(drag("dragenter"))

    expect(el("zone").hasAttribute("data-dragging")).toBe(false)

    el("zone").dispatchEvent(drag("drop", [file("a.txt")]))
    await nextFrame()

    expect(Array.from(el("input").files)).toEqual([])
    expect(el("list").children.length).toBe(0)
  })
})
