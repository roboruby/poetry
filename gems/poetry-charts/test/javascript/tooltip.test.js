import { beforeEach, describe, expect, it } from "vitest"
import { Application } from "@hotwired/stimulus"
import { registerPoetryChartsControllers } from "../../app/javascript/poetry/charts/index.js"

// poetry--charts--tooltip JS-unit: the zero-client-math contract. The
// fixture mirrors the rendered shape: SVG target + hidden chrome + the
// embedded JSON (centers/categories/pre-formatted values/pixel extents).
// What this file proves: bisect picks the nearest category, show swaps
// PRE-FORMATTED text (no toLocaleString anywhere), rows with missing
// values hide, data-active reflects onto marks and active dots, keyboard
// walks categories and Escape dismisses, leave clears everything.

const nextFrame = () => new Promise((resolve) => setTimeout(resolve, 0))

const PAYLOAD = {
  layout: "vertical",
  categories: ["January", "February", "March"],
  x: [12, 320, 628],
  series: { desktop: [100, 40, 80], mobile: [140, 90, null] },
  values: { desktop: ["1,860", "3,050", "2,370"], mobile: ["800", "2,000", null] },
}

const markup = () => `
  <div data-chart="chart-t" style="position:relative">
    <div data-controller="poetry--charts--tooltip">
      <svg viewBox="0 0 640 360" role="application" tabindex="0"
           data-poetry--charts--tooltip-target="svg"
           data-action="pointermove->poetry--charts--tooltip#move pointerleave->poetry--charts--tooltip#leave focus->poetry--charts--tooltip#focus blur->poetry--charts--tooltip#blur keydown->poetry--charts--tooltip#keydown">
        <path data-slot="chart-bar" data-index="0"></path>
        <path data-slot="chart-bar" data-index="1"></path>
        <circle data-slot="chart-active-dot" data-index="0" display="none"></circle>
        <circle data-slot="chart-active-dot" data-index="1" display="none"></circle>
      </svg>
      <div data-poetry--charts--tooltip-target="tooltip" hidden>
        <div data-slot="chart-tooltip-label"></div>
        <div data-slot="chart-tooltip-item" data-key="desktop"><span data-slot="chart-tooltip-value"></span></div>
        <div data-slot="chart-tooltip-item" data-key="mobile"><span data-slot="chart-tooltip-value"></span></div>
      </div>
      <script type="application/json" data-poetry--charts--tooltip-target="data">${JSON.stringify(PAYLOAD)}</script>
    </div>
  </div>`

describe("poetry--charts--tooltip", () => {
  let application
  let controller

  beforeEach(async () => {
    document.body.innerHTML = markup()
    application = Application.start()
    registerPoetryChartsControllers(application)
    await nextFrame()
    const element = document.querySelector("[data-controller]")
    controller = application.getControllerForElementAndIdentifier(element, "poetry--charts--tooltip")
    return async () => {
      application?.stop()
      document.body.replaceChildren()
      await nextFrame()
    }
  })

  const tooltip = () => document.querySelector('[data-poetry--charts--tooltip-target="tooltip"]')

  it("show swaps pre-formatted values into the server-rendered chrome", () => {
    controller.show(1)

    expect(tooltip().hidden).toBe(false)
    expect(document.querySelector('[data-slot="chart-tooltip-label"]').textContent).toBe("February")
    const rows = document.querySelectorAll('[data-slot="chart-tooltip-item"]')
    expect(rows[0].querySelector("[data-slot=chart-tooltip-value]").textContent).toBe("3,050")
    expect(rows[1].querySelector("[data-slot=chart-tooltip-value]").textContent).toBe("2,000")
  })

  it("rows with missing values hide for that index", () => {
    controller.show(2)

    const mobile = document.querySelector('[data-slot="chart-tooltip-item"][data-key="mobile"]')
    expect(mobile.style.display).toBe("none")
    controller.show(0)
    expect(mobile.style.display).toBe("")
  })

  it("data-active reflects onto marks and active dots", () => {
    controller.show(1)

    expect(document.querySelector('[data-index="1"][data-slot="chart-bar"]').hasAttribute("data-active")).toBe(true)
    expect(document.querySelector('[data-index="0"][data-slot="chart-bar"]').hasAttribute("data-active")).toBe(false)
    expect(document.querySelector('[data-slot="chart-active-dot"][data-index="1"]').getAttribute("display")).toBe("")
    expect(document.querySelector('[data-slot="chart-active-dot"][data-index="0"]').getAttribute("display")).toBe("none")
  })

  it("keyboard walks the categories and Escape dismisses", () => {
    const svg = document.querySelector("svg")
    svg.dispatchEvent(new KeyboardEvent("keydown", { key: "ArrowRight", bubbles: true, cancelable: true }))
    expect(controller.activeIndex).toBe(0)

    svg.dispatchEvent(new KeyboardEvent("keydown", { key: "ArrowRight", bubbles: true, cancelable: true }))
    expect(controller.activeIndex).toBe(1)
    expect(document.querySelector('[data-slot="chart-tooltip-label"]').textContent).toBe("February")

    svg.dispatchEvent(new KeyboardEvent("keydown", { key: "End", bubbles: true, cancelable: true }))
    expect(controller.activeIndex).toBe(2)

    svg.dispatchEvent(new KeyboardEvent("keydown", { key: "Escape", bubbles: true, cancelable: true }))
    expect(tooltip().hidden).toBe(true)
    expect(controller.activeIndex).toBeNull()
  })

  it("leave clears active state everywhere", () => {
    controller.show(1)
    controller.leave()

    expect(tooltip().hidden).toBe(true)
    expect(document.querySelectorAll("[data-active]").length).toBe(0)
    expect(document.querySelector('[data-slot="chart-active-dot"][data-index="1"]').getAttribute("display")).toBe("none")
  })

  it("focus shows the first category when nothing is active", () => {
    document.querySelector("svg").dispatchEvent(new FocusEvent("focus"))

    expect(controller.activeIndex).toBe(0)
    expect(document.querySelector('[data-slot="chart-tooltip-label"]').textContent).toBe("January")
  })
})

