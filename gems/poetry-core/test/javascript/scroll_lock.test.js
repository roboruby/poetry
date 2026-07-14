import { afterEach, beforeEach, describe, expect, it, vi } from "vitest"
import { lockScroll, resetScrollLock, unlockScroll } from "@poetry/controllers/helpers/scroll_lock"

// jsdom reports no layout, so the scrollbar gap is stubbed explicitly.
function stubGap(gap) {
  Object.defineProperty(document.documentElement, "clientWidth", {
    value: window.innerWidth - gap, configurable: true
  })
}

describe("scroll_lock helper", () => {
  beforeEach(() => {
    resetScrollLock()
    document.body.style.overflow = ""
    document.body.style.paddingRight = ""
  })

  afterEach(() => {
    resetScrollLock()
    stubGap(0)
  })

  it("locks with scrollbar-gutter compensation and restores both styles", () => {
    stubGap(15)

    lockScroll()

    expect(document.body.style.overflow).toBe("hidden")
    expect(document.body.style.paddingRight).toBe("15px")

    unlockScroll()

    expect(document.body.style.overflow).toBe("")
    expect(document.body.style.paddingRight).toBe("")
  })

  it("adds no padding when the page has no scrollbar", () => {
    stubGap(0)

    lockScroll()

    expect(document.body.style.overflow).toBe("hidden")
    expect(document.body.style.paddingRight).toBe("")

    unlockScroll()
  })

  it("refcounts stacked overlays - only the last unlock restores", () => {
    stubGap(15)

    lockScroll()
    lockScroll()
    unlockScroll()

    expect(document.body.style.overflow).toBe("hidden")
    expect(document.body.style.paddingRight).toBe("15px")

    unlockScroll()

    expect(document.body.style.overflow).toBe("")
    expect(document.body.style.paddingRight).toBe("")
  })

  it("preserves pre-existing body padding under compensation", () => {
    stubGap(15)
    document.body.style.paddingRight = "8px"

    lockScroll()

    expect(document.body.style.paddingRight).toBe("23px")

    unlockScroll()

    expect(document.body.style.paddingRight).toBe("8px")
  })

  it("tolerates unbalanced unlocks", () => {
    unlockScroll()

    expect(document.body.style.overflow).toBe("")
  })

  // scrollbar-gutter: stable reserves the rail at the VIEWPORT, so
  // position:fixed elements hold still too - preferred over the body
  // padding hack wherever supported (jsdom is not such a place, hence the
  // stub; the padding tests above pin the fallback path).
  describe("the scrollbar-gutter path", () => {
    let originalSupports

    beforeEach(() => {
      globalThis.CSS = globalThis.CSS || {}
      originalSupports = globalThis.CSS.supports
      globalThis.CSS.supports = vi.fn((query) => query === "scrollbar-gutter: stable")
    })

    afterEach(() => {
      if (originalSupports === undefined) delete globalThis.CSS.supports
      else globalThis.CSS.supports = originalSupports
      document.documentElement.style.scrollbarGutter = ""
    })

    it("prefers scrollbar-gutter on the root over body padding, and restores it", () => {
      stubGap(15)

      lockScroll()

      expect(document.body.style.overflow).toBe("hidden")
      expect(document.documentElement.style.scrollbarGutter).toBe("stable")
      expect(document.body.style.paddingRight).toBe("") // no padding hack

      unlockScroll()

      expect(document.body.style.overflow).toBe("")
      expect(document.documentElement.style.scrollbarGutter).toBe("")
    })

    it("leaves the gutter alone when there is no scrollbar to compensate", () => {
      stubGap(0)

      lockScroll()

      expect(document.documentElement.style.scrollbarGutter).toBe("")

      unlockScroll()
    })
  })
})
