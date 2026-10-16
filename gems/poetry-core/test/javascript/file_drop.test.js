import { beforeEach, describe, expect, it, vi } from "vitest"
import { Application } from "@hotwired/stimulus"
import { registerPoetryControllers } from "@poetry/controllers"
import { acceptMatcher, carriesFiles, formatFileSize } from "@poetry/controllers/behaviors/file_drop"
import { hasScope } from "@poetry/controllers/helpers/scope"

// poetry--core--file-drop JS-unit: the intake behavior over a native
// input - the accept grammar, size and count codes, the surplus rejected
// file by file, the single-zone first-file rule, paste, the full-window
// overlay, the folder walk, the document guard, picker filtering, the
// drag verdict, disabled inertness, and a teardown that leaves no
// document listener behind. The selection list is the file-input
// controller's (file_input.test.js).

const settle = () => new Promise((resolve) => setTimeout(resolve, 0))

const el = (id) => document.getElementById(id)

// A fixed lastModified: the behavior treats name, size and that stamp as
// the identity of a file, the way a second drop of the same file reads.
const file = (name, size = 10, type = "text/plain") => new File([new Uint8Array(size)], name, { type, lastModified: 0 })

// jsdom's input.files is not assignable with a plain array - swap it for
// a writable data property so the behavior's fallback assignment lands.
const writableFiles = (input) => {
  Object.defineProperty(input, "files", { writable: true, configurable: true, value: [] })
}

const drag = (type, files = [], { types = ["Files"], items = null } = {}) => {
  const event = new Event(type, { bubbles: true, cancelable: true })
  event.dataTransfer = { files, types, items: items ?? files.map((f) => ({ kind: "file", type: f.type })) }
  return event
}

const paste = (files) => {
  const event = new Event("paste", { bubbles: true, cancelable: true })
  event.clipboardData = { files }
  return event
}

const values = (options) => Object.entries(options)
  .map(([name, value]) => `data-poetry--core--file-drop-${name}-value='${typeof value === "object" ? JSON.stringify(value) : value}'`)
  .join(" ")

const markup = ({ disabled = false, ...options } = {}) => `
  <div id="zone" data-controller="poetry--core--file-drop" ${values(options)}>
    <label>
      <input id="input" type="file" ${options.multiple ? "multiple" : ""} ${disabled ? "disabled" : ""}
             data-poetry--core--file-drop-target="input">
      <span>Drag and drop</span>
    </label>
    <button id="open" type="button" data-action="click->poetry--core--file-drop#open">Browse</button>
  </div>
  <p id="outside">elsewhere</p>`

const names = (files) => Array.from(files).map((f) => f.name)

