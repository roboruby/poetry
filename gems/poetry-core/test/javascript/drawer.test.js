import { beforeEach, describe, expect, it, vi } from "vitest"
import { Application } from "@hotwired/stimulus"
import { registerPoetryControllers } from "@poetry/controllers"

// poetry--core--drawer JS-unit: the swipe gesture + the presence-hold
// close, on top of the inherited dialog machinery. What this file proves:
// the CSS-var contract (--drawer-swipe-movement-*/progress written to the
// <dialog> during a drag, data-swiping after the slop), the release
// physics (past-half or flicked -> strength-scaled dismissal; short+slow
// -> snap back), gesture guards (interactive targets and toward-gesture
// scrollable content own the pointer; the handle always swipes), and the
// animated close path flipping the open/closed pair. Real transition
// timing is the browser rig's job - jsdom reports no transitions, so
// exitPresence settles synchronously here.

const nextFrame = () => new Promise((resolve) => setTimeout(resolve, 0))
const el = (id) => document.getElementById(id)

const markup = ({ direction = "down", inner = "" } = {}) => `
  <div id="root" data-controller="poetry--core--drawer"
       data-poetry--core--drawer-direction-value="${direction}">
    <button id="trigger" type="button" data-action="click->poetry--core--drawer#open">Open</button>
    <dialog id="dialog" data-slot="drawer-content" data-closed
            data-poetry--core--drawer-target="dialog"
            data-action="cancel->poetry--core--drawer#close click->poetry--core--drawer#backdropClose
                         pointerdown->poetry--core--drawer#swipeStart pointermove->poetry--core--drawer#swipeMove
                         pointerup->poetry--core--drawer#swipeEnd pointercancel->poetry--core--drawer#swipeCancel">
      <div data-slot="drawer-swipe-handle" id="handle" aria-hidden="true"></div>
      <p id="body-text">Drawer body</p>
      <button id="inner-button" type="button">Action</button>
      ${inner}
    </dialog>
  </div>`

async function mount(html) {
  document.body.innerHTML = html
  // jsdom lacks the dialog methods (the known shim, see dialog tests).
  if (!HTMLDialogElement.prototype.showModal || HTMLDialogElement.prototype.__vitestShim) {
    HTMLDialogElement.prototype.__vitestShim = true
    HTMLDialogElement.prototype.showModal = function () { this.setAttribute("open", "") }
    HTMLDialogElement.prototype.close = function () { this.removeAttribute("open") }
  }
  Element.prototype.setPointerCapture ||= () => {}
  Element.prototype.releasePointerCapture ||= () => {}
  const application = Application.start()
  registerPoetryControllers(application)
  await nextFrame()
  return application
}

const pointer = (type, target, { x = 0, y = 0, id = 1, time } = {}) => {
  const event = new MouseEvent(type, { bubbles: true, cancelable: true, clientX: x, clientY: y, button: 0 })
  Object.defineProperty(event, "pointerId", { value: id })
  Object.defineProperty(event, "pointerType", { value: "touch" })
  if (time !== undefined) Object.defineProperty(event, "timeStamp", { value: time })
  target.dispatchEvent(event)
}

const dragFromHandle = async (movements, { time = 0 } = {}) => {
  const handle = el("handle")
  pointer("pointerdown", handle, { y: 100, time })
  for (const [y, t] of movements) pointer("pointermove", el("dialog"), { y, time: t })
}

