import { afterEach, beforeEach, describe, expect, it, vi } from "vitest"
import { createTypeahead, typeaheadLabel } from "@poetry/controllers/helpers/typeahead"

// The shared typeahead helper (extracted from menu_controller.js, consumed
// by the menu family and Select): the APG buffer semantics are tested ONCE
// here; consumers only test their wiring (what a match means).

const item = (label, textValue = null) => {
  const element = document.createElement("div")
  element.textContent = label
  if (textValue !== null) element.dataset.textValue = textValue
  return element
}

describe("typeaheadLabel", () => {
  it("reads trimmed textContent", () => {
    expect(typeaheadLabel(item("  Apple  "))).toBe("Apple")
  })

  it("data-text-value overrides textContent", () => {
    expect(typeaheadLabel(item("icon soup", "Zip"))).toBe("Zip")
  })
})

describe("createTypeahead", () => {
  let typeahead
  let items

  beforeEach(() => {
    vi.useFakeTimers()
    typeahead = createTypeahead()
    items = [item("Apple"), item("Banana"), item("Blueberry"), item("Cherry")]
  })

  afterEach(() => {
    vi.useRealTimers()
  })

  it("matches by prefix from the start when nothing is active", () => {
    expect(typeahead.search("b", items)).toBe(items[1])
  })

  it("a growing buffer narrows the match", () => {
    expect(typeahead.search("b", items)).toBe(items[1])
    expect(typeahead.search("l", items, { active: items[1] })).toBe(items[2]) // "bl" -> Blueberry
  })

  it("a growing buffer keeps the current item while it still matches", () => {
    expect(typeahead.search("b", items, { active: items[0] })).toBe(items[1])
    expect(typeahead.search("a", items, { active: items[1] })).toBe(items[1]) // "ba" still matches Banana
  })

  it("single-letter search always advances past the active item", () => {
    expect(typeahead.search("b", items, { active: items[1] })).toBe(items[2]) // advances to Blueberry

    typeahead.reset()
    // The active item is EXCLUDED from a single-letter search - the sole
    // match being active means no match (it always advances, never sits).
    expect(typeahead.search("a", items, { active: items[0] })).toBe(null)
  })

  it("a repeated same-letter buffer cycles matches", () => {
    expect(typeahead.search("b", items)).toBe(items[1])
    expect(typeahead.search("b", items, { active: items[1] })).toBe(items[2])
    expect(typeahead.search("b", items, { active: items[2] })).toBe(items[1]) // wraps back
  })

  it("the buffer resets after the timeout", () => {
    expect(typeahead.search("b", items)).toBe(items[1])
    expect(typeahead.pending()).toBe(true)

    vi.advanceTimersByTime(1001)
    expect(typeahead.pending()).toBe(false)
    expect(typeahead.search("c", items)).toBe(items[3]) // fresh single-letter search
  })

  it("honors a custom timeout", () => {
    typeahead.search("b", items, { timeout: 200 })
    vi.advanceTimersByTime(201)
    expect(typeahead.pending()).toBe(false)
  })

  it("reset clears the buffer immediately", () => {
    typeahead.search("b", items)
    typeahead.reset()
    expect(typeahead.pending()).toBe(false)
    expect(typeahead.search("c", items)).toBe(items[3])
  })

  it("matching is case-insensitive and uses data-text-value", () => {
    const zipped = item("Archive", "Zip")
    expect(typeahead.search("z", [items[0], zipped])).toBe(zipped)
  })

  it("returns null with no match or no items", () => {
    expect(typeahead.search("x", items)).toBe(null)
    expect(typeahead.search("a", [])).toBe(null)
  })
})
