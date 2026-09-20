import { beforeEach, describe, expect, it } from "vitest"
import { Application } from "@hotwired/stimulus"
import { registerPoetryControllers } from "@poetry/controllers"

// poetry--core--file-input JS-unit: the dropzone engine over a native
// input - drag counter (no flicker over children), file-only drags,
// drop -> input.files + a real change event, single-mode first-file rule,
// the built (never innerHTML'd) selection list, clear, disabled inertness.
// Click-to-browse is the <label>'s platform behavior - not JS, not here.

const nextFrame = () => new Promise((resolve) => setTimeout(resolve, 0))

const el = (id) => document.getElementById(id)

const file = (name, size = 10) => new File([new Uint8Array(size)], name, { type: "text/plain" })

// jsdom's input.files is not assignable with a plain array - swap it for
// a writable data property so the controller's assignment lands.
const writableFiles = (input) => {
  Object.defineProperty(input, "files", { writable: true, configurable: true, value: [] })
}

const drag = (type, files = [], types = ["Files"]) => {
  const event = new Event(type, { bubbles: true, cancelable: true })
  event.dataTransfer = { files, types }
  return event
}

const markup = ({ multiple = false, disabled = false } = {}) => `
  <label id="zone" data-slot="file-input" data-component="file-input"
         data-controller="poetry--core--file-input"
         data-poetry--core--file-input-multiple-value="${multiple}"
         data-action="dragenter->poetry--core--file-input#dragenter
                      dragover->poetry--core--file-input#dragover
                      dragleave->poetry--core--file-input#dragleave
                      drop->poetry--core--file-input#drop">
    <input id="input" type="file" ${multiple ? "multiple" : ""} ${disabled ? "disabled" : ""}
           data-poetry--core--file-input-target="input"
           data-action="change->poetry--core--file-input#changed">
    <span data-slot="file-input-prompt">Drag and drop</span>
    <ul id="list" data-poetry--core--file-input-target="list"></ul>
    <button id="clear" type="button" data-poetry--core--file-input-target="clear"
            data-action="click->poetry--core--file-input#clear">Clear</button>
  </label>`

describe("poetry--core--file-input", () => {
  let application

  beforeEach(async () => {
    document.body.innerHTML = `<div id="host"></div>`
    application = Application.start()
    registerPoetryControllers(application)
    await nextFrame()
    return () => application.stop()
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

    const items = el("list").querySelectorAll("[data-slot=file-input-item]")

    expect(items.length).toBe(1)
    expect(items[0].querySelector("[data-slot=file-input-item-name]").textContent).toBe("report.pdf")
    expect(items[0].querySelector("[data-slot=file-input-item-size]").textContent).toBe("2.0 KB")
    expect(el("zone").hasAttribute("data-populated")).toBe(true)
    expect(el("clear").hidden).toBe(false)
    expect(seen).toEqual([["report.pdf"]])
  })

  it("the drag counter survives children: two enters + one leave stay dragging; the second clears", async () => {
    await mount()

    el("zone").dispatchEvent(drag("dragenter"))
    el("zone").dispatchEvent(drag("dragenter")) // crossing INTO a child fires again

    expect(el("zone").hasAttribute("data-dragging")).toBe(true)

    el("zone").dispatchEvent(drag("dragleave"))

    expect(el("zone").hasAttribute("data-dragging")).toBe(true)

    el("zone").dispatchEvent(drag("dragleave"))

    expect(el("zone").hasAttribute("data-dragging")).toBe(false)
  })

  it("a non-file drag (text, links) never arms the zone", async () => {
    await mount()

    el("zone").dispatchEvent(drag("dragenter", [], ["text/plain"]))

    expect(el("zone").hasAttribute("data-dragging")).toBe(false)
  })

  it("drop assigns the files to the native input and fires a real change through it", async () => {
    await mount({ multiple: true })
    const dropped = [file("a.txt"), file("b.txt")]

    el("zone").dispatchEvent(drag("dragenter"))
    el("zone").dispatchEvent(drag("drop", dropped))

    expect(Array.from(el("input").files).map((f) => f.name)).toEqual(["a.txt", "b.txt"])
    expect(el("zone").hasAttribute("data-dragging")).toBe(false)
    expect(el("list").children.length).toBe(2)
  })

  it("a single-file zone takes the FIRST dropped file (the native picker's rule)", async () => {
    await mount()
    // The stub DataTransfer the normalizer builds through.
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

      expect(Array.from(el("input").files).map((f) => f.name)).toEqual(["first.png"])
    } finally {
      delete globalThis.DataTransfer
    }
  })

  it("clear empties the input, the list, and the populated state - and never re-opens the picker", async () => {
    await mount()
    el("input").files = [file("a.txt")]
    el("input").dispatchEvent(new Event("change", { bubbles: true }))

    expect(el("zone").hasAttribute("data-populated")).toBe(true)

    const click = new MouseEvent("click", { bubbles: true, cancelable: true })
    el("input").files = []
    el("clear").dispatchEvent(click)

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

    expect(Array.from(el("input").files)).toEqual([])
  })
})
