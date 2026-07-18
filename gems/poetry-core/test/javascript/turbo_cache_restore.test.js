import { afterEach, beforeEach, describe, expect, it } from "vitest"
import { Application } from "@hotwired/stimulus"
import { registerPoetryControllers } from "@poetry/controllers"
import { lockScroll, unlockScroll, resetScrollLock } from "@poetry/controllers/helpers/scroll_lock"

// The Turbo cache-restore class (, both legs reproduced live against
// the docs app): an overlay open at turbo:before-cache serializes into the
// snapshot - the open attribute and the body's inline scroll-lock / scrim
// styles survive, top-layer state does not. Restored pages showed a
// de-modalized zombie dialog that could never scroll again, and a Select
// page whose body pointer-events:none made it click-dead forever. The
// contract under test: overlays tear down synchronously on before-cache,
// and every save-and-restore of a body style refuses to save the value it
// would itself write (the poisoned-previous class).

const nextFrame = () => new Promise((resolve) => setTimeout(resolve, 0))

const beforeCache = () => document.dispatchEvent(new Event("turbo:before-cache"))

const el = (id) => document.getElementById(id)

const dialogMarkup = (openAttr = "") => `
  <div id="root" data-controller="poetry--core--dialog">
    <button id="trigger" data-action="poetry--core--dialog#open">Open</button>
    <dialog id="dlg" ${openAttr} data-poetry--core--dialog-target="dialog"
            data-action="cancel->poetry--core--dialog#close">
      <p>content</p>
    </dialog>
  </div>`

describe("turbo cache restore ",  => {
  let application

  beforeEach(() => {
    resetScrollLock()
    document.body.style.overflow = ""
    document.body.style.pointerEvents = ""
  })

  afterEach(() => {
    application?.stop()
    application = null
  })

  const start = async () => {
    application = Application.start()
    registerPoetryControllers(application)
    await nextFrame()
  }

  it("an open dialog closes synchronously on turbo:before-cache", async () => {
    document.body.innerHTML = dialogMarkup()
    await start()

    el("trigger").click()
    expect(el("dlg").open).toBe(true)
    expect(document.body.style.overflow).toBe("hidden")

    beforeCache()

    expect(el("dlg").open).toBe(false)
    expect(el("dlg").hasAttribute("data-closed")).toBe(true)
    expect(document.body.style.overflow).toBe("")
  })

  it("a zombie dialog restored from a pre-fix snapshot heals on connect", async () => {
    // The snapshot shape: open attribute serialized, no modal state, the
    // scroll lock's inline styles present with no refcount behind them.
    document.body.style.overflow = "hidden"
    document.body.innerHTML = dialogMarkup("open")
    await start()

    expect(el("dlg").open).toBe(false)
    expect(el("dlg").hasAttribute("data-closed")).toBe(true)
    expect(document.body.style.overflow).toBe("")
  })

  it("lockScroll never saves the hidden it would itself write", () => {
    document.body.style.overflow = "hidden" // serialized leftover
    lockScroll()
    unlockScroll()

    expect(document.body.style.overflow).toBe("")
  })

  it("an open layer dispatches dismiss on turbo:before-cache", async () => {
    document.body.innerHTML = `
      <div id="layer" data-controller="poetry--core--dismissable">
        <button>inner</button>
      </div>`
    await start()

    const seen = []
    el("layer").addEventListener("poetry--core--dismissable:dismiss", () => seen.push("layer"))
    beforeCache()

    expect(seen).toEqual(["layer"])
  })

  it("a scrim layer releases the body synchronously on turbo:before-cache", async () => {
    document.body.innerHTML = `
      <div id="layer" data-controller="poetry--core--dismissable"
           data-poetry--core--dismissable-disable-outside-pointer-events-value="true">
        <button>inner</button>
      </div>`
    await start()

    expect(document.body.style.pointerEvents).toBe("none")

    beforeCache() // the owner's unmount may ride an exit transition - too late

    expect(document.body.style.pointerEvents).toBe("")

    el("layer").remove() // the deferred disconnect must not double-release
    await nextFrame()

    expect(document.body.style.pointerEvents).toBe("")
  })

  it("turbo:load heals a poisoned body left by a pre-fix snapshot", async () => {
    document.body.innerHTML = "<p>restored page, no layers</p>"
    document.body.style.pointerEvents = "none" // serialized leftover
    document.dispatchEvent(new Event("turbo:load"))

    expect(document.body.style.pointerEvents).toBe("")
  })

  it("the scrim never saves the none it would itself write", async () => {
    document.body.style.pointerEvents = "none" // serialized leftover
    document.body.innerHTML = `
      <div id="layer" data-controller="poetry--core--dismissable"
           data-poetry--core--dismissable-disable-outside-pointer-events-value="true">
        <button>inner</button>
      </div>`
    await start()

    expect(document.body.style.pointerEvents).toBe("none") // scrim active while open

    el("layer").remove() // the owner closing: layer unmounts, scrim releases
    await nextFrame()

    expect(document.body.style.pointerEvents).toBe("")
  })
})