describe("poetry--core--drawer", () => {
  let application

  beforeEach(async () => {
    application = await mount(markup())
    el("trigger").click()
    await nextFrame()
    // Give the dialog a measurable height for progress math.
    Object.defineProperty(el("dialog"), "offsetHeight", { value: 400, configurable: true })
    return async () => {
      application.stop()
      document.body.replaceChildren()
      await nextFrame()
    }
  })

  it("open flips the pair and rides the starting-style two-frame trick", () => {
    const dialog = el("dialog")

    expect(dialog.hasAttribute("open")).toBe(true)
    expect(dialog.hasAttribute("data-open")).toBe(true)
    expect(dialog.hasAttribute("data-closed")).toBe(false)
  })

  it("a drag past the slop writes the CSS-var contract onto the dialog", async () => {
    await dragFromHandle([[110, 16], [200, 32]])
    const dialog = el("dialog")

    expect(dialog.hasAttribute("data-swiping")).toBe(true)
    expect(dialog.style.getPropertyValue("--drawer-swipe-movement-y")).toBe("100px")
    expect(dialog.style.getPropertyValue("--drawer-swipe-progress")).toBe("0.25")
  })

  it("released past half the height dismisses with a strength-scaled exit", async () => {
    const dialog = el("dialog")
    // jsdom has no transitions, so exitPresence settles (and resets the
    // vars) synchronously - observe the strength write via a spy.
    const setProperty = vi.spyOn(dialog.style, "setProperty")

    await dragFromHandle([[150, 16], [350, 48]])
    pointer("pointerup", dialog, { y: 350, time: 64 })
    await nextFrame()

    // 250px of 400 = 0.625 progress -> strength 0.375.
    expect(setProperty).toHaveBeenCalledWith("--drawer-swipe-strength", "0.375")
    expect(dialog.hasAttribute("data-swiping")).toBe(false)
    expect(dialog.hasAttribute("data-closed")).toBe(true)
    expect(dialog.hasAttribute("open")).toBe(false)
  })

  it("a fast flick dismisses even from a short distance", async () => {
    // 80px in 40ms = 2 px/ms - far past the velocity threshold.
    await dragFromHandle([[140, 20], [180, 40]])
    pointer("pointerup", el("dialog"), { y: 180, time: 40 })
    await nextFrame()

    expect(el("dialog").hasAttribute("data-closed")).toBe(true)
  })

  it("a short slow drag snaps back instead of dismissing", async () => {
    await dragFromHandle([[120, 300], [160, 900]])
    pointer("pointerup", el("dialog"), { y: 160, time: 1500 })
    // The snap-back write rides requestAnimationFrame - wait for a real frame.
    await new Promise((resolve) => requestAnimationFrame(() => resolve()))
    await nextFrame()

    const dialog = el("dialog")

    expect(dialog.hasAttribute("data-open")).toBe(true)
    expect(dialog.hasAttribute("data-swiping")).toBe(false)
    expect(dialog.style.getPropertyValue("--drawer-swipe-movement-y")).toBe("0px")
  })

  it("interactive targets own the pointer - no drag starts from a button", () => {
    pointer("pointerdown", el("inner-button"), { y: 100 })
    pointer("pointermove", el("dialog"), { y: 200 })

    expect(el("dialog").hasAttribute("data-swiping")).toBe(false)
  })

  it("content scrolled toward the gesture owns the pointer", async () => {
    application.stop()
    application = await mount(markup({
      inner: '<div id="scroller"><p>tall content</p></div>'
    }))
    el("trigger").click()
    await nextFrame()
    const scroller = el("scroller")
    Object.defineProperty(scroller, "scrollHeight", { value: 500, configurable: true })
    Object.defineProperty(scroller, "clientHeight", { value: 200, configurable: true })
    scroller.scrollTop = 50 // scrolled down - a down-swipe would fight scroll-up

    pointer("pointerdown", scroller, { y: 100 })
    pointer("pointermove", el("dialog"), { y: 200 })

    expect(el("dialog").hasAttribute("data-swiping")).toBe(false)
  })

  it("the swipe vars reset once the drawer is closed", async () => {
    await dragFromHandle([[150, 16], [350, 48]])
    pointer("pointerup", el("dialog"), { y: 350, time: 64 })
    await nextFrame()

    const dialog = el("dialog")

    expect(dialog.style.getPropertyValue("--drawer-swipe-progress")).toBe("")
    expect(dialog.style.getPropertyValue("--drawer-swipe-strength")).toBe("")
  })
})
