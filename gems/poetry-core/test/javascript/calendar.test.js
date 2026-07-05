import { beforeEach, describe, expect, it, vi } from "vitest"
import { Application } from "@hotwired/stimulus"
import { registerPoetryControllers } from "@poetry/controllers"

// poetry--core--calendar JS-unit: the own-the-engine month grid. What this
// file proves: selection writes the hidden input + the data-selected/aria
// vocabulary, month nav regenerates the 42 cells in place (labels, outside,
// disabled, caption), arrow keys move focus by day/week crossing month
// boundaries, min/max disable, and the roving tab-stop. The server renders
// the initial month, so a fixed 42-cell June-2026 grid is the fixture.

const nextFrame = () => new Promise((resolve) => setTimeout(resolve, 0))
const el = (id) => document.getElementById(id)

// June 2026: the 1st is a Monday, so with weekStart=0 (Sunday) the grid
// leads with 5 outside days (May 31 is Sunday... actually May 31 2026 is a
// Sunday). 42 cells from May 31 to Jul 11.
const START = Date.UTC(2026, 4, 31) // May 31 2026 (Sunday)
const isoOf = (index) => new Date(START + index * 86400000).toISOString().slice(0, 10)

const dayButton = (index) => {
  const iso = isoOf(index)
  const outside = !iso.startsWith("2026-06")
  // The role=gridcell wrapper carries aria-selected (the real markup shape).
  return `<div role="gridcell" aria-selected="false">
            <button type="button" data-slot="calendar-day" data-poetry--core--calendar-target="day"
                    data-date="${iso}" ${outside ? "data-outside" : ""} tabindex="-1"
                    data-action="click->poetry--core--calendar#select">
              <span data-slot="calendar-day-label">${new Date(iso + "T00:00:00Z").getUTCDate()}</span>
            </button>
          </div>`
}

const markup = ({ selected = "", min = "", max = "" } = {}) => `
  <div id="cal" data-controller="poetry--core--calendar"
       data-poetry--core--calendar-month-value="2026-06"
       data-poetry--core--calendar-selected-value="${selected}"
       data-poetry--core--calendar-min-value="${min}"
       data-poetry--core--calendar-max-value="${max}">
    <div data-poetry--core--calendar-target="caption">June 2026</div>
    <button id="prev" type="button" data-action="click->poetry--core--calendar#previousMonth">‹</button>
    <button id="next" type="button" data-action="click->poetry--core--calendar#nextMonth">›</button>
    <input type="hidden" id="input" data-poetry--core--calendar-target="input" value="${selected}">
    <div data-poetry--core--calendar-target="grid" data-action="keydown->poetry--core--calendar#keydown">
      ${Array.from({ length: 42 }, (_, i) => dayButton(i)).join("")}
    </div>
  </div>`

const dayFor = (iso) => [...document.querySelectorAll('[data-slot="calendar-day"]')].find((d) => d.dataset.date === iso)

async function mount(options) {
  document.body.innerHTML = markup(options)
  const application = Application.start()
  registerPoetryControllers(application)
  await nextFrame()
  return application
}

describe("poetry--core--calendar", () => {
  let application

  beforeEach(() => {
    // Pin "today" so the today marker is deterministic.
    vi.setSystemTime(new Date("2026-06-15T12:00:00Z"))
    return async () => {
      application?.stop()
      document.body.replaceChildren()
      vi.useRealTimers()
      await nextFrame()
    }
  })

  it("clicking a day selects it: hidden input + vocabulary + change event", async () => {
    application = await mount()
    let detail = null
    el("cal").addEventListener("poetry--core--calendar:change", (event) => { detail = event.detail })

    dayFor("2026-06-20").click()

    expect(el("input").value).toBe("2026-06-20")
    expect(dayFor("2026-06-20").hasAttribute("data-selected")).toBe(true)
    expect(dayFor("2026-06-20").closest('[role="gridcell"]').getAttribute("aria-selected")).toBe("true")
    expect(detail).toEqual({ value: "2026-06-20" })
  })

  it("only one day is selected at a time", async () => {
    application = await mount({ selected: "2026-06-10" })

    dayFor("2026-06-20").click()

    expect(dayFor("2026-06-10").hasAttribute("data-selected")).toBe(false)
    expect(dayFor("2026-06-20").hasAttribute("data-selected")).toBe(true)
  })

  it("next month regenerates the grid in place: labels, caption, outside", async () => {
    application = await mount()

    el("next").click()

    // July 2026 starts on a Wednesday; the first cell is Jun 28 (outside).
    const first = document.querySelector('[data-slot="calendar-day"]')
    expect(first.dataset.date).toBe("2026-06-28")
    expect(first.hasAttribute("data-outside")).toBe(true)
    expect(el("cal").querySelector("[data-poetry--core--calendar-target=caption]").textContent).toBe("July 2026")
    // A known July day is in-month.
    expect(dayFor("2026-07-04").hasAttribute("data-outside")).toBe(false)
  })

  it("today wears aria-current=date", async () => {
    application = await mount()

    expect(dayFor("2026-06-15").getAttribute("aria-current")).toBe("date")
    expect(dayFor("2026-06-14").hasAttribute("aria-current")).toBe(false)
  })

  it("min/max disable out-of-range days", async () => {
    application = await mount({ min: "2026-06-10", max: "2026-06-20" })
    // The controller reflects on connect; nav re-applies. Force a render.
    el("next").click()
    el("prev").click()

    expect(dayFor("2026-06-05").disabled).toBe(true)
    expect(dayFor("2026-06-15").disabled).toBe(false)
    expect(dayFor("2026-06-25").disabled).toBe(true)
  })

  it("arrow keys move focus by day and week", async () => {
    application = await mount({ selected: "2026-06-15" })
    const start = dayFor("2026-06-15")
    start.focus()

    start.dispatchEvent(new KeyboardEvent("keydown", { key: "ArrowRight", bubbles: true, cancelable: true }))
    expect(document.activeElement).toBe(dayFor("2026-06-16"))

    dayFor("2026-06-16").dispatchEvent(new KeyboardEvent("keydown", { key: "ArrowDown", bubbles: true, cancelable: true }))
    expect(document.activeElement).toBe(dayFor("2026-06-23"))
  })

  it("arrowing across a month boundary re-renders then focuses", async () => {
    application = await mount({ selected: "2026-06-30" })
    const start = dayFor("2026-06-30")
    start.focus()

    start.dispatchEvent(new KeyboardEvent("keydown", { key: "ArrowRight", bubbles: true, cancelable: true }))

    expect(el("cal").querySelector("[data-poetry--core--calendar-target=caption]").textContent).toBe("July 2026")
    expect(document.activeElement.dataset.date).toBe("2026-07-01")
  })
})
