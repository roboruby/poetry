import { afterEach, beforeEach, describe, expect, it, vi } from "vitest"
import { Application, Controller } from "@hotwired/stimulus"
import { hasScope, scopeOf, teardown } from "@poetry/controllers/helpers/scope"
import { useListen } from "@poetry/controllers/behaviors/listen"
import { useEscape } from "@poetry/controllers/behaviors/escape"
import { useBeforeCache } from "@poetry/controllers/behaviors/before_cache"
import { useLayers } from "@poetry/controllers/behaviors/layers"
import { usePresence } from "@poetry/controllers/behaviors/presence"
import { usePortal } from "@poetry/controllers/behaviors/portal"
import { useScrollLock } from "@poetry/controllers/behaviors/scroll_lock"
import { useTypeahead } from "@poetry/controllers/behaviors/typeahead"
import { useMobile } from "@poetry/controllers/behaviors/mobile"
import { resetScrollLock } from "@poetry/controllers/helpers/scroll_lock"

// The per-connect scope and the behaviors over it: a disposer stack
// renewed every connect, torn down in one line. The reconnect matrix the
// behaviors plan asks for sits at the end, on a real Stimulus
// application: connect/disconnect/connect twice binds once; an unchanged
// element under a morph keeps its behaviors live; idiomorph's connect,
// connect, disconnect order leaves the survivor intact; two instances on
// one page each keep their own Escape.

const nextFrame = () => new Promise((resolve) => setTimeout(resolve, 0))

const keydown = (key, target = window) => {
  target.dispatchEvent(new KeyboardEvent("keydown", { key, bubbles: true, cancelable: true }))
}

describe("scopeOf / teardown", () => {
  it("creates one scope per controller until teardown, then a fresh one", () => {
    const controller = {}

    expect(hasScope(controller)).toBe(false)
    const first = scopeOf(controller)
    expect(scopeOf(controller)).toBe(first)
    expect(hasScope(controller)).toBe(true)

    teardown(controller)
    expect(hasScope(controller)).toBe(false)
    expect(first.signal.aborted).toBe(true)

    const second = scopeOf(controller)
    expect(second).not.toBe(first)
    expect(second.signal.aborted).toBe(false)
  })

  it("runs disposers newest first and only once", () => {
    const controller = {}
    const order = []
    scopeOf(controller).defer(() => order.push("first"))
    scopeOf(controller).defer(() => order.push("second"))

    teardown(controller)
    teardown(controller)

    expect(order).toEqual(["second", "first"])
  })

  it("removes a listener at teardown and honours the capture flag", () => {
    const controller = {}
    const target = document.createElement("div")
    const bubble = vi.fn()
    const capture = vi.fn()
    scopeOf(controller).listen(target, "ping", bubble)
    scopeOf(controller).listen(target, "ping", capture, true)

    target.dispatchEvent(new Event("ping"))
    teardown(controller)
    target.dispatchEvent(new Event("ping"))

    expect(bubble).toHaveBeenCalledTimes(1)
    expect(capture).toHaveBeenCalledTimes(1)
  })

  it("lets a listener leave early through its own return", () => {
    const controller = {}
    const target = document.createElement("div")
    const listener = vi.fn()
    const unlisten = scopeOf(controller).listen(target, "ping", listener)

    unlisten()
    target.dispatchEvent(new Event("ping"))

    expect(listener).not.toHaveBeenCalled()
  })
})

