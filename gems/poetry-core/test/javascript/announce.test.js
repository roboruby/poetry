import { afterEach, beforeEach, describe, expect, it, vi } from "vitest"
import { acquire, announce, release } from "@poetry/controllers/helpers/announce"

// The announce singleton (P5) unit suite: lazy region creation, refcounted
// acquire/release, polite/assertive routing, the clear-then-set microtask
// (identical consecutive messages re-announce), the per-region queue gap,
// and tab-visibility muting with the last-message flush. What jsdom cannot
// see - whether screen readers actually SPEAK - is the browser/SR pass's
// job (the live-region bug surface is jsdom-invisible by nature).

const flushMicrotasks = async () => {
  await Promise.resolve()
  await Promise.resolve()
}

const politeRegion = () => document.querySelector('[data-poetry-announce-region="polite"]')
const assertiveRegion = () => document.querySelector('[data-poetry-announce-region="assertive"]')

const setHidden = (hidden) => {
  Object.defineProperty(document, "hidden", { configurable: true, value: hidden })
  document.dispatchEvent(new Event("visibilitychange"))
}

describe("helpers/announce", () => {
  beforeEach(() => {
    vi.useRealTimers()
    // Wiping body detaches any regions a previous test left; the module
    // rebuilds lazily (the body-swap guard).
    document.body.innerHTML = ""
    setHidden(false)
  })

  afterEach(() => {
    vi.useRealTimers()
    setHidden(false)
  })

  describe("lazy creation", () => {
    it("no regions exist before first use; first announce creates the polite+assertive pair on body", async () => {
      expect(politeRegion()).toBeNull()
      expect(assertiveRegion()).toBeNull()

      announce("Saved")
      await flushMicrotasks()

      const polite = politeRegion()
      const assertive = assertiveRegion()

      expect(polite.parentElement).toBe(document.body)
      expect(polite.getAttribute("role")).toBe("status")
      expect(polite.getAttribute("aria-live")).toBe("polite")
      expect(polite.getAttribute("aria-atomic")).toBe("true")
      expect(assertive.getAttribute("role")).toBe("alert")
      expect(assertive.getAttribute("aria-live")).toBe("assertive")
      expect(assertive.getAttribute("aria-atomic")).toBe("true")
    })

    it("acquire() alone creates the regions (a toaster with no toasts yet)", () => {
      acquire()

      expect(politeRegion()).not.toBeNull()
      expect(assertiveRegion()).not.toBeNull()

      release()
    })
  })

  describe("politeness routing", () => {
    it("polite (default) writes the status region; assertive writes the alert region; textContent only", async () => {
      announce("Saved")
      announce("Failed", "assertive")
      await flushMicrotasks()

      expect(politeRegion().textContent).toBe("Saved")
      expect(assertiveRegion().textContent).toBe("Failed")
      expect(politeRegion().innerHTML).not.toContain("<") // never markup
    })

    it("an unknown politeness falls back to polite", async () => {
      announce("Hm", "shouty")
      await flushMicrotasks()

      expect(politeRegion().textContent).toBe("Hm")
    })
  })

  describe("the clear-then-set queue", () => {
    it("identical consecutive messages re-announce (cleared, then set again on a microtask)", async () => {
      vi.useFakeTimers()

      announce("Saved")
      await vi.advanceTimersByTimeAsync(150)
      expect(politeRegion().textContent).toBe("Saved")

      announce("Saved")
      expect(politeRegion().textContent).toBe("") // the clear happened synchronously

      await vi.advanceTimersByTimeAsync(0)
      expect(politeRegion().textContent).toBe("Saved") // re-set: SRs re-announce
    })

    it("queued messages drain one per gap, never dropped", async () => {
      vi.useFakeTimers()

      announce("one")
      announce("two")
      await vi.advanceTimersByTimeAsync(0)

      expect(politeRegion().textContent).toBe("one")

      await vi.advanceTimersByTimeAsync(150)
      expect(politeRegion().textContent).toBe("two")
    })
  })

  describe("refcounted lifecycle", () => {
    it("regions survive until the LAST consumer releases", () => {
      acquire()
      acquire()

      release()
      expect(politeRegion()).not.toBeNull()

      release()
      expect(politeRegion()).toBeNull()
      expect(assertiveRegion()).toBeNull()
    })

    it("release below zero is a no-op", () => {
      release()

      expect(politeRegion()).toBeNull()
    })
  })

  describe("tab-visibility muting", () => {
    it("hidden flips both regions to aria-live=off; visible restores politeness and flushes at most the LAST message", async () => {
      vi.useFakeTimers()

      announce("before")
      await vi.advanceTimersByTimeAsync(150)

      setHidden(true)

      expect(politeRegion().getAttribute("aria-live")).toBe("off")
      expect(assertiveRegion().getAttribute("aria-live")).toBe("off")

      announce("while hidden 1")
      announce("while hidden 2")
      announce("while hidden 3", "assertive")
      await vi.advanceTimersByTimeAsync(500)

      // Muted: nothing was written while hidden.
      expect(politeRegion().textContent).toBe("before")

      setHidden(false)
      await vi.advanceTimersByTimeAsync(0)

      expect(politeRegion().getAttribute("aria-live")).toBe("polite")
      expect(assertiveRegion().getAttribute("aria-live")).toBe("assertive")
      // Only the LAST hidden message flushed (no backlog flood), at its
      // own politeness.
      expect(assertiveRegion().textContent).toBe("while hidden 3")
      expect(politeRegion().textContent).toBe("before")
    })
  })
})
