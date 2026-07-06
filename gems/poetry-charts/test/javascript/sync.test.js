import { beforeEach, describe, expect, it } from "vitest"
import { Application } from "@hotwired/stimulus"
import { registerPoetryChartsControllers } from "../../app/javascript/poetry/charts/index.js"

// C-W4 synced charts (recharts syncId): tooltips sharing a sync value
// follow each other's active index over a window event - show follows,
// leave follows, different groups stay independent, and the loop guard
// keeps the broadcast from echoing forever.

const nextFrame = () => new Promise((resolve) => setTimeout(resolve, 0))

const PAYLOAD = {
  layout: "vertical",
  categories: ["January", "February", "March"],
  x: [12, 320, 628],
  values: { desktop: ["10", "20", "30"] },
  series: { desktop: [100, 40, 80] },
}

const chart = (id, sync) => `
  <div data-chart="chart-${id}" style="position:relative">
    <div id="${id}" data-controller="poetry--charts--tooltip"
         data-poetry--charts--tooltip-sync-value="${sync}">
      <svg viewBox="0 0 640 360" data-poetry--charts--tooltip-target="svg"
           data-action="keydown->poetry--charts--tooltip#keydown"></svg>
      <div data-poetry--charts--tooltip-target="tooltip" hidden>
        <div data-slot="chart-tooltip-label"></div>
        <div data-slot="chart-tooltip-item" data-key="desktop"><span data-slot="chart-tooltip-value"></span></div>
      </div>
      <script type="application/json" data-poetry--charts--tooltip-target="data">${JSON.stringify(PAYLOAD)}</script>
    </div>
  </div>`

describe("synced tooltips", () => {
  let application

  const controllerFor = (id) =>
    application.getControllerForElementAndIdentifier(document.getElementById(id), "poetry--charts--tooltip")

  beforeEach(async () => {
    document.body.innerHTML = chart("a", "grp") + chart("b", "grp") + chart("c", "other")
    application = Application.start()
    registerPoetryChartsControllers(application)
    await nextFrame()
    return async () => {
      application?.stop()
      document.body.replaceChildren()
      await nextFrame()
    }
  })

  it("show follows across the group, leave follows, other groups stay put", () => {
    const a = controllerFor("a")
    const b = controllerFor("b")
    const c = controllerFor("c")

    a.show(2)
    expect(b.activeIndex).toBe(2)
    expect(document.querySelector("#b [data-slot='chart-tooltip-label']").textContent).toBe("March")
    expect(c.activeIndex).toBe(null)

    a.leave()
    expect(b.activeIndex).toBe(null)
    expect(document.querySelector("#b [data-poetry--charts--tooltip-target='tooltip']").hidden).toBe(true)
  })

  it("the loop guard keeps a synced show from echoing back", () => {
    const a = controllerFor("a")
    const b = controllerFor("b")

    let broadcasts = 0
    const count = () => (broadcasts += 1)
    window.addEventListener("poetry-chart:sync", count)
    a.show(1)
    window.removeEventListener("poetry-chart:sync", count)

    // One broadcast from A; B applies it silently (no echo).
    expect(broadcasts).toBe(1)
    expect(b.activeIndex).toBe(1)
  })
})
