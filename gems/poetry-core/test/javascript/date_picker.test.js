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

const markup = () => `
  <div id="picker" data-controller="poetry--core--date-picker"
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

  it("a cleared value restores the placeholder and leaves the popover open", () => {
    fireChange("2026-06-20")
    closeSpy.mockClear()

    fireChange("")

    expect(el("label").textContent).toBe("Pick a date")
    expect(closeSpy).not.toHaveBeenCalled()
  })
})
