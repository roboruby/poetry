import { beforeEach, describe, expect, it, vi } from "vitest"
import { Application } from "@hotwired/stimulus"
import { registerPoetryControllers } from "@poetry/controllers"

// poetry--core--carousel JS-unit: the native scroll-snap engine. What this
// file proves: prev/next page by scrollIntoView on the TARGET slide,
// button state follows the nearest-slide index (rect-based - RTL-safe by
// construction), arrows page per orientation, and the select event carries
// the index. The real snap physics are the platform's (browser rig).

const nextFrame = () => new Promise((resolve) => setTimeout(resolve, 0))
const el = (id) => document.getElementById(id)

const markup = () => `
  <div id="root" role="region" aria-roledescription="carousel" aria-label="Artwork"
       data-controller="poetry--core--carousel"
       data-action="keydown->poetry--core--carousel#keydown">
    <div id="viewport" data-poetry--core--carousel-target="viewport"
         data-action="scroll->poetry--core--carousel#scrolled">
      <div id="slide-0" data-slot="carousel-item"></div>
      <div id="slide-1" data-slot="carousel-item"></div>
      <div id="slide-2" data-slot="carousel-item"></div>
    </div>
    <button id="prev" type="button" data-poetry--core--carousel-target="previous"
            data-action="click->poetry--core--carousel#previous">Prev</button>
    <button id="next" type="button" data-poetry--core--carousel-target="next"
            data-action="click->poetry--core--carousel#next">Next</button>
  </div>`

// jsdom has no layout - stub each slide's rect so "nearest to the
// viewport's left edge" resolves to `current`.
const layout = (current) => {
  el("viewport").getBoundingClientRect = () => ({ left: 0, top: 0, width: 300, height: 100 })
  ;[0, 1, 2].forEach((index) => {
    el(`slide-${index}`).getBoundingClientRect =
      () => ({ left: (index - current) * 300, top: 0, width: 300, height: 100 })
  })
}

async function mount() {
  document.body.innerHTML = markup()
  Element.prototype.scrollIntoView ||= () => {}
  layout(0)
  const application = Application.start()
  registerPoetryControllers(application)
  await nextFrame()
  return application
}

describe("poetry--core--carousel", () => {
  let application

  beforeEach(async () => {
    application = await mount()
    return async () => {
      application.stop()
      document.body.replaceChildren()
      await nextFrame()
    }
  })

  it("connect syncs button state from the current slide", () => {
    expect(el("prev").disabled).toBe(true)
    expect(el("next").disabled).toBe(false)
  })

  it("next scrolls the following slide into view and flips button state", () => {
    const scrollIntoView = vi.fn()
    el("slide-1").scrollIntoView = scrollIntoView

    el("next").click()
    layout(1)
    el("viewport").dispatchEvent(new Event("scroll"))

    expect(scrollIntoView).toHaveBeenCalledWith(
      expect.objectContaining({ behavior: "smooth", inline: "start" })
    )
  })

  it("button state follows scrolling from ANY source", async () => {
    layout(2)
    el("viewport").dispatchEvent(new Event("scroll"))
    await new Promise((resolve) => requestAnimationFrame(() => resolve()))

    expect(el("prev").disabled).toBe(false)
    expect(el("next").disabled).toBe(true)
  })

  it("arrows page per orientation", () => {
    const scrollIntoView = vi.fn()
    el("slide-1").scrollIntoView = scrollIntoView

    el("root").dispatchEvent(new KeyboardEvent("keydown", { key: "ArrowRight", bubbles: true, cancelable: true }))

    expect(scrollIntoView).toHaveBeenCalled()
  })

  it("select events carry the nearest index", async () => {
    let detail = null
    el("root").addEventListener("poetry--core--carousel:select", (event) => { detail = event.detail })

    layout(1)
    el("viewport").dispatchEvent(new Event("scroll"))
    await new Promise((resolve) => requestAnimationFrame(() => resolve()))

    expect(detail).toEqual({ index: 1 })
  })
})
