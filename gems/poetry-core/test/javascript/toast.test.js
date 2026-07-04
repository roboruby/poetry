import { beforeEach, describe, expect, it, vi } from "vitest"
import { Application } from "@hotwired/stimulus"
import { registerPoetryControllers } from "@poetry/controllers"

// poetry--core--toast + poetry--core--toaster JS-unit: the item announces
// ONCE through the singleton at its politeness (destructive -> assertive)
// and never self-announces (aria-live=off); the APG timer pauses on hover,
// focus, window blur and tab-hidden with refcounted reasons; dismiss
// reasons (timeout/close-press/action) ride poetry:toast:dismiss before presence
// removal; the toaster acquires/releases the announce singleton, owns the
// hotkey + focus return, enforces the visible limit (overflow queues with
// timers held), and writes the stack reflow index. Swipe is a
// browser-verification-gated enhancement - deliberately absent here.

const nextFrame = () => new Promise((resolve) => setTimeout(resolve, 0))

const el = (id) => document.getElementById(id)

const politeRegion = () => document.querySelector('[data-poetry-announce-region="polite"]')
const assertiveRegion = () => document.querySelector('[data-poetry-announce-region="assertive"]')

const record = (type, target) => {
  const seen = []
  target.addEventListener(type, (event) => seen.push(event.detail))
  return seen
}

const hover = (element, type) =>
  element.dispatchEvent(new MouseEvent(type, { bubbles: true }))

const toasterMarkup = ({ limit = 3 } = {}) => `
  <ol id="poetry-toaster" data-slot="toaster" data-component="toast" data-turbo-permanent
      role="region" aria-label="Notifications (F8)" tabindex="-1"
      data-controller="poetry--core--toaster"
      data-poetry--core--toaster-hotkey-value="F8"
      data-poetry--core--toaster-limit-value="${limit}">
  </ol>`

const toastMarkup = (id, {
  variant = "default", duration = 5000, politeness = "polite",
  title = "Saved", description = "", action = false
} = {}) => `
  <li id="${id}" data-slot="toast" data-open data-variant="${variant}"
      role="status" aria-live="off" aria-atomic="true" tabindex="0"
      data-controller="poetry--core--toast"
      data-poetry--core--toast-duration-value="${duration}"
      data-poetry--core--toast-politeness-value="${politeness}"
      data-action="mouseenter->poetry--core--toast#pause mouseleave->poetry--core--toast#resume
                   focusin->poetry--core--toast#pause focusout->poetry--core--toast#resume">
    <div data-slot="toast-title">${title}</div>
    ${description ? `<div data-slot="toast-description">${description}</div>` : ""}
    ${action ? `<button id="${id}-action" type="button" data-slot="toast-action"
                        data-poetry--core--toast-target="action"
                        data-action="poetry--core--toast#dismiss">Undo</button>` : ""}
    <button id="${id}-close" type="button" data-slot="toast-close"
            data-poetry--core--toast-target="close"
            data-action="poetry--core--toast#dismiss">Close</button>
  </li>`

