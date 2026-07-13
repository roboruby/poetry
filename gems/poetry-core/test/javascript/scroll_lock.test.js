import { afterEach, beforeEach, describe, expect, it } from "vitest"
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
})
