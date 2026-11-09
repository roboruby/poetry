import { afterEach, beforeEach, describe, expect, it, vi } from "vitest"
import { Application } from "@hotwired/stimulus"

import { registerPoetryMotionControllers } from "@poetry/motion"

// The rank-one layout effects: the animated list wraps the Turbo Streams
// that touch it, and the layout group moves a data-layout-id element from
// its old box to its new one.

let application
let reduce = false
const wait = (ms) => new Promise((resolve) => setTimeout(resolve, ms))

beforeEach(async () => {
  reduce = false
  window.matchMedia = vi.fn((query) => ({
    get matches() { return query.includes("reduced-motion") ? reduce : false },
    addEventListener: () => {},
  }))
  document.documentElement.style.setProperty("--motion-duration-normal", "300ms")
  application = Application.start()
  await registerPoetryMotionControllers(application)
})

afterEach(() => {
  application.stop()
  document.body.innerHTML = ""
  delete document.startViewTransition
})

const connected = (element, identifier) => application.getControllerForElementAndIdentifier(element, identifier)
const mount = async (html, identifier) => {
  document.body.innerHTML = html
  const element = document.body.firstElementChild
  for (let i = 0; i < 100 && !connected(element, identifier); i++) await wait(10)
  return element
}

// A turbo:before-stream-render event as Turbo dispatches it from the stream element.
const streamRender = (targets) => {
  const stream = document.createElement("turbo-stream")
  stream.targetElements = targets
  document.body.append(stream)
  const render = vi.fn()
  const event = new CustomEvent("turbo:before-stream-render", { bubbles: true, detail: { render, newStream: stream } })
  stream.dispatchEvent(event)
  return { event, render, stream }
}

describe("animated list", () => {
  const list = `<ul id="feed" data-animated-list="poetry-animated-list-1" data-controller="poetry--motion--animated-list">
    <li>one</li><li>two</li></ul>`

  it("wraps a stream that targets the list, and leaves others alone", async () => {
    const root = await mount(list, "poetry--motion--animated-list")
    const elsewhere = document.createElement("div")
    document.body.append(elsewhere)

    const touching = streamRender([root])
    expect(touching.event.detail.render).not.toBe(touching.render)
    const other = streamRender([elsewhere])
    expect(other.event.detail.render).toBe(other.render)

    await touching.event.detail.render(touching.stream)
    expect(touching.render).toHaveBeenCalledWith(touching.stream)
  })

  it("wraps a stream that targets an item inside the list", async () => {
    const root = await mount(list, "poetry--motion--animated-list")
    const touching = streamRender([root.querySelector("li")])
    expect(touching.event.detail.render).not.toBe(touching.render)
  })

  it("runs the render as a view transition when the policy allows one", async () => {
    const root = await mount(list, "poetry--motion--animated-list")
    document.startViewTransition = vi.fn((update) => {
      update()
      const done = Promise.resolve()
      return { ready: done, finished: done, updateCallbackDone: done, skipTransition() {} }
    })
    const { event, render, stream } = streamRender([root])
    await event.detail.render(stream)
    expect(render).toHaveBeenCalledOnce()
    await wait(50)
    expect(document.startViewTransition).toHaveBeenCalled()
  })

  it("stops wrapping when it disconnects", async () => {
    const root = await mount(list, "poetry--motion--animated-list")
    root.remove()
    await wait(10)
    const { event, render } = streamRender([root])
    expect(event.detail.render).toBe(render)
  })
})

describe("layout group", () => {
  const group = `<div data-controller="poetry--motion--layout-group">
    <button><span data-layout-id="pill" id="a">a</span></button>
    <button><span data-layout-id="pill" id="b" hidden>b</span></button>
  </div>`

  const place = (element, rect) => {
    element.getBoundingClientRect = () => (element.hidden ? { left: 0, top: 0, width: 0, height: 0 } : rect)
  }

  it("moves the newly visible element from the old one's box to its own", async () => {
    document.body.innerHTML = group
    const root = document.body.firstElementChild
    root.getBoundingClientRect = () => ({ left: 0, top: 0, width: 400, height: 40 })
    const a = root.querySelector("#a")
    const b = root.querySelector("#b")
    place(a, { left: 10, top: 5, width: 80, height: 30 })
    place(b, { left: 110, top: 5, width: 40, height: 30 })
    for (let i = 0; i < 100 && !connected(root, "poetry--motion--layout-group"); i++) await wait(10)

    a.hidden = true
    b.hidden = false
    await wait(120)

    expect(b.style.translate).not.toBe("")
    const [x] = b.style.translate.split(" ").map(parseFloat)
    expect(x).toBeLessThan(0)
    expect(x).toBeGreaterThan(-100)
  })

  it("under reduced motion the change simply happens", async () => {
    reduce = true
    document.body.innerHTML = group
    const root = document.body.firstElementChild
    root.getBoundingClientRect = () => ({ left: 0, top: 0, width: 400, height: 40 })
    const a = root.querySelector("#a")
    const b = root.querySelector("#b")
    place(a, { left: 10, top: 5, width: 80, height: 30 })
    place(b, { left: 110, top: 5, width: 40, height: 30 })
    for (let i = 0; i < 100 && !connected(root, "poetry--motion--layout-group"); i++) await wait(10)

    a.hidden = true
    b.hidden = false
    await wait(60)
    expect(b.getAttribute("style")).toBeNull()
  })
})
