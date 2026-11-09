import { afterEach, beforeEach, describe, expect, it, vi } from "vitest"
import { Application } from "@hotwired/stimulus"

import { IslandController, registerPoetryIslandControllers } from "@poetry/island"

// The island controller in a real Stimulus application, with the module
// loader replaced: what a module receives, what the page shows while the
// island is up and when it is not, and the Turbo lifecycle around it.

let application
let module
const wait = (ms) => new Promise((resolve) => setTimeout(resolve, ms))
const tick = () => wait(0)

const island = (attributes = "", shell = "<p>shell</p>", input = "") => `
  <div data-slot="island" data-controller="poetry--island--island"
       data-poetry--island--island-import-value="islands/demo" ${attributes}>
    <div data-slot="island-shell" data-poetry--island--island-target="shell">${shell}</div>
    ${input}
    <script type="application/json">{"zoom":12}</script>
  </div>`

const mount = async (html) => {
  document.body.innerHTML = html
  const element = document.body.firstElementChild
  for (let i = 0; i < 50 && !element.hasAttribute("data-island-mounted") && !element.dataset.failed; i++) await wait(5)
  return element
}

const settle = async (element) => {
  for (let i = 0; i < 50 && module.mount.mock.calls.length === 0; i++) await wait(5)
  await tick()
  return element
}

beforeEach(() => {
  module = {
    mount: vi.fn((root, props) => {
      root.textContent = `island ${props.zoom}`
      return { unmount: vi.fn(), update: vi.fn() }
    })
  }
  IslandController.load = vi.fn(async () => module)
  vi.spyOn(console, "error").mockImplementation(() => {})
  document.documentElement.removeAttribute("data-turbo-preview")
  application = Application.start()
  registerPoetryIslandControllers(application)
})

afterEach(() => {
  document.body.innerHTML = ""
  application.stop()
  vi.restoreAllMocks()
})

describe("mounting", () => {
  it("imports the module, mounts it beside the shell and marks the island", async () => {
    const element = await mount(island())

    expect(IslandController.load).toHaveBeenCalledWith("islands/demo")
    const root = element.querySelector(":scope > [data-island-root]")
    expect(root.textContent).toBe("island 12")
    expect(root.style.position).toBe("absolute")
    expect(element.hasAttribute("data-island-mounted")).toBe(true)
    expect(module.mount.mock.calls[0][1]).toEqual({ zoom: 12, input: null, focus: false })
  })

  it("a flow island's root takes its place in the flow", async () => {
    const element = await mount(island(`data-poetry--island--island-mode-value="flow"`))

    expect(element.querySelector("[data-island-root]").style.position).toBe("")
  })

  it("hands the module the hidden input and whether the shell had focus", async () => {
    document.body.innerHTML = island("", `<button>edit</button>`,
      `<input type="hidden" name="body" data-slot="island-input" data-poetry--island--island-target="input">`)
    const element = document.body.firstElementChild
    element.querySelector("button").focus()
    await settle(element)

    const props = module.mount.mock.calls[0][1]
    expect(props.input).toBe(element.querySelector("input"))
    expect(props.focus).toBe(true)
  })

  it("dispatches mount with the import", async () => {
    const seen = []
    document.addEventListener("poetry--island--island:mount", (event) => seen.push(event.detail.import))
    await mount(island())

    expect(seen).toEqual(["islands/demo"])
  })
})

describe("the shell stays", () => {
  it("when the import fails", async () => {
    IslandController.load = vi.fn(async () => { throw new Error("404") })
    const errors = []
    document.addEventListener("poetry--island--island:error", (event) => errors.push(event.detail.stage))
    document.body.innerHTML = island()
    const element = document.body.firstElementChild
    for (let i = 0; i < 50 && errors.length === 0; i++) await wait(5)

    expect(errors).toEqual(["load"])
    expect(element.querySelector("[data-island-root]")).toBeNull()
    expect(element.hasAttribute("data-island-mounted")).toBe(false)
    expect(console.error).toHaveBeenCalled()
  })

  it("when the module exports no mount, and when mount throws", async () => {
    IslandController.load = vi.fn(async () => ({}))
    const errors = []
    document.addEventListener("poetry--island--island:error", (event) => errors.push(event.detail.stage))
    document.body.innerHTML = island()
    for (let i = 0; i < 50 && errors.length === 0; i++) await wait(5)
    expect(errors).toEqual(["load"])

    module.mount = vi.fn(() => { throw new Error("no WebGL") })
    IslandController.load = vi.fn(async () => module)
    document.body.innerHTML = island()
    const element = document.body.firstElementChild
    for (let i = 0; i < 50 && errors.length === 1; i++) await wait(5)
    expect(errors).toEqual(["load", "mount"])
    expect(element.querySelector("[data-island-root]")).toBeNull()
  })

  it("during a Turbo preview", async () => {
    document.documentElement.setAttribute("data-turbo-preview", "")
    document.body.innerHTML = island()
    await wait(20)

    expect(IslandController.load).not.toHaveBeenCalled()
    expect(document.querySelector("[data-island-root]")).toBeNull()
  })
})

describe("the Turbo lifecycle", () => {
  it("unmounts on disconnect and removes the root and the mark", async () => {
    const element = await mount(island())
    const handle = module.mount.mock.results[0].value

    element.remove()
    await tick()

    expect(handle.unmount).toHaveBeenCalledOnce()
    expect(element.querySelector("[data-island-root]")).toBeNull()
    expect(element.hasAttribute("data-island-mounted")).toBe(false)
  })

  it("clears a cached snapshot's dead root and mark on connect", async () => {
    document.body.innerHTML = island(`data-island-mounted=""`, `<p>shell</p>`, `<div data-island-root="">dead</div>`)
    const element = document.body.firstElementChild
    await settle(element)

    expect(element.querySelectorAll("[data-island-root]").length).toBe(1)
    expect(element.querySelector("[data-island-root]").textContent).toBe("island 12")
    expect(element.hasAttribute("data-island-mounted")).toBe(true)
  })

  it("keeps the island through a morph refresh and hands it the new props", async () => {
    const element = await mount(island())
    const handle = module.mount.mock.results[0].value
    const incoming = document.createElement("div")
    incoming.innerHTML = `<p>new shell</p><script type="application/json">{"zoom":15}</script>`
    const event = new CustomEvent("turbo:before-morph-element", {
      bubbles: true, cancelable: true, detail: { currentElement: element, newElement: incoming }
    })

    element.dispatchEvent(event)

    expect(event.defaultPrevented).toBe(true)
    expect(handle.update).toHaveBeenCalledWith({ zoom: 15, input: null })
    expect(handle.unmount).not.toHaveBeenCalled()
    expect(element.querySelector("[data-island-root]").textContent).toBe("island 12")
  })

  it("leaves a morph of something inside the island alone", async () => {
    const element = await mount(island())
    const shell = element.querySelector("[data-slot=island-shell]")
    const event = new CustomEvent("turbo:before-morph-element", {
      bubbles: true, cancelable: true, detail: { currentElement: shell, newElement: shell.cloneNode(true) }
    })

    shell.dispatchEvent(event)

    expect(event.defaultPrevented).toBe(false)
  })

  it("a mount that resolves after the island left the page does nothing", async () => {
    let resolve
    IslandController.load = vi.fn(() => new Promise((r) => { resolve = r }))
    document.body.innerHTML = island()
    const element = document.body.firstElementChild
    await tick()
    element.remove()
    await tick()
    resolve(module)
    await tick()

    expect(module.mount).not.toHaveBeenCalled()
    expect(element.querySelector("[data-island-root]")).toBeNull()
  })
})
