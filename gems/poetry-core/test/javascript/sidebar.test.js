import { beforeEach, describe, expect, it } from "vitest"
import { Application } from "@hotwired/stimulus"
import { registerPoetryControllers } from "@poetry/controllers"
/* eslint-disable no-unused-vars */

// poetry--core--sidebar JS-unit: the collapse state machine. What this
// file proves: reflect-on-connect from the server value, toggle flipping
// data-state + data-collapsible (the mode while collapsed, "" expanded),
// the cookie persisting only on genuine toggles (not the SSR value the
// server already knows), the Cmd/Ctrl+B shortcut, and collapsible=none
// being inert. The width/transform work is pure CSS (no JS to test).

const nextFrame = () => new Promise((resolve) => setTimeout(resolve, 0))
const el = (id) => document.getElementById(id)

const markup = ({ open = true, collapsible = "offcanvas" } = {}) => `
  <div id="wrapper" data-controller="poetry--core--sidebar"
       data-poetry--core--sidebar-open-value="${open}"
       data-poetry--core--sidebar-collapsible-value="${collapsible}">
    <button id="trigger" type="button" data-action="click->poetry--core--sidebar#toggle">Toggle</button>
    <div id="sidebar" data-poetry--core--sidebar-target="sidebar"
         data-state="${open ? "expanded" : "collapsed"}"
         data-collapsible="${open ? "" : collapsible}"></div>
  </div>`

const clearCookie = () => { document.cookie = "sidebar_state=; path=/; max-age=0" }
const readCookie = () =>
  document.cookie.split("; ").find((row) => row.startsWith("sidebar_state="))?.split("=")[1]

async function mount(options) {
  clearCookie()
  document.body.innerHTML = markup(options)
  const application = Application.start()
  registerPoetryControllers(application)
  await nextFrame()
  return application
}

const state = () => ({
  state: el("sidebar").getAttribute("data-state"),
  collapsible: el("sidebar").getAttribute("data-collapsible")
})

describe("poetry--core--sidebar", () => {
  let application

  beforeEach(() => {
    return async () => {
      // Clear the DOM while the application still OBSERVES: stop() first
      // halts the mutation observer, so controllers never disconnect and
      // their window listeners leak into the next test (masked before the
      // shortcut gained the first-claim-wins defaultPrevented gate).
      document.body.replaceChildren()
      await nextFrame()
      application?.stop()
      clearCookie()
    }
  })

  it("connect reflects the server-rendered state without writing the cookie", async () => {
    application = await mount({ open: true })

    expect(state()).toEqual({ state: "expanded", collapsible: "" })
    expect(readCookie()).toBeUndefined("the server already knows the SSR value - no echo write")
  })

  it("toggle collapses: data-state + the mode on data-collapsible, and persists", async () => {
    application = await mount({ open: true, collapsible: "icon" })

    el("trigger").click()

    expect(state()).toEqual({ state: "collapsed", collapsible: "icon" })
    expect(readCookie()).toBe("false")

    el("trigger").click()

    expect(state()).toEqual({ state: "expanded", collapsible: "" })
    expect(readCookie()).toBe("true")
  })

  it("Cmd/Ctrl+B toggles from anywhere", async () => {
    application = await mount({ open: true })

    window.dispatchEvent(new KeyboardEvent("keydown", { key: "b", metaKey: true, bubbles: true, cancelable: true }))
    expect(state().state).toBe("collapsed")

    window.dispatchEvent(new KeyboardEvent("keydown", { key: "b", ctrlKey: true, bubbles: true, cancelable: true }))
    expect(state().state).toBe("expanded")
  })

  it("a bare 'b' keypress does nothing", async () => {
    application = await mount({ open: true })

    window.dispatchEvent(new KeyboardEvent("keydown", { key: "b", bubbles: true, cancelable: true }))

    expect(state().state).toBe("expanded")
  })

  it("collapsible=none is inert - trigger and shortcut do nothing", async () => {
    application = await mount({ open: true, collapsible: "none" })

    el("trigger").click()
    window.dispatchEvent(new KeyboardEvent("keydown", { key: "b", metaKey: true }))

    expect(state().state).toBe("expanded")
  })

  it("dispatches a toggle event with the open state", async () => {
    application = await mount({ open: true })
    let detail = null
    el("wrapper").addEventListener("poetry--core--sidebar:toggle", (event) => { detail = event.detail })

    el("trigger").click()

    expect(detail).toEqual({ open: false })
  })

  it("the programmatic open/close surface", async () => {
    application = await mount({ open: true })
    const controller = application.getControllerForElementAndIdentifier(el("wrapper"), "poetry--core--sidebar")

    controller.close()
    expect(state().state).toBe("collapsed")

    controller.open()
    expect(state().state).toBe("expanded")
  })
})

