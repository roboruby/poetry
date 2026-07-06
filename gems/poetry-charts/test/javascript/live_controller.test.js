import { beforeEach, describe, expect, it, vi } from "vitest"
import fs from "node:fs"
import path from "node:path"
import { fileURLToPath } from "node:url"
import { Application } from "@hotwired/stimulus"
import { registerPoetryChartsControllers } from "../../app/javascript/poetry/charts/index.js"

// Phase B-W3: the live channel. The fixture is the REAL server render
// (live_fixtures area case, full frame wiring); the tests prove the two
// channels feed one render path, the renderer's own coordinates rewrite
// never re-triggers the observer, the tooltip refresh dispatch fires,
// and reduced motion snaps.

const ROOT = path.dirname(path.dirname(path.dirname(fileURLToPath(import.meta.url))))
const FIXTURES = JSON.parse(fs.readFileSync(path.join(ROOT, "test/fixtures/live_fixtures.json"), "utf8"))
const AREA = FIXTURES.cases.find((c) => c.name === "area_stacked")

const nextFrame = () => new Promise((resolve) => setTimeout(resolve, 0))
// MutationObserver callbacks are microtasks; give them a macrotask to land.
const settleObservers = () => new Promise((resolve) => setTimeout(resolve, 0))

describe("poetry--charts--live", () => {
  let application
  let frame

  beforeEach(async () => {
    // Snaps, not tweens - rAF-free tests; the morph path is covered by
    // the motion suite over the same flip module.
    globalThis.matchMedia = () => ({ matches: true })
    document.body.innerHTML = `<div data-chart="chart-live-a">${AREA.frame_a}</div>`
    frame = document.querySelector("[data-controller]")
    application = Application.start()
    registerPoetryChartsControllers(application)
    await nextFrame()
    return async () => {
      application?.stop()
      document.body.replaceChildren()
      delete globalThis.matchMedia
      await nextFrame()
    }
  })

  const areaD = () => frame.querySelector('path[data-slot="chart-area"]').getAttribute("d")
  const payloadScript = () => frame.querySelector('[data-slot="chart-live-payload"]')

  it("re-renders when the payload script is rewritten (the turbo_stream shape)", async () => {
    const before = areaD()
    const payload = JSON.parse(payloadScript().textContent)
    payload.spec.data = AREA.data_b
    payloadScript().textContent = JSON.stringify(payload)
    await settleObservers()

    expect(areaD()).not.toBe(before)
    expect(frame.querySelector("svg").getAttribute("data-motion")).toBe("settled")
  })

  it("re-renders through the poetry-chart:update event channel", async () => {
    const before = areaD()
    const updates = []
    frame.addEventListener("poetry--charts--live:updated", () => updates.push(1))

    frame.dispatchEvent(new CustomEvent("poetry-chart:update", { detail: { data: AREA.data_b } }))
    await settleObservers()

    expect(areaD()).not.toBe(before)
    expect(updates.length).toBe(1)
    // The payload script now holds the new data - the DOM is current state.
    expect(JSON.parse(payloadScript().textContent).spec.data).toEqual(AREA.data_b)
  })

  it("the renderer's own coordinates rewrite never re-triggers the observer", async () => {
    const render = vi.fn()
    frame.addEventListener("poetry--charts--live:updated", render)

    const payload = JSON.parse(payloadScript().textContent)
    payload.spec.data = AREA.data_b
    payloadScript().textContent = JSON.stringify(payload)
    await settleObservers()
    await settleObservers()

    expect(render).toHaveBeenCalledTimes(1)
  })

  it("the legend toggle hides the series, rescales the domain, and restores", async () => {
    // A toggle button as the legend renders it (action + param).
    const button = document.createElement("button")
    button.dataset.slot = "chart-legend-item"
    button.dataset.key = "desktop"
    button.dataset.action = "click->poetry--charts--live#toggleSeries"
    button.setAttribute("data-poetry--charts--live-key-param", "desktop")
    frame.appendChild(button)
    await nextFrame()

    const desktopArea = frame.querySelector('path[data-slot="chart-area"][data-key="desktop"]')
    const yTick = () => frame.querySelector('[data-slot="chart-y-axis"] text')?.textContent
    const before = yTick()

    button.click()
    await settleObservers()

    expect(desktopArea.style.display).toBe("none")
    expect(button.hasAttribute("data-hidden")).toBe(true)
    expect(JSON.parse(payloadScript().textContent).frame.hidden).toEqual(["desktop"])
    const coordinates = JSON.parse(frame.querySelector('[data-slot="chart-coordinates"]').textContent)
    expect(Object.keys(coordinates.values)).toEqual(["mobile"])
    if (before != null) expect(yTick()).not.toBe(before) // the domain rescaled

    button.click()
    await settleObservers()

    expect(desktopArea.style.display).toBe("")
    expect(button.hasAttribute("data-hidden")).toBe(false)
    expect(JSON.parse(payloadScript().textContent).frame.hidden).toEqual([])
  })

  it("the tooltip serves the fresh values after refresh", async () => {
    const svg = frame.querySelector("svg")
    // Activate index 0 via keyboard (End -> last, Home -> first).
    svg.dispatchEvent(new KeyboardEvent("keydown", { key: "Home", bubbles: true }))
    await nextFrame()

    frame.dispatchEvent(new CustomEvent("poetry-chart:update", { detail: { data: AREA.data_b } }))
    await settleObservers()

    const desktopRow = frame.querySelector('[data-slot="chart-tooltip-item"][data-key="desktop"]')
    expect(desktopRow.querySelector('[data-slot="chart-tooltip-value"]').textContent)
      .toBe("94.5") // data_b January desktop
  })
})
