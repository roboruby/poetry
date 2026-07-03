import { afterEach, beforeEach, describe, expect, it } from "vitest"
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

  // The CommandDialog affordance (Command): an OPT-IN
  // hotkey value toggles the dialog from a window keydown; "meta" matches
  // metaKey OR ctrlKey (⌘K / ^K, the cmdk convention).
  describe("the opt-in hotkey", () => {
    // application.stop() does not DISCONNECT live controllers - remove the
    // root while the application still observes, so the window listener's
    // disconnect cleanup actually runs between tests.
    afterEach(async () => {
      document.getElementById("root")?.remove()
      await nextFrame()
    })

    const press = (key, options = {}) => {
      const event = new KeyboardEvent("keydown", { key, bubbles: true, cancelable: true, ...options })
      window.dispatchEvent(event)
      return event
    }

    async function mountWithHotkey(hotkey = "meta+k") {
      document.body.style.overflow = ""
      document.body.innerHTML = `
        <div id="root" data-controller="poetry--core--dialog"
             data-poetry--core--dialog-hotkey-value="${hotkey}">
          <dialog id="dlg" data-poetry--core--dialog-target="dialog"></dialog>
        </div>`
      const hotkeyApplication = Application.start()
      registerPoetryControllers(hotkeyApplication)
      await nextFrame()
      return hotkeyApplication
    }

    it("meta+k toggles the dialog (metaKey OR ctrlKey) and prevents default", async () => {
      application.stop()
      application = await mountWithHotkey()

      const dlg = document.getElementById("dlg")

      expect(press("k", { metaKey: true }).defaultPrevented).toBe(true)
      expect(dlg.open).toBe(true)

      press("k", { ctrlKey: true }) // ^K parity
      expect(dlg.open).toBe(false)
    })

    it("a bare key or a wrong modifier never triggers", async () => {
      application.stop()
      application = await mountWithHotkey()

      const dlg = document.getElementById("dlg")

      expect(press("k").defaultPrevented).toBe(false)
      press("k", { shiftKey: true, metaKey: true })
      press("j", { metaKey: true })

      expect(dlg.open).toBe(false)
    })

    it("no hotkey value -> no window listener (plain typing untouched)", () => {
      expect(press("k", { metaKey: true }).defaultPrevented).toBe(false)
      expect(document.getElementById("dlg").open).toBe(false)
    })

    it("the listener is removed on disconnect", async () => {
      application.stop()
      application = await mountWithHotkey()

      document.getElementById("root").remove()
      await nextFrame()

      expect(press("k", { metaKey: true }).defaultPrevented).toBe(false)
    })
  })
})
