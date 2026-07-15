import { beforeEach, describe, expect, it } from "vitest"
import { Application } from "@hotwired/stimulus"
import { registerPoetryControllers } from "@poetry/controllers"

// The ActionBar contract: shows on non-zero selection, focus
// never moves in, the count RETAINS its last non-zero value through hide,
// "Actions available." announces once per appearance, and Escape inside
// dispatches the clear the table engine listens for.

const nextFrame = () => new Promise((resolve) => setTimeout(resolve, 0))

const IDENTIFIER = "poetry--core--action-bar"

const el = (id) => document.getElementById(id)

const markup = () => `
  <div id="wrapper">
    <div id="table"></div>
    <div id="bar" hidden data-controller="${IDENTIFIER}"
         data-available-label="Actions available."
         data-${IDENTIFIER}-label-value="%{count} selected"
         data-action="keydown->${IDENTIFIER}#keydown">
      <span id="count" data-${IDENTIFIER}-target="count"></span>
      <button id="archive">Archive</button>
      <button id="clear" data-action="click->${IDENTIFIER}#clear">Clear</button>
    </div>
  </div>`

const select = (count) =>
  el("table").dispatchEvent(new CustomEvent("poetry:data-table:selection-change", {
    bubbles: true, detail: { count, values: [] }
  }))

describe("poetry--core--action-bar", () => {
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

  async function mount() {
    el("host").innerHTML = markup()
    await nextFrame()
  }

  it("shows on non-zero selection with the count text; focus never moves in", async () => {
    await mount()

    el("table").setAttribute("tabindex", "0")
    el("table").focus()
    select(3)

    expect(el("bar").hidden).toBe(false)
    expect(el("bar").hasAttribute("data-open")).toBe(true)
    expect(el("count").textContent).toBe("3 selected")
    expect(document.activeElement).toBe(el("table"))
  })

  it("hides at zero but RETAINS the last non-zero count text", async () => {
    await mount()

    select(2)
    select(0)

    expect(el("bar").hidden).toBe(true)
    expect(el("count").textContent).toBe("2 selected") // no None-selected flash
  })

  it("Escape inside dispatches the clear the table engine listens for", async () => {
    await mount()

    select(2)

    const clears = []

    el("wrapper").addEventListener("poetry:data-table:clear-selection", () => clears.push(true))

    el("archive").dispatchEvent(
      new KeyboardEvent("keydown", { key: "Escape", bubbles: true, cancelable: true })
    )

    expect(clears).toEqual([true])
  })

  it("returns focus to the pre-entry element when the bar hides under focus", async () => {
    await mount()

    el("table").setAttribute("tabindex", "0")
    el("table").focus()
    select(2)

    el("archive").focus() // the user tabbed in
    select(0)

    expect(document.activeElement).toBe(el("table"))
  })
})
