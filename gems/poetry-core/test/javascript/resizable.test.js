import { beforeEach, describe, expect, it } from "vitest"
import { Application } from "@hotwired/stimulus"
import { registerPoetryControllers } from "@poetry/controllers"

// poetry--core--resizable JS-unit: the APG window splitter. What this file
// proves: a drag redistributes the two adjacent panels' flex-grow
// percentages (both panels' min/max honored), arrows step and Home/End
// jump the range, aria-valuenow tracks the preceding panel, and the
// resize event reports all sizes.

const nextFrame = () => new Promise((resolve) => setTimeout(resolve, 0))
const el = (id) => document.getElementById(id)

const markup = () => `
  <div id="group" data-controller="poetry--core--resizable" data-orientation="horizontal"
       data-slot="resizable-panel-group">
    <div id="a" data-slot="resizable-panel" data-min-size="20" style="flex: 50 1 0px"></div>
    <div id="handle" data-slot="resizable-handle" role="separator" tabindex="0" aria-orientation="vertical"
         data-action="pointerdown->poetry--core--resizable#dragStart
                      pointermove->poetry--core--resizable#dragMove
                      pointerup->poetry--core--resizable#dragEnd
                      keydown->poetry--core--resizable#keydown"></div>
    <div id="b" data-slot="resizable-panel" data-min-size="20" style="flex: 50 1 0px"></div>
  </div>`

const pointer = (type, target, { x = 0, id = 1 } = {}) => {
  const event = new MouseEvent(type, { bubbles: true, cancelable: true, clientX: x, button: 0 })
  Object.defineProperty(event, "pointerId", { value: id })
  Object.defineProperty(event, "pointerType", { value: "touch" })
  target.dispatchEvent(event)
}

const sizes = () => [parseFloat(el("a").style.flexGrow), parseFloat(el("b").style.flexGrow)]

async function mount() {
  document.body.innerHTML = markup()
  Element.prototype.setPointerCapture ||= () => {}
  el("group").getBoundingClientRect = () => ({ left: 0, top: 0, width: 400, height: 200 })
  const application = Application.start()
  registerPoetryControllers(application)
  await nextFrame()
  return application
}

describe("poetry--core--resizable", () => {
  let application

  beforeEach(async () => {
    application = await mount()
    return async () => {
      application.stop()
      document.body.replaceChildren()
      await nextFrame()
    }
  })

  it("connect reflects the preceding panel onto the handle", () => {
    const handle = el("handle")

    expect(handle.getAttribute("aria-valuenow")).toBe("50")
    expect(handle.getAttribute("aria-valuemin")).toBe("20")
    expect(handle.getAttribute("aria-valuemax")).toBe("90")
  })

  it("a drag redistributes the two adjacent panels", () => {
    pointer("pointerdown", el("handle"), { x: 200 })
    pointer("pointermove", el("handle"), { x: 240 }) // +40px of 400 = +10%

    expect(sizes()).toEqual([60, 40])
    expect(el("handle").getAttribute("aria-valuenow")).toBe("60")
  })

  it("min sizes clamp the drag for BOTH panels", () => {
    pointer("pointerdown", el("handle"), { x: 200 })
    pointer("pointermove", el("handle"), { x: 390 }) // would leave b at 2.5%

    expect(sizes()).toEqual([80, 20], "b's min-size (20) holds the line")
  })

  it("arrows step and Home/End jump the range", () => {
    const handle = el("handle")

    handle.dispatchEvent(new KeyboardEvent("keydown", { key: "ArrowRight", bubbles: true, cancelable: true }))

    expect(sizes()).toEqual([55, 45])

    handle.dispatchEvent(new KeyboardEvent("keydown", { key: "Home", bubbles: true, cancelable: true }))

    expect(sizes()).toEqual([20, 80], "Home collapses the preceding panel to its min")

    handle.dispatchEvent(new KeyboardEvent("keydown", { key: "End", bubbles: true, cancelable: true }))

    expect(sizes()).toEqual([80, 20], "End gives the preceding panel everything the next one can spare")
  })

  it("the resize event reports every panel's size", () => {
    let detail = null
    el("group").addEventListener("poetry--core--resizable:resize", (event) => { detail = event.detail })

    el("handle").dispatchEvent(new KeyboardEvent("keydown", { key: "ArrowLeft", bubbles: true, cancelable: true }))

    expect(detail).toEqual({ sizes: [45, 55] })
  })
})
