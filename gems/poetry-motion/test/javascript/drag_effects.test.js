import { afterEach, beforeEach, describe, expect, it, vi } from "vitest"
import { Application } from "@hotwired/stimulus"

import { registerPoetryMotionControllers } from "@poetry/motion"

// The rank-seven drag effects: the draggable follows the pointer within
// its parent and comes home; the swipe stack commits past the threshold,
// tells the host, and swipes from the keyboard and from actions too.

let application
let reduce = false
const wait = (ms) => new Promise((resolve) => setTimeout(resolve, ms))

beforeEach(async () => {
  reduce = false
  window.matchMedia = vi.fn((query) => ({
    get matches() { return query.includes("reduced-motion") ? reduce : false },
    addEventListener: () => {},
  }))
  document.documentElement.style.setProperty("--motion-duration-normal", "100ms")
  document.documentElement.style.setProperty("--motion-spring-snappy", "400 40 1")
  application = Application.start()
  await registerPoetryMotionControllers(application)
})

afterEach(() => {
  application.stop()
  document.body.innerHTML = ""
})

const mount = async (html, selector, identifier) => {
  document.body.innerHTML = html
  const element = document.querySelector(selector)
  for (let i = 0; i < 100 && !application.getControllerForElementAndIdentifier(element, identifier); i++) await wait(10)
  return element
}
const pointer = (element, type, init = {}) =>
  element.dispatchEvent(Object.assign(new Event(type, { bubbles: true }),
    { pointerId: 1, pointerType: "mouse", button: 0, clientX: 0, clientY: 0, ...init }))

describe("draggable", () => {
  const html = (attrs = "") => `<div id="box"><div data-slot="draggable" data-controller="poetry--motion--draggable"
    data-poetry--motion--draggable-bounded-value="true" ${attrs}>x</div></div>`

  it("stays inside its parent and leaves no style after it springs home", async () => {
    const root = await mount(html(), "[data-slot=draggable]", "poetry--motion--draggable")
    root.parentElement.getBoundingClientRect = () => ({ left: 0, top: 0, right: 300, bottom: 200 })
    root.getBoundingClientRect = () => ({ left: 100, top: 50, right: 150, bottom: 80 })
    pointer(root, "pointerdown", { clientX: 120, clientY: 60 })
    pointer(root, "pointermove", { clientX: 520, clientY: 60 })
    expect(root.style.getPropertyValue("--motion-drag-x")).toBe("150px")
    pointer(root, "pointerup", { clientX: 520, clientY: 60 })
    await wait(1200)
    expect(root.getAttribute("style") ?? "").toBe("")
  })

  it("stays where it was dropped with snap-back off", async () => {
    const root = await mount(html('data-poetry--motion--draggable-snap-back-value="false"'),
      "[data-slot=draggable]", "poetry--motion--draggable")
    root.parentElement.getBoundingClientRect = () => ({ left: 0, top: 0, right: 300, bottom: 200 })
    root.getBoundingClientRect = () => ({ left: 100, top: 50, right: 150, bottom: 80 })
    pointer(root, "pointerdown", { clientX: 120, clientY: 60 })
    pointer(root, "pointermove", { clientX: 160, clientY: 90 })
    pointer(root, "pointerup", { clientX: 160, clientY: 90 })
    await wait(200)
    expect(root.style.getPropertyValue("--motion-drag-x")).toBe("40px")
  })
})

describe("swipe cards", () => {
  const stack = `<div data-slot="swipe-cards" tabindex="0" data-controller="poetry--motion--swipe-cards"
      data-poetry--motion--swipe-cards-threshold-value="80">
    <div data-slot="swipe-cards-card" id="a" data-poetry--motion--swipe-cards-target="card">A</div>
    <div data-slot="swipe-cards-card" id="b" data-poetry--motion--swipe-cards-target="card">B</div>
  </div>`

  it("springs back short of the threshold and swipes past it, telling the host", async () => {
    const root = await mount(stack, "[data-slot=swipe-cards]", "poetry--motion--swipe-cards")
    const swipes = []
    root.addEventListener("poetry--motion--swipe-cards:swipe", (event) => swipes.push([event.detail.direction, event.detail.index]))
    const a = root.querySelector("#a")
    expect(a.hasAttribute("data-top")).toBe(true)

    pointer(a, "pointerdown", { clientX: 0 })
    pointer(a, "pointermove", { clientX: 40 })
    pointer(a, "pointerup", { clientX: 40 })
    expect(swipes).toEqual([])

    pointer(a, "pointerdown", { clientX: 0 })
    pointer(a, "pointermove", { clientX: 150 })
    pointer(a, "pointerup", { clientX: 150 })
    expect(swipes).toEqual([["right", 0]])
    await wait(400)
    expect(a.hidden).toBe(true)
    expect(a.dataset.dismissed).toBe("right")
    expect(root.querySelector("#b").hasAttribute("data-top")).toBe(true)
  })

  it("swipes from the arrow keys and marks the stack empty at the end", async () => {
    reduce = true
    const root = await mount(stack, "[data-slot=swipe-cards]", "poetry--motion--swipe-cards")
    let empty = false
    root.addEventListener("poetry--motion--swipe-cards:empty", () => { empty = true })
    root.dispatchEvent(new KeyboardEvent("keydown", { key: "ArrowLeft", bubbles: true }))
    await wait(10)
    root.dispatchEvent(new KeyboardEvent("keydown", { key: "ArrowRight", bubbles: true }))
    await wait(10)
    expect(root.querySelector("#a").dataset.dismissed).toBe("left")
    expect(root.querySelector("#b").dataset.dismissed).toBe("right")
    expect(root.hasAttribute("data-empty")).toBe(true)
    expect(empty).toBe(true)
  })
})
