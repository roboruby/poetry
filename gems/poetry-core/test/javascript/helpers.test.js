import { describe, expect, it, vi } from "vitest"
import { setState, stateOf } from "@poetry/controllers/helpers/state"
import { collectionItems } from "@poetry/controllers/helpers/collection"
import { directionOf } from "@poetry/controllers/helpers/direction"
import { tabbableWithin } from "@poetry/controllers/helpers/tabbable"
import { onEscapeKeydown } from "@poetry/controllers/helpers/escape"

describe("state", () => {
  it("writes data-state and dispatches a bubbling poetry:state-change", () => {
    const parent = document.createElement("div")
    const el = document.createElement("div")
    parent.appendChild(el)
    const seen = []
    parent.addEventListener("poetry:state-change", (event) => seen.push(event.detail.state))

    setState(el, "open")

    expect(el.dataset.state).toBe("open")
    expect(stateOf(el)).toBe("open")
    expect(seen).toEqual(["open"])
  })
})

describe("collection", () => {
  it("returns items in DOM order - the DOM is the registry", () => {
    document.body.innerHTML = `
      <ul>
        <li data-poetry-collection-item id="a"></li>
        <li id="skip"></li>
        <li data-poetry-collection-item id="b"></li>
      </ul>`

    expect(collectionItems(document.body).map((el) => el.id)).toEqual(["a", "b"])
  })
})

describe("direction", () => {
  it("reads the closest dir ancestor, defaulting to ltr", () => {
    document.body.innerHTML = `<div dir="RTL"><span id="inner"></span></div><span id="outer"></span>`

    expect(directionOf(document.getElementById("inner"))).toBe("rtl")
    expect(directionOf(document.getElementById("outer"))).toBe("ltr")
  })
})

describe("tabbable", () => {
  it("collects candidates and filters disabled / hidden / tabindex=-1 / inert", () => {
    document.body.innerHTML = `
      <div id="scope">
        <a href="#" id="link">a</a>
        <button id="btn">b</button>
        <button disabled id="disabled">c</button>
        <input type="hidden" id="hiddenInput">
        <input id="text">
        <span tabindex="0" id="focusable-span"></span>
        <span tabindex="-1" id="skipped-span"></span>
        <div inert><button id="inert-btn">d</button></div>
        <button hidden id="hidden-btn">e</button>
      </div>`

    const ids = tabbableWithin(document.getElementById("scope")).map((el) => el.id)

    expect(ids).toEqual(["link", "btn", "text", "focusable-span"])
  })
})

describe("escape", () => {
  it("fires on Escape only and unsubscribes cleanly", () => {
    const callback = vi.fn()
    const unsubscribe = onEscapeKeydown(callback)

    window.dispatchEvent(new KeyboardEvent("keydown", { key: "Escape" }))
    window.dispatchEvent(new KeyboardEvent("keydown", { key: "Enter" }))
    expect(callback).toHaveBeenCalledTimes(1)

    unsubscribe()
    window.dispatchEvent(new KeyboardEvent("keydown", { key: "Escape" }))
    expect(callback).toHaveBeenCalledTimes(1)
  })
})
