import { afterEach, beforeEach, describe, expect, it, vi } from "vitest"
import { Application } from "@hotwired/stimulus"
import { registerPoetryControllers } from "@poetry/controllers"

// The mode machine + event contract, driven with STUBBED geometry (rects,
// scrollTop, clientHeight, scrollTo) - jsdom computes no layout, so REAL
// pinning/anchoring behavior (native scroll anchoring, smooth-scroll
// settling, IntersectionObserver firing) is the browser-verification
// suite's job, never faked here. What this file CAN prove: transitions,
// data-state/data-scrollable mirroring, event dispatch, value defaults,
// user-intent release, the 180ms autoscrolling suppression, branch order,
// and disconnect teardown.

const ID = "poetry--core--message-scroller"

const nextFrame = () => new Promise((resolve) => setTimeout(resolve, 0))
// MutationObserver delivers on a microtask; a macrotask hop is past it.
const flushMutations = nextFrame

// jsdom lacks ResizeObserver / IntersectionObserver (cf. the
// HTMLDialogElement shim in setup.js) - minimal recording stubs, local to
// this file so the geometry tests stay observer-free.
class ResizeObserverStub {
  static instances = []
  constructor(callback) {
    this.callback = callback
    this.observed = new Set()
    this.disconnected = false
    ResizeObserverStub.instances.push(this)
  }
  observe(element) { this.observed.add(element) }
  unobserve(element) { this.observed.delete(element) }
  disconnect() { this.observed.clear(); this.disconnected = true }
}

class IntersectionObserverStub {
  static instances = []
  constructor(callback, options) {
    this.callback = callback
    this.options = options
    this.observed = new Set()
    this.disconnected = false
    IntersectionObserverStub.instances.push(this)
  }
  observe(element) { this.observed.add(element) }
  unobserve(element) { this.observed.delete(element) }
  disconnect() { this.observed.clear(); this.disconnected = true }
}

// Manual rAF so coalesced commits run only when a test says so.
let rafCallbacks
let rafId
const runFrame = () => {
  const callbacks = [...rafCallbacks.values()]
  rafCallbacks.clear()
  callbacks.forEach((callback) => callback(0))
}

let application

beforeEach(() => {
  globalThis.ResizeObserver = ResizeObserverStub
  globalThis.IntersectionObserver = IntersectionObserverStub
  ResizeObserverStub.instances = []
  IntersectionObserverStub.instances = []

  rafCallbacks = new Map()
  rafId = 0
  vi.stubGlobal("requestAnimationFrame", (callback) => {
    rafCallbacks.set(++rafId, callback)
    return rafId
  })
  vi.stubGlobal("cancelAnimationFrame", (id) => rafCallbacks.delete(id))
})

afterEach(() => {
  application?.stop()
  application = null
  vi.unstubAllGlobals()
  delete globalThis.ResizeObserver
  delete globalThis.IntersectionObserver
  document.body.innerHTML = ""
})

function setRect(element, rect) {
  element.getBoundingClientRect = () => ({
    top: rect.top,
    bottom: rect.top + rect.height,
    height: rect.height,
    left: 0,
    right: 0,
    width: 0,
    x: 0,
    y: rect.top,
    toJSON: () => ({})
  })
}

function makeRow({ id, anchor = false, top = 0, height = 100 } = {}) {
  const element = document.createElement("div")
  if (id) element.dataset.messageId = id
  element.dataset.scrollAnchor = anchor ? "true" : "false"
  setRect(element, { top, height })
  return element
}

// Viewport metrics live on a mutable bag so tests can move the "layout".
function stubViewport(viewport, metrics) {
  setRect(viewport, { top: metrics.top, height: metrics.height })
  Object.defineProperty(viewport, "clientHeight", { configurable: true, get: () => metrics.height })
  Object.defineProperty(viewport, "scrollTop", {
    configurable: true,
    get: () => metrics.scrollTop,
    set: (value) => { metrics.scrollTop = value }
  })
  Object.defineProperty(viewport, "scrollHeight", { configurable: true, get: () => metrics.scrollHeight })
  viewport.scrollTo = (options) => {
    metrics.lastScrollTo = options
    metrics.scrollTop = options.top
  }
  return metrics
}

