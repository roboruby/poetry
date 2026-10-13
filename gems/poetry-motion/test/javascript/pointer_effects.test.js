import { afterEach, beforeEach, describe, expect, it, vi } from "vitest"
import { Application } from "@hotwired/stimulus"

import { registerPoetryMotionControllers } from "@poetry/motion"

// The rank-two pointer effects: each follows a fine pointer through custom
// properties, settles when it leaves, stays still for touch and reduced
// motion, and leaves no style when it disconnects.

let application
let reduce = false
const wait = (ms) => new Promise((resolve) => setTimeout(resolve, ms))

beforeEach(async () => {
  reduce = false
  window.matchMedia = vi.fn((query) => ({
    get matches() { return query.includes("reduced-motion") ? reduce : false },
    addEventListener: () => {},
  }))
  document.documentElement.style.setProperty("--motion-spring-snappy", "400 40 1")
  application = Application.start()
  await registerPoetryMotionControllers(application)
})

afterEach(() => {
  application.stop()
  document.body.innerHTML = ""
})

const mount = async (html, identifier) => {
  document.body.innerHTML = html
  const element = document.body.firstElementChild
  element.getBoundingClientRect = () => ({ left: 0, top: 0, width: 200, height: 100 })
  for (let i = 0; i < 100 && !application.getControllerForElementAndIdentifier(element, identifier); i++) await wait(10)
  return element
}
const pointer = (element, type, init = {}) =>
  element.dispatchEvent(Object.assign(new Event(type, { bubbles: true }), { pointerType: "mouse", clientX: 0, clientY: 0, ...init }))

describe("spotlight card", () => {
  const card = `<div data-slot="spotlight-card" data-controller="poetry--motion--spotlight-card">x</div>`

  it("puts the glow at the pointer and takes it away on leave", async () => {
    const root = await mount(card, "poetry--motion--spotlight-card")
    pointer(root, "pointermove", { clientX: 150, clientY: 25 })
    await wait(40)
    expect(root.style.getPropertyValue("--spotlight-x")).toBe("150px")
    expect(root.style.getPropertyValue("--spotlight-y")).toBe("25px")
    expect(root.style.getPropertyValue("--spotlight-opacity")).toBe("1")
    pointer(root, "pointerleave")
    expect(root.getAttribute("style")).toBe("")
  })

  it("stays plain under reduced motion", async () => {
    reduce = true
    const root = await mount(card, "poetry--motion--spotlight-card")
    pointer(root, "pointermove", { clientX: 150, clientY: 25 })
    await wait(40)
    expect(root.getAttribute("style")).toBeNull()
  })
})

describe("magnetic", () => {
  const magnetic = `<span data-slot="magnetic" data-controller="poetry--motion--magnetic"
      data-poetry--motion--magnetic-strength-value="10">
    <span data-slot="magnetic-layer" data-poetry--motion--magnetic-target="layer"><button>Go</button></span></span>`

  it("pulls the layer toward the pointer and lets it go home", async () => {
    const root = await mount(magnetic, "poetry--motion--magnetic")
    const layer = root.querySelector("[data-slot=magnetic-layer]")
    pointer(root, "pointermove", { clientX: 200, clientY: 100 })
    const pull = () => parseFloat(layer.style.getPropertyValue("--magnet-x"))
    for (let i = 0; i < 150 && !(Math.abs(pull() - 10) < 0.5); i++) await wait(10)
    expect(pull()).toBeCloseTo(10, 0)
    expect(parseFloat(layer.style.getPropertyValue("--magnet-y"))).toBeCloseTo(10, 0)
    pointer(root, "pointerleave")
    for (let i = 0; i < 150 && !(Math.abs(pull()) < 0.5); i++) await wait(10)
    expect(pull()).toBeCloseTo(0, 0)
    root.remove()
    await wait(10)
    expect(layer.style.getPropertyValue("--magnet-x")).toBe("")
  })
})

describe("dock", () => {
  const dock = `<nav data-slot="dock" data-controller="poetry--motion--dock" data-orientation="horizontal"
      data-poetry--motion--dock-magnification-value="2" data-poetry--motion--dock-distance-value="100">
    <a id="one">1</a><a id="two">2</a><a id="three">3</a></nav>`

  const lay = (root) => [...root.children].forEach((item, index) => {
    item.getBoundingClientRect = () => ({ left: index * 50, top: 0, width: 40, height: 40 })
  })

  it("swells the item under the pointer most and settles on leave", async () => {
    const root = await mount(dock, "poetry--motion--dock")
    lay(root)
    pointer(root, "pointermove", { clientX: 20, clientY: 20 })
    await wait(500)
    const scale = (id) => parseFloat(root.querySelector(`#${id}`).style.getPropertyValue("--dock-scale"))
    expect(scale("one")).toBeCloseTo(2, 1)
    expect(scale("two")).toBeGreaterThan(1)
    expect(scale("two")).toBeLessThan(scale("one"))
    expect(scale("three")).toBeCloseTo(1, 1)
    pointer(root, "pointerleave")
    await wait(500)
    expect(scale("one")).toBeCloseTo(1, 1)
  })

  it("stays still for touch and under reduced motion", async () => {
    const root = await mount(dock, "poetry--motion--dock")
    lay(root)
    pointer(root, "pointermove", { clientX: 20, clientY: 20, pointerType: "touch" })
    await wait(100)
    expect(root.querySelector("#one").getAttribute("style")).toBeNull()

    application.stop()
    document.body.innerHTML = ""
    reduce = true
    application = Application.start()
    await registerPoetryMotionControllers(application)
    const still = await mount(dock, "poetry--motion--dock")
    lay(still)
    pointer(still, "pointermove", { clientX: 20, clientY: 20 })
    await wait(100)
    expect(still.querySelector("#one").getAttribute("style")).toBeNull()
  })
})
