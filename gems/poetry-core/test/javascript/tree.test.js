import { beforeEach, describe, expect, it } from "vitest"
import { Application } from "@hotwired/stimulus"
import { registerPoetryControllers } from "@poetry/controllers"

// The Tree engine (the flat-treegrid contract): visibility is
// every-ancestor-expanded (nested collapsed state survives an ancestor's
// collapse/expand cycle), arrows walk VISIBLE rows, ArrowLeft walks to
// the parent from a leaf, Enter toggles expandable rows, the chevron
// never steals focus, and expansion state round-trips through
// aria-expanded + the cancelable-free toggle event.

const nextFrame = () => new Promise((resolve) => setTimeout(resolve, 0))

const IDENTIFIER = "poetry--core--tree"

const el = (id) => document.getElementById(id)

// docs > guides > (intro, advanced), src (leaf), README (leaf)
const treeMarkup = ({ guidesExpanded = "true", docsExpanded = "true" } = {}) => `
  <div id="tree" role="treegrid" aria-label="Files"
       data-controller="${IDENTIFIER}"
       data-action="keydown->${IDENTIFIER}#keydown click->${IDENTIFIER}#press">
    <div id="docs" role="row" data-slot="tree-item" aria-level="1" aria-posinset="1"
         aria-setsize="3" aria-expanded="${docsExpanded}"
         ${docsExpanded === "true" ? 'data-expanded=""' : ""} tabindex="0" data-value="docs">
      <span role="gridcell">docs
        <button id="docs-chevron" tabindex="-1" aria-label="Collapse"
                data-action="pointerdown->${IDENTIFIER}#pressStart click->${IDENTIFIER}#toggle"></button>
      </span>
    </div>
    <div id="guides" role="row" data-slot="tree-item" aria-level="2" aria-posinset="1"
         aria-setsize="1" aria-expanded="${guidesExpanded}"
         ${guidesExpanded === "true" ? 'data-expanded=""' : ""} tabindex="-1" data-value="guides">
      <span role="gridcell">guides</span>
    </div>
    <div id="intro" role="row" data-slot="tree-item" aria-level="3" aria-posinset="1"
         aria-setsize="2" tabindex="-1" data-value="intro">
      <span role="gridcell">intro</span>
    </div>
    <div id="advanced" role="row" data-slot="tree-item" aria-level="3" aria-posinset="2"
         aria-setsize="2" tabindex="-1" data-value="advanced">
      <span role="gridcell">advanced</span>
    </div>
    <div id="src" role="row" data-slot="tree-item" aria-level="1" aria-posinset="2"
         aria-setsize="3" tabindex="-1" data-value="src">
      <span role="gridcell">src</span>
    </div>
    <div id="readme" role="row" data-slot="tree-item" aria-level="1" aria-posinset="3"
         aria-setsize="3" tabindex="-1" data-value="readme">
      <span role="gridcell">README</span>
    </div>
  </div>`

const press = (element, key) =>
  element.dispatchEvent(new KeyboardEvent("keydown", { key, bubbles: true, cancelable: true }))

