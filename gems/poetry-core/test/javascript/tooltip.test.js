import { beforeEach, describe, expect, it, vi } from "vitest"
import { Application } from "@hotwired/stimulus"
import { registerPoetryControllers } from "@poetry/controllers"

// poetry--core--tooltip JS-unit: the trio's timing machine - pointer rest
// opens after the provider delay (cold: data-open, no data-instant) or
// instantly (warm: data-open + data-instant="delay"); the trigger mirrors
// the bare data-popup-open; touch never opens; focus opens instantly
// (data-instant="focus") unless the pointerdown latch is set;
// leave/blur/activate/Esc/scroll close with the right reason; will-open
// closes the other open tooltip (one open page-wide); the warm registry
// counts opens and expires after skip_delay; describedby toggles open-only.
// Positioning (popper + arrow) is markup-owned - the browser pass's job.

const nextFrame = () => new Promise((resolve) => setTimeout(resolve, 0))

const el = (id) => document.getElementById(id)

// The Base UI pair + reason (contract §2): open is data-open with
// data-instant carrying the reason ("delay" | "focus") when the open was
// instant, absent when the open rode the delay; closed is data-closed with
// data-instant removed.
const expectOpen = (id, instant = null) => {
  expect(el(id).hasAttribute("data-open")).toBe(true)
  expect(el(id).hasAttribute("data-closed")).toBe(false)
  expect(el(id).getAttribute("data-instant")).toBe(instant)
}

const expectClosed = (id) => {
  expect(el(id).hasAttribute("data-closed")).toBe(true)
  expect(el(id).hasAttribute("data-open")).toBe(false)
  expect(el(id).hasAttribute("data-instant")).toBe(false)
}

const DISMISS_TOKEN = "poetry--core--dismissable"

const controllersOf = (id) => (el(id).getAttribute("data-controller") ?? "").split(/\s+/).filter(Boolean)

const pointer = (element, type, { pointerType = "mouse", related = null } = {}) => {
  const event = new MouseEvent(type, { bubbles: true, cancelable: true, relatedTarget: related })

  Object.defineProperty(event, "pointerType", { value: pointerType })
  element.dispatchEvent(event)
  return event
}

const pressEscape = () =>
  window.dispatchEvent(new KeyboardEvent("keydown", { key: "Escape", bubbles: true }))

const record = (type, target) => {
  const seen = []
  target.addEventListener(type, (event) => seen.push(event.detail))
  return seen
}

const tooltip = (key, { open = false, delayOverride = null } = {}) => `
  <div id="root-${key}" data-slot="tooltip" data-component="tooltip"
       data-controller="poetry--core--tooltip"
       data-poetry--core--tooltip-open-value="${open}"
       ${delayOverride === null ? "" : `data-poetry--core--tooltip-delay-duration-value="${delayOverride}"`}>
    <button type="button" id="${key}-trigger" data-slot="tooltip-trigger"
            ${open ? "data-popup-open" : ""}
            ${open ? `aria-describedby="${key}-content"` : ""}
            data-action="pointermove->poetry--core--tooltip#pointerMove pointerleave->poetry--core--tooltip#pointerLeave
                         pointerdown->poetry--core--tooltip#pointerDown click->poetry--core--tooltip#clickClose
                         focus->poetry--core--tooltip#focusOpen blur->poetry--core--tooltip#blurClose">
      Trigger ${key}
    </button>
    <div id="${key}-content" data-slot="tooltip-content" role="tooltip"
         ${open ? "data-open" : "data-closed hidden"}>
      Tooltip ${key}
    </div>
  </div>`

// Every test mounts under a fresh provider element so the module-level warm
// WeakMap (keyed by the provider) can never leak scope across tests.
const markup = ({ delay = 700, skip = 300, disableHoverable = false, tooltips = {} } = {}) => `
  <div id="provider" data-slot="tooltip-provider"
       data-delay-duration="${delay}" data-skip-delay-duration="${skip}"
       ${disableHoverable ? 'data-disable-hoverable-content="true"' : ""}>
    ${tooltip("a", tooltips.a ?? {})}
    ${tooltip("b", tooltips.b ?? {})}
  </div>`