// The polar shape (pie/radial): per-index anchors + names/colors retint
// the single chrome row; slices are hit by pointerover on [data-index].
const POLAR_PAYLOAD = {
  layout: "polar",
  categories: ["Chrome", "Safari"],
  names: ["Chrome", "Safari"],
  colors: ["var(--color-chrome)", "var(--color-safari)"],
  anchors: [[400, 100], [200, 250]],
  values: { visitors: ["275", "200"] },
}

const polarMarkup = () => `
  <div data-chart="chart-p" style="position:relative">
    <div data-controller="poetry--charts--tooltip">
      <svg viewBox="0 0 640 360" role="application" tabindex="0"
           data-poetry--charts--tooltip-target="svg"
           data-action="pointerover->poetry--charts--tooltip#enter keydown->poetry--charts--tooltip#keydown">
        <path data-slot="chart-pie-sector" data-index="0"></path>
        <path data-slot="chart-pie-sector" data-index="1"></path>
      </svg>
      <div data-poetry--charts--tooltip-target="tooltip" hidden>
        <div data-slot="chart-tooltip-item" data-key="visitors">
          <div data-slot="chart-tooltip-indicator"></div>
          <span data-slot="chart-tooltip-name"></span>
          <span data-slot="chart-tooltip-value"></span>
        </div>
      </div>
      <script type="application/json" data-poetry--charts--tooltip-target="data">${JSON.stringify(POLAR_PAYLOAD)}</script>
    </div>
  </div>`

describe("poetry--charts--tooltip (polar)", () => {
  let application

  beforeEach(async () => {
    document.body.innerHTML = polarMarkup()
    application = Application.start()
    registerPoetryChartsControllers(application)
    await nextFrame()
    return async () => {
      application?.stop()
      document.body.replaceChildren()
      await nextFrame()
    }
  })

  it("pointerover on a slice shows and RETINTS the single row", async () => {
    const slice = document.querySelector('[data-index="1"]')
    slice.dispatchEvent(new MouseEvent("pointerover", { bubbles: true }))
    await nextFrame()

    const tooltip = document.querySelector('[data-poetry--charts--tooltip-target="tooltip"]')
    expect(tooltip.hidden).toBe(false)
    expect(document.querySelector('[data-slot="chart-tooltip-name"]').textContent).toBe("Safari")
    expect(document.querySelector('[data-slot="chart-tooltip-value"]').textContent).toBe("200")
    const indicator = document.querySelector('[data-slot="chart-tooltip-indicator"]')
    expect(indicator.style.getPropertyValue("--color-bg")).toBe("var(--color-safari)")
    expect(slice.hasAttribute("data-active")).toBe(true)
  })

  it("keyboard walks slices through the anchors count", async () => {
    const svg = document.querySelector("svg")
    svg.dispatchEvent(new KeyboardEvent("keydown", { key: "ArrowRight", bubbles: true, cancelable: true }))
    await nextFrame()

    expect(document.querySelector('[data-slot="chart-tooltip-name"]').textContent).toBe("Chrome")
    svg.dispatchEvent(new KeyboardEvent("keydown", { key: "End", bubbles: true, cancelable: true }))
    expect(document.querySelector('[data-slot="chart-tooltip-name"]').textContent).toBe("Safari")
  })
})