describe("poetry--core--toast / poetry--core--toaster", () => {
  let application

  beforeEach(async () => {
    vi.useRealTimers()
    document.body.innerHTML = `<button id="outside">outside</button><div id="host"></div>`
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

  async function mountToaster(options = {}) {
    el("host").innerHTML = toasterMarkup(options)
    await nextFrame()
  }

  // Under fake timers Stimulus connects on flushed microtasks, so appends
  // settle with an async zero-advance.
  async function append(id, options = {}) {
    el("poetry-toaster").insertAdjacentHTML("beforeend", toastMarkup(id, options))

    if (vi.isFakeTimers()) await vi.advanceTimersByTimeAsync(0)
    else await nextFrame()
  }

  describe("the announce path (through the singleton)", () => {
    it("the toaster acquires the regions on connect and releases them on disconnect", async () => {
      await mountToaster()

      expect(politeRegion()).not.toBeNull()
      expect(assertiveRegion()).not.toBeNull()

      el("host").replaceChildren()
      await nextFrame()

      expect(politeRegion()).toBeNull()
    })

    it("a toast announces title + description ONCE, politely, while staying aria-live=off itself", async () => {
      await mountToaster()
      const shows = record("poetry:toast:show", el("poetry-toaster"))

      await append("t1", { title: "Saved", description: "Your note is safe." })
      await nextFrame()

      expect(politeRegion().textContent).toBe("Saved Your note is safe.")
      expect(el("t1").getAttribute("aria-live")).toBe("off")
      expect(shows).toEqual([{ id: "t1", variant: "default" }])
    })

    it("destructive politeness routes to the assertive region", async () => {
      await mountToaster()

      await append("t1", { variant: "destructive", politeness: "assertive", title: "Delete failed" })
      await nextFrame()

      expect(assertiveRegion().textContent).toBe("Delete failed")
      expect(politeRegion().textContent).toBe("")
    })
  })

  describe("the auto-dismiss timer (APG timing)", () => {
    it("dismisses after duration with reason timeout; presence removes the node after the event", async () => {
      await mountToaster()
      const dismissals = record("poetry:toast:dismiss", el("poetry-toaster"))

      vi.useFakeTimers()
      await append("t1")

      await vi.advanceTimersByTimeAsync(4999)
      expect(el("t1")).not.toBeNull()

      await vi.advanceTimersByTimeAsync(1)

      expect(el("t1")).toBeNull()
      expect(dismissals).toEqual([{ id: "t1", reason: "timeout" }])
    })

    it("duration 0 is persistent (undo toasts): no timer ever fires", async () => {
      await mountToaster()

      vi.useFakeTimers()
      await append("t1", { duration: 0, action: true })
      await vi.advanceTimersByTimeAsync(60000)

      expect(el("t1")).not.toBeNull()
    })

    it("hover pauses and resumes with the REMAINING time (not a restart)", async () => {
      await mountToaster()

      vi.useFakeTimers()
      await append("t1")

      await vi.advanceTimersByTimeAsync(3000)
      hover(el("t1"), "mouseenter")
      await vi.advanceTimersByTimeAsync(60000) // paused: nothing happens
      expect(el("t1")).not.toBeNull()

      hover(el("t1"), "mouseleave")
      await vi.advanceTimersByTimeAsync(1999)
      expect(el("t1")).not.toBeNull()

      await vi.advanceTimersByTimeAsync(1) // 3000 elapsed + 2000 remaining
      expect(el("t1")).toBeNull()
    })

    it("pause reasons are refcounted: hover-out does not resume while focus is still held", async () => {
      await mountToaster()

      vi.useFakeTimers()
      await append("t1")

      hover(el("t1"), "mouseenter")
      el("t1").dispatchEvent(new FocusEvent("focusin", { bubbles: true }))
      hover(el("t1"), "mouseleave") // focus hold remains

      await vi.advanceTimersByTimeAsync(60000)
      expect(el("t1")).not.toBeNull()

      el("t1").dispatchEvent(new FocusEvent("focusout", { bubbles: true }))
      await vi.advanceTimersByTimeAsync(5000)
      expect(el("t1")).toBeNull()
    })

    it("window blur and tab-hidden pause; focus and visible resume", async () => {
      await mountToaster()

      vi.useFakeTimers()
      await append("t1")

      window.dispatchEvent(new Event("blur"))
      await vi.advanceTimersByTimeAsync(60000)
      expect(el("t1")).not.toBeNull()

      window.dispatchEvent(new Event("focus"))
      await vi.advanceTimersByTimeAsync(5000)
      expect(el("t1")).toBeNull()
    })
  })

  describe("dismissal reasons", () => {
    it("the close button reports close-press; the action slot reports action", async () => {
      await mountToaster()
      const dismissals = record("poetry:toast:dismiss", el("poetry-toaster"))

      await append("t1", { action: true })
      await append("t2")

      el("t1-action").click()
      el("t2-close").click()
      await nextFrame()

      expect(dismissals).toEqual([
        { id: "t1", reason: "action" },
        { id: "t2", reason: "close-press" }
      ])
    })

    it("Esc while focus is inside dismisses that toast", async () => {
      await mountToaster()

      await append("t1")
      el("t1").focus()
      el("t1").dispatchEvent(new KeyboardEvent("keydown", { key: "Escape", bubbles: true }))
      await nextFrame()

      expect(el("t1")).toBeNull()
    })
  })

  describe("the toaster region", () => {
    it("the hotkey focuses the most recent toast; dismissing it returns focus to the prior element", async () => {
      await mountToaster()

      await append("t1")
      await append("t2")

      el("outside").focus()
      window.dispatchEvent(new KeyboardEvent("keydown", { key: "F8", bubbles: true, cancelable: true }))

      expect(document.activeElement).toBe(el("t2"))

      el("t2").dispatchEvent(new KeyboardEvent("keydown", { key: "Escape", bubbles: true }))
      await nextFrame()

      expect(el("t2")).toBeNull()
      expect(document.activeElement).toBe(el("outside"))
    })

    it("enforces the limit: the OLDEST overflow toast queues hidden with its timer held, promoted when a slot frees", async () => {
      await mountToaster({ limit: 3 })

      vi.useFakeTimers()
      await append("t1")
      await append("t2")
      await append("t3")
      await append("t4")

      expect(el("t1").hidden).toBe(true)
      expect(el("t1").hasAttribute("data-queued")).toBe(true)
      expect(el("t4").hidden).toBe(false)

      // The three visible toasts time out; t1 promotes and lives its FULL
      // duration from promotion (the queued timer was held).
      await vi.advanceTimersByTimeAsync(5000)

      expect(el("t2")).toBeNull()
      expect(el("t4")).toBeNull()
      expect(el("t1")).not.toBeNull()
      expect(el("t1").hidden).toBe(false)
      expect(el("t1").hasAttribute("data-queued")).toBe(false)

      await vi.advanceTimersByTimeAsync(5000)
      expect(el("t1")).toBeNull()
    })

    it("reflow writes --poetry-toast-index with the newest toast at 0", async () => {
      await mountToaster()

      await append("t1")
      await append("t2")
      await append("t3")
      await nextFrame()

      expect(el("t3").style.getPropertyValue("--poetry-toast-index")).toBe("0")
      expect(el("t2").style.getPropertyValue("--poetry-toast-index")).toBe("1")
      expect(el("t1").style.getPropertyValue("--poetry-toast-index")).toBe("2")
    })
  })
})
