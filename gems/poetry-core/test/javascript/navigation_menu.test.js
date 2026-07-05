import { beforeEach, describe, expect, it, vi } from "vitest"
import { Application } from "@hotwired/stimulus"
import { registerPoetryControllers } from "@poetry/controllers"

// poetry--core--navigation-menu JS-unit: the disclosure-bar coordinator.
// What this file proves: click toggling with ONE panel open at a time
// (the vocabulary flip: aria-expanded + data-popup-open on triggers,
// presence pair + hidden on panels), hover intent (cold entry waits the
// open delay; switching while open is instant; leave waits the close
// delay), Esc closing + refocusing the trigger, focus-out closing,
// outside press closing, and arrow keys moving between the bar's stops
// WITHOUT any tabindex management (a disclosure, not a menu).

const nextFrame = () => new Promise((resolve) => setTimeout(resolve, 0))
const el = (id) => document.getElementById(id)

const item = (value, { link = false } = {}) => link
  ? `<div id="item-${value}" data-slot="navigation-menu-item" data-value="${value}" class="relative">
       <a id="link-${value}" href="/${value}">${value}</a>
     </div>`
  : `<div id="item-${value}" data-slot="navigation-menu-item" data-value="${value}" class="relative"
         data-action="pointerenter->poetry--core--navigation-menu#scheduleOpen
                      pointerleave->poetry--core--navigation-menu#scheduleClose">
       <button id="trigger-${value}" type="button" data-slot="navigation-menu-trigger"
               aria-expanded="false" aria-controls="panel-${value}"
               data-action="click->poetry--core--navigation-menu#toggle">${value}</button>
       <div id="panel-${value}" data-slot="navigation-menu-content" data-closed hidden>
         <a href="/${value}/one">${value} one</a>
       </div>
     </div>`

const markup = () => `
  <nav id="root" aria-label="Main" data-controller="poetry--core--navigation-menu"
       data-action="keydown->poetry--core--navigation-menu#keydown
                    focusout->poetry--core--navigation-menu#focusLeft">
    <div data-slot="navigation-menu-list">
      ${item("products")}
      ${item("solutions")}
      ${item("docs", { link: true })}
    </div>
  </nav>
  <button id="elsewhere" type="button">Elsewhere</button>`

const hover = (type, target) => {
  const event = new MouseEvent(type, { bubbles: true })
  Object.defineProperty(event, "pointerType", { value: "mouse" })
  target.dispatchEvent(event)
}

const stateOf = (value) => ({
  expanded: el(`trigger-${value}`)?.getAttribute("aria-expanded"),
  popupOpen: el(`trigger-${value}`)?.hasAttribute("data-popup-open"),
  hidden: el(`panel-${value}`)?.hidden
})

async function mount() {
  document.body.innerHTML = markup()
  const application = Application.start()
  registerPoetryControllers(application)
  await nextFrame()
  return application
}

describe("poetry--core--navigation-menu", () => {
  let application

  beforeEach(async () => {
    application = await mount()
    // Fake timers only AFTER Stimulus has booted (the Tabs lesson).
    vi.useFakeTimers()
    return async () => {
      vi.useRealTimers()
      application.stop()
      document.body.replaceChildren()
      await nextFrame()
    }
  })

  it("click opens with the full vocabulary; a second click closes", () => {
    el("trigger-products").click()

    expect(stateOf("products")).toEqual({ expanded: "true", popupOpen: true, hidden: false })

    el("trigger-products").click()

    expect(stateOf("products")).toEqual({ expanded: "false", popupOpen: false, hidden: true })
  })

  it("only one panel is open at a time", () => {
    el("trigger-products").click()
    el("trigger-solutions").click()

    expect(stateOf("solutions").hidden).toBe(false)
    expect(stateOf("products")).toEqual({ expanded: "false", popupOpen: false, hidden: true })
  })

  it("hover waits the open delay cold, switches instantly while open", () => {
    hover("pointerenter", el("item-products"))

    expect(stateOf("products").hidden).toBe(true, "intent delay - not yet")
    vi.advanceTimersByTime(60)
    expect(stateOf("products").hidden).toBe(false)

    hover("pointerenter", el("item-solutions"))
    vi.advanceTimersByTime(0)

    expect(stateOf("solutions").hidden).toBe(false, "already open - instant switch")
    expect(stateOf("products").hidden).toBe(true)
  })

  it("leaving waits the close delay - re-entering cancels it", () => {
    el("trigger-products").click()
    hover("pointerleave", el("item-products"))
    vi.advanceTimersByTime(100)

    expect(stateOf("products").hidden).toBe(false, "still inside the close window")

    hover("pointerenter", el("item-products"))
    vi.advanceTimersByTime(500)

    expect(stateOf("products").hidden).toBe(false, "re-entry cancelled the close")
  })

  it("Escape closes and refocuses the open trigger", () => {
    el("trigger-products").click()
    el("root").dispatchEvent(new KeyboardEvent("keydown", { key: "Escape", bubbles: true, cancelable: true }))

    expect(stateOf("products").hidden).toBe(true)
    expect(document.activeElement).toBe(el("trigger-products"))
  })

  it("focus leaving the bar closes it", () => {
    el("trigger-products").click()
    el("root").dispatchEvent(new FocusEvent("focusout", { bubbles: true, relatedTarget: el("elsewhere") }))

    expect(stateOf("products").hidden).toBe(true)
  })

  it("an outside press closes; presses inside do not", () => {
    el("trigger-products").click()

    el("panel-products").dispatchEvent(new MouseEvent("pointerdown", { bubbles: true }))
    expect(stateOf("products").hidden).toBe(false)

    document.body.dispatchEvent(new MouseEvent("pointerdown", { bubbles: true }))
    expect(stateOf("products").hidden).toBe(true)
  })

  it("arrows move between triggers AND top-level links, no tabindex writes", () => {
    el("trigger-products").focus()
    el("trigger-products")
      .dispatchEvent(new KeyboardEvent("keydown", { key: "ArrowRight", bubbles: true, cancelable: true }))

    expect(document.activeElement).toBe(el("trigger-solutions"))

    el("trigger-solutions")
      .dispatchEvent(new KeyboardEvent("keydown", { key: "ArrowRight", bubbles: true, cancelable: true }))

    expect(document.activeElement).toBe(el("link-docs"), "plain links are arrow stops too")
    expect(el("trigger-products").hasAttribute("tabindex")).toBe(false, "a disclosure never roves tabindex")
  })
})
