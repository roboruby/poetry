import { afterEach, beforeEach, describe, expect, it } from "vitest"
import { Application } from "@hotwired/stimulus"
// Registered directly: scroll-spy is PARKED out of the public registration
// map (no component consumes it yet) but keeps its behavior coverage.
import ScrollSpyController from "@poetry/controllers/scroll_spy_controller"

const nextFrame = () => new Promise((resolve) => setTimeout(resolve, 20))

// jsdom has no layout: each section's viewport top is stubbed directly.
function placeSection(id, top) {
  document.getElementById(id).getBoundingClientRect = () => ({ top })
}

describe("poetry--core--scroll-spy", () => {
  let application

  beforeEach(async () => {
    document.body.innerHTML = `
      <nav id="toc" data-controller="poetry--core--scroll-spy"
           data-poetry--core--scroll-spy-offset-value="96">
        <a id="l-usage" href="#usage" data-poetry--core--scroll-spy-target="link">Usage</a>
        <a id="l-theming" href="#theming" data-poetry--core--scroll-spy-target="link">Theming</a>
        <a id="l-missing" href="#nowhere" data-poetry--core--scroll-spy-target="link">Ghost</a>
      </nav>
      <section id="usage"></section>
      <section id="theming"></section>`
    placeSection("usage", -40)
    placeSection("theming", 400)
    application = Application.start()
    application.register("poetry--core--scroll-spy", ScrollSpyController)
    await nextFrame()
  })

  afterEach(() => application.stop())

  it("marks the last section above the offset line, ignoring dead links", () => {
    expect(document.getElementById("l-usage").hasAttribute("data-active")).toBe(true)
    expect(document.getElementById("l-theming").hasAttribute("data-active")).toBe(false)
  })

  it("moves the marker on scroll and announces the change", async () => {
    const seen = []
    document.getElementById("toc").addEventListener("poetry--core--scroll-spy:changed",
      (event) => seen.push(event.detail.id))

    placeSection("theming", 60)
    window.dispatchEvent(new Event("scroll"))
    await nextFrame()

    expect(document.getElementById("l-theming").hasAttribute("data-active")).toBe(true)
    expect(document.getElementById("l-usage").hasAttribute("data-active")).toBe(false)
    expect(seen).toEqual(["theming"])
  })

  it("clears the marker when scrolled above every section", async () => {
    placeSection("usage", 300)
    placeSection("theming", 700)
    window.dispatchEvent(new Event("scroll"))
    await nextFrame()

    expect(document.querySelectorAll("[data-active]").length).toBe(0)
  })
})