async function mount({ values = {}, rows = [], metrics = {} } = {}) {
  // The poetry ViewComponent opts into following by default; the raw
  // controller default is the source-faithful false. Tests mount the
  // component posture unless a test overrides the value.
  values = { "auto-scroll": true, ...values }
  document.body.innerHTML = ""

  const root = document.createElement("div")
  root.setAttribute("data-controller", ID)
  for (const [name, value] of Object.entries(values)) {
    root.setAttribute(`data-${ID}-${name}-value`, String(value))
  }

  const viewport = document.createElement("div")
  viewport.setAttribute(`data-${ID}-target`, "viewport")
  const content = document.createElement("div")
  content.setAttribute(`data-${ID}-target`, "content")
  const spacer = document.createElement("div")
  spacer.setAttribute(`data-${ID}-target`, "spacer")
  spacer.hidden = true

  const rowElements = rows.map((spec) => {
    const element = makeRow(spec)
    content.appendChild(element)
    return element
  })
  content.appendChild(spacer)
  viewport.appendChild(content)
  root.appendChild(viewport)

  const button = document.createElement("button")
  button.setAttribute(`data-${ID}-target`, "button")
  button.dataset.direction = "end"
  button.dataset.active = "false"
  button.setAttribute("data-action", `click->${ID}#jump`)
  root.appendChild(button)

  const m = stubViewport(viewport, { top: 0, height: 200, scrollTop: 0, scrollHeight: 200, ...metrics })

  document.body.appendChild(root)
  application = Application.start()
  registerPoetryControllers(application)
  await nextFrame()

  const controller = application.getControllerForElementAndIdentifier(root, ID)

  return { root, viewport, content, spacer, button, rowElements, metrics: m, controller }
}

function recordEvents(root, ...names) {
  const seen = []
  for (const name of names) {
    root.addEventListener(`${ID}:${name}`, (event) => seen.push({ name, detail: event.detail }))
  }
  return seen
}

