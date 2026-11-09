import { afterEach, beforeEach, describe, expect, it, vi } from "vitest"
import { Application } from "@hotwired/stimulus"

// jsdom has no canvas or WebGL: the confetti and globe kernels are mocked,
// and the tests hold the controllers to what they ask of them.
const cannon = vi.fn()
cannon.reset = vi.fn()
const create = vi.fn(() => cannon)
vi.mock("@poetry/motion/confetti", () => ({ create }))
const globe = { update: vi.fn(), destroy: vi.fn() }
const createGlobe = vi.fn(() => globe)
vi.mock("@poetry/motion/globe", () => ({ createGlobe }))

const { registerPoetryMotionControllers } = await import("@poetry/motion")

let application
let reduce = false
const wait = (ms) => new Promise((resolve) => setTimeout(resolve, ms))

beforeEach(async () => {
  reduce = false
  vi.clearAllMocks()
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

const confetti = (trigger = "click") => `<span data-slot="confetti" data-controller="poetry--motion--confetti"
    data-poetry--motion--confetti-trigger-value="${trigger}" data-poetry--motion--confetti-count-value="50">
  <button>Ship</button>
  <canvas data-slot="confetti-canvas" data-poetry--motion--confetti-target="canvas"></canvas></span>`

describe("confetti", () => {
  it("bursts from the click, on its own canvas, and clears at teardown", async () => {
    const root = await mount(confetti(), "poetry--motion--confetti")
    root.querySelector("button").dispatchEvent(new MouseEvent("click", { bubbles: true, clientX: 100, clientY: 50, detail: 1 }))
    await wait(30)
    expect(create).toHaveBeenCalledWith(root.querySelector("canvas"), expect.objectContaining({ disableForReducedMotion: true }))
    expect(cannon).toHaveBeenCalledWith(expect.objectContaining({ particleCount: 50,
      origin: { x: 100 / window.innerWidth, y: 50 / window.innerHeight } }))
    root.remove()
    await wait(10)
    expect(cannon.reset).toHaveBeenCalled()
  })

  it("bursts once on load, and never under reduced motion", async () => {
    await mount(confetti("load"), "poetry--motion--confetti")
    await wait(30)
    expect(cannon).toHaveBeenCalledOnce()

    vi.clearAllMocks()
    reduce = true
    const root = await mount(confetti(), "poetry--motion--confetti")
    root.querySelector("button").click()
    await wait(30)
    expect(cannon).not.toHaveBeenCalled()
  })
})

const globeHtml = `<div data-slot="globe" data-controller="poetry--motion--globe"
    data-poetry--motion--globe-markers-value="[[37.77,-122.42]]">
  <canvas data-slot="globe-canvas" data-poetry--motion--globe-target="canvas"></canvas></div>`

describe("globe", () => {
  it("builds the globe with its markers, turns it, and destroys it at teardown", async () => {
    const root = await mount(globeHtml, "poetry--motion--globe")
    root.querySelector("canvas").getBoundingClientRect = () => ({ width: 300, height: 300 })
    await wait(80)
    expect(createGlobe).toHaveBeenCalledOnce()
    expect(createGlobe.mock.calls[0][1].markers).toEqual([{ location: [37.77, -122.42], size: 0.05 }])
    expect(globe.update.mock.calls.length).toBeGreaterThan(1)
    root.remove()
    await wait(10)
    expect(globe.destroy).toHaveBeenCalled()
  })

  it("draws once and stands still under reduced motion", async () => {
    reduce = true
    await mount(globeHtml, "poetry--motion--globe")
    await wait(80)
    expect(createGlobe).toHaveBeenCalledOnce()
    expect(globe.update).toHaveBeenCalledTimes(1)
  })
})

describe("particles", () => {
  it("draws on its canvas and clears it at teardown", async () => {
    const calls = []
    const context = new Proxy({}, { get: (_target, name) => (...args) => calls.push(name) })
    document.body.innerHTML = `<div data-slot="particles" data-controller="poetry--motion--particles">
      <canvas data-slot="particles-canvas" data-poetry--motion--particles-target="canvas"></canvas></div>`
    const canvas = document.querySelector("canvas")
    canvas.getContext = () => context
    canvas.getBoundingClientRect = () => ({ width: 200, height: 100 })
    const root = document.body.firstElementChild
    for (let i = 0; i < 100 && !application.getControllerForElementAndIdentifier(root, "poetry--motion--particles"); i++) await wait(10)
    await wait(80)
    expect(calls).toContain("arc")
    root.remove()
    await wait(10)
    expect(calls).toContain("clearRect")
  })
})
