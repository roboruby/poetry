import { afterEach, beforeEach, describe, expect, it, vi } from "vitest"
import { Application } from "@hotwired/stimulus"

import { registerPoetryMotionControllers } from "@poetry/motion"
import { useScrollValue } from "@poetry/motion/behaviors/scroll_value"

// The rank-five scroll effects: a progress bar follows the reader's own
// scrolling even under reduced motion; parallax stays put there; both
// clear their property at teardown and before the Turbo cache.

let application
let reduce = false
const wait = (ms) => new Promise((resolve) => setTimeout(resolve, ms))

beforeEach(async () => {
  reduce = false
  window.matchMedia = vi.fn((query) => ({
    get matches() { return query.includes("reduced-motion") ? reduce : false },
    addEventListener: () => {},
  }))
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
  for (let i = 0; i < 100 && !application.getControllerForElementAndIdentifier(element, identifier); i++) await wait(10)
  return element
}

describe("useScrollValue follow:", () => {
  it("decoration reports the finished state under reduced motion; follow: does not", () => {
    reduce = true
    const decoration = []
    const feedback = []
    useScrollValue({}, (progress) => decoration.push(progress))
    useScrollValue({}, (progress) => feedback.push(progress), { follow: true })
    expect(decoration).toEqual([1])
    expect(feedback).toEqual([])
  })
})

describe("scroll progress", () => {
  const bar = `<div data-slot="scroll-progress" aria-hidden="true" data-controller="poetry--motion--scroll-progress"></div>`

  it("empties the bar before the Turbo cache and when it disconnects", async () => {
    const root = await mount(bar, "poetry--motion--scroll-progress")
    root.style.setProperty("--scroll-progress", "0.4")
    document.dispatchEvent(new Event("turbo:before-cache"))
    expect(root.style.getPropertyValue("--scroll-progress")).toBe("")
    root.style.setProperty("--scroll-progress", "0.7")
    root.remove()
    await wait(10)
    expect(root.style.getPropertyValue("--scroll-progress")).toBe("")
  })
})

describe("parallax", () => {
  const parallax = `<div data-slot="parallax" data-controller="poetry--motion--parallax"
      data-poetry--motion--parallax-distance-value="80">x</div>`

  it("stays where the server put it under reduced motion", async () => {
    reduce = true
    const root = await mount(parallax, "poetry--motion--parallax")
    await wait(60)
    expect(root.getAttribute("style")).toBeNull()
  })

  it("clears its drift before the Turbo cache and when it disconnects", async () => {
    const root = await mount(parallax, "poetry--motion--parallax")
    root.style.setProperty("--parallax-y", "12px")
    document.dispatchEvent(new Event("turbo:before-cache"))
    expect(root.style.getPropertyValue("--parallax-y")).toBe("")
    root.style.setProperty("--parallax-y", "12px")
    root.remove()
    await wait(10)
    expect(root.style.getPropertyValue("--parallax-y")).toBe("")
  })
})