describe("poetry--core--message-scroller", () => {
  describe("values and initial state", () => {
    it("ships the contract defaults", async () => {
      const { controller } = await mount()

      expect(controller.autoScrollValue).toBe(true)
      expect(controller.defaultScrollPositionValue).toBe("end")
      expect(controller.preserveScrollOnPrependValue).toBe(true)
      expect(controller.trackVisibilityValue).toBe(false)
      expect(controller.scrollEdgeThresholdValue).toBe(8)
      expect(controller.scrollPreviousItemPeekValue).toBe(64)
      expect(controller.scrollMarginValue).toBe(0)
      // Lazy visibility: no IntersectionObserver unless opted in.
      expect(IntersectionObserverStub.instances).toHaveLength(0)
    })

    it("mirrors the initial mode to data-state (following-bottom under autoScroll)", async () => {
      const { root } = await mount()
      expect(root.dataset.state).toBe("following-bottom")
    })

    it("starts free-scrolling when autoScroll is off", async () => {
      const { root } = await mount({ values: { "auto-scroll": false } })
      expect(root.dataset.state).toBe("free-scrolling")
    })

    it("applies defaultScrollPosition end once on first content", async () => {
      const { metrics } = await mount({
        rows: [{ id: "m1", top: 0, height: 100 }, { id: "m2", top: 100, height: 100 }],
        metrics: { scrollHeight: 600 }
      })

      expect(metrics.scrollTop).toBe(400) // maxScrollTop = 600 - 200
    })

    it("applies defaultScrollPosition start", async () => {
      const { root, metrics } = await mount({
        values: { "auto-scroll": false, "default-scroll-position": "start" },
        rows: [{ id: "m1", top: 0, height: 100 }],
        metrics: { scrollTop: 0 }
      })

      expect(metrics.scrollTop).toBe(0)
      expect(root.dataset.state).toBe("free-scrolling")
    })
  })

  describe("follow-bottom arm / release (reconcile)", () => {
    it("releases to free-scrolling on scroll away, with an unpinned scroll-away reason", async () => {
      const { root, viewport, rowElements } = await mount({
        rows: [{ id: "m1", top: 0, height: 100 }, { id: "m2", top: 100, height: 100 }]
      })
      const events = recordEvents(root, "mode", "unpinned")

      // Overflow appears below the viewport (a scrollbar drag away from the end).
      setRect(rowElements[1], { top: 100, height: 400 })
      viewport.dispatchEvent(new Event("scroll"))

      expect(root.dataset.state).toBe("free-scrolling")
      expect(events).toContainEqual({
        name: "mode",
        detail: { from: "following-bottom", to: "free-scrolling", mode: "free-scrolling" }
      })
      expect(events).toContainEqual({ name: "unpinned", detail: { reason: "scroll-away" } })
    })

    it("re-arms (pinned) when the viewport reaches the bottom again, however it got there", async () => {
      const { root, viewport, rowElements } = await mount({
        rows: [{ id: "m1", top: 0, height: 100 }, { id: "m2", top: 100, height: 100 }]
      })

      setRect(rowElements[1], { top: 100, height: 400 })
      viewport.dispatchEvent(new Event("scroll"))
      expect(root.dataset.state).toBe("free-scrolling")

      const events = recordEvents(root, "pinned")
      setRect(rowElements[1], { top: 100, height: 100 })
      viewport.dispatchEvent(new Event("scroll"))

      expect(root.dataset.state).toBe("following-bottom")
      expect(events).toHaveLength(1)
    })

    it("suppresses the release while autoscrolling, then releases after the 180ms clear", async () => {
      const { root, viewport, rowElements, metrics, controller } = await mount({
        rows: [{ id: "m1", top: 0, height: 100 }, { id: "m2", top: 100, height: 100 }]
      })
      const events = recordEvents(root, "unpinned")

      // Content grows; a programmatic follow move starts (sets the flag).
      setRect(rowElements[1], { top: 100, height: 400 })
      metrics.scrollHeight = 600
      controller.scrollToEnd()

      expect(root.hasAttribute("data-autoscrolling")).toBe(true)

      // Mid-animation the geometry still reads scrolled-away: no release.
      viewport.dispatchEvent(new Event("scroll"))
      expect(root.dataset.state).toBe("following-bottom")
      expect(events).toHaveLength(0)

      // 180ms after the move the flag clears; the clear's own commit releases.
      await new Promise((resolve) => setTimeout(resolve, 250))
      expect(root.dataset.state).toBe("free-scrolling")
      expect(root.hasAttribute("data-autoscrolling")).toBe(false)
      expect(events).toEqual([{ name: "unpinned", detail: { reason: "scroll-away" } }])
    })
  })

  describe("user intent", () => {
    it("wheel releases follow-bottom with reason user-intent", async () => {
      const { root, viewport } = await mount({
        rows: [{ id: "m1", top: 0, height: 100 }]
      })
      const events = recordEvents(root, "unpinned")

      viewport.dispatchEvent(new Event("wheel"))

      expect(root.dataset.state).toBe("free-scrolling")
      expect(events).toEqual([{ name: "unpinned", detail: { reason: "user-intent" } }])
    })

    it("touchmove releases follow-bottom", async () => {
      const { root, viewport } = await mount({ rows: [{ id: "m1", top: 0, height: 100 }] })

      viewport.dispatchEvent(new Event("touchmove"))

      expect(root.dataset.state).toBe("free-scrolling")
    })

    it("only USER_SCROLL_KEYS count as keyboard intent", async () => {
      const { root, viewport } = await mount({ rows: [{ id: "m1", top: 0, height: 100 }] })

      viewport.dispatchEvent(new KeyboardEvent("keydown", { key: "a" }))
      expect(root.dataset.state).toBe("following-bottom")

      viewport.dispatchEvent(new KeyboardEvent("keydown", { key: "PageDown" }))
      expect(root.dataset.state).toBe("free-scrolling")
    })
  })

  describe("content changes (the load-bearing branch order)", () => {
    it("a single new anchor row moves to the reading line (anchored-to-message)", async () => {
      const { root, content, spacer, metrics } = await mount({
        values: { "auto-scroll": false },
        rows: [{ id: "m1", top: 0, height: 100 }]
      })
      metrics.scrollHeight = 600 // after mount, so the opening scrollToEnd stayed at 0

      content.insertBefore(makeRow({ id: "m2", anchor: true, top: 100, height: 50 }), spacer)
      await flushMutations()

      // elementTop 100 - (scrollMargin 0 + peek 64) = 36.
      expect(metrics.scrollTop).toBe(36)
      expect(root.dataset.state).toBe("anchored-to-message")
      // Tail spacer fakes the room below: 36 + 200 - contentBottom 150 = 86.
      expect(spacer.style.height).toBe("86px")
      expect(spacer.hidden).toBe(false)
    })

    it("a multi-anchor batch while pinned keeps following the end (no yank)", async () => {
      const { root, content, spacer, metrics } = await mount({
        rows: [{ id: "m1", top: 0, height: 100 }],
        metrics: { scrollHeight: 600 }
      })
      metrics.scrollHeight = 900

      content.insertBefore(makeRow({ id: "m2", anchor: true, top: 100, height: 50 }), spacer)
      content.insertBefore(makeRow({ id: "m3", anchor: true, top: 150, height: 50 }), spacer)
      await flushMutations()

      expect(root.dataset.state).toBe("following-bottom")
      expect(metrics.scrollTop).toBe(700) // maxScrollTop, not the first anchor's line
    })

    it("an append with no anchor keeps following the end while pinned", async () => {
      const { root, content, spacer, metrics } = await mount({
        rows: [{ id: "m1", top: 0, height: 100 }]
      })
      metrics.scrollHeight = 600

      content.insertBefore(makeRow({ id: "m2", top: 100, height: 100 }), spacer)
      await flushMutations()

      expect(root.dataset.state).toBe("following-bottom")
      expect(metrics.scrollTop).toBe(400)
    })

    it("preserves scroll on prepend by re-adding the measured viewport-relative delta", async () => {
      const { root, content, rowElements, metrics } = await mount({
        values: { "auto-scroll": false, "default-scroll-position": "start" },
        rows: [
          { id: "m1", top: 0, height: 100 },
          { id: "m2", top: 100, height: 100 }
        ]
      })

      // History lands above; simulate an engine WITHOUT native scroll
      // anchoring (Safari): the old first row is pushed down 120px.
      content.insertBefore(makeRow({ id: "m0", top: -120, height: 120 }), rowElements[0])
      setRect(rowElements[0], { top: 120, height: 100 })
      await flushMutations()

      expect(metrics.scrollTop).toBe(120)
      expect(root.dataset.state).toBe("free-scrolling")
    })

    it("prepend restore is skipped when preserveScrollOnPrepend is false", async () => {
      const { content, rowElements, metrics } = await mount({
        values: {
          "auto-scroll": false,
          "default-scroll-position": "start",
          "preserve-scroll-on-prepend": false
        },
        rows: [
          { id: "m1", top: 0, height: 100 },
          { id: "m2", top: 100, height: 100 }
        ]
      })

      content.insertBefore(makeRow({ id: "m0", top: -120, height: 120 }), rowElements[0])
      setRect(rowElements[0], { top: 120, height: 100 })
      await flushMutations()

      expect(metrics.scrollTop).toBe(0)
    })
  })

  describe("commands", () => {
    it("scrollToMessage enters settling-jump; reconcile never arms over it; intent releases it", async () => {
      const { root, viewport, metrics, controller } = await mount({
        rows: [
          { id: "m1", top: 0, height: 100 },
          { id: "m2", top: 100, height: 100 }
        ],
        metrics: { scrollHeight: 600 }
      })

      expect(controller.scrollToMessage("m2")).toBe(true)
      expect(root.dataset.state).toBe("settling-jump")

      // At-bottom geometry would normally ARM following-bottom - not while a
      // jump is settling (intent detection and re-pinning suppressed).
      viewport.dispatchEvent(new Event("scroll"))
      expect(root.dataset.state).toBe("settling-jump")

      viewport.dispatchEvent(new Event("wheel"))
      expect(root.dataset.state).toBe("free-scrolling")
    })

    it("queues scrollToMessage to an unmounted row on an empty transcript and flushes on arrival", async () => {
      const { root, content, spacer, metrics, controller } = await mount({
        rows: [],
        metrics: { scrollHeight: 600 }
      })

      expect(controller.scrollToMessage("m9")).toBe(true) // queued

      content.insertBefore(makeRow({ id: "m9", top: 300, height: 50 }), spacer)
      await flushMutations()

      // Flushed jump (align start, no peek), NOT defaultScrollPosition end.
      expect(metrics.scrollTop).toBe(300)
      expect(root.dataset.state).toBe("settling-jump")
    })

    it("returns false for an unknown id once rows exist", async () => {
      const { controller } = await mount({ rows: [{ id: "m1", top: 0, height: 100 }] })

      expect(controller.scrollToMessage("nope")).toBe(false)
    })

    it("scrollToStart releases to free-scrolling with reason user-intent and resets the spacer", async () => {
      const { root, spacer, metrics, controller } = await mount({
        rows: [{ id: "m1", top: 0, height: 100 }],
        metrics: { scrollTop: 0, scrollHeight: 600 }
      })
      metrics.scrollTop = 400
      const events = recordEvents(root, "unpinned")

      controller.scrollToStart()

      expect(metrics.scrollTop).toBe(0)
      expect(root.dataset.state).toBe("free-scrolling")
      expect(spacer.hidden).toBe(true)
      expect(events).toEqual([{ name: "unpinned", detail: { reason: "user-intent" } }])
    })
  })

  describe("resize", () => {
    it("viewport resize re-pins while following-bottom (keyboard inset / orientation)", async () => {
      const { metrics } = await mount({
        rows: [{ id: "m1", top: 0, height: 100 }]
      })
      metrics.scrollHeight = 600

      const viewportResizeObserver = ResizeObserverStub.instances[0]
      viewportResizeObserver.callback()

      expect(metrics.scrollTop).toBe(400)
    })

    it("content growth re-anchors the streaming turn at the reading line", async () => {
      const { root, content, spacer, metrics } = await mount({
        values: { "auto-scroll": false },
        rows: [{ id: "m1", top: 0, height: 100 }]
      })
      metrics.scrollHeight = 600 // after mount, so the opening scrollToEnd stayed at 0

      const anchor = makeRow({ id: "m2", anchor: true, top: 100, height: 50 })
      content.insertBefore(anchor, spacer)
      await flushMutations()
      expect(root.dataset.state).toBe("anchored-to-message")
      expect(metrics.scrollTop).toBe(36)

      // The reply streams in below the turn: an in-place growth (no
      // childList) lands on the content ResizeObserver, not the mutation
      // observer. Instances: [viewport RO, content RO].
      setRect(anchor, { top: 100 - 36, height: 300 }) // grew; client top shifted by the scroll
      const contentResizeObserver = ResizeObserverStub.instances[1]
      contentResizeObserver.callback()

      // Re-placed: elementTop (64 + 36) - peek 64 = 36 -> holds the line.
      expect(root.dataset.state).toBe("anchored-to-message")
      expect(metrics.scrollTop).toBe(36)
    })
  })

  describe("scrollable state + button choreography", () => {
    it("mirrors data-scrollable on root and viewport and emits scrollable on change", async () => {
      const { root, viewport, rowElements, metrics } = await mount({
        values: { "auto-scroll": false, "default-scroll-position": "start" },
        rows: [{ id: "m1", top: 0, height: 100 }]
      })
      const events = recordEvents(root, "scrollable")

      metrics.scrollTop = 100
      setRect(rowElements[0], { top: 0, height: 500 })
      viewport.dispatchEvent(new Event("scroll"))

      expect(root.getAttribute("data-scrollable")).toBe("start end")
      expect(viewport.getAttribute("data-scrollable")).toBe("start end")

      metrics.scrollTop = 0
      setRect(rowElements[0], { top: 0, height: 100 })
      viewport.dispatchEvent(new Event("scroll"))

      expect(root.hasAttribute("data-scrollable")).toBe(false)
      expect(events).toEqual([
        { name: "scrollable", detail: { start: true, end: true } },
        { name: "scrollable", detail: { start: false, end: false } }
      ])
    })

    it("activates the end button on overflow; inactive means inert + untabbable", async () => {
      const { viewport, button, rowElements } = await mount({
        values: { "auto-scroll": false, "default-scroll-position": "start" },
        rows: [{ id: "m1", top: 0, height: 100 }]
      })

      expect(button.dataset.active).toBe("false")
      expect(button.hasAttribute("inert")).toBe(true)
      expect(button.getAttribute("tabindex")).toBe("-1")

      setRect(rowElements[0], { top: 0, height: 500 })
      viewport.dispatchEvent(new Event("scroll"))

      expect(button.dataset.active).toBe("true")
      expect(button.hasAttribute("inert")).toBe(false)
      expect(button.hasAttribute("tabindex")).toBe(false)
    })

    it("jump scrolls smoothly to the end, blurs the button, and no-ops while inactive", async () => {
      const { viewport, button, rowElements, metrics } = await mount({
        values: { "auto-scroll": false, "default-scroll-position": "start" },
        rows: [{ id: "m1", top: 0, height: 100 }]
      })
      button.blur = vi.fn()

      button.click() // inactive: nothing happens
      expect(metrics.lastScrollTo).toBeUndefined()

      setRect(rowElements[0], { top: 0, height: 500 })
      metrics.scrollHeight = 600
      viewport.dispatchEvent(new Event("scroll"))
      button.click()

      expect(button.blur).toHaveBeenCalled()
      expect(metrics.lastScrollTo).toEqual({ top: 400, behavior: "smooth" })
    })

    it("jump is instant under prefers-reduced-motion", async () => {
      const { viewport, button, rowElements, metrics } = await mount({
        values: { "auto-scroll": false, "default-scroll-position": "start" },
        rows: [{ id: "m1", top: 0, height: 100 }]
      })
      vi.stubGlobal("matchMedia", (query) => ({ matches: query.includes("reduce") }))

      setRect(rowElements[0], { top: 0, height: 500 })
      metrics.scrollHeight = 600
      viewport.dispatchEvent(new Event("scroll"))
      button.click()

      expect(metrics.lastScrollTo).toEqual({ top: 400, behavior: "auto" })
    })
  })

  describe("visibility tracking (opt-in)", () => {
    it("builds the reading-line IntersectionObserver and emits visibility snapshots", async () => {
      const { root, viewport, rowElements } = await mount({
        values: { "auto-scroll": false, "track-visibility": true },
        rows: [{ id: "m1", anchor: true, top: 0, height: 100 }]
      })
      const events = recordEvents(root, "visibility")

      const observer = IntersectionObserverStub.instances[0]
      expect(observer.options.root).toBe(viewport)
      expect(observer.options.rootMargin).toBe("-64px 0px 0px 0px") // -(margin 0 + peek 64)
      expect(observer.options.threshold).toEqual([0, 0.01, 0.5, 1])
      expect(observer.observed.has(rowElements[0])).toBe(true)

      observer.callback([{ target: rowElements[0], isIntersecting: true }])
      runFrame()

      expect(events.at(-1)).toEqual({
        name: "visibility",
        detail: { currentAnchorId: "m1", visibleMessageIds: ["m1"] }
      })
    })

    it("observes rows appended later and prunes removed ones", async () => {
      const { content, spacer, rowElements } = await mount({
        values: { "auto-scroll": false, "track-visibility": true },
        rows: [{ id: "m1", top: 0, height: 100 }]
      })
      const observer = IntersectionObserverStub.instances[0]

      const late = makeRow({ id: "m2", top: 100, height: 100 })
      content.insertBefore(late, spacer)
      await flushMutations()
      expect(observer.observed.has(late)).toBe(true)

      rowElements[0].remove()
      await flushMutations()
      expect(observer.observed.has(rowElements[0])).toBe(false)
    })
  })

  describe("disconnect teardown (Turbo cache / morph safety)", () => {
    it("cancels pending frames, clears the timeout, and disconnects every observer", async () => {
      const { root, viewport, content, spacer, metrics, controller } = await mount({
        values: { "track-visibility": true },
        rows: [{ id: "m1", top: 0, height: 100 }]
      })

      // Leave a state frame + the autoscrolling timeout in flight.
      metrics.scrollHeight = 600
      controller.scrollToEnd()
      expect(rafCallbacks.size).toBeGreaterThan(0)

      root.remove()
      await nextFrame()

      expect(rafCallbacks.size).toBe(0)
      expect(ResizeObserverStub.instances.every((observer) => observer.disconnected)).toBe(true)
      expect(IntersectionObserverStub.instances.every((observer) => observer.disconnected)).toBe(true)

      // The mutation observer is gone: appended rows change nothing.
      const events = recordEvents(root, "mode", "scrollable", "pinned", "unpinned")
      const stateBefore = root.dataset.state
      content.insertBefore(makeRow({ id: "m2", top: 100, height: 400 }), spacer)
      await flushMutations()
      viewport.dispatchEvent(new Event("scroll")) // listener removed too
      await new Promise((resolve) => setTimeout(resolve, 250)) // timeout cleared: no late commit

      expect(root.dataset.state).toBe(stateBefore)
      expect(events).toHaveLength(0)
    })
  })
})
