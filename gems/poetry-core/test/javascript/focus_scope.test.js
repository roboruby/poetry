import { beforeEach, describe, expect, it } from "vitest"
import { Application } from "@hotwired/stimulus"
import { registerPoetryControllers } from "@poetry/controllers"

const nextFrame = () => new Promise((resolve) => setTimeout(resolve, 0))

const GUARD_SELECTOR = "[data-poetry-focus-guard]"

const press = (element, key, options = {}) =>
  element.dispatchEvent(new KeyboardEvent("keydown", { key, bubbles: true, cancelable: true, ...options }))

const scopeMarkup = (id, values = "") => `
  <div id="${id}" data-controller="poetry--core--focus-scope" ${values}>
    <button id="${id}-first">first</button>
    <button id="${id}-last">last</button>
  </div>`

// Scopes mount AFTER focus is parked outside, so connect's activeElement
// snapshot (the focus-return target) is deterministic in every test.
async function mountScope(values = "") {
  document.getElementById("host").insertAdjacentHTML("beforeend", scopeMarkup("scope", values))
  await nextFrame()
}

const el = (id) => document.getElementById(id)

describe("poetry--core--focus-scope", () => {
  let application

  beforeEach(async () => {
    document.body.innerHTML = `<button id="outside">outside</button><div id="host"></div>`
    application = Application.start()
    registerPoetryControllers(application)
    await nextFrame()
    el("outside").focus()
    // application.stop() does NOT disconnect live controllers (see
    // dialog.test.js) - remove the scopes and await the disconnect so the
    // class-level stack and the guard refcount cannot leak across tests.
    return async () => {
      el("host")?.replaceChildren()
      await nextFrame()
      application.stop()
    }
  })

  it("connect focuses the first tabbable and posts the body-edge focus guards", async () => {
    await mountScope()

    expect(document.activeElement).toBe(el("scope-first"))

    const guards = document.querySelectorAll(GUARD_SELECTOR)
    expect(guards.length).toBe(2)
    expect(document.body.firstElementChild).toBe(guards[0])
    expect(document.body.lastElementChild).toBe(guards[1])
    expect(guards[0].getAttribute("tabindex")).toBe("0")
    expect(guards[0].getAttribute("aria-hidden")).toBe("true")
  })

  it("mount-auto-focus is cancelable: the consumer keeps initial focus for itself", async () => {
    el("host").addEventListener("poetry--core--focus-scope:mount-auto-focus", (event) => event.preventDefault())
    await mountScope()

    expect(document.activeElement).toBe(el("outside"))
  })

  it("Tab on the last tabbable loops to the first; Shift+Tab on the first loops to the last", async () => {
    await mountScope()

    el("scope-last").focus()
    const handled = !press(el("scope-last"), "Tab")
    expect(handled).toBe(true)
    expect(document.activeElement).toBe(el("scope-first"))

    press(el("scope-first"), "Tab", { shiftKey: true })
    expect(document.activeElement).toBe(el("scope-last"))
  })

  it("loop=false still traps: Tab at the edge is swallowed but focus stays put", async () => {
    await mountScope(`data-poetry--core--focus-scope-loop-value="false"`)

    el("scope-last").focus()
    const notHandled = press(el("scope-last"), "Tab")

    expect(notHandled).toBe(false) // preventDefault'ed - the hard stop
    expect(document.activeElement).toBe(el("scope-last"))
  })

  it("trapped: focus escaping the scope is yanked back to the last focused element within", async () => {
    await mountScope()

    el("scope-last").focus()
    el("outside").focus() // a guard landing / programmatic escape

    expect(document.activeElement).toBe(el("scope-last"))
  })

  it("disconnect RESTORES the connect-time active element and drops the guards", async () => {
    await mountScope()
    expect(document.activeElement).toBe(el("scope-first"))

    el("scope").remove()
    await nextFrame()

    expect(document.activeElement).toBe(el("outside"))
    expect(document.querySelectorAll(GUARD_SELECTOR).length).toBe(0)
  })

  it("unmount-auto-focus is cancelable: the consumer redirects the focus return", async () => {
    await mountScope()

    const scope = el("scope")
    scope.addEventListener("poetry--core--focus-scope:unmount-auto-focus", (event) => event.preventDefault())
    scope.remove()
    await nextFrame()

    expect(document.activeElement).not.toBe(el("outside"))
  })

  it("nested scopes stack: the top traps alone, and closing it resumes (and refocuses) the parent", async () => {
    el("host").insertAdjacentHTML("beforeend", scopeMarkup("parent"))
    await nextFrame()
    expect(document.activeElement).toBe(el("parent-first"))

    el("host").insertAdjacentHTML("beforeend", scopeMarkup("child"))
    await nextFrame()
    expect(document.activeElement).toBe(el("child-first"))

    // Only the TOP scope traps: focusing into the paused parent counts as
    // outside the child and is yanked back to the child.
    el("parent-first").focus()
    expect(document.activeElement).toBe(el("child-first"))

    // Two trapped scopes share ONE refcounted guard pair.
    expect(document.querySelectorAll(GUARD_SELECTOR).length).toBe(2)

    // Closing the child returns focus to the parent (the child's snapshot)
    // and the parent resumes trapping.
    el("child").remove()
    await nextFrame()
    expect(document.activeElement).toBe(el("parent-first"))

    el("outside").focus()
    expect(document.activeElement).toBe(el("parent-first"))
    expect(document.querySelectorAll(GUARD_SELECTOR).length).toBe(2)

    el("parent").remove()
    await nextFrame()
    expect(document.querySelectorAll(GUARD_SELECTOR).length).toBe(0)
  })
})
