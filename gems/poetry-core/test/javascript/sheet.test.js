import { beforeEach, describe, expect, it } from "vitest"
import { Application } from "@hotwired/stimulus"
import { registerPoetryControllers } from "@poetry/controllers"

// poetry--core--sheet JS-unit: the dialog machinery +
// the presence-hold close - the Drawer's animated path minus the swipe.
// What this file proves: open flips the pair through enterPresence, close
// routes through exitPresence (flipping to data-closed BEFORE the native
// close()), Esc's cancel is preventDefault'd onto the animated path, and
// the closing guard swallows double-closes. Real slide timing is the
// browser rig's job - jsdom reports no animations, so exitPresence
// settles synchronously here.

const nextFrame = () => new Promise((resolve) => setTimeout(resolve, 0))
const el = (id) => document.getElementById(id)

const markup = () => `
  <div id="root" data-controller="poetry--core--sheet">
    <button id="trigger" type="button" data-action="click->poetry--core--sheet#open">Open</button>
    <dialog id="dialog" data-slot="sheet-content" data-side="right" data-closed
            data-poetry--core--sheet-target="dialog"
            data-action="cancel->poetry--core--sheet#close click->poetry--core--sheet#backdropClose">
      <p>Sheet body</p>
      <button id="close" type="button" data-action="click->poetry--core--sheet#close">Close</button>
    </dialog>
  </div>`

async function mount() {
  document.body.innerHTML = markup()
  if (!HTMLDialogElement.prototype.showModal || HTMLDialogElement.prototype.__vitestShim) {
    HTMLDialogElement.prototype.__vitestShim = true
    HTMLDialogElement.prototype.showModal = function () { this.setAttribute("open", "") }
    HTMLDialogElement.prototype.close = function () { this.removeAttribute("open") }
  }
  const application = Application.start()
  registerPoetryControllers(application)
  await nextFrame()
  return application
}

describe("poetry--core--sheet", () => {
  let application

  beforeEach(() => async () => {
    application?.stop()
    document.body.replaceChildren()
    await nextFrame()
  })

  it("open shows the dialog through enterPresence", async () => {
    application = await mount()
    el("trigger").click()

    const dialog = el("dialog")
    expect(dialog.hasAttribute("open")).toBe(true)
    expect(dialog.hasAttribute("data-open")).toBe(true)
    expect(dialog.hasAttribute("data-closed")).toBe(false)
  })

  it("close flips to data-closed through the presence hold before the native close", async () => {
    application = await mount()
    el("trigger").click()
    el("close").click()

    const dialog = el("dialog")
    // jsdom: no exit animation -> exitPresence settles synchronously.
    expect(dialog.hasAttribute("data-closed")).toBe(true)
    expect(dialog.hasAttribute("data-open")).toBe(false)
    expect(dialog.hasAttribute("open")).toBe(false)

    // Re-openable after the animated close (the closing flag resets).
    el("trigger").click()
    expect(dialog.hasAttribute("data-open")).toBe(true)
  })

  it("Esc's cancel event routes through the animated path", async () => {
    application = await mount()
    el("trigger").click()

    const cancel = new Event("cancel", { bubbles: false, cancelable: true })
    el("dialog").dispatchEvent(cancel)

    expect(cancel.defaultPrevented).toBe(true)
    expect(el("dialog").hasAttribute("data-closed")).toBe(true)
  })
})
