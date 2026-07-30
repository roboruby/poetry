import { beforeEach, describe, expect, it, vi } from "vitest"
import { Application } from "@hotwired/stimulus"
import { registerPoetryControllers } from "@poetry/controllers"

// poetry--core--carousel JS-unit: the native scroll-snap engine. What this
// file proves: prev/next page the VIEWPORT by a rect delta (start-aligned,
// scroll-margin-adjusted - never scrollIntoView, whose alignment bubbles
// to ancestors and whose "nearest" no-ops on multi-visible stacks),
// button state follows the nearest-slide index (rect-based - RTL-safe by
// construction) plus the end-of-scroller (embla containScroll parity),
// arrows page per orientation, and the select event carries the index.
// The real snap physics are the platform's (browser rig).

const nextFrame = () => new Promise((resolve) => setTimeout(resolve, 0))
const el = (id) => document.getElementById(id)

const markup = (orientation = "horizontal") => `
  <div id="root" role="region" aria-roledescription="carousel" aria-label="Artwork"
       data-controller="poetry--core--carousel"
       data-poetry--core--carousel-orientation-value="${orientation}"
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
// viewport's start edge" resolves to `current`. Horizontal steps by 300,
// vertical by 100.
const layout = (current, { vertical = false } = {}) => {
  el("viewport").getBoundingClientRect = () => ({ left: 0, top: 0, width: 300, height: 100 })
  ;[0, 1, 2].forEach((index) => {
    el(`slide-${index}`).getBoundingClientRect = () => ({
      left: vertical ? 0 : (index - current) * 300,
      top: vertical ? (index - current) * 100 : 0,
      width: 300, height: 100
    })
  })
}

// The end-of-scroller geometry (#atEnd reads it; jsdom defaults are 0).
const scroller = (viewport, { size, extent, position }) => {
  Object.defineProperties(viewport, {
    scrollWidth: { value: extent, configurable: true },
    scrollHeight: { value: extent, configurable: true },
    clientWidth: { value: size, configurable: true },
    clientHeight: { value: size, configurable: true },
    scrollLeft: { value: position, configurable: true, writable: true },
    scrollTop: { value: position, configurable: true, writable: true }
  })
}

async function mount(orientation = "horizontal") {
  document.body.innerHTML = markup(orientation)
  layout(0, { vertical: orientation === "vertical" })
  el("viewport").scrollBy = vi.fn()
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

  it("next pages the viewport by the target slide's start-aligned delta", () => {
    el("next").click()

    expect(el("viewport").scrollBy).toHaveBeenCalledWith({ behavior: "smooth", left: 300, top: 0 })
  })

  it("the delta subtracts the slide's scroll-margin (the snap position, not the border box)", () => {
    // jsdom's cssstyle never parses scroll-margin - impersonate the
    // computed value the browser would report for the gutter item.
    const real = window.getComputedStyle.bind(window)
    vi.spyOn(window, "getComputedStyle").mockImplementation((target, ...rest) =>
      target === el("slide-1") ? { scrollMarginLeft: "-16px", scrollMarginTop: "-16px" } : real(target, ...rest)
    )

    el("next").click()

    expect(el("viewport").scrollBy).toHaveBeenCalledWith({ behavior: "smooth", left: 316, top: 0 })
    vi.restoreAllMocks()
  })

  it("button state follows scrolling from ANY source", async () => {
    layout(2)
    el("viewport").dispatchEvent(new Event("scroll"))
    await new Promise((resolve) => requestAnimationFrame(() => resolve()))

    expect(el("prev").disabled).toBe(false)
    expect(el("next").disabled).toBe(true)
  })

  it("next disables at max scroll even mid-roster (embla containScroll parity)", async () => {
    layout(1)
    scroller(el("viewport"), { size: 300, extent: 900, position: 600 })
    el("viewport").dispatchEvent(new Event("scroll"))
    await new Promise((resolve) => requestAnimationFrame(() => resolve()))

    expect(el("next").disabled).toBe(true)
    expect(el("prev").disabled).toBe(false)
  })

  it("arrows page per orientation", () => {
    el("root").dispatchEvent(
      new KeyboardEvent("keydown", { key: "ArrowRight", bubbles: true, cancelable: true })
    )

    expect(el("viewport").scrollBy).toHaveBeenCalled()
  })

  it("select events carry the nearest index", async () => {
    let detail = null
    el("root").addEventListener("poetry--core--carousel:select", (event) => { detail = event.detail })

    layout(1)
    el("viewport").dispatchEvent(new Event("scroll"))
    await new Promise((resolve) => requestAnimationFrame(() => resolve()))

    expect(detail).toEqual({ index: 1 })
  })

  describe("vertical", () => {
    beforeEach(async () => {
      application.stop()
      document.body.replaceChildren()
      await nextFrame()
      application = await mount("vertical")
    })

    it("next pages the viewport on the block axis", () => {
      el("next").click()

      expect(el("viewport").scrollBy).toHaveBeenCalledWith({ behavior: "smooth", left: 0, top: 100 })
    })

    it("ArrowDown pages, ArrowRight does not", () => {
      el("root").dispatchEvent(
        new KeyboardEvent("keydown", { key: "ArrowRight", bubbles: true, cancelable: true })
      )
      expect(el("viewport").scrollBy).not.toHaveBeenCalled()

      el("root").dispatchEvent(
        new KeyboardEvent("keydown", { key: "ArrowDown", bubbles: true, cancelable: true })
      )
      expect(el("viewport").scrollBy).toHaveBeenCalled()
    })
  })
})
