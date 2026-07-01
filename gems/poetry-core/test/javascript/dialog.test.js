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

  // jsdom has no layout - give the dialog a real rect so the
  // backdrop-vs-padding coordinate discrimination is testable.
  const stubPanelRect = (dlg) => {
    dlg.getBoundingClientRect = () => ({ top: 100, left: 100, right: 500, bottom: 400 })
  }

  it("a backdrop click (dialog target, coords outside the panel) dismisses", () => {
    document.getElementById("trigger").click()
    const dlg = document.getElementById("dlg")
    stubPanelRect(dlg)
    dlg.dispatchEvent(new MouseEvent("click", { bubbles: true, clientX: 10, clientY: 10 }))

    expect(dlg.open).toBe(false)
  })

  it("clicks on the dialog's own padding (target dialog, coords inside) do NOT dismiss", () => {
    // The 2026-07-01 browser pass: p-6 / grid-gap clicks target the
    // <dialog> element itself - target-only discrimination dismissed them.
    document.getElementById("trigger").click()
    const dlg = document.getElementById("dlg")
    stubPanelRect(dlg)
    dlg.dispatchEvent(new MouseEvent("click", { bubbles: true, clientX: 110, clientY: 110 }))

    expect(dlg.open).toBe(true)
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
    const dlg = document.getElementById("dlg")
    stubPanelRect(dlg)
    dlg.dispatchEvent(new MouseEvent("click", { bubbles: true, clientX: 10, clientY: 10 }))

    expect(dlg.open).toBe(true)
  })

  it("Esc (the native cancel event) routes through close, keeping state in sync", () => {
    document.getElementById("trigger").click()
    document.getElementById("dlg").dispatchEvent(new Event("cancel"))

    const dlg = document.getElementById("dlg")
    expect(dlg.open).toBe(false)
    expect(dlg.dataset.state).toBe("closed")
  })
})
