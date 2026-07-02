import { beforeEach, describe, expect, it } from "vitest"
import { Application } from "@hotwired/stimulus"
import { registerPoetryControllers } from "@poetry/controllers"

const nextFrame = () => new Promise((resolve) => setTimeout(resolve, 0))

const press = (element, key, options = {}) =>
  element.dispatchEvent(new KeyboardEvent("keydown", { key, bubbles: true, cancelable: true, ...options }))

async function mount({ orientation = "vertical", loop = true, manageTabindex = true, dir = null } = {}) {
  document.body.innerHTML = `
    <div id="wrapper" ${dir ? `dir="${dir}"` : ""}>
      <div id="group" data-controller="poetry--core--roving-focus"
           data-poetry--core--roving-focus-orientation-value="${orientation}"
           data-poetry--core--roving-focus-loop-value="${loop}"
           data-poetry--core--roving-focus-manage-tabindex-value="${manageTabindex}"
           data-action="keydown->poetry--core--roving-focus#keydown">
        <button id="a" data-poetry-collection-item>a</button>
        <button id="b" data-poetry-collection-item>b</button>
        <button id="c" data-poetry-collection-item>c</button>
      </div>
    </div>`
  const application = Application.start()
  registerPoetryControllers(application)
  await nextFrame()
  return application
}

const el = (id) => document.getElementById(id)
const tabindexes = () => ["a", "b", "c"].map((id) => el(id).getAttribute("tabindex"))

describe("poetry--core--roving-focus", () => {
  let application

  beforeEach(async () => {
    application = await mount()
    return () => application.stop()
  })

  it("connect writes the roving tabindex (one 0, rest -1) and mirrors data-orientation", () => {
    expect(tabindexes()).toEqual(["0", "-1", "-1"])
    expect(el("group").dataset.orientation).toBe("vertical")
    expect(el("a").dataset.orientation).toBe("vertical")
  })

  it("ArrowDown/ArrowUp move focus and the tab stop moves with it (vertical)", () => {
    el("a").focus()
    press(el("a"), "ArrowDown")

    expect(document.activeElement).toBe(el("b"))
    expect(tabindexes()).toEqual(["-1", "0", "-1"])

    press(el("b"), "ArrowUp")

    expect(document.activeElement).toBe(el("a"))
    expect(tabindexes()).toEqual(["0", "-1", "-1"])
  })

  it("Home and End jump to the first and last items", () => {
    el("b").focus()
    press(el("b"), "End")
    expect(document.activeElement).toBe(el("c"))

    press(el("c"), "Home")
    expect(document.activeElement).toBe(el("a"))
  })

  it("loop wraps past the edges in both directions", () => {
    el("a").focus()
    press(el("a"), "ArrowUp")
    expect(document.activeElement).toBe(el("c"))

    press(el("c"), "ArrowDown")
    expect(document.activeElement).toBe(el("a"))
  })

  it("loop=false clamps at the edges", async () => {
    application.stop()
    application = await mount({ loop: false })

    el("a").focus()
    press(el("a"), "ArrowUp")
    expect(document.activeElement).toBe(el("a"))

    el("c").focus()
    press(el("c"), "ArrowDown")
    expect(document.activeElement).toBe(el("c"))
  })

  it("a vertical group ignores the horizontal arrows (they fall through)", () => {
    el("a").focus()
    const notHandled = press(el("a"), "ArrowRight") // dispatchEvent: true = not preventDefault'ed

    expect(notHandled).toBe(true)
    expect(document.activeElement).toBe(el("a"))
  })

  it("horizontal maps Left/Right instead of Up/Down", async () => {
    application.stop()
    application = await mount({ orientation: "horizontal" })

    expect(el("group").dataset.orientation).toBe("horizontal")

    el("a").focus()
    press(el("a"), "ArrowRight")
    expect(document.activeElement).toBe(el("b"))

    press(el("b"), "ArrowLeft")
    expect(document.activeElement).toBe(el("a"))

    press(el("a"), "ArrowDown")
    expect(document.activeElement).toBe(el("a"))
  })

  it("RTL flips Left/Right (read from the closest [dir] ancestor)", async () => {
    application.stop()
    application = await mount({ orientation: "horizontal", dir: "rtl" })

    el("a").focus()
    press(el("a"), "ArrowLeft") // rtl: Left advances
    expect(document.activeElement).toBe(el("b"))

    press(el("b"), "ArrowRight") // rtl: Right retreats
    expect(document.activeElement).toBe(el("a"))
  })

  it("the entry event is cancelable: preventDefault keeps focus and the tab stop in place", () => {
    el("group").addEventListener("poetry--core--roving-focus:entry", (event) => event.preventDefault())

    el("a").focus()
    press(el("a"), "ArrowDown")

    expect(document.activeElement).toBe(el("a"))
    expect(tabindexes()).toEqual(["0", "-1", "-1"])
  })

  it("a dynamically added item is stamped tabindex=-1 immediately (no second Tab stop)", async () => {
    const added = document.createElement("button")
    added.id = "d"
    added.setAttribute("data-poetry-collection-item", "")
    el("group").appendChild(added)
    await nextFrame() // MutationObserver delivery

    expect(added.getAttribute("tabindex")).toBe("-1")
    expect(added.dataset.orientation).toBe("vertical")

    el("a").focus()
    press(el("a"), "End") // and navigation reaches it
    expect(document.activeElement).toBe(added)
  })

  it("manageTabindex=false never writes tabindex (connect, navigation, or mutation) while arrows still move focus", async () => {
    application.stop()
    application = await mount({ manageTabindex: false })

    // Focus-nav-only mode (the APG accordion): every trigger stays tabbable;
    // arrows are convenience navigation, not a roving tab stop.
    expect(tabindexes()).toEqual([null, null, null])

    el("a").focus()
    press(el("a"), "ArrowDown")
    expect(document.activeElement).toBe(el("b"))
    expect(tabindexes()).toEqual([null, null, null])

    press(el("b"), "End")
    expect(document.activeElement).toBe(el("c"))
    expect(tabindexes()).toEqual([null, null, null])

    const added = document.createElement("button")
    added.id = "d"
    added.setAttribute("data-poetry-collection-item", "")
    el("group").appendChild(added)
    await nextFrame() // MutationObserver delivery

    expect(added.getAttribute("tabindex")).toBeNull()
    expect(added.dataset.orientation).toBe("vertical") // orientation still mirrors
  })

  it("removing the current tab stop hands tabindex=0 back to the first item", async () => {
    el("a").focus()
    press(el("a"), "ArrowDown") // stop is now b

    el("b").remove()
    await nextFrame()

    expect(el("a").getAttribute("tabindex")).toBe("0")
    expect(el("c").getAttribute("tabindex")).toBe("-1")
  })
})
