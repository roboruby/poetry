import { afterEach, beforeEach, describe, expect, it, vi } from "vitest"
import { Application } from "@hotwired/stimulus"

import { registerPoetryMotionControllers } from "@poetry/motion"

// The four effects' controllers in a real Stimulus application: each
// leaves the server-rendered finished state in place when it disconnects,
// under reduced motion, and before Turbo caches the page.

let application
let reduce = false
const wait = (ms) => new Promise((resolve) => setTimeout(resolve, ms))
const tick = () => wait(0)

beforeEach(async () => {
  reduce = false
  window.matchMedia = vi.fn((query) => ({
    get matches() { return query.includes("reduced-motion") ? reduce : false },
    addEventListener: () => {},
  }))
  const root = document.documentElement
  delete root.dataset.motion
  root.style.setProperty("--motion-spring-gentle", "120 22 1")
  root.style.setProperty("--motion-spring-snappy", "400 40 1")
  application = Application.start()
  await registerPoetryMotionControllers(application)
})

afterEach(() => {
  application.stop()
  document.body.innerHTML = ""
})

const mount = async (html) => {
  document.body.innerHTML = html
  // The lazy import, then the connect: wait until every controller on the page is live.
  const connected = () => [...document.querySelectorAll("[data-controller]")].every((element) =>
    element.dataset.controller.split(/\s+/).every((identifier) =>
      application.getControllerForElementAndIdentifier(element, identifier)))
  for (let i = 0; i < 100 && !connected(); i++) await wait(10)
  return document.body.firstElementChild
}

describe("marquee", () => {
  it("the pause control holds the loop still and says so", async () => {
    const marquee = await mount(`
      <div data-slot="marquee" data-controller="poetry--motion--marquee">
        <div data-slot="marquee-track">a</div>
        <button data-slot="marquee-pause" aria-pressed="false" data-poetry--motion--marquee-target="pause"
                data-action="click->poetry--motion--marquee#toggle">Pause</button>
      </div>`)
    const pause = marquee.querySelector("button")

    pause.click()
    await tick()
    expect(marquee.hasAttribute("data-paused")).toBe(true)
    expect(pause.getAttribute("aria-pressed")).toBe("true")
    pause.click()
    await tick()
    expect(marquee.hasAttribute("data-paused")).toBe(false)
    expect(pause.getAttribute("aria-pressed")).toBe("false")
  })
})

const ticker = (attrs = "") => `
  <span data-slot="number-ticker" data-controller="poetry--motion--number-ticker"
        data-poetry--motion--number-ticker-value-value="1200" data-poetry--motion--number-ticker-trigger-value="load"
        data-poetry--motion--number-ticker-spring-value="gentle" ${attrs}>
    <span class="sr-only">1,200</span>
    <span aria-hidden="true" data-slot="number-ticker-display" data-poetry--motion--number-ticker-target="display">1,200</span>
  </span>`

describe("number ticker", () => {
  it("counts from `from` and lands on the server's text", async () => {
    const root = await mount(ticker())
    const display = root.querySelector("[data-slot=number-ticker-display]")
    const seen = []
    for (let i = 0; i < 40; i++) {
      seen.push(Number(display.textContent.replace(/,/g, "")))
      await wait(10)
    }
    expect(seen.some((value) => value > 0 && value < 1200)).toBe(true)
    await wait(1500)
    expect(display.textContent).toBe("1,200")
  })

  it("shows the final number at once under reduced motion", async () => {
    reduce = true
    const root = await mount(ticker())
    await wait(80)
    expect(root.querySelector("[data-slot=number-ticker-display]").textContent).toBe("1,200")
  })

  it("restores the server's text when it disconnects mid-count and before Turbo caches", async () => {
    const root = await mount(ticker())
    const display = root.querySelector("[data-slot=number-ticker-display]")
    await wait(80)
    document.dispatchEvent(new Event("turbo:before-cache"))
    expect(display.textContent).toBe("1,200")

    const again = await mount(ticker())
    const second = again.querySelector("[data-slot=number-ticker-display]")
    await wait(80)
    again.remove()
    await tick()
    expect(second.textContent).toBe("1,200")
  })

  it("animate: false leaves the number alone", async () => {
    const root = await mount(ticker('data-poetry--motion--number-ticker-animate-value="false"'))
    await wait(80)
    expect(root.querySelector("[data-slot=number-ticker-display]").textContent).toBe("1,200")
  })
})

const reveal = `
  <p data-slot="text-reveal" data-controller="poetry--motion--text-reveal" style="--reveal-count: 2">
    <span class="sr-only">Two words</span>
    <span aria-hidden="true"><span data-slot="text-reveal-word" style="--word-index: 0">Two</span>
    <span data-slot="text-reveal-word" style="--word-index: 1">words</span></span>
  </p>`

describe("text reveal", () => {
  it("pins the progress at the finished state under reduced motion", async () => {
    reduce = true
    const root = await mount(reveal)
    expect(root.style.getPropertyValue("--reveal-progress")).toBe("1")
  })

  it("clears the progress before Turbo caches and when it disconnects", async () => {
    reduce = true
    const root = await mount(reveal)
    document.dispatchEvent(new Event("turbo:before-cache"))
    expect(root.style.getPropertyValue("--reveal-progress")).toBe("")
    root.style.setProperty("--reveal-progress", "0.4")
    root.remove()
    await tick()
    expect(root.style.getPropertyValue("--reveal-progress")).toBe("")
  })
})

const tilt = `
  <div data-slot="tilt-card" data-controller="poetry--motion--tilt-card" data-poetry--motion--tilt-card-max-value="10">
    <div data-slot="tilt-card-layer" data-poetry--motion--tilt-card-target="layer">card</div>
  </div>`

const pointer = (element, type, init) =>
  element.dispatchEvent(Object.assign(new Event(type, { bubbles: true }), { pointerType: "mouse", ...init }))

describe("tilt card", () => {
  it("leans toward the pointer and springs back flat when it leaves", async () => {
    const root = await mount(tilt)
    root.getBoundingClientRect = () => ({ left: 0, top: 0, width: 200, height: 100 })
    const layer = root.querySelector("[data-slot=tilt-card-layer]")

    pointer(root, "pointermove", { clientX: 200, clientY: 0 })
    await wait(600)
    expect(parseFloat(layer.style.getPropertyValue("--tilt-x"))).toBeCloseTo(10, 0)
    expect(parseFloat(layer.style.getPropertyValue("--tilt-y"))).toBeCloseTo(10, 0)

    pointer(root, "pointerleave", {})
    await wait(600)
    expect(parseFloat(layer.style.getPropertyValue("--tilt-x"))).toBeCloseTo(0, 0)
  })

  it("stays flat under reduced motion and after it disconnects", async () => {
    reduce = true
    const root = await mount(tilt)
    root.getBoundingClientRect = () => ({ left: 0, top: 0, width: 200, height: 100 })
    const layer = root.querySelector("[data-slot=tilt-card-layer]")
    pointer(root, "pointermove", { clientX: 200, clientY: 0 })
    await wait(100)
    expect(layer.getAttribute("style")).toBeNull()

    reduce = false
    const live = await mount(tilt)
    live.getBoundingClientRect = () => ({ left: 0, top: 0, width: 200, height: 100 })
    const liveLayer = live.querySelector("[data-slot=tilt-card-layer]")
    pointer(live, "pointermove", { clientX: 200, clientY: 0 })
    await wait(100)
    live.remove()
    await tick()
    expect(liveLayer.style.getPropertyValue("--tilt-x")).toBe("")
  })
})
