import { beforeEach, describe, expect, it } from "vitest"
import { Application } from "@hotwired/stimulus"
import { registerPoetryControllers } from "@poetry/controllers"

const nextFrame = () => new Promise((resolve) => setTimeout(resolve, 0))

async function mount(dismissible = true) {
  // application.stop() does not disconnect live controllers, so a prior
  // test's scroll lock would leak into this one's lockScroll capture.
  document.body.style.overflow = ""
  document.body.innerHTML = `
    <div id="root" data-controller="poetry--core--dialog"
         data-poetry--core--dialog-dismissible-value="${dismissible}">
      <button id="trigger" data-action="poetry--core--dialog#open">Open</button>
      <dialog id="dlg" data-poetry--core--dialog-target="dialog"
              data-action="cancel->poetry--core--dialog#close click->poetry--core--dialog#backdropClose">
        <p id="inner">content</p>
        <button id="closer" data-action="poetry--core--dialog#close">Close</button>
      </dialog>
    </div>`
  const application = Application.start()
  registerPoetryControllers(application)
  await nextFrame()
  return application
}

describe("poetry--core--dialog", () => {
  let application

  beforeEach(async () => {
    application = await mount()
    return () => application.stop()
  })

  it("open() shows the modal, sets data-state, and locks scroll", () => {
    const dlg = document.getElementById("dlg")
    document.getElementById("trigger").click()

    expect(dlg.open).toBe(true)
    expect(dlg.dataset.state).toBe("open")
    expect(document.body.style.overflow).toBe("hidden")
  })

  it("close() closes, syncs state, and unlocks scroll", () => {
    document.getElementById("trigger").click()
    document.getElementById("closer").click()

    const dlg = document.getElementById("dlg")
    expect(dlg.open).toBe(false)
    expect(dlg.dataset.state).toBe("closed")
    expect(document.body.style.overflow).toBe("")
  })

  it("a backdrop click (the dialog element itself) dismisses", () => {
    document.getElementById("trigger").click()
    document.getElementById("dlg").dispatchEvent(new MouseEvent("click", { bubbles: true }))

    expect(document.getElementById("dlg").open).toBe(false)
  })

  it("clicks on dialog CONTENT do not dismiss", () => {
    document.getElementById("trigger").click()
    document.getElementById("inner").dispatchEvent(new MouseEvent("click", { bubbles: true }))

    expect(document.getElementById("dlg").open).toBe(true)
  })

  it("dismissible=false ignores backdrop clicks (the AlertDialog contract)", async () => {
    application.stop()
    application = await mount(false)
    document.getElementById("trigger").click()
    document.getElementById("dlg").dispatchEvent(new MouseEvent("click", { bubbles: true }))

    expect(document.getElementById("dlg").open).toBe(true)
  })

  it("Esc (the native cancel event) routes through close, keeping state in sync", () => {
    document.getElementById("trigger").click()
    document.getElementById("dlg").dispatchEvent(new Event("cancel"))

    const dlg = document.getElementById("dlg")
    expect(dlg.open).toBe(false)
    expect(dlg.dataset.state).toBe("closed")
  })
})
