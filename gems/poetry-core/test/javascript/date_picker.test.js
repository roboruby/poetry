import { beforeEach, describe, expect, it, vi } from "vitest"
import { Application } from "@hotwired/stimulus"
import { registerPoetryControllers } from "@poetry/controllers"

// poetry--core--date-picker JS-unit: the Popover<->Calendar glue. What this
// file proves: a calendar change writes the human-formatted date into the
// trigger label and closes the popover; a cleared value restores the
// placeholder and leaves the popover alone. The Calendar/Popover behavior
// is tested in their own files - here we only assert the coordination.

const nextFrame = () => new Promise((resolve) => setTimeout(resolve, 0))
const el = (id) => document.getElementById(id)

const markup = ({ mode = "" } = {}) => `
  <div id="picker" data-controller="poetry--core--date-picker"
       ${mode ? `data-poetry--core--date-picker-mode-value="${mode}"` : ""}
       data-action="poetry--core--calendar:change->poetry--core--date-picker#picked">
    <button id="trigger" type="button">
      <span id="label" data-poetry--core--date-picker-target="label">Pick a date</span>
    </button>
    <div id="pop" data-controller="poetry--core--popover"></div>
  </div>`

async function mount() {
  document.body.innerHTML = markup()
  const application = Application.start()
  registerPoetryControllers(application)
  await nextFrame()
  return application
}

const fireChange = (value) =>
  el("picker").dispatchEvent(new CustomEvent("poetry--core--calendar:change", { bubbles: true, detail: { value } }))

describe("poetry--core--date-picker", () => {
  let application
  let closeSpy

  beforeEach(async () => {
    application = await mount()
    const popover = application.getControllerForElementAndIdentifier(el("pop"), "poetry--core--popover")
    closeSpy = vi.spyOn(popover, "close").mockImplementation(() => {})
    return async () => {
      application.stop()
      document.body.replaceChildren()
      await nextFrame()
    }
  })

  it("a selection formats the label and closes the popover", () => {
    fireChange("2026-06-20")

    expect(el("label").textContent).toBe("June 20, 2026")
    expect(closeSpy).toHaveBeenCalled()
  })

  it("the input variant: picking writes the input, typing syncs the calendar, ArrowDown opens", async () => {
    application.stop()
    document.body.replaceChildren()
    await nextFrame()

    // A compact REAL calendar (June 2026, grid leads Sunday May 31) so the
    // typed-date sync exercises the reactive calendar values end to end.
    const day = (i) => {
      const iso = new Date(Date.UTC(2026, 4, 31 + i)).toISOString().slice(0, 10)
      return `<div role="gridcell" aria-selected="false">
                <button type="button" data-slot="calendar-day" data-poetry--core--calendar-target="day"
                        data-date="${iso}" tabindex="-1" data-action="click->poetry--core--calendar#select">
                  <span data-slot="calendar-day-label">x</span></button></div>`
    }
    document.body.innerHTML = `
      <div id="picker" data-controller="poetry--core--date-picker"
           data-action="poetry--core--calendar:change->poetry--core--date-picker#picked">
        <input id="din" type="text" data-poetry--core--date-picker-target="input"
               data-action="input->poetry--core--date-picker#inputChanged keydown->poetry--core--date-picker#inputKeydown">
        <div id="pop" data-controller="poetry--core--popover"></div>
        <div id="cal" data-controller="poetry--core--calendar"
             data-poetry--core--calendar-month-value="2026-06">
          <div data-poetry--core--calendar-target="caption">June 2026</div>
          <input type="hidden" id="cal-input" data-poetry--core--calendar-target="input" value="">
          <div data-poetry--core--calendar-target="grid">${Array.from({ length: 42 }, (_, i) => day(i)).join("")}</div>
        </div>
      </div>`
    application = Application.start()
    registerPoetryControllers(application)
    await nextFrame()

    const input = el("din")

    input.value = "June 20, 2026"
    input.dispatchEvent(new Event("input", { bubbles: true }))
    await nextFrame()

    expect(el("cal-input").value).toBe("2026-06-20")

    el("picker").dispatchEvent(new CustomEvent("poetry--core--calendar:change", {
      bubbles: true, detail: { value: "2026-06-05" }
    }))

    expect(input.value).toBe("June 5, 2026")

    const popover = application.getControllerForElementAndIdentifier(el("pop"), "poetry--core--popover")
    const openSpy = vi.spyOn(popover, "open").mockImplementation(() => {})

    input.dispatchEvent(new KeyboardEvent("keydown", { key: "ArrowDown", bubbles: true, cancelable: true }))

    expect(openSpy).toHaveBeenCalled()
  })

  it("range mode joins the pair with SHORT month names (two long-month dates outgrow the trigger)", async () => {
    application.stop()
    document.body.replaceChildren()
    await nextFrame()
    document.body.innerHTML = markup({ mode: "range" })
    application = Application.start()
    registerPoetryControllers(application)
    await nextFrame()

    el("picker").dispatchEvent(new CustomEvent("poetry--core--calendar:change", {
      bubbles: true, detail: { start: "2026-06-09", end: "2026-06-18" }
    }))

    expect(el("label").textContent).toBe("Jun 9, 2026 – Jun 18, 2026")
  })

  it("a cleared value restores the placeholder and leaves the popover open", () => {
    fireChange("2026-06-20")
    closeSpy.mockClear()

    fireChange("")

    expect(el("label").textContent).toBe("Pick a date")
    expect(closeSpy).not.toHaveBeenCalled()
  })
})

// The PORTALED coordination (docs/portal-on-open.md - the event
// bridge's first production consumer): the calendar's change fires INSIDE
// popover content that portal-on-open moved to body, and the picker's
// root data-action still hears it because the bridge re-dispatches from
// the home position. Without the bridge this exact wiring goes deaf.
describe("poetry--core--date-picker through the portal bridge", () => {
  const nested = () => `
    <div id="picker" data-controller="poetry--core--date-picker"
         data-action="poetry--core--calendar:change->poetry--core--date-picker#picked">
      <div id="pop" data-slot="popover" data-component="popover"
           data-controller="poetry--core--popover">
        <button id="trigger" type="button" data-slot="popover-trigger"
                aria-haspopup="dialog" aria-controls="content" aria-expanded="false"
                data-action="poetry--core--popover#toggle">
          <span id="label" data-poetry--core--date-picker-target="label">Pick a date</span>
        </button>
        <div id="content" data-slot="popover-content" role="dialog" tabindex="-1" data-closed hidden>
          <div id="calendar">grid</div>
        </div>
      </div>
    </div>`

  it("a pick inside the PORTALED popover formats the label and closes it", async () => {
    document.body.innerHTML = nested()
    const application = Application.start()
    registerPoetryControllers(application)
    await nextFrame()

    el("trigger").click()
    await nextFrame()

    expect(el("content").parentNode).toBe(document.body, "the popover portaled")

    el("calendar").dispatchEvent(
      new CustomEvent("poetry--core--calendar:change", { bubbles: true, detail: { value: "2026-06-20" } })
    )
    await nextFrame()

    expect(el("label").textContent).toBe("June 20, 2026")
    expect(el("content").hasAttribute("data-closed")).toBe(true)
    expect(el("content").parentNode).toBe(el("pop"), "close restored the content home")

    application.stop()
    document.body.replaceChildren()
    await nextFrame()
  })
})
