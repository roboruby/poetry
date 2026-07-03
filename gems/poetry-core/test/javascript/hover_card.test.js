import { beforeEach, describe, expect, it, vi } from "vitest"
import { Application } from "@hotwired/stimulus"
import { registerPoetryControllers } from "@poetry/controllers"

// poetry--core--hover-card JS-unit: the trio's thinnest machine -
// pointerenter arms open_delay / opens; touch pointerType no-ops and
// touchstart preventDefaults (the double-guard); focus opens immediately /
// blur closes; pair-leave arms close_delay and re-enter cancels; the
// selection hold defers the pointer-leave close but never Esc/outside; the
// tabindex strip runs per-open and catches streamed-in tabbables; timers
// and the body user-select suppression are cleared on disconnect. NO aria
// is ever added (the card is invisible to AT on purpose). Positioning is
// popper's; real drag-copy is the browser pass's job.

const nextFrame = () => new Promise((resolve) => setTimeout(resolve, 0))

const el = (id) => document.getElementById(id)

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

const markup = ({ open = false, openDelay = 700, closeDelay = 300 } = {}) => `
  <div id="root" data-slot="hover-card" data-component="hover-card"
       data-controller="poetry--core--hover-card"
       data-poetry--core--hover-card-open-value="${open}"
       data-poetry--core--hover-card-open-delay-value="${openDelay}"
       data-poetry--core--hover-card-close-delay-value="${closeDelay}">
    <a id="hc-trigger" data-slot="hover-card-trigger" href="/users/nextjs"
       data-state="${open ? "open" : "closed"}"
       data-action="pointerenter->poetry--core--hover-card#pointerEnter pointerleave->poetry--core--hover-card#pointerLeave
                    focus->poetry--core--hover-card#focusOpen blur->poetry--core--hover-card#blurClose
                    touchstart->poetry--core--hover-card#touchGuard">@nextjs</a>
    <div id="hc-content" data-slot="hover-card-content"
         data-state="${open ? "open" : "closed"}" ${open ? "" : "hidden"}>
      <a id="inside-link" href="/users/nextjs">full profile</a>
      <button id="inside-button" type="button">follow</button>
      The React framework.
    </div>
  </div>`

