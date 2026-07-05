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
      application?.stop()
      document.body.replaceChildren()
      clearCookie()
      await nextFrame()
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
