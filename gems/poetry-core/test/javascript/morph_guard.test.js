import { afterEach, describe, expect, it } from "vitest"
import { Application } from "@hotwired/stimulus"
import { registerPoetryControllers } from "@poetry/controllers"
import {
  MORPH_GUARDED_ATTRIBUTES,
  installMorphGuard,
  isDirtyControl,
  keepsAttribute,
  ownsAttribute
} from "@poetry/controllers/helpers/morph_guard"

// The observer delivers in a microtask; a macrotask hop is past it.
const delivered = () => new Promise((resolve) => setTimeout(resolve, 0))

// What Turbo dispatches for every attribute idiomorph would sync.
const morphAttribute = (element, attributeName, mutationType = "update") => {
  const event = new CustomEvent("turbo:before-morph-attribute", {
    bubbles: true, cancelable: true, detail: { attributeName, mutationType }
  })
  element.dispatchEvent(event)
  return event.defaultPrevented
}

describe("the morph guard", () => {
  afterEach(() => {
    document.body.innerHTML = ""
  })

  it("is installed once by registerPoetryControllers", () => {
    registerPoetryControllers(Application.start())

    expect(installMorphGuard(document)).toBe(false)
  })

  it("guards the state vocabulary and the mirrors controllers write beside it", () => {
    expect(MORPH_GUARDED_ATTRIBUTES).toContain("data-open")
    expect(MORPH_GUARDED_ATTRIBUTES).toContain("data-active")
    expect(MORPH_GUARDED_ATTRIBUTES).toContain("aria-selected")
    expect(MORPH_GUARDED_ATTRIBUTES).toContain("hidden")
    expect(MORPH_GUARDED_ATTRIBUTES).toContain("open")
    expect(MORPH_GUARDED_ATTRIBUTES).not.toContain("class")
  })

  it("owns an attribute the client changed, per element, never one it re-asserted", async () => {
    document.body.innerHTML = `
      <div id="mine" data-closed tabindex="0"></div>
      <div id="theirs" data-closed></div>`
    const mine = document.getElementById("mine")
    mine.setAttribute("data-open", "")
    mine.removeAttribute("data-closed")
    mine.setAttribute("tabindex", "0")
    mine.setAttribute("class", "touched")
    await delivered()

    expect(ownsAttribute(mine, "data-open")).toBe(true)
    expect(ownsAttribute(mine, "data-closed")).toBe(true)
    expect(ownsAttribute(mine, "tabindex")).toBe(false)
    expect(ownsAttribute(mine, "class")).toBe(false)
    expect(ownsAttribute(document.getElementById("theirs"), "data-closed")).toBe(false)
  })

  it("keeps an owned attribute through a morph and lets every other one follow the server", async () => {
    document.body.innerHTML = `
      <button id="tab" aria-selected="false" tabindex="-1" data-closed></button>
      <div id="panel" hidden></div>
      <div id="untouched" data-closed></div>`
    const tab = document.getElementById("tab")
    const panel = document.getElementById("panel")
    tab.setAttribute("aria-selected", "true")
    tab.setAttribute("tabindex", "0")
    panel.hidden = false
    await delivered()

    expect(morphAttribute(tab, "aria-selected")).toBe(true)
    expect(morphAttribute(tab, "tabindex")).toBe(true)
    expect(morphAttribute(panel, "hidden", "update")).toBe(true)
    expect(morphAttribute(tab, "data-closed", "remove")).toBe(false)
    expect(morphAttribute(tab, "class")).toBe(false)
    expect(morphAttribute(document.getElementById("untouched"), "data-closed", "remove")).toBe(false)
  })

  it("drops the morph's own writes, then records the client's again", async () => {
    document.body.innerHTML = `<div id="root"><div id="inner" data-closed></div></div>`
    const inner = document.getElementById("inner")

    document.getElementById("root").dispatchEvent(new CustomEvent("turbo:before-morph-element", { bubbles: true }))
    inner.setAttribute("data-open", "")
    inner.removeAttribute("data-closed")
    await delivered()

    expect(ownsAttribute(inner, "data-open")).toBe(false)
    expect(ownsAttribute(inner, "data-closed")).toBe(false)

    inner.setAttribute("data-closed", "")
    await delivered()

    expect(ownsAttribute(inner, "data-closed")).toBe(true)
  })

  it("keeps a dirty control by the browser's own rule and never a clean one", () => {
    document.body.innerHTML = `
      <input id="typed" value="server"><input id="clean" value="server"><input id="blank">
      <input id="box" type="checkbox"><input id="radio" type="radio" checked>
      <textarea id="area">server</textarea>
      <select id="pick"><option id="first" selected>one</option><option id="second">two</option></select>
      <input id="file" type="file">`
    document.getElementById("typed").value = "mine"
    document.getElementById("blank").value = "mine"
    document.getElementById("box").checked = true
    document.getElementById("radio").checked = false
    document.getElementById("area").value = "mine"
    document.getElementById("second").selected = true

    expect(keepsAttribute(document.getElementById("typed"), "value")).toBe(true)
    expect(keepsAttribute(document.getElementById("blank"), "value")).toBe(true)
    expect(keepsAttribute(document.getElementById("clean"), "value")).toBe(false)
    expect(keepsAttribute(document.getElementById("box"), "checked")).toBe(true)
    expect(keepsAttribute(document.getElementById("radio"), "checked")).toBe(true)
    expect(keepsAttribute(document.getElementById("area"), "value")).toBe(true)
    expect(keepsAttribute(document.getElementById("second"), "selected")).toBe(true)
    expect(keepsAttribute(document.getElementById("first"), "selected")).toBe(true)
    expect(isDirtyControl(document.getElementById("file"))).toBe(false)
    expect(morphAttribute(document.getElementById("typed"), "value", "remove")).toBe(true)
    expect(morphAttribute(document.getElementById("clean"), "value", "remove")).toBe(false)
  })
})