describe("poetry--core--hover-card", () => {
  let application

  beforeEach(async () => {
    vi.useRealTimers()
    vi.restoreAllMocks()
    document.body.innerHTML = `<button id="outside">outside</button><div id="host"></div>`
    application = Application.start()
    registerPoetryControllers(application)
    await nextFrame()
    return async () => {
      vi.useRealTimers()
      vi.restoreAllMocks()
      el("host")?.replaceChildren()
      await nextFrame()
      application.stop()
    }
  })

  async function mount(options = {}) {
    el("host").innerHTML = markup(options)
    await nextFrame()
  }

  describe("the pointer path (700/300 Radix defaults)", () => {
    it("pointerenter opens after open_delay: data-state, the dismissable token, the strip, poetry:hover-card:open", async () => {
      await mount()
      const opens = record("poetry:hover-card:open", el("root"))

      vi.useFakeTimers()
      pointer(el("hc-trigger"), "pointerenter")

      await vi.advanceTimersByTimeAsync(699)
      expect(el("hc-content").dataset.state).toBe("closed")

      await vi.advanceTimersByTimeAsync(1)
      expect(el("hc-content").dataset.state).toBe("open")
      expect(el("hc-trigger").dataset.state).toBe("open")
      expect(el("hc-content").hidden).toBe(false)
      expect(controllersOf("hc-content")).toContain(DISMISS_TOKEN)
      expect(el("inside-link").getAttribute("tabindex")).toBe("-1")
      expect(el("inside-button").getAttribute("tabindex")).toBe("-1")
      expect(opens.length).toBe(1)
    })

    it("pair-leave closes after close_delay; re-entering the content cancels the close", async () => {
      await mount()
      const closes = record("poetry:hover-card:closed", el("root"))

      vi.useFakeTimers()
      pointer(el("hc-trigger"), "pointerenter")
      await vi.advanceTimersByTimeAsync(700)

      pointer(el("hc-trigger"), "pointerleave")
      await vi.advanceTimersByTimeAsync(299)
      expect(el("hc-content").dataset.state).toBe("open")

      pointer(el("hc-content"), "pointerenter") // travel into the card: cancel
      await vi.advanceTimersByTimeAsync(1000)
      expect(el("hc-content").dataset.state).toBe("open")

      pointer(el("hc-content"), "pointerleave")
      await vi.advanceTimersByTimeAsync(300)

      expect(el("hc-content").dataset.state).toBe("closed")
      expect(el("hc-content").hidden).toBe(true)
      expect(controllersOf("hc-content")).toEqual([])
      expect(closes).toEqual([{ reason: "leave" }])
    })

    it("pointerleave before open_delay elapses cancels the pending open", async () => {
      await mount()

      vi.useFakeTimers()
      pointer(el("hc-trigger"), "pointerenter")
      await vi.advanceTimersByTimeAsync(400)
      pointer(el("hc-trigger"), "pointerleave")
      await vi.advanceTimersByTimeAsync(2000)

      expect(el("hc-content").dataset.state).toBe("closed")
    })

    it("open_delay / close_delay are Values", async () => {
      await mount({ openDelay: 100, closeDelay: 50 })

      vi.useFakeTimers()
      pointer(el("hc-trigger"), "pointerenter")
      await vi.advanceTimersByTimeAsync(100)
      expect(el("hc-content").dataset.state).toBe("open")

      pointer(el("hc-trigger"), "pointerleave")
      await vi.advanceTimersByTimeAsync(50)
      expect(el("hc-content").dataset.state).toBe("closed")
    })
  })

  describe("the touch double-guard", () => {
    it("touch pointerenter never arms the open timer", async () => {
      await mount()

      vi.useFakeTimers()
      pointer(el("hc-trigger"), "pointerenter", { pointerType: "touch" })
      await vi.advanceTimersByTimeAsync(2000)

      expect(el("hc-content").dataset.state).toBe("closed")
    })

    it("touchstart is preventDefaulted (no synthetic focus-open; the tap navigates the link)", async () => {
      await mount()

      const event = new Event("touchstart", { bubbles: true, cancelable: true })

      el("hc-trigger").dispatchEvent(event)

      expect(event.defaultPrevented).toBe(true)
    })
  })

  describe("the focus mirror", () => {
    it("trigger focus opens IMMEDIATELY (no delay); blur closes immediately (reason blur)", async () => {
      await mount()
      const closes = record("poetry:hover-card:closed", el("root"))

      el("hc-trigger").focus()
      await nextFrame()

      expect(el("hc-content").dataset.state).toBe("open")

      el("hc-trigger").blur()
      await nextFrame()

      expect(el("hc-content").dataset.state).toBe("closed")
      expect(closes).toEqual([{ reason: "blur" }])
    })

    it("no aria surface appears at runtime: no aria-haspopup/expanded/controls/describedby anywhere", async () => {
      await mount()

      el("hc-trigger").focus()
      await nextFrame()

      for (const attribute of ["aria-haspopup", "aria-expanded", "aria-controls", "aria-describedby"]) {
        expect(el("hc-trigger").hasAttribute(attribute)).toBe(false)
      }
      expect(el("hc-content").hasAttribute("role")).toBe(false)
    })
  })

  describe("dismissal", () => {
    it("Esc closes via the token-activated layer (reason escape)", async () => {
      await mount()
      const closes = record("poetry:hover-card:closed", el("root"))

      el("hc-trigger").focus()
      await nextFrame() // the layer controller connects

      pressEscape()
      await nextFrame()

      expect(el("hc-content").dataset.state).toBe("closed")
      expect(closes).toEqual([{ reason: "escape" }])
    })

    it("outside press closes (reason outside)", async () => {
      await mount()
      const closes = record("poetry:hover-card:closed", el("root"))

      el("hc-trigger").focus()
      await nextFrame()

      el("outside").dispatchEvent(new MouseEvent("pointerdown", { bubbles: true }))
      await nextFrame()

      expect(closes).toEqual([{ reason: "outside" }])
    })
  })

  describe("the selection hold", () => {
    it("pointerdown on the content suppresses body user-select (webkit included); pointerup restores it", async () => {
      await mount()

      el("hc-trigger").focus()
      await nextFrame()

      pointer(el("hc-content"), "pointerdown")

      expect(document.body.style.userSelect).toBe("none")
      expect(document.body.style.webkitUserSelect).toBe("none")

      pointer(document.body, "pointerup")

      expect(document.body.style.userSelect).toBe("")
      expect(document.body.style.webkitUserSelect).toBe("")
    })

    it("an existing selection defers the pointer-leave close - but Esc still closes", async () => {
      await mount()

      el("hc-trigger").focus()
      await nextFrame()

      vi.useFakeTimers()
      vi.spyOn(document, "getSelection").mockReturnValue({ toString: () => "The React framework." })

      pointer(el("hc-content"), "pointerdown")
      pointer(document.body, "pointerup")
      await vi.advanceTimersByTimeAsync(0) // the selection snapshot rides one tick behind

      pointer(el("hc-content"), "pointerleave")
      await vi.advanceTimersByTimeAsync(5000)

      expect(el("hc-content").dataset.state).toBe("open") // held open for the copy

      pressEscape()
      await vi.advanceTimersByTimeAsync(0)

      expect(el("hc-content").dataset.state).toBe("closed") // the hold never blocks Esc
    })

    it("disconnect restores a suppressed body user-select (teardown contract)", async () => {
      await mount()

      el("hc-trigger").focus()
      await nextFrame()
      pointer(el("hc-content"), "pointerdown")
      expect(document.body.style.userSelect).toBe("none")

      el("host").replaceChildren()
      await nextFrame()

      expect(document.body.style.userSelect).toBe("")
    })
  })

  describe("the tabindex strip", () => {
    it("re-strips per-open: content streamed in while closed is stripped on the NEXT open", async () => {
      await mount()

      el("hc-trigger").focus()
      await nextFrame()
      el("hc-trigger").blur()
      await nextFrame()

      el("hc-content").insertAdjacentHTML(
        "beforeend", '<button id="streamed" type="button">late</button>'
      )

      el("hc-trigger").focus()
      await nextFrame()

      expect(el("streamed").getAttribute("tabindex")).toBe("-1")
    })
  })

  describe("controllable state + reconcile-on-connect", () => {
    it("a server-pinned card (open: true) activates the layer + the strip on connect", async () => {
      await mount({ open: true })

      expect(controllersOf("hc-content")).toContain(DISMISS_TOKEN)
      expect(el("inside-link").getAttribute("tabindex")).toBe("-1")
      expect(el("inside-button").getAttribute("tabindex")).toBe("-1")
    })

    it("flipping the open value drives the machine (reason programmatic)", async () => {
      await mount()
      const closes = record("poetry:hover-card:closed", el("root"))

      el("root").setAttribute("data-poetry--core--hover-card-open-value", "true")
      await nextFrame()

      expect(el("hc-content").dataset.state).toBe("open")

      el("root").setAttribute("data-poetry--core--hover-card-open-value", "false")
      await nextFrame()

      expect(el("hc-content").dataset.state).toBe("closed")
      expect(closes).toEqual([{ reason: "programmatic" }])
    })
  })
})