describe("poetry--core--tooltip", () => {
  let application

  beforeEach(async () => {
    vi.useRealTimers()
    document.body.innerHTML = `<div id="host"></div>`
    application = Application.start()
    registerPoetryControllers(application)
    await nextFrame()
    return async () => {
      vi.useRealTimers()
      el("host")?.replaceChildren()
      await nextFrame()
      application.stop()
    }
  })

  async function mount(options = {}) {
    el("host").innerHTML = markup(options)
    await nextFrame()
  }

  describe("the pointer open path (cold scope)", () => {
    it("pointer rest opens after the provider delay (no data-instant), wiring describedby + the dismissable token", async () => {
      await mount()
      const opens = record("poetry:tooltip:open", el("root-a"))

      vi.useFakeTimers()
      pointer(el("a-trigger"), "pointermove")

      await vi.advanceTimersByTimeAsync(699)
      expectClosed("a-content")

      await vi.advanceTimersByTimeAsync(1)
      expectOpen("a-content")
      expect(el("a-trigger").hasAttribute("data-popup-open")).toBe(true)
      expect(el("a-content").hidden).toBe(false)
      expect(el("a-trigger").getAttribute("aria-describedby")).toBe("a-content")
      expect(controllersOf("a-content")).toContain(DISMISS_TOKEN)
      expect(opens).toEqual([{ state: "open", instant: null }])
    })

    it("delay 0 (the shadcn provider default) opens immediately", async () => {
      await mount({ delay: 0 })

      pointer(el("a-trigger"), "pointermove")

      expectOpen("a-content")
    })

    it("a per-tooltip delayDuration value overrides the provider", async () => {
      await mount({ delay: 700, tooltips: { a: { delayOverride: 100 } } })

      vi.useFakeTimers()
      pointer(el("a-trigger"), "pointermove")
      await vi.advanceTimersByTimeAsync(100)

      expectOpen("a-content")
    })

    it("touch pointerType NEVER opens (no long-press path either)", async () => {
      await mount({ delay: 0 })

      pointer(el("a-trigger"), "pointermove", { pointerType: "touch" })
      await nextFrame()

      expectClosed("a-content")
      expect(el("a-trigger").hasAttribute("aria-describedby")).toBe(false)
    })

    it("pointerleave before the delay elapses cancels the pending open", async () => {
      await mount()

      vi.useFakeTimers()
      pointer(el("a-trigger"), "pointermove")
      await vi.advanceTimersByTimeAsync(400)
      pointer(el("a-trigger"), "pointerleave")
      await vi.advanceTimersByTimeAsync(1000)

      expectClosed("a-content")
    })
  })

  describe("the warm scope (the provider mechanism)", () => {
    it("a sibling opens INSTANTLY while another tooltip in the scope is open, and the first closes as superseded", async () => {
      await mount({ delay: 700 })
      const closes = record("poetry:tooltip:closed", el("root-a"))

      vi.useFakeTimers()
      pointer(el("a-trigger"), "pointermove")
      await vi.advanceTimersByTimeAsync(700)
      expectOpen("a-content")

      pointer(el("b-trigger"), "pointermove")
      await vi.advanceTimersByTimeAsync(0)

      expectOpen("b-content", "delay")
      expectClosed("a-content")
      expect(closes).toEqual([{ reason: "sibling-open" }])
    })

    it("the warm window survives a close for skip_delay ms, then the scope is cold again", async () => {
      await mount({ delay: 700, skip: 300, disableHoverable: true })

      vi.useFakeTimers()
      pointer(el("a-trigger"), "pointermove")
      await vi.advanceTimersByTimeAsync(700)
      pointer(el("a-trigger"), "pointerleave")
      await vi.advanceTimersByTimeAsync(0)
      expectClosed("a-content")

      // 100ms after the close: still warm - the sweep is instant.
      await vi.advanceTimersByTimeAsync(100)
      pointer(el("b-trigger"), "pointermove")
      expectOpen("b-content", "delay")

      pointer(el("b-trigger"), "pointerleave")
      await vi.advanceTimersByTimeAsync(0)

      // 301ms after the LAST close: the warm window expired - cold again.
      await vi.advanceTimersByTimeAsync(301)
      pointer(el("a-trigger"), "pointermove")
      expectClosed("a-content") // delay pending

      await vi.advanceTimersByTimeAsync(700)
      expectOpen("a-content")
    })
  })

  describe("the keyboard path", () => {
    it("focus opens instantly with data-instant=focus; blur closes with reason trigger-focus", async () => {
      await mount({ delay: 700 })
      const closes = record("poetry:tooltip:closed", el("root-a"))

      el("a-trigger").focus()
      await nextFrame()

      expectOpen("a-content", "focus")
      expect(el("a-trigger").getAttribute("aria-describedby")).toBe("a-content")

      el("a-trigger").blur()
      await nextFrame()

      expectClosed("a-content")
      expect(el("a-trigger").hasAttribute("aria-describedby")).toBe(false)
      expect(closes).toEqual([{ reason: "trigger-focus" }])
    })

    it("focus caused by pointerdown does NOT open (the isPointerDown latch)", async () => {
      await mount({ delay: 0 })

      pointer(el("a-trigger"), "pointerdown")
      el("a-trigger").focus()
      await nextFrame()

      expectClosed("a-content")

      // After pointerup the latch clears - a later real focus opens.
      pointer(document.body, "pointerup")
      el("a-trigger").blur()
      el("a-trigger").focus()
      await nextFrame()

      expectOpen("a-content", "focus")
    })
  })

  describe("close paths", () => {
    it("activating the trigger closes (pointerdown -> reason trigger-press)", async () => {
      await mount({ delay: 0 })
      const closes = record("poetry:tooltip:closed", el("root-a"))

      pointer(el("a-trigger"), "pointermove")
      expectOpen("a-content")

      pointer(el("a-trigger"), "pointerdown")
      await nextFrame()

      expectClosed("a-content")
      expect(closes).toEqual([{ reason: "trigger-press" }])
    })

    it("Esc closes via the token-activated dismissable layer (reason escape-key) and removes the token", async () => {
      await mount({ delay: 0 })
      const closes = record("poetry:tooltip:closed", el("root-a"))

      pointer(el("a-trigger"), "pointermove")
      await nextFrame() // the layer controller connects

      pressEscape()
      await nextFrame()

      expectClosed("a-content")
      expect(el("a-content").hidden).toBe(true)
      expect(controllersOf("a-content")).toEqual([])
      expect(closes).toEqual([{ reason: "escape-key" }])
    })

    it("scrolling an ancestor of the trigger closes (reason scroll), and the listener is dropped after close", async () => {
      await mount({ delay: 0 })
      const closes = record("poetry:tooltip:closed", el("root-a"))

      pointer(el("a-trigger"), "pointermove")
      await nextFrame()

      document.dispatchEvent(new Event("scroll", { bubbles: true }))
      await nextFrame()

      expect(closes).toEqual([{ reason: "scroll" }])

      document.dispatchEvent(new Event("scroll", { bubbles: true }))
      await nextFrame()

      expect(closes.length).toBe(1) // dropped listener: no double close
    })
  })

  describe("hoverable content (the close-intent grace)", () => {
    it("leaving the trigger arms a grace timer; entering the content cancels it; leaving the content closes", async () => {
      await mount({ delay: 0 })
      const closes = record("poetry:tooltip:closed", el("root-a"))

      pointer(el("a-trigger"), "pointermove")

      vi.useFakeTimers()
      pointer(el("a-trigger"), "pointerleave")
      await vi.advanceTimersByTimeAsync(299)
      expectOpen("a-content")

      pointer(el("a-content"), "pointerenter") // travel INTO the content: cancel
      await vi.advanceTimersByTimeAsync(1000)
      expectOpen("a-content")

      pointer(el("a-content"), "pointerleave")
      await vi.advanceTimersByTimeAsync(300)

      expectClosed("a-content")
      expect(closes).toEqual([{ reason: "trigger-hover" }])
    })

    it("disable-hoverable-content on the provider closes on trigger-leave immediately", async () => {
      await mount({ delay: 0, disableHoverable: true })

      pointer(el("a-trigger"), "pointermove")
      pointer(el("a-trigger"), "pointerleave")
      await nextFrame()

      expectClosed("a-content")
    })
  })

  describe("controllable state + reconcile-on-connect", () => {
    it("a server-rendered pinned tooltip activates describedby + the layer + the warm scope on connect", async () => {
      await mount({ delay: 700, tooltips: { a: { open: true } } })

      expect(controllersOf("a-content")).toContain(DISMISS_TOKEN)
      expect(el("a-trigger").getAttribute("aria-describedby")).toBe("a-content")

      // The pinned tooltip counts toward the scope: a sibling opens warm.
      pointer(el("b-trigger"), "pointermove")
      expectOpen("b-content", "delay")
    })

    it("flipping the open value drives the machine (pinned open/close, reason none)", async () => {
      await mount()
      const closes = record("poetry:tooltip:closed", el("root-a"))

      el("root-a").setAttribute("data-poetry--core--tooltip-open-value", "true")
      await nextFrame()

      expectOpen("a-content", "delay") // programmatic opens skip the delay

      el("root-a").setAttribute("data-poetry--core--tooltip-open-value", "false")
      await nextFrame()

      expectClosed("a-content")
      expect(closes).toEqual([{ reason: "none" }])
    })
  })

  describe("portal-on-open (docs/portal-on-open.md S1)", () => {
    it("open portals the content to body + flips popper to absolute; close restores both", async () => {
      await mount({ delay: 0 })

      pointer(el("a-trigger"), "pointermove")

      expectOpen("a-content")
      expect(el("a-content").parentNode).toBe(document.body)
      expect(el("root-a").getAttribute("data-poetry--core--popper-strategy-value")).toBe("absolute")
      // the id pair keeps resolving across the move - describedby is live
      expect(el("a-trigger").getAttribute("aria-describedby")).toBe("a-content")

      pointer(el("a-trigger"), "pointerdown") // activate-dismisses, closes immediately
      await nextFrame()

      expectClosed("a-content")
      expect(el("a-content").parentNode).toBe(el("root-a"))
      expect(el("root-a").getAttribute("data-poetry--core--popper-strategy-value")).toBe("fixed")
    })

    it("a server-pinned open tooltip portals one frame after connect (the popper cache order)", async () => {
      await mount({ tooltips: { a: { open: true } } })

      // (the deferral itself is a rAF - too fast to assert against
      // jsdom's 16ms rAF timer without flaking; the OUTCOME is the pin)
      await new Promise((resolve) => setTimeout(resolve, 40))

      expect(el("a-content").parentNode).toBe(document.body)
      expect(el("root-a").getAttribute("data-poetry--core--popper-strategy-value")).toBe("absolute")
    })

    it("disconnecting an open tooltip never strands content at body (drop-never-strand)", async () => {
      await mount({ delay: 0 })

      pointer(el("a-trigger"), "pointermove")
      expect(el("a-content").parentNode).toBe(document.body)

      el("host").replaceChildren() // the whole component subtree goes away
      await nextFrame()

      expect(document.getElementById("a-content")).toBe(null)
    })
  })
})