// -- the mobile sheet (DOM-move) ------------------------------------------

const mobileMarkup = () => `
  <div id="wrapper" data-controller="poetry--core--sidebar"
       data-poetry--core--sidebar-open-value="true">
    <button id="trigger" type="button" data-action="click->poetry--core--sidebar#toggle">Toggle</button>
    <div id="sidebar" data-poetry--core--sidebar-target="sidebar" data-state="expanded" data-collapsible="">
      <div id="inner" data-poetry--core--sidebar-target="inner">
        <nav id="nav"><a href="/" id="nav-link">Home</a></nav>
      </div>
    </div>
    <dialog id="mobile" data-slot="sidebar-mobile" data-closed
            data-poetry--core--sidebar-target="mobileDialog"
            data-action="cancel->poetry--core--sidebar#closeMobile click->poetry--core--sidebar#mobileBackdropClose">
      <div id="mobile-inner" data-poetry--core--sidebar-target="mobileInner"></div>
    </dialog>
  </div>`

// A controllable matchMedia stub: flip() crosses the breakpoint.
function stubMatchMedia(initial) {
  const listeners = new Set()
  const query = {
    matches: initial,
    addEventListener: (_, fn) => listeners.add(fn),
    removeEventListener: (_, fn) => listeners.delete(fn),
  }
  window.matchMedia = () => query
  return {
    flip(matches) {
      query.matches = matches
      for (const fn of listeners) fn()
    },
  }
}

async function mountMobile({ mobile = true } = {}) {
  clearCookie()
  const media = stubMatchMedia(mobile)
  document.body.innerHTML = mobileMarkup()
  if (!HTMLDialogElement.prototype.showModal || HTMLDialogElement.prototype.__vitestShim) {
    HTMLDialogElement.prototype.__vitestShim = true
    HTMLDialogElement.prototype.showModal = function () { this.setAttribute("open", "") }
    HTMLDialogElement.prototype.close = function () { this.removeAttribute("open") }
  }
  const application = Application.start()
  registerPoetryControllers(application)
  await nextFrame()
  return { application, media }
}

describe("poetry--core--sidebar mobile", () => {
  let application

  beforeEach(() => async () => {
    application?.stop()
    delete window.matchMedia
    document.body.replaceChildren()
    await nextFrame()
  })

  it("the trigger routes to the sheet: adopt the nav, show, never persist", async () => {
    ({ application } = await mountMobile())
    el("trigger").click()

    expect(el("mobile").hasAttribute("open")).toBe(true)
    expect(el("mobile").hasAttribute("data-open")).toBe(true)
    expect(el("mobile-inner").querySelector("#nav")).not.toBe(null) // adopted
    expect(el("inner").children.length).toBe(0)
    expect(el("sidebar").getAttribute("data-state")).toBe("expanded") // desktop state untouched
    expect(readCookie()).toBe(undefined) // openMobile is never cookie-persisted

    // Toggle again: the animated close returns the children home.
    el("trigger").click()
    expect(el("mobile").hasAttribute("open")).toBe(false)
    expect(el("inner").querySelector("#nav")).not.toBe(null)
    expect(el("mobile-inner").children.length).toBe(0)
  })

  it("Esc's cancel routes through the animated close", async () => {
    ({ application } = await mountMobile())
    el("trigger").click()

    const cancel = new Event("cancel", { bubbles: false, cancelable: true })
    el("mobile").dispatchEvent(cancel)

    expect(cancel.defaultPrevented).toBe(true)
    expect(el("mobile").hasAttribute("open")).toBe(false)
    expect(el("inner").querySelector("#nav")).not.toBe(null)
  })

  it("crossing to desktop while open restores instantly", async () => {
    let media
    ;({ application, media } = await mountMobile())
    el("trigger").click()
    expect(el("mobile").hasAttribute("open")).toBe(true)

    media.flip(false)

    expect(el("mobile").hasAttribute("open")).toBe(false)
    expect(el("mobile").hasAttribute("data-closed")).toBe(true)
    expect(el("inner").querySelector("#nav")).not.toBe(null)

    // Now on desktop: the trigger flips data-state (and persists) again.
    el("trigger").click()
    expect(el("sidebar").getAttribute("data-state")).toBe("collapsed")
    expect(readCookie()).toBe("false")
  })
})
