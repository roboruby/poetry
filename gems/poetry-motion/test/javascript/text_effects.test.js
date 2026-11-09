import { afterEach, beforeEach, describe, expect, it, vi } from "vitest"
import { Application } from "@hotwired/stimulus"

import { registerPoetryMotionControllers } from "@poetry/motion"

// The rank-three text effects: each animates an aria-hidden copy and ends
// on the server's text, at teardown and before Turbo caches the page too.

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

const typewriter = `<span data-slot="typewriter" data-cursor data-controller="poetry--motion--typewriter"
    data-poetry--motion--typewriter-speed-value="10" data-poetry--motion--typewriter-trigger-value="load">
  <span class="sr-only">Hello there</span>
  <span data-slot="typewriter-display" aria-hidden="true" data-poetry--motion--typewriter-target="display">Hello there</span>
</span>`

describe("typewriter", () => {
  it("types the line and ends on it", async () => {
    const root = await mount(typewriter, "poetry--motion--typewriter")
    const display = root.querySelector("[data-slot=typewriter-display]")
    const seen = []
    for (let i = 0; i < 20; i++) { seen.push(display.textContent); await wait(10) }
    expect(seen.some((text) => text.length > 0 && text.length < 11)).toBe(true)
    await wait(200)
    expect(display.textContent).toBe("Hello there")
    expect(root.hasAttribute("data-typing")).toBe(false)
  })

  it("shows the line at once under reduced motion and restores it before the cache", async () => {
    reduce = true
    const still = await mount(typewriter, "poetry--motion--typewriter")
    expect(still.querySelector("[data-slot=typewriter-display]").textContent).toBe("Hello there")

    reduce = false
    const root = await mount(typewriter, "poetry--motion--typewriter")
    await wait(30)
    document.dispatchEvent(new Event("turbo:before-cache"))
    expect(root.querySelector("[data-slot=typewriter-display]").textContent).toBe("Hello there")
  })
})

describe("scramble", () => {
  const scramble = `<span data-slot="scramble" data-controller="poetry--motion--scramble"
      data-poetry--motion--scramble-duration-value="200" data-poetry--motion--scramble-trigger-value="load">
    <span class="sr-only">ACCESS GRANTED</span>
    <span data-slot="scramble-display" aria-hidden="true" data-poetry--motion--scramble-target="display">ACCESS GRANTED</span>
  </span>`

  it("scrambles, keeps the spaces, and lands on the text", async () => {
    const root = await mount(scramble, "poetry--motion--scramble")
    const display = root.querySelector("[data-slot=scramble-display]")
    await wait(60)
    const midway = display.textContent
    expect(midway).toHaveLength("ACCESS GRANTED".length)
    expect(midway[6]).toBe(" ")
    await wait(300)
    expect(display.textContent).toBe("ACCESS GRANTED")
  })

  it("restores the text when it disconnects mid-scramble", async () => {
    const root = await mount(scramble, "poetry--motion--scramble")
    const display = root.querySelector("[data-slot=scramble-display]")
    await wait(40)
    root.remove()
    await wait(10)
    expect(display.textContent).toBe("ACCESS GRANTED")
  })
})

describe("word rotate", () => {
  const rotate = `<span data-slot="word-rotate" data-controller="poetry--motion--word-rotate"
      data-poetry--motion--word-rotate-interval-value="40" data-poetry--motion--word-rotate-rounds-value="1">
    <span class="sr-only">faster</span>
    <span aria-hidden="true">
      <span data-slot="word-rotate-word" data-active data-poetry--motion--word-rotate-target="word">faster</span>
      <span data-slot="word-rotate-word" data-poetry--motion--word-rotate-target="word">safer</span>
      <span data-slot="word-rotate-word" data-poetry--motion--word-rotate-target="word">together</span>
    </span>
  </span>`
  const active = (root) => root.querySelector("[data-slot=word-rotate-word][data-active]").textContent

  it("turns through the words once and settles on the first", async () => {
    const root = await mount(rotate, "poetry--motion--word-rotate")
    const seen = new Set()
    for (let i = 0; i < 30; i++) { seen.add(active(root)); await wait(10) }
    expect(seen.size).toBeGreaterThan(1)
    await wait(200)
    expect(active(root)).toBe("faster")
    await wait(100)
    expect(active(root)).toBe("faster")
  })

  it("holds while hovered", async () => {
    const root = await mount(rotate, "poetry--motion--word-rotate")
    root.dispatchEvent(new Event("pointerenter"))
    await wait(150)
    expect(active(root)).toBe("faster")
  })
})