describe("poetry--core--tree", () => {
  let application

  beforeEach(async () => {
    document.body.innerHTML = `<div id="host"></div>`
    application = Application.start()
    registerPoetryControllers(application)
    await nextFrame()
    return async () => {
      el("host")?.replaceChildren()
      await nextFrame()
      application.stop()
    }
  })

  async function mount(options = {}) {
    el("host").innerHTML = treeMarkup(options)
    await nextFrame()
  }

  it("arrows walk VISIBLE rows only; Home/End jump", async () => {
    await mount()

    el("docs").focus()
    press(el("docs"), "ArrowDown")
    expect(document.activeElement).toBe(el("guides"))

    press(el("guides"), "End")
    expect(document.activeElement).toBe(el("readme"))

    press(el("readme"), "Home")
    expect(document.activeElement).toBe(el("docs"))
  })

  it("collapsing hides the whole subtree; arrows skip hidden rows", async () => {
    await mount()

    el("docs").focus()
    press(el("docs"), "ArrowLeft") // collapse docs

    expect(el("docs").getAttribute("aria-expanded")).toBe("false")
    expect(el("guides").hidden).toBe(true)
    expect(el("intro").hidden).toBe(true)

    press(el("docs"), "ArrowDown")
    expect(document.activeElement).toBe(el("src"))
  })

  it("nested collapsed state SURVIVES an ancestor collapse/expand cycle", async () => {
    await mount({ guidesExpanded: "false" })

    expect(el("intro").hidden).toBe(true) // guides collapsed from the server

    el("docs").focus()
    press(el("docs"), "ArrowLeft") // collapse docs
    press(el("docs"), "ArrowRight") // expand docs again

    expect(el("guides").hidden).toBe(false)
    expect(el("intro").hidden).toBe(true) // guides stayed collapsed
  })

  it("ArrowRight expands a collapsed parent; on a leaf it does nothing", async () => {
    await mount({ docsExpanded: "false" })

    el("docs").focus()
    press(el("docs"), "ArrowRight")

    expect(el("docs").getAttribute("aria-expanded")).toBe("true")
    expect(el("guides").hidden).toBe(false)

    el("readme").focus()
    press(el("readme"), "ArrowRight") // leaf: no-op

    expect(document.activeElement).toBe(el("readme"))
  })

  it("ArrowLeft on a leaf focuses the PARENT row", async () => {
    await mount()

    el("intro").focus()
    press(el("intro"), "ArrowLeft")
    expect(document.activeElement).toBe(el("guides"))

    press(el("guides"), "ArrowLeft") // guides is expanded: collapses instead
    expect(el("guides").getAttribute("aria-expanded")).toBe("false")

    press(el("guides"), "ArrowLeft") // now collapsed: walks to docs
    expect(document.activeElement).toBe(el("docs"))
  })

  it("Enter toggles an expandable row and fires the toggle event", async () => {
    await mount()

    const toggles = []

    el("tree").addEventListener("poetry:tree:toggle", (event) => toggles.push(event.detail))

    el("docs").focus()
    press(el("docs"), "Enter")

    expect(el("docs").getAttribute("aria-expanded")).toBe("false")
    expect(toggles).toEqual([{ id: "docs", value: "docs", expanded: false }])
  })

  it("the chevron toggles without stealing focus (pointerdown prevented, row refocused)", async () => {
    await mount()

    el("docs").focus()

    const down = new MouseEvent("pointerdown", { bubbles: true, cancelable: true })

    el("docs-chevron").dispatchEvent(down)
    expect(down.defaultPrevented).toBe(true)

    el("docs-chevron").dispatchEvent(new MouseEvent("click", { bubbles: true, cancelable: true }))

    expect(el("docs").getAttribute("aria-expanded")).toBe("false")
    expect(document.activeElement).toBe(el("docs"))
  })

  it("clicking an expandable row toggles it (the no-action press default)", async () => {
    await mount()

    el("src").dispatchEvent(new MouseEvent("click", { bubbles: true, cancelable: true }))
    expect(el("src").hasAttribute("aria-expanded")).toBe(false) // leaf: untouched

    el("docs").dispatchEvent(new MouseEvent("click", { bubbles: true, cancelable: true }))
    expect(el("docs").getAttribute("aria-expanded")).toBe("false")
  })

  it("typeahead focuses by visible text", async () => {
    await mount()

    el("docs").focus()
    press(el("docs"), "s")

    expect(document.activeElement).toBe(el("src"))
  })

  it("exactly one visible row keeps tabindex 0 after visibility changes", async () => {
    await mount()

    el("guides").focus()
    press(el("guides"), "ArrowLeft") // collapse guides (focus stays)

    const stops = Array.from(document.querySelectorAll("[data-slot='tree-item']"))
      .filter((row) => row.getAttribute("tabindex") === "0")

    expect(stops.length).toBe(1)
  })
})
