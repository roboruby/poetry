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

// -- range mode (N9 D1): the addToRange transcription + the range wire ------

const rangeMarkup = ({ start = "", end = "" } = {}) => `
  <div id="cal" data-controller="poetry--core--calendar"
       data-poetry--core--calendar-month-value="2026-06"
       data-poetry--core--calendar-mode-value="range"
       data-poetry--core--calendar-range-start-value="${start}"
       data-poetry--core--calendar-range-end-value="${end}">
    <div data-poetry--core--calendar-target="caption">June 2026</div>
    <button id="prev" type="button" data-action="click->poetry--core--calendar#previousMonth">‹</button>
    <input type="hidden" id="start-input" data-poetry--core--calendar-target="startInput" value="${start}">
    <input type="hidden" id="end-input" data-poetry--core--calendar-target="endInput" value="${end}">
    <div data-poetry--core--calendar-target="grid" data-action="keydown->poetry--core--calendar#keydown">
      ${Array.from({ length: 42 }, (_, i) => dayButton(i)).join("")}
    </div>
  </div>`

async function mountRange(options) {
  document.body.innerHTML = rangeMarkup(options)
  const application = Application.start()
  registerPoetryControllers(application)
  await nextFrame()
  return application
}

describe("poetry--core--calendar range mode", () => {
  let application

  beforeEach(() => async () => {
    application?.stop()
    document.body.replaceChildren()
    await nextFrame()
  })

  const attrsOf = (iso) => {
    const day = dayFor(iso)
    return {
      selected: day.hasAttribute("data-selected"),
      start: day.hasAttribute("data-range-start"),
      middle: day.hasAttribute("data-range-middle"),
      end: day.hasAttribute("data-range-end"),
      aria: day.closest("[role=gridcell]").getAttribute("aria-selected"),
    }
  }

  it("walks the addToRange states: start, complete, extend, restart, clear", async () => {
    application = await mountRange()
    const changes = []
    el("cal").addEventListener("poetry--core--calendar:change", (e) => changes.push({ ...e.detail }))

    // First click: a start-only pick renders as a plain selected single day.
    dayFor("2026-06-10").click()
    expect(attrsOf("2026-06-10")).toMatchObject({ selected: true, start: false, aria: "true" })
    expect(el("start-input").value).toBe("2026-06-10")
    expect(el("end-input").value).toBe("")
    expect(changes.at(-1)).toEqual({ start: "2026-06-10", end: "" })

    // Second click after: completes - the range vocabulary appears.
    dayFor("2026-06-15").click()
    expect(attrsOf("2026-06-10")).toMatchObject({ selected: false, start: true })
    expect(attrsOf("2026-06-12")).toMatchObject({ middle: true, aria: "true" })
    expect(attrsOf("2026-06-15")).toMatchObject({ end: true })
    expect(el("end-input").value).toBe("2026-06-15")

    // Click past the end: moves the end.
    dayFor("2026-06-20").click()
    expect(attrsOf("2026-06-15")).toMatchObject({ middle: true, end: false })
    expect(attrsOf("2026-06-20")).toMatchObject({ end: true })

    // Click before the start: extends backward.
    dayFor("2026-06-05").click()
    expect(attrsOf("2026-06-05")).toMatchObject({ start: true })
    expect(attrsOf("2026-06-10")).toMatchObject({ middle: true, start: false })

    // Click the end of a complete range: restarts from it.
    dayFor("2026-06-20").click()
    expect(attrsOf("2026-06-20")).toMatchObject({ selected: true, start: false, end: false })
    expect(el("end-input").value).toBe("")
    expect(attrsOf("2026-06-05")).toMatchObject({ start: false, selected: false, aria: "false" })

    // Complete as a single day, then re-click clears everything.
    dayFor("2026-06-20").click()
    expect(attrsOf("2026-06-20")).toMatchObject({ start: true, end: true })
    dayFor("2026-06-20").click()
    expect(attrsOf("2026-06-20")).toMatchObject({ selected: false, start: false, end: false, aria: "false" })
    expect(el("start-input").value).toBe("")
    expect(changes.at(-1)).toEqual({ start: "", end: "" })
  })

  it("click-before-start swaps into a valid range", async () => {
    application = await mountRange()
    dayFor("2026-06-15").click()
    dayFor("2026-06-10").click()

    expect(attrsOf("2026-06-10")).toMatchObject({ start: true })
    expect(attrsOf("2026-06-15")).toMatchObject({ end: true })
    expect(el("start-input").value).toBe("2026-06-10")
    expect(el("end-input").value).toBe("2026-06-15")
  })

  it("the range vocabulary survives month navigation (offscreen endpoints)", async () => {
    application = await mountRange({ start: "2026-06-20", end: "2026-07-10" })
    await nextFrame()

    // June view: the start wears range-start, later June days are middle.
    expect(attrsOf("2026-06-20")).toMatchObject({ start: true })
    expect(attrsOf("2026-06-25")).toMatchObject({ middle: true })

    // Navigate to July: the end appears, early July days are middle, the
    // start is offscreen but the span still paints.
    el("cal").querySelector("#prev").click() // May
    el("cal").querySelector("#prev") // (noop - just ensure re-render safe)
    application.getControllerForElementAndIdentifier(el("cal"), "poetry--core--calendar").nextMonth() // June
    application.getControllerForElementAndIdentifier(el("cal"), "poetry--core--calendar").nextMonth() // July

    expect(dayFor("2026-07-05").hasAttribute("data-range-middle")).toBe(true)
    expect(dayFor("2026-07-10").hasAttribute("data-range-end")).toBe(true)
  })
})