describe("the behaviors", () => {
  afterEach(() => {
    document.body.innerHTML = ""
    resetScrollLock()
  })

  it("useListen binds for the scope's lifetime", () => {
    const controller = {}
    const listener = vi.fn()
    useListen(controller, document, "ping", listener)

    document.dispatchEvent(new Event("ping"))
    teardown(controller)
    document.dispatchEvent(new Event("ping"))

    expect(listener).toHaveBeenCalledTimes(1)
  })

  it("useEscape subscribes until teardown and filters IME cancels", () => {
    const controller = {}
    const callback = vi.fn()
    useEscape(controller, callback)

    keydown("Escape")
    window.dispatchEvent(new KeyboardEvent("keydown", { key: "Escape", keyCode: 229 }))
    teardown(controller)
    keydown("Escape")

    expect(callback).toHaveBeenCalledTimes(1)
  })

  it("useBeforeCache subscribes until teardown", () => {
    const controller = {}
    const callback = vi.fn()
    useBeforeCache(controller, callback)

    document.dispatchEvent(new Event("turbo:before-cache"))
    teardown(controller)
    document.dispatchEvent(new Event("turbo:before-cache"))

    expect(callback).toHaveBeenCalledTimes(1)
  })

  it("useLayers adds tokens once, removes them, and deactivates what is left at teardown", () => {
    const controller = {}
    const content = document.createElement("div")
    content.setAttribute("data-controller", "popper")
    const layers = useLayers(controller)

    layers.activate(content, ["focus-scope", "dismissable"])
    layers.activate(content, ["dismissable"])
    expect(content.getAttribute("data-controller")).toBe("popper focus-scope dismissable")

    layers.deactivate(content, ["focus-scope"])
    expect(content.getAttribute("data-controller")).toBe("popper dismissable")

    teardown(controller)
    expect(content.getAttribute("data-controller")).toBe("popper")
  })

  it("usePresence tracks exits per node and abandons them at teardown without removal", () => {
    const controller = {}
    const presence = usePresence(controller)
    const a = document.createElement("div")
    const b = document.createElement("div")
    document.body.append(a, b)
    // jsdom reports no animation: the exit settles inside the call.
    const removedA = vi.fn()
    presence.exit(a, { onRemove: removedA })

    expect(removedA).toHaveBeenCalledTimes(1)
    expect(presence.exiting(a)).toBe(false)
    expect(a.hasAttribute("data-closed")).toBe(true)

    presence.enter(b)
    expect(b.hasAttribute("data-open")).toBe(true)

    teardown(controller)
    expect(removedA).toHaveBeenCalledTimes(1)
  })

  it("usePortal restores every node it moved at teardown", () => {
    const controller = {}
    const home = document.createElement("div")
    const content = document.createElement("div")
    home.append(content)
    document.body.append(home)
    const portal = usePortal(controller)

    expect(portal.portal(content)).toBe(true)
    expect(content.parentNode).toBe(document.body)

    teardown(controller)
    expect(content.parentNode).toBe(home)
  })

  it("useScrollLock is idempotent per instance and balanced at teardown", () => {
    const controller = {}
    const lock = useScrollLock(controller)

    lock.lock()
    lock.lock()
    expect(lock.locked()).toBe(true)
    expect(document.body.style.overflow).toBe("hidden")

    lock.unlock()
    lock.unlock()
    expect(document.body.style.overflow).toBe("")

    lock.lock()
    teardown(controller)
    expect(document.body.style.overflow).toBe("")
  })

  it("useTypeahead resets its pending buffer at teardown", () => {
    vi.useFakeTimers()
    const controller = {}
    const typeahead = useTypeahead(controller)
    const item = document.createElement("div")
    item.textContent = "Apple"

    typeahead.search("a", [item])
    expect(typeahead.pending()).toBe(true)

    teardown(controller)
    expect(typeahead.pending()).toBe(false)
    expect(vi.getTimerCount()).toBe(0)
    vi.useRealTimers()
  })

  it("useMobile reports desktop without matchMedia and unwatches at teardown", () => {
    const controller = {}
    const onChange = vi.fn()
    const unwatch = useMobile(controller, onChange)

    expect(onChange).toHaveBeenCalledWith(false)
    expect(typeof unwatch).toBe("function")
    teardown(controller)
  })
})

// --- the reconnect matrix ---------------------------------------------------

class ProbeController extends Controller {
  static instances = []

  pings = 0
  escapes = 0

  initialize() {
    ProbeController.instances.push(this)
  }

  connect() {
    useListen(this, this.element, "ping", () => { this.pings += 1 })
    useEscape(this, () => { this.escapes += 1 })
  }

  disconnect() {
    teardown(this)
  }
}

describe("the reconnect matrix", () => {
  let application

  beforeEach(async () => {
    ProbeController.instances = []
    document.body.innerHTML = `<div id="host"><div id="probe" data-controller="probe"></div></div>`
    application = Application.start()
    application.register("probe", ProbeController)
    await nextFrame()
  })

  afterEach(() => {
    application.stop()
    document.body.innerHTML = ""
  })

  it("connect, disconnect, connect twice binds one listener", async () => {
    const host = document.getElementById("host")
    const probe = document.getElementById("probe")
    const [controller] = ProbeController.instances

    for (let round = 0; round < 2; round += 1) {
      probe.remove()
      await nextFrame()
      expect(hasScope(controller)).toBe(false)
      host.append(probe)
      await nextFrame()
    }

    probe.dispatchEvent(new Event("ping"))
    keydown("Escape")

    expect(controller.pings).toBe(1)
    expect(controller.escapes).toBe(1)
  })

  it("an element a morph leaves in place keeps its behaviors live without a second connect", async () => {
    const probe = document.getElementById("probe")
    const [controller] = ProbeController.instances

    probe.setAttribute("data-foo", "bar")
    probe.innerHTML = "<span>child</span>"
    await nextFrame()

    probe.dispatchEvent(new Event("ping"))
    expect(controller.pings).toBe(1)
    expect(ProbeController.instances).toHaveLength(1)
  })

  it("idiomorph's connect, connect, disconnect order leaves the survivor intact", async () => {
    const host = document.getElementById("host")
    const old = document.getElementById("probe")
    const fresh = document.createElement("div")
    fresh.id = "probe-2"
    fresh.setAttribute("data-controller", "probe")

    host.append(fresh)
    await nextFrame()
    old.remove()
    await nextFrame()

    const [first, second] = ProbeController.instances
    expect(hasScope(first)).toBe(false)
    expect(hasScope(second)).toBe(true)

    fresh.dispatchEvent(new Event("ping"))
    keydown("Escape")
    expect(second.pings).toBe(1)
    expect(second.escapes).toBe(1)
    expect(first.escapes).toBe(0)
  })

  it("two instances on one page each keep their own Escape until their own teardown", async () => {
    const host = document.getElementById("host")
    const other = document.createElement("div")
    other.id = "probe-2"
    other.setAttribute("data-controller", "probe")
    host.append(other)
    await nextFrame()

    const [first, second] = ProbeController.instances
    keydown("Escape")
    expect(first.escapes).toBe(1)
    expect(second.escapes).toBe(1)

    other.remove()
    await nextFrame()
    keydown("Escape")
    expect(first.escapes).toBe(2)
    expect(second.escapes).toBe(1)
  })
})
