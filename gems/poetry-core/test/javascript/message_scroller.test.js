import { afterEach, beforeEach, describe, expect, it, vi } from "vitest"
import { Application } from "@hotwired/stimulus"
import { registerPoetryControllers } from "@poetry/controllers"

// The mode machine + event contract, driven with STUBBED geometry (rects,
// scrollTop, clientHeight, scrollTo) - jsdom computes no layout, so REAL
// pinning/anchoring behavior (native scroll anchoring, smooth-scroll
// settling, IntersectionObserver firing) is the browser-verification
// suite's job, never faked here. What this file CAN prove: transitions,
// data-mode/data-scrollable mirroring, event dispatch, value defaults,
// user-intent release, the 180ms autoscrolling suppression, branch order,
// and disconnect teardown.

const ID = "poetry--core--message-scroller"
const EVENTS = "poetry:message-scroller" // the component-facing event namespace

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

async function mount({ values = {}, rows = [], metrics = {}, hold = false } = {}) {
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
  // The server renders the opening-position hold on root + viewport.
  if (hold) {
    root.setAttribute("data-pending-scroll", "")
    viewport.setAttribute("data-pending-scroll", "")
  }
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
    root.addEventListener(`${EVENTS}:${name}`, (event) => seen.push({ name, detail: event.detail }))
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

    it("mirrors the initial mode to data-mode (following-bottom under autoScroll)", async () => {
      const { root } = await mount()
      expect(root.dataset.mode).toBe("following-bottom")
    })

    it("starts free-scrolling when autoScroll is off", async () => {
      const { root } = await mount({ values: { "auto-scroll": false } })
      expect(root.dataset.mode).toBe("free-scrolling")
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
      expect(root.dataset.mode).toBe("free-scrolling")
    })
  })

  describe("follow-bottom arm / release (reconcile)", () => {
    // Settled at the end of a long transcript (the last commit saw scrollTop 400).
    function settleAtEnd({ viewport, rowElements, metrics }) {
      Object.assign(metrics, { scrollHeight: 600, scrollTop: 400 })
      setRect(rowElements[1], { top: -300, height: 500 })
      viewport.dispatchEvent(new Event("scroll"))
    }

    // A scrollbar drag up: scrollTop drops, the row (content y 100..600) moves
    // down with it, and only a scroll event fires (no wheel, touch or key).
    function dragUp({ viewport, rowElements, metrics }, to = 100) {
      metrics.scrollTop = to
      setRect(rowElements[1], { top: 100 - to, height: 500 })
      viewport.dispatchEvent(new Event("scroll"))
    }

    it("releases to free-scrolling on scroll away, with an unpinned scroll-away reason", async () => {
      const mounted = await mount({
        rows: [{ id: "m1", top: 0, height: 100 }, { id: "m2", top: 100, height: 100 }]
      })
      const { root } = mounted
      settleAtEnd(mounted)
      const events = recordEvents(root, "mode", "unpinned")

      dragUp(mounted)

      expect(root.dataset.mode).toBe("free-scrolling")
      expect(events).toContainEqual({
        name: "mode",
        detail: { from: "following-bottom", to: "free-scrolling", mode: "free-scrolling" }
      })
      expect(events).toContainEqual({ name: "unpinned", detail: { reason: "scroll-away" } })
    })

    it("re-arms (pinned) when the viewport reaches the bottom again, however it got there", async () => {
      const mounted = await mount({
        rows: [{ id: "m1", top: 0, height: 100 }, { id: "m2", top: 100, height: 100 }]
      })
      const { root } = mounted
      settleAtEnd(mounted)
      dragUp(mounted)
      expect(root.dataset.mode).toBe("free-scrolling")

      const events = recordEvents(root, "pinned")
      dragUp(mounted, 400)

      expect(root.dataset.mode).toBe("following-bottom")
      expect(events).toHaveLength(1)
    })

    // A transient layout (a full-page capture, a print pass) drops the
    // overflow: the browser clamps scrollTop to 0 while the last row still
    // measures below the fold (what Chrome reports mid-capture).
    function collapse({ rowElements, metrics }) {
      Object.assign(metrics, { scrollHeight: 200, scrollTop: 0 })
      setRect(rowElements[1], { top: 100, height: 500 })
    }

    // The layout comes back with the content below; scrollTop stays clamped.
    function restore({ rowElements, metrics }) {
      metrics.scrollHeight = 600
      setRect(rowElements[1], { top: 100, height: 500 })
    }

    it("a clamp seen by a commit inside the collapsed layout never releases", async () => {
      const mounted = await mount({
        rows: [{ id: "m1", top: 0, height: 100 }, { id: "m2", top: 100, height: 100 }]
      })
      const { root, viewport, metrics } = mounted
      const [viewportResizeObserver] = ResizeObserverStub.instances
      settleAtEnd(mounted)
      const events = recordEvents(root, "unpinned")

      // A commit runs inside the collapsed layout: a move up with content
      // below, but the viewport sits at the end of its own scroll range.
      collapse(mounted)
      viewport.dispatchEvent(new Event("scroll"))
      expect(root.dataset.mode).toBe("following-bottom")

      restore(mounted)
      viewport.dispatchEvent(new Event("scroll"))
      viewportResizeObserver.callback()
      runFrame()

      expect(events).toHaveLength(0)
      expect(metrics.scrollTop).toBe(400)
    })

    it("the clamp's scroll event after the layout returns never releases", async () => {
      const mounted = await mount({
        rows: [{ id: "m1", top: 0, height: 100 }, { id: "m2", top: 100, height: 100 }]
      })
      const { root, viewport, metrics } = mounted
      const [viewportResizeObserver] = ResizeObserverStub.instances
      settleAtEnd(mounted)
      const events = recordEvents(root, "unpinned")

      // The observer delivers right after the collapsed layout and defers its
      // pass to the next frame; the clamp's scroll event comes first, with the
      // layout already back and the range open again.
      collapse(mounted)
      viewportResizeObserver.callback()
      restore(mounted)
      viewport.dispatchEvent(new Event("scroll"))

      expect(root.dataset.mode).toBe("following-bottom")
      expect(events).toHaveLength(0)

      runFrame()
      expect(metrics.scrollTop).toBe(400)
    })

    it("suppresses the release while autoscrolling; the 180ms clear alone never releases", async () => {
      const mounted = await mount({
        rows: [{ id: "m1", top: 0, height: 100 }, { id: "m2", top: 100, height: 100 }]
      })
      const { root, viewport, rowElements, metrics, controller } = mounted
      settleAtEnd(mounted)
      const events = recordEvents(root, "unpinned")

      // Content grows; a programmatic follow move starts (sets the flag).
      metrics.scrollHeight = 800
      setRect(rowElements[1], { top: -300, height: 700 })
      controller.scrollToEnd()

      expect(root.hasAttribute("data-autoscrolling")).toBe(true)

      // Mid-animation a frame reads scrollTop up and the content still below
      // (the content shifting under the move): not the reader's, no release.
      metrics.scrollTop = 300
      setRect(rowElements[1], { top: -200, height: 700 })
      viewport.dispatchEvent(new Event("scroll"))
      expect(root.dataset.mode).toBe("following-bottom")
      expect(events).toHaveLength(0)

      // 180ms after the move the flag clears. The reader has not moved since,
      // so the clear's own commit keeps following.
      await new Promise((resolve) => setTimeout(resolve, 250))
      expect(root.hasAttribute("data-autoscrolling")).toBe(false)
      expect(root.dataset.mode).toBe("following-bottom")

      // A drag up after the clear releases.
      metrics.scrollTop = 100
      setRect(rowElements[1], { top: 0, height: 700 })
      viewport.dispatchEvent(new Event("scroll"))
      expect(root.dataset.mode).toBe("free-scrolling")
      expect(events).toEqual([{ name: "unpinned", detail: { reason: "scroll-away" } }])
    })

    it("content growth a commit sees before the resize handler keeps following", async () => {
      const mounted = await mount({
        rows: [{ id: "m1", top: 0, height: 100 }, { id: "m2", top: 100, height: 100 }]
      })
      const { root, viewport, button, rowElements, metrics } = mounted
      settleAtEnd(mounted)

      // A streamed chunk grows the last row past the live edge; a scroll event
      // commits before the frame-coalesced resize pass has followed. The
      // reader did not move: no release, and the gap is not published (that
      // would strobe the scroll button once per chunk).
      metrics.scrollHeight = 760
      setRect(rowElements[1], { top: -300, height: 660 })
      viewport.dispatchEvent(new Event("scroll"))
      expect(root.dataset.mode).toBe("following-bottom")
      expect(root.getAttribute("data-scrollable") ?? "").not.toContain("end")
      expect(button.dataset.active).toBe("false")

      ResizeObserverStub.instances[1].callback()
      runFrame()
      expect(metrics.scrollTop).toBe(560)
      expect(root.getAttribute("data-scrollable") ?? "").not.toContain("end")
    })

    it("a release still publishes the gap it released over", async () => {
      const mounted = await mount({
        rows: [{ id: "m1", top: 0, height: 100 }, { id: "m2", top: 100, height: 100 }]
      })
      const { root, button } = mounted
      settleAtEnd(mounted)
      const events = recordEvents(root, "scrollable")

      dragUp(mounted)

      expect(root.dataset.mode).toBe("free-scrolling")
      expect(root.getAttribute("data-scrollable")).toContain("end")
      expect(button.dataset.active).toBe("true")
      expect(events.at(-1).detail.end).toBe(true)
    })
  })

  describe("user intent", () => {
    it("wheel releases follow-bottom with reason user-intent", async () => {
      const { root, viewport } = await mount({
        rows: [{ id: "m1", top: 0, height: 100 }]
      })
      const events = recordEvents(root, "unpinned")

      viewport.dispatchEvent(new Event("wheel"))

      expect(root.dataset.mode).toBe("free-scrolling")
      expect(events).toEqual([{ name: "unpinned", detail: { reason: "user-intent" } }])
    })

    it("touchmove releases follow-bottom", async () => {
      const { root, viewport } = await mount({ rows: [{ id: "m1", top: 0, height: 100 }] })

      viewport.dispatchEvent(new Event("touchmove"))

      expect(root.dataset.mode).toBe("free-scrolling")
    })

    it("only USER_SCROLL_KEYS count as keyboard intent", async () => {
      const { root, viewport } = await mount({ rows: [{ id: "m1", top: 0, height: 100 }] })

      viewport.dispatchEvent(new KeyboardEvent("keydown", { key: "a" }))
      expect(root.dataset.mode).toBe("following-bottom")

      viewport.dispatchEvent(new KeyboardEvent("keydown", { key: "PageDown" }))
      expect(root.dataset.mode).toBe("free-scrolling")
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
      expect(root.dataset.mode).toBe("anchored-to-message")
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

      expect(root.dataset.mode).toBe("following-bottom")
      expect(metrics.scrollTop).toBe(700) // maxScrollTop, not the first anchor's line
    })

    it("an append with no anchor keeps following the end while pinned", async () => {
      const { root, content, spacer, metrics } = await mount({
        rows: [{ id: "m1", top: 0, height: 100 }]
      })
      metrics.scrollHeight = 600

      content.insertBefore(makeRow({ id: "m2", top: 100, height: 100 }), spacer)
      await flushMutations()

      expect(root.dataset.mode).toBe("following-bottom")
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
      expect(root.dataset.mode).toBe("free-scrolling")
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
      expect(root.dataset.mode).toBe("settling-jump")

      // At-bottom geometry would normally ARM following-bottom - not while a
      // jump is settling (intent detection and re-pinning suppressed).
      viewport.dispatchEvent(new Event("scroll"))
      expect(root.dataset.mode).toBe("settling-jump")

      viewport.dispatchEvent(new Event("wheel"))
      expect(root.dataset.mode).toBe("free-scrolling")
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
      expect(root.dataset.mode).toBe("settling-jump")
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
      expect(root.dataset.mode).toBe("free-scrolling")
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
      expect(metrics.scrollTop).toBe(0) // coalesced: nothing moves until the frame

      runFrame()
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
      expect(root.dataset.mode).toBe("anchored-to-message")
      expect(metrics.scrollTop).toBe(36)

      // The reply streams in below the turn: an in-place growth (no
      // childList) lands on the content ResizeObserver, not the mutation
      // observer. Instances: [viewport RO, content RO].
      setRect(anchor, { top: 100 - 36, height: 300 }) // grew; client top shifted by the scroll
      const contentResizeObserver = ResizeObserverStub.instances[1]
      contentResizeObserver.callback()
      runFrame()

      // Re-placed: elementTop (64 + 36) - peek 64 = 36 -> holds the line.
      expect(root.dataset.mode).toBe("anchored-to-message")
      expect(metrics.scrollTop).toBe(36)
    })

    it("coalesces both observers onto one frame, and disconnect cancels a pending pass", async () => {
      const { root, viewport, metrics } = await mount({
        rows: [{ id: "m1", top: 0, height: 100 }]
      })
      const moves = []
      const scrollTo = viewport.scrollTo
      viewport.scrollTo = (options) => { moves.push(options); scrollTo(options) }
      const [viewportResizeObserver, contentResizeObserver] = ResizeObserverStub.instances

      metrics.scrollHeight = 600
      viewportResizeObserver.callback()
      contentResizeObserver.callback()
      expect(metrics.scrollTop).toBe(0)

      runFrame()
      expect(metrics.scrollTop).toBe(400)
      expect(moves).toHaveLength(1)

      metrics.scrollHeight = 800
      viewportResizeObserver.callback()
      root.remove()
      await nextFrame()

      expect(rafCallbacks.size).toBe(0)
      runFrame()
      expect(metrics.scrollTop).toBe(400)
    })

    it("hands off from the anchor hold to following once the streamed reply fills the viewport", async () => {
      const { root, content, spacer, rowElements, metrics } = await mount({
        rows: [{ id: "m1", top: 0, height: 100 }]
      })
      const [, contentResizeObserver] = ResizeObserverStub.instances
      metrics.scrollHeight = 600 // after mount, so the opening scrollToEnd stayed at 0

      // The submitted turn anchors at the reading line with tail spacer room
      // below for the reply to stream into.
      const anchor = makeRow({ id: "m2", anchor: true, top: 100, height: 50 })
      content.insertBefore(anchor, spacer)
      await flushMutations()
      expect(metrics.scrollTop).toBe(36)
      expect(spacer.style.height).toBe("86px")
      setRect(rowElements[0], { top: -36, height: 100 })
      setRect(anchor, { top: 64, height: 50 })

      // The spacer makes the turn read as "at the end"; the pending commit
      // must not re-arm following over the hold.
      runFrame()
      expect(root.dataset.mode).toBe("anchored-to-message")

      // While the reply still fits in the spacer room the anchor holds.
      setRect(anchor, { top: 64, height: 100 })
      contentResizeObserver.callback()
      runFrame()
      expect(metrics.scrollTop).toBe(36)
      expect(spacer.style.height).toBe("36px")
      expect(root.dataset.mode).toBe("anchored-to-message")

      // Growth past the spacer: the reply has filled the viewport and the
      // reader is at the live edge, so autoScroll takes over from the anchor.
      setRect(anchor, { top: 64, height: 300 })
      metrics.scrollHeight = 400
      contentResizeObserver.callback()
      runFrame()
      expect(metrics.scrollTop).toBe(200)
      expect(root.dataset.mode).toBe("following-bottom")

      // Following stays engaged for the rest of the stream.
      setRect(anchor, { top: -100, height: 400 })
      metrics.scrollHeight = 500
      contentResizeObserver.callback()
      runFrame()
      expect(metrics.scrollTop).toBe(300)
      expect(root.getAttribute("data-scrollable") ?? "").not.toContain("end")
    })

    it("a turn taller than the viewport, placed with no spacer, stays held as it grows", async () => {
      const { root, content, spacer, rowElements, metrics } = await mount({
        rows: [{ id: "m1", top: 0, height: 100 }]
      })
      const [, contentResizeObserver] = ResizeObserverStub.instances
      metrics.scrollHeight = 600

      const anchor = makeRow({ id: "m2", anchor: true, top: 100, height: 300 })
      content.insertBefore(anchor, spacer)
      await flushMutations()
      expect(metrics.scrollTop).toBe(36)
      expect(spacer.hidden).toBe(true)
      setRect(rowElements[0], { top: -36, height: 100 })
      setRect(anchor, { top: 64, height: 300 })

      setRect(anchor, { top: 64, height: 500 })
      contentResizeObserver.callback()
      runFrame()

      expect(metrics.scrollTop).toBe(36)
      expect(root.dataset.mode).toBe("anchored-to-message")
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

  describe("the opening-position hold (data-pending-scroll)", () => {
    const held = (element) => element.hasAttribute("data-pending-scroll")

    it("releases the server-rendered hold on root and viewport once the opening position applies", async () => {
      const { root, viewport, metrics } = await mount({
        hold: true,
        rows: [{ id: "m1", top: 0, height: 100 }, { id: "m2", top: 100, height: 100 }],
        metrics: { scrollHeight: 600 }
      })

      expect(metrics.scrollTop).toBe(400)
      expect(held(root)).toBe(false)
      expect(held(viewport)).toBe(false)
    })

    it("last-anchor releases through the anchor branch", async () => {
      const { root, viewport } = await mount({
        hold: true,
        values: { "default-scroll-position": "last-anchor" },
        rows: [{ id: "m1", top: 0, height: 100 }, { id: "m2", anchor: true, top: 100, height: 400 }],
        metrics: { scrollHeight: 500 }
      })

      expect(held(root)).toBe(false)
      expect(held(viewport)).toBe(false)
    })

    it("an empty transcript has nothing to scroll: the hold releases at mount", async () => {
      const { root, viewport } = await mount({ hold: true, rows: [] })

      expect(held(root)).toBe(false)
      expect(held(viewport)).toBe(false)
    })

    it("start opens where the browser does: a stray hold is cleared", async () => {
      const { root, viewport } = await mount({
        hold: true,
        values: { "auto-scroll": false, "default-scroll-position": "start" },
        rows: [{ id: "m1", top: 0, height: 100 }]
      })

      expect(held(root)).toBe(false)
      expect(held(viewport)).toBe(false)
    })

    it("a morph re-stamping the attribute after the position applied is stripped", async () => {
      const { root, viewport } = await mount({ hold: true, rows: [{ id: "m1", top: 0, height: 100 }] })

      root.setAttribute("data-pending-scroll", "")
      viewport.setAttribute("data-pending-scroll", "")
      await flushMutations()

      expect(held(root)).toBe(false)
      expect(held(viewport)).toBe(false)
    })

    it("a live value change re-applies the position without hiding the viewport again", async () => {
      const { root, viewport } = await mount({
        hold: true,
        rows: [{ id: "m1", top: 0, height: 100 }],
        metrics: { scrollHeight: 600 }
      })

      root.setAttribute(`data-${ID}-default-scroll-position-value`, "start")
      await nextFrame()

      expect(held(root)).toBe(false)
      expect(held(viewport)).toBe(false)
    })

    it("turbo:before-cache re-arms the hold so a restored snapshot never paints the top of the thread", async () => {
      const { root, viewport } = await mount({ rows: [{ id: "m1", top: 0, height: 100 }] })

      document.dispatchEvent(new Event("turbo:before-cache"))

      expect(held(root)).toBe(true)
      expect(held(viewport)).toBe(true)
    })

    it("before-cache holds nothing for start", async () => {
      const { root, viewport } = await mount({
        values: { "auto-scroll": false, "default-scroll-position": "start" },
        rows: [{ id: "m1", top: 0, height: 100 }]
      })

      document.dispatchEvent(new Event("turbo:before-cache"))

      expect(held(root)).toBe(false)
      expect(held(viewport)).toBe(false)
    })

    it("disconnect drops the before-cache subscription", async () => {
      const { root, viewport } = await mount({ rows: [{ id: "m1", top: 0, height: 100 }] })

      root.remove()
      await nextFrame()
      document.dispatchEvent(new Event("turbo:before-cache"))

      expect(held(root)).toBe(false)
      expect(held(viewport)).toBe(false)
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
      const stateBefore = root.dataset.mode
      content.insertBefore(makeRow({ id: "m2", top: 100, height: 400 }), spacer)
      await flushMutations()
      viewport.dispatchEvent(new Event("scroll")) // listener removed too
      await new Promise((resolve) => setTimeout(resolve, 250)) // timeout cleared: no late commit

      expect(root.dataset.mode).toBe(stateBefore)
      expect(events).toHaveLength(0)
    })
  })
})