describe("poetry--core--file-drop", () => {
  let application
  let reports

  beforeEach(async () => {
    document.body.innerHTML = `<div id="host"></div>`
    application = Application.start()
    registerPoetryControllers(application)
    reports = []
    const listening = new AbortController()
    document.addEventListener("poetry:file-drop:files", (event) => reports.push(event.detail), { signal: listening.signal })
    await settle()
    // Stopping the application stops its observers without disconnecting
    // the controllers, so the zone leaves the document first: its
    // disconnect tears the document listeners down before the next test.
    return async () => {
      el("zone")?.remove()
      await settle()
      listening.abort()
      application.stop()
    }
  })

  async function mount(options = {}) {
    el("host").innerHTML = markup(options)
    await settle()
    writableFiles(el("input"))
  }

  const controller = () => application.getControllerForElementAndIdentifier(el("zone"), "poetry--core--file-drop")

  it("the accept grammar: a wildcard type, an extension for a typeless file, and a rejection with the translated message", async () => {
    await mount({ accept: "image/*,.pdf", multiple: true, messages: { "file-invalid-type": "{name}: not accepted" } })

    el("zone").dispatchEvent(drag("drop", [file("a.png", 10, "image/png"), file("b.PDF", 10, ""), file("c.txt")]))
    await settle()

    expect(names(el("input").files)).toEqual(["a.png", "b.PDF"])
    expect(reports.at(-1).source).toBe("drop")
    expect(names(reports.at(-1).accepted)).toEqual(["a.png", "b.PDF"])
    expect(reports.at(-1).rejected.map((r) => [r.file.name, r.errors[0].code, r.errors[0].message]))
      .toEqual([["c.txt", "file-invalid-type", "c.txt: not accepted"]])
  })

  it("size limits reject with their codes and the formatted limit", async () => {
    await mount({ multiple: true, "max-size": 1024, "min-size": 4 })

    el("zone").dispatchEvent(drag("drop", [file("big.txt", 2048), file("tiny.txt", 2), file("ok.txt", 512)]))
    await settle()

    expect(names(el("input").files)).toEqual(["ok.txt"])
    const codes = Object.fromEntries(reports.at(-1).rejected.map((r) => [r.file.name, r.errors[0]]))
    expect(codes["big.txt"].code).toBe("file-too-large")
    expect(codes["big.txt"].message).toBe("big.txt is larger than 1.0 KB")
    expect(codes["tiny.txt"].code).toBe("file-too-small")
  })

  it("the surplus beyond max files is rejected file by file, and later drops append up to the limit", async () => {
    await mount({ multiple: true, "max-files": 2 })

    el("zone").dispatchEvent(drag("drop", [file("1.txt"), file("2.txt"), file("3.txt")]))
    await settle()

    expect(names(el("input").files)).toEqual(["1.txt", "2.txt"])
    expect(reports.at(-1).rejected.map((r) => [r.file.name, r.errors[0].code])).toEqual([["3.txt", "too-many-files"]])

    el("zone").dispatchEvent(drag("drop", [file("4.txt")]))
    await settle()

    expect(names(el("input").files)).toEqual(["1.txt", "2.txt"])
    expect(reports.at(-1).rejected[0].errors[0].code).toBe("too-many-files")
    expect(names(reports.at(-1).files)).toEqual(["1.txt", "2.txt"])
  })

  it("a multiple zone appends across drops and skips a file it already holds", async () => {
    await mount({ multiple: true })

    el("zone").dispatchEvent(drag("drop", [file("a.txt")]))
    await settle()
    el("zone").dispatchEvent(drag("drop", [file("a.txt"), file("b.txt")]))
    await settle()

    expect(names(el("input").files)).toEqual(["a.txt", "b.txt"])
  })

  it("a single-file zone takes the FIRST dropped file (the native picker's rule) and rejects the rest", async () => {
    await mount()

    el("zone").dispatchEvent(drag("drop", [file("first.png"), file("second.png")]))
    await settle()

    expect(names(el("input").files)).toEqual(["first.png"])
    expect(reports.at(-1).rejected.map((r) => r.errors[0].code)).toEqual(["too-many-files"])

    el("zone").dispatchEvent(drag("drop", [file("third.png")]))
    await settle()

    expect(names(el("input").files)).toEqual(["third.png"]) // a single zone replaces
  })

  it("a paste carrying files lands in the zone; a text paste is left alone", async () => {
    await mount({ paste: true, multiple: true })

    const withFiles = paste([file("shot.png", 10, "image/png")])
    el("zone").dispatchEvent(withFiles)
    await settle()

    expect(withFiles.defaultPrevented).toBe(true)
    expect(names(el("input").files)).toEqual(["shot.png"])
    expect(reports.at(-1).source).toBe("paste")

    const text = paste([])
    el("zone").dispatchEvent(text)

    expect(text.defaultPrevented).toBe(false)
    expect(reports.length).toBe(1)
  })

  it("without paste: a paste with files is not taken", async () => {
    await mount({ multiple: true })

    el("zone").dispatchEvent(paste([file("shot.png")]))
    await settle()

    expect(names(el("input").files)).toEqual([])
    expect(reports.length).toBe(0)
  })

  it("the overlay: files over the window flip data-drag-global, and a drop anywhere lands here", async () => {
    await mount({ overlay: true, multiple: true })

    el("outside").dispatchEvent(drag("dragenter"))

    expect(el("zone").hasAttribute("data-drag-global")).toBe(true)

    el("outside").dispatchEvent(drag("dragleave"))

    expect(el("zone").hasAttribute("data-drag-global")).toBe(false)

    el("outside").dispatchEvent(drag("dragenter"))
    const dropped = drag("drop", [file("anywhere.txt")])
    el("outside").dispatchEvent(dropped)
    await settle()

    expect(dropped.defaultPrevented).toBe(true)
    expect(el("zone").hasAttribute("data-drag-global")).toBe(false)
    expect(names(el("input").files)).toEqual(["anywhere.txt"])
  })

  it("without the overlay the document guard swallows a stray drop and takes nothing", async () => {
    await mount()

    const over = drag("dragover")
    el("outside").dispatchEvent(over)
    const dropped = drag("drop", [file("stray.txt")])
    el("outside").dispatchEvent(dropped)
    await settle()

    expect(over.defaultPrevented).toBe(true)
    expect(dropped.defaultPrevented).toBe(true)
    expect(names(el("input").files)).toEqual([])
    expect(el("zone").hasAttribute("data-drag-global")).toBe(false)
  })

  it("a dropped folder is walked for its files, housekeeping files left out", async () => {
    await mount({ directory: true, multiple: true })

    const fileEntry = (name) => ({ isFile: true, isDirectory: false, name, file: (resolve) => resolve(file(name)) })
    const pages = [[fileEntry("inner.txt"), fileEntry(".DS_Store")], []]
    const folder = {
      isFile: false, isDirectory: true, name: "docs",
      createReader: () => ({ readEntries: (resolve) => resolve(pages.shift()) })
    }
    const items = [
      { kind: "file", type: "", webkitGetAsEntry: () => folder },
      { kind: "file", type: "text/plain", webkitGetAsEntry: () => fileEntry("top.txt") }
    ]
    el("zone").dispatchEvent(drag("drop", [], { items }))
    await settle()
    await settle()

    expect(names(el("input").files)).toEqual(["inner.txt", "top.txt"])
  })

  it("a picker selection is filtered: the rejected file leaves the input, the report says picker", async () => {
    await mount({ accept: ".txt", multiple: true })

    el("input").files = [file("keep.txt"), file("drop.png", 10, "image/png")]
    el("input").dispatchEvent(new Event("change", { bubbles: true }))
    await settle()

    expect(names(el("input").files)).toEqual(["keep.txt"])
    expect(reports.at(-1).source).toBe("picker")
    expect(reports.at(-1).rejected.map((r) => r.file.name)).toEqual(["drop.png"])

    el("input").files = []
    el("input").dispatchEvent(new Event("change", { bubbles: true }))

    expect(reports.at(-1).source).toBe("clear")
    expect(reports.at(-1).files).toEqual([])
  })

  it("the drag verdict: a type the zone cannot take reads reject; no readable items reads unknown", async () => {
    await mount({ accept: "image/*" })
    const verdicts = []
    el("zone").addEventListener("poetry:file-drop:drag", (event) => verdicts.push(event.detail.verdict))

    el("zone").dispatchEvent(drag("dragenter", [], { items: [{ kind: "file", type: "text/plain" }] }))

    expect(el("zone").hasAttribute("data-dragging")).toBe(true)
    expect(el("zone").hasAttribute("data-drag-reject")).toBe(true)

    el("zone").dispatchEvent(drag("dragleave"))

    expect(el("zone").hasAttribute("data-dragging")).toBe(false)
    expect(el("zone").hasAttribute("data-drag-reject")).toBe(false)

    el("zone").dispatchEvent(drag("dragenter", [], { items: [] }))

    expect(el("zone").hasAttribute("data-drag-reject")).toBe(false)
    expect(verdicts).toEqual(["reject", "none", "unknown"])
  })

  it("the drag counter survives children, and a non-file drag never arms the zone", async () => {
    await mount()

    el("zone").dispatchEvent(drag("dragenter"))
    el("zone").dispatchEvent(drag("dragenter")) // crossing INTO a child fires again
    el("zone").dispatchEvent(drag("dragleave"))

    expect(el("zone").hasAttribute("data-dragging")).toBe(true)

    el("zone").dispatchEvent(drag("dragleave"))

    expect(el("zone").hasAttribute("data-dragging")).toBe(false)

    el("zone").dispatchEvent(drag("dragenter", [], { types: ["text/plain"], items: [] }))

    expect(el("zone").hasAttribute("data-dragging")).toBe(false)
  })

  it("a disabled input keeps the zone inert", async () => {
    await mount({ disabled: true, paste: true })

    el("zone").dispatchEvent(drag("dragenter"))

    expect(el("zone").hasAttribute("data-dragging")).toBe(false)

    el("zone").dispatchEvent(drag("drop", [file("a.txt")]))
    el("zone").dispatchEvent(paste([file("b.txt")]))
    await settle()

    expect(names(el("input").files)).toEqual([])
    expect(reports.length).toBe(0)
  })

  it("open clicks the native input from a trigger outside the label", async () => {
    await mount()
    const click = vi.spyOn(el("input"), "click").mockImplementation(() => {})

    el("open").dispatchEvent(new MouseEvent("click", { bubbles: true, cancelable: true }))

    expect(click).toHaveBeenCalledTimes(1)
  })

  it("teardown drops the document listeners and the scope", async () => {
    await mount({ overlay: true })
    const instance = controller()
    const zone = el("zone")

    expect(hasScope(instance)).toBe(true)

    zone.remove()
    await settle()

    expect(hasScope(instance)).toBe(false)

    const over = drag("dragover")
    el("outside").dispatchEvent(over)
    el("outside").dispatchEvent(drag("dragenter"))

    expect(over.defaultPrevented).toBe(false)
    expect(zone.hasAttribute("data-drag-global")).toBe(false)
  })

  it("the helpers: accept matching, the files check and size formatting", () => {
    const images = acceptMatcher("image/*, .PDF")

    expect(images("image/png", "a.png")).toBe(true)
    expect(images("", "scan.pdf")).toBe(true)
    expect(images("application/pdf", "scan.pdf")).toBe(true)
    expect(images("text/plain", "a.txt")).toBe(false)
    expect(acceptMatcher("")("anything", "x")).toBe(true)
    expect(carriesFiles({ types: ["Files"] })).toBe(true)
    expect(carriesFiles({ types: ["text/plain"], items: [{ kind: "file" }] })).toBe(true)
    expect(carriesFiles({ types: ["text/plain"], items: [{ kind: "string" }] })).toBe(false)
    expect(formatFileSize(2048)).toBe("2.0 KB")
    expect(formatFileSize(12)).toBe("12 B")
    expect(formatFileSize(-1)).toBe("")
  })
})
