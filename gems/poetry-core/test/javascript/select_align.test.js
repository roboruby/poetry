import { beforeEach, describe, expect, it, vi } from "vitest"
import { Application } from "@hotwired/stimulus"
import { registerPoetryControllers } from "@poetry/controllers"

// poetry--core--select alignItemWithTrigger - the MODE/FALLBACK
// logic only: jsdom has no layout, so every geometry path resolves to the
// Base UI fallback (trigger at 0,0 sits inside the 20px collision
// threshold), which is exactly the branch worth pinning here. The real
// alignment geometry (item text over trigger text, list scroll, viewport
// vars) is browser-proven on the docs /components/select aligned example.

const nextFrame = () => new Promise((resolve) => setTimeout(resolve, 0))
const el = (id) => document.getElementById(id)

const markup = ({ aligned = false } = {}) => `
  <div id="root" data-slot="select" data-component="select"
       data-controller="poetry--core--select"
       data-poetry--core--select-align-item-with-trigger-value="${aligned}">
    <select id="native" data-slot="select-native" aria-hidden="true" tabindex="-1" name="fruit"
            data-action="change->poetry--core--select#nativeChanged">
      <option value=""></option>
      <option value="apple" selected>Apple</option>
    </select>
    <button type="button" id="trigger" data-slot="select-trigger" role="combobox"
            aria-controls="content" aria-expanded="false"
            data-action="poetry--core--select#toggle">
      <span id="display" data-slot="select-value">Apple</span>
    </button>
    <div id="content" data-slot="select-content" role="listbox" tabindex="-1" data-closed hidden>
      <div id="viewport" data-slot="select-viewport">
        <div id="item-apple" data-slot="select-item" role="option" tabindex="-1"
             data-poetry-collection-item data-value="apple" aria-selected="true" data-selected
             data-action="click->poetry--core--select#commit">
          <span data-slot="select-item-text">Apple</span>
        </div>
      </div>
    </div>
  </div>`

async function mount(options = {}) {
  document.body.innerHTML = markup(options)
  const application = Application.start()
  registerPoetryControllers(application)
  await nextFrame()
  return application
}

const open = async () => {
  el("trigger").click()
  await nextFrame()
  await nextFrame()
}

describe("poetry--core--select alignItemWithTrigger", () => {
  let application

  beforeEach(() => {
    return async () => {
      document.body.replaceChildren()
      await nextFrame()
      application.stop()
      vi.unstubAllGlobals()
    }
  })

  it("stays a plain popper select when the value is off (the default)", async () => {
    application = await mount({ aligned: false })
    await open()

    expect(el("content").hasAttribute("data-align-item-with-trigger")).toBe(false)
  })

  it("falls back on coarse pointers (the touch delta, Base UI parity)", async () => {
    vi.stubGlobal("matchMedia", vi.fn().mockReturnValue({ matches: true }))
    application = await mount({ aligned: true })
    await open()

    expect(el("content").hasAttribute("data-align-item-with-trigger")).toBe(false)
    expect(el("content").hidden).toBe(false)
  })

  it("collision fallback removes the marker and leaves no aligned styles behind", async () => {
    // jsdom rects are all zeros: triggerRect.top(0) < 20 -> the collision
    // fallback path runs after the marker was set for the measure.
    vi.stubGlobal("matchMedia", vi.fn().mockReturnValue({ matches: false }))
    application = await mount({ aligned: true })
    await open()

    const content = el("content")
    expect(content.hasAttribute("data-align-item-with-trigger")).toBe(false)
    expect(content.style.position).toBe("")
    expect(content.style.height).toBe("")
    expect(content.style.getPropertyValue("--radix-select-trigger-height")).toBe("")
    expect(content.hidden).toBe(false) // the open itself survives the fallback
  })

  it("close clears the aligned state even if a run left it on", async () => {
    application = await mount({ aligned: true })
    await open()

    const content = el("content")
    content.setAttribute("data-align-item-with-trigger", "")
    content.style.position = "fixed"
    content.style.height = "300px"

    el("trigger").click()
    await nextFrame()

    expect(content.hasAttribute("data-align-item-with-trigger")).toBe(false)
    expect(content.style.position).toBe("")
    expect(content.style.height).toBe("")
  })
})
