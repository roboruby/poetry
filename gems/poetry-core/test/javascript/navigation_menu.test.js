import { beforeEach, describe, expect, it, vi } from "vitest"
import { Application } from "@hotwired/stimulus"
import { registerPoetryControllers } from "@poetry/controllers"

// The viewport tests mount the popper on the nav root; jsdom computes no
// layout, so the vendored floating-ui is mocked (the popper suite's own
// convention) - real positioning is the browser rig's job.
vi.mock("@poetry/controllers/vendor/floating_ui_dom", () => {
  const middleware = () => vi.fn(() => ({}))

  return {
    computePosition: vi.fn(async () => ({
      x: 0, y: 40, placement: "bottom-start", strategy: "absolute", middlewareData: {}
    })),
    autoUpdate: vi.fn((_reference, _content, update) => {
      update()
      return () => {}
    }),
    offset: middleware(),
    shift: middleware(),
    flip: middleware(),
    size: middleware(),
    arrow: middleware(),
    hide: middleware(),
    limitShift: vi.fn(() => ({}))
  }
})

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

// -- the morphing viewport ----------------------------------

const viewportMarkup = () => `
  <nav id="root" aria-label="Main" data-viewport="true"
       data-controller="poetry--core--navigation-menu poetry--core--popper"
       data-poetry--core--popper-strategy-value="absolute"
       data-action="keydown->poetry--core--navigation-menu#keydown
                    focusout->poetry--core--navigation-menu#focusLeft">
    <div data-slot="navigation-menu-list">
      ${item("products")}
      ${item("solutions")}
    </div>
    <div id="positioner" data-slot="navigation-menu-positioner" hidden
         data-poetry--core--popper-target="content"
         data-action="pointerenter->poetry--core--navigation-menu#cancelClose
                      pointerleave->poetry--core--navigation-menu#scheduleClose">
      <div id="popup" data-slot="navigation-menu-popup" data-closed>
        <div id="viewport" data-slot="navigation-menu-viewport"></div>
      </div>
    </div>
  </nav>`

async function mountViewport() {
  document.body.innerHTML = viewportMarkup()
  // Deterministic trigger geometry so the direction stamp has a delta.
  el("trigger-products").getBoundingClientRect = () => ({ left: 0, top: 0, right: 80, bottom: 36, width: 80, height: 36 })
  el("trigger-solutions").getBoundingClientRect = () => ({ left: 100, top: 0, right: 180, bottom: 36, width: 80, height: 36 })
  const application = Application.start()
  application.handleError = (error, message) => {
    console.log(`STIMULUS ERROR: ${message}: ${error?.message}\n${error?.stack}`)
  }
  registerPoetryControllers(application)
  await nextFrame()
  return application
}

describe("poetry--core--navigation-menu viewport mode", () => {
  let application

  beforeEach(() => async () => {
    application?.stop()
    document.body.replaceChildren()
    await nextFrame()
  })

  it("first activation adopts the panel, shows the positioner, pins the size vars", async () => {
    application = await mountViewport()
    el("trigger-products").click()
    await nextFrame()

    const panel = el("panel-products")
    expect(panel.parentElement).toBe(el("viewport"), "lazy adoption into the shared viewport")
    expect(panel.hasAttribute("data-viewport-panel")).toBe(true)
    expect(panel.hidden).toBe(false)
    expect(el("positioner").hidden).toBe(false)
    expect(el("popup").hasAttribute("data-open")).toBe(true)
    // jsdom has no layout: the pins are 0px, and the reset (no animations
    // to await) lands synchronously - vars end at auto.
    expect(el("popup").style.getPropertyValue("--popup-width")).toBe("auto")
    expect(el("positioner").style.getPropertyValue("--positioner-height")).toBe("auto")
  })

  it("switching stamps the travel direction on BOTH panels and swaps them", async () => {
    application = await mountViewport()
    el("trigger-products").click()
    await nextFrame()
    el("trigger-solutions").click()
    await nextFrame()

    expect(el("panel-products").getAttribute("data-activation-direction")).toBe("right")
    expect(el("panel-solutions").getAttribute("data-activation-direction")).toBe("right")
    expect(el("panel-solutions").parentElement).toBe(el("viewport"))
    expect(el("panel-solutions").hidden).toBe(false)
    expect(el("trigger-solutions").getAttribute("aria-expanded")).toBe("true")
    expect(el("trigger-products").getAttribute("aria-expanded")).toBe("false")
  })

  it("Escape closes the viewport composite", async () => {
    application = await mountViewport()
    el("trigger-products").click()
    await nextFrame()

    const escape = new KeyboardEvent("keydown", { key: "Escape", bubbles: true, cancelable: true })
    el("trigger-products").dispatchEvent(escape)

    expect(el("positioner").hidden).toBe(true)
    expect(el("popup").hasAttribute("data-closed")).toBe(true)
    expect(el("panel-products").hidden).toBe(true)
  })

  it("entering the positioner cancels a pending close", async () => {
    application = await mountViewport()
    // Fake timers only AFTER Stimulus has booted (the Tabs lesson) - and
    // after mount, whose nextFrame is a real setTimeout.
    vi.useFakeTimers()
    try {
      el("trigger-products").click()

      hover("pointerleave", el("item-products")) // schedules the 150ms close
      hover("pointerenter", el("positioner")) // crossing into the popup cancels it
      vi.advanceTimersByTime(500)

      expect(el("positioner").hidden).toBe(false)
      expect(el("trigger-products").getAttribute("aria-expanded")).toBe("true")
    } finally {
      vi.useRealTimers()
    }
  })
})
