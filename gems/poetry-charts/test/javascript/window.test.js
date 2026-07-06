import { beforeEach, describe, expect, it } from "vitest"
import fs from "node:fs"
import path from "node:path"
import { fileURLToPath } from "node:url"
import { Application } from "@hotwired/stimulus"
import { registerPoetryChartsControllers } from "../../app/javascript/poetry/charts/index.js"

// C-W5 the window: brush handle drags and drag-zoom both funnel into
// frame.window - the renderer slices the FULL data, the strip repaints
// from index fractions, double-click resets. The fixture is the real
// server render (live_fixtures area case) with the brush strip injected
// exactly as the server emits it.

const ROOT = path.dirname(path.dirname(path.dirname(fileURLToPath(import.meta.url))))
const FIXTURES = JSON.parse(fs.readFileSync(path.join(ROOT, "test/fixtures/live_fixtures.json"), "utf8"))
const AREA = FIXTURES.cases.find((c) => c.name === "area_stacked")

const nextFrame = () => new Promise((resolve) => setTimeout(resolve, 0))

const BRUSH = `
  <g data-slot="chart-brush" data-action="pointerdown->poetry--charts--window#startBrush">
    <rect data-slot="chart-brush-track" x="12" y="322" width="616" height="30"></rect>
    <rect data-slot="chart-brush-window" x="12" y="322" width="616" height="30"></rect>
    <rect data-slot="chart-brush-handle" data-edge="start" x="9" y="322" width="6" height="30"></rect>
    <rect data-slot="chart-brush-handle" data-edge="end" x="625" y="322" width="6" height="30"></rect>
  </g>
  <rect data-slot="chart-zoom-selection" x="0" y="5" width="0" height="320" display="none"></rect>`

describe("poetry--charts--window", () => {
  let application
  let frame

  beforeEach(async () => {
    globalThis.matchMedia = () => ({ matches: true }) // snap renders
    document.body.innerHTML = `<div data-chart="chart-live-a">${AREA.frame_a}</div>`
    frame = document.querySelector("[data-controller]")
    frame.setAttribute("data-controller", `${frame.getAttribute("data-controller")} poetry--charts--window`)
    frame.setAttribute("data-poetry--charts--window-zoom-value", "true")
    frame.setAttribute("data-poetry--charts--window-plot-value", "[12, 628, 5, 325]")
    frame.setAttribute("data-poetry--charts--window-brush-value", "[12, 322, 616, 30]")
    const svg = frame.querySelector("svg")
    svg.insertAdjacentHTML("beforeend", BRUSH)
    svg.setAttribute(
      "data-action",
      `${svg.getAttribute("data-action") ?? ""} pointerdown->poetry--charts--window#startZoom ` +
        "dblclick->poetry--charts--window#reset"
    )
    // clientX == viewBox x under a 640-wide rect at origin.
    svg.getBoundingClientRect = () => ({ left: 0, top: 0, width: 640, height: 360 })

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

  const payload = () => JSON.parse(frame.querySelector('[data-slot="chart-live-payload"]').textContent)
  const tickCount = () => frame.querySelectorAll('[data-slot="chart-x-axis"] text').length

  it("dragging the end handle narrows the window and slices the chart", async () => {
    expect(tickCount()).toBe(6)

    const handle = frame.querySelector('[data-slot="chart-brush-handle"][data-edge="end"]')
    handle.dispatchEvent(new MouseEvent("pointerdown", { bubbles: true, clientX: 628 }))
    // 616px track over 5 index steps: -370px ~ -3 indexes -> window [0, 2].
    window.dispatchEvent(new MouseEvent("pointermove", { clientX: 258 }))
    window.dispatchEvent(new MouseEvent("pointerup", { clientX: 258 }))
    await nextFrame()

    expect(payload().frame.window).toEqual([0, 2])
    expect(tickCount()).toBe(3)
    // The strip repainted: the window rect shrank to 2/5 of the track.
    const windowRect = frame.querySelector('[data-slot="chart-brush-window"]')
    expect(Number(windowRect.getAttribute("width"))).toBeCloseTo(616 * (2 / 5), 1)
  })

  it("drag-zoom on the plot selects an index range; double-click resets", async () => {
    const svg = frame.querySelector("svg")
    // Drag across the middle: x 135 -> 382 over plot [12, 628] and 6
    // categories -> indexes 1..3.
    svg.dispatchEvent(new MouseEvent("pointerdown", { bubbles: true, clientX: 135 }))
    window.dispatchEvent(new MouseEvent("pointermove", { clientX: 382 }))
    const selection = frame.querySelector('[data-slot="chart-zoom-selection"]')
    expect(selection.getAttribute("display")).toBe(null) // visible mid-drag
    window.dispatchEvent(new MouseEvent("pointerup", { clientX: 382 }))
    await nextFrame()

    expect(payload().frame.window).toEqual([1, 3])
    expect(tickCount()).toBe(3)
    expect(selection.getAttribute("display")).toBe("none")

    svg.dispatchEvent(new MouseEvent("dblclick", { bubbles: true }))
    await nextFrame()

    expect(payload().frame.window).toEqual([0, 5])
    expect(tickCount()).toBe(6)
  })
})
