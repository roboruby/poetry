import { beforeEach, describe, expect, it } from "vitest"
import { Application } from "@hotwired/stimulus"
import { registerPoetryControllers } from "@poetry/controllers"

const nextFrame = () => new Promise((resolve) => setTimeout(resolve, 0))

const pressEscape = () =>
  window.dispatchEvent(new KeyboardEvent("keydown", { key: "Escape", bubbles: true }))

const pointerdown = (element) =>
  element.dispatchEvent(new MouseEvent("pointerdown", { bubbles: true }))

const layerMarkup = (id, values = "") => `
  <div id="${id}" data-controller="poetry--core--dismissable" ${values}>
    <button id="${id}-inner">inner</button>
  </div>`

const el = (id) => document.getElementById(id)

// The controller never removes DOM - it dispatches "dismiss" and the
// consumer closes itself. These listeners stand in for the consumer.
const dismissalsOf = (id) => {
  const seen = []
  el(id).addEventListener("poetry--core--dismissable:dismiss", () => seen.push(id))
  return seen
}

describe("poetry--core--dismissable", () => {
  let application

  beforeEach(async () => {
    document.body.innerHTML = `<button id="outside">outside</button><div id="host"></div>`
    application = Application.start()
    registerPoetryControllers(application)
    await nextFrame()
    // application.stop() does NOT disconnect live controllers (see
    // dialog.test.js) - remove the layers and await the disconnect so the
    // class-level stack and document listeners cannot leak across tests.
    return async () => {
      el("host")?.replaceChildren()
      await nextFrame()
      application.stop()
    }
  })

  async function mountLayer(id, values = "") {
    el("host").insertAdjacentHTML("beforeend", layerMarkup(id, values))
    await nextFrame()
    return dismissalsOf(id)
  }

  it("Escape dispatches dismiss (the consumer closes itself; no DOM is removed)", async () => {
    const dismissals = await mountLayer("layer")

    pressEscape()

    expect(dismissals).toEqual(["layer"])
    expect(el("layer")).not.toBeNull()
  })

  it("only the TOPMOST layer dismisses on Escape; the next layer takes over once it closes", async () => {
    const bottom = await mountLayer("bottom")
    const top = await mountLayer("top")

    pressEscape()
    expect(top).toEqual(["top"])
    expect(bottom).toEqual([])

    el("top").remove()
    await nextFrame()

    pressEscape()
    expect(bottom).toEqual(["bottom"])
    expect(top).toEqual(["top"])
  })

  it("a pointerdown outside fires interact-outside (with the original event) then dismiss", async () => {
    const dismissals = await mountLayer("layer")
    const outsideEvents = []
    el("layer").addEventListener("poetry--core--dismissable:interact-outside", (event) => {
      outsideEvents.push(event.detail.originalEvent.type)
    })

    pointerdown(el("outside"))

    expect(outsideEvents).toEqual(["pointerdown"])
    expect(dismissals).toEqual(["layer"])
  })

  it("a pointerdown inside does not dismiss", async () => {
    const dismissals = await mountLayer("layer")

    pointerdown(el("layer-inner"))

    expect(dismissals).toEqual([])
  })

  it("preventDefault on interact-outside vetoes the dismissal", async () => {
    const dismissals = await mountLayer("layer")
    el("layer").addEventListener("poetry--core--dismissable:interact-outside", (event) => event.preventDefault())

    pointerdown(el("outside"))

    expect(dismissals).toEqual([])
  })

  it("a pointerdown inside a HIGHER layer is not 'outside' (the portaled-nesting case)", async () => {
    const bottom = await mountLayer("bottom")
    const top = await mountLayer("top")

    pointerdown(el("top-inner"))

    expect(bottom).toEqual([])
    expect(top).toEqual([])
  })

  it("disableOutsidePointerEvents scrims the body while mounted and restores it after", async () => {
    await mountLayer("layer", `data-poetry--core--dismissable-disable-outside-pointer-events-value="true"`)

    expect(document.body.style.pointerEvents).toBe("none")
    expect(el("layer").style.pointerEvents).toBe("auto")

    el("layer").remove()
    await nextFrame()

    expect(document.body.style.pointerEvents).toBe("")
  })
})
