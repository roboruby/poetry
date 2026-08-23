import { describe, expect, it, vi } from "vitest"
import { setState, stateOf } from "@poetry/controllers/helpers/state"
import { collectionItems } from "@poetry/controllers/helpers/collection"
import { directionOf } from "@poetry/controllers/helpers/direction"
import { tabbableWithin } from "@poetry/controllers/helpers/tabbable"
import { onEscapeKeydown } from "@poetry/controllers/helpers/escape"
import { FOCUS_GUARD_SELECTOR, ensureFocusGuards, removeFocusGuards } from "@poetry/controllers/helpers/focus_guards"
import { enterPresence, exitPresence, measurePresence } from "@poetry/controllers/helpers/presence"

describe("state", () => {
  it("writes the vocabulary pair and dispatches a bubbling poetry:state-change", () => {
    const parent = document.createElement("div")
    const el = document.createElement("div")
    parent.appendChild(el)
    const seen = []
    parent.addEventListener("poetry:state-change", (event) => seen.push(event.detail.state))

    setState(el, "open")

    expect(el.hasAttribute("data-open")).toBe(true)
    expect(el.hasAttribute("data-closed")).toBe(false)
    expect(stateOf(el)).toBe("open")
    expect(seen).toEqual(["open"])
  })
})

describe("collection", () => {
  it("returns items in DOM order - the DOM is the registry", () => {
    document.body.innerHTML = `
      <ul>
        <li data-poetry-collection-item id="a"></li>
        <li id="skip"></li>
        <li data-poetry-collection-item id="b"></li>
      </ul>`

    expect(collectionItems(document.body).map((el) => el.id)).toEqual(["a", "b"])
  })
})

describe("direction", () => {
  it("reads the closest dir ancestor, defaulting to ltr", () => {
    document.body.innerHTML = `<div dir="RTL"><span id="inner"></span></div><span id="outer"></span>`

    expect(directionOf(document.getElementById("inner"))).toBe("rtl")
    expect(directionOf(document.getElementById("outer"))).toBe("ltr")
  })
})

describe("tabbable", () => {
  it("collects candidates and filters disabled / hidden / tabindex=-1 / inert", () => {
    document.body.innerHTML = `
      <div id="scope">
        <a href="#" id="link">a</a>
        <button id="btn">b</button>
        <button disabled id="disabled">c</button>
        <input type="hidden" id="hiddenInput">
        <input id="text">
        <span tabindex="0" id="focusable-span"></span>
        <span tabindex="-1" id="skipped-span"></span>
        <div inert><button id="inert-btn">d</button></div>
        <button hidden id="hidden-btn">e</button>
      </div>`

    const ids = tabbableWithin(document.getElementById("scope")).map((el) => el.id)

    expect(ids).toEqual(["link", "btn", "text", "focusable-span"])
  })
})

describe("escape", () => {
  it("fires on Escape only and unsubscribes cleanly", () => {
    const callback = vi.fn()
    const unsubscribe = onEscapeKeydown(callback)

    window.dispatchEvent(new KeyboardEvent("keydown", { key: "Escape" }))
    window.dispatchEvent(new KeyboardEvent("keydown", { key: "Enter" }))
    expect(callback).toHaveBeenCalledTimes(1)

    unsubscribe()
    window.dispatchEvent(new KeyboardEvent("keydown", { key: "Escape" }))
    expect(callback).toHaveBeenCalledTimes(1)
  })
})

describe("focus guards", () => {
  it("posts two body-edge sentinels (tabindex 0, aria-hidden), removed on release", () => {
    document.body.innerHTML = `<button id="content">content</button>`

    ensureFocusGuards()

    const guards = document.querySelectorAll(FOCUS_GUARD_SELECTOR)
    expect(guards.length).toBe(2)
    expect(document.body.firstElementChild).toBe(guards[0])
    expect(document.body.lastElementChild).toBe(guards[1])
    expect(guards[0].getAttribute("tabindex")).toBe("0")
    expect(guards[0].getAttribute("aria-hidden")).toBe("true")

    removeFocusGuards()
    expect(document.querySelectorAll(FOCUS_GUARD_SELECTOR).length).toBe(0)
  })

  it("is refcounted: one pair per page, held until the LAST holder releases", () => {
    document.body.innerHTML = ""

    ensureFocusGuards()
    ensureFocusGuards()
    expect(document.querySelectorAll(FOCUS_GUARD_SELECTOR).length).toBe(2)

    removeFocusGuards()
    expect(document.querySelectorAll(FOCUS_GUARD_SELECTOR).length).toBe(2)

    removeFocusGuards()
    expect(document.querySelectorAll(FOCUS_GUARD_SELECTOR).length).toBe(0)
  })

  it("releasing below zero is a no-op (an unbalanced caller cannot corrupt the count)", () => {
    document.body.innerHTML = ""

    removeFocusGuards()
    ensureFocusGuards()

    expect(document.querySelectorAll(FOCUS_GUARD_SELECTOR).length).toBe(2)
    removeFocusGuards()
  })
})

describe("presence", () => {
  const mount = () => {
    document.body.innerHTML = `<div id="panel"><span id="panel-child"></span></div>`
    return document.getElementById("panel")
  }

  // jsdom has no CSS engine, so exit animations are declared by stubbing
  // getComputedStyle - exactly the surface the helper reads.
  const stubStyle = (overrides = {}) =>
    vi.spyOn(window, "getComputedStyle").mockReturnValue({
      animationName: "none",
      animationDuration: "0s",
      animationDelay: "0s",
      transitionDuration: "0s",
      transitionDelay: "0s",
      ...overrides
    })

  // jsdom has no layout - stub scrollHeight, recording what the element
  // looked like at the exact moment the measure read it.
  const stubScrollHeight = (element, height, seenAtRead = {}) => {
    Object.defineProperty(element, "scrollHeight", {
      configurable: true,
      get() {
        seenAtRead.hidden = element.hidden
        seenAtRead.animation = element.style.animation
        return height
      }
    })
    return seenAtRead
  }

  it("enterPresence flips the pair to data-open", () => {
    const panel = mount()

    enterPresence(panel)

    expect(panel.hasAttribute("data-open")).toBe(true)
  })

  it("measurePresence writes scrollHeight as a px var, measuring unhidden with animations suppressed, then restores", () => {
    const panel = mount()
    panel.hidden = true
    panel.style.animation = "poetry-exit 0.2s"
    const seen = stubScrollHeight(panel, 120)

    const height = measurePresence(panel)

    expect(height).toBe(120)
    expect(panel.style.getPropertyValue("--poetry-presence-height")).toBe("120px")
    expect(seen.hidden).toBe(false) // unhidden for the read
    expect(seen.animation).toBe("none") // keyframes suppressed for the read
    expect(panel.hidden).toBe(true) // both restored afterward
    expect(panel.style.animation).toBe("poetry-exit 0.2s")
  })

  it("the measure var name is overridable (the vendored chain reads --accordion-panel-height)", () => {
    const panel = mount()
    stubScrollHeight(panel, 64)

    measurePresence(panel, { property: "--accordion-panel-height" })

    expect(panel.style.getPropertyValue("--accordion-panel-height")).toBe("64px")
    expect(panel.style.getPropertyValue("--poetry-presence-height")).toBe("")
  })

  it("enterPresence measure:true sets the var BEFORE the pair flips to data-open", () => {
    const panel = mount()
    stubScrollHeight(panel, 80)
    let varAtFlip = null
    panel.addEventListener("poetry:state-change", () => {
      varAtFlip = panel.style.getPropertyValue("--poetry-presence-height")
    })

    enterPresence(panel, { measure: true })

    expect(panel.hasAttribute("data-open")).toBe(true)
    expect(varAtFlip).toBe("80px") // the open keyframe can consume it from frame one
  })

  it("exitPresence measure:true measures while still visible, before the closed flip", () => {
    const panel = mount()
    const seen = stubScrollHeight(panel, 48)
    const onRemove = vi.fn()
    let varAtFlip = null
    panel.addEventListener("poetry:state-change", () => {
      varAtFlip = panel.style.getPropertyValue("--poetry-presence-height")
    })

    exitPresence(panel, { onRemove, measure: true })

    expect(varAtFlip).toBe("48px")
    expect(seen.hidden).toBe(false)
    expect(panel.hasAttribute("data-closed")).toBe(true)
    expect(onRemove).toHaveBeenCalledTimes(1) // no animation in jsdom: still instant
  })

  it("exitPresence with no animation (jsdom's default computed style) removes immediately", () => {
    const panel = mount()
    const onRemove = vi.fn()

    exitPresence(panel, { onRemove })

    expect(panel.hasAttribute("data-closed")).toBe(true)
    expect(onRemove).toHaveBeenCalledTimes(1)
  })

  it("holds through an exit animation, then removes ONCE on the element's animationend", () => {
    const panel = mount()
    const spy = stubStyle({ animationName: "poetry-exit", animationDuration: "0.2s" })
    const onRemove = vi.fn()

    exitPresence(panel, { onRemove })
    expect(panel.hasAttribute("data-closed")).toBe(true)
    expect(onRemove).not.toHaveBeenCalled()

    // A child's animation ending is not the panel's exit finishing.
    document.getElementById("panel-child").dispatchEvent(new Event("animationend", { bubbles: true }))
    expect(onRemove).not.toHaveBeenCalled()

    panel.dispatchEvent(new Event("animationend", { bubbles: true }))
    panel.dispatchEvent(new Event("animationend", { bubbles: true }))
    expect(onRemove).toHaveBeenCalledTimes(1)

    spy.mockRestore()
  })

  it("a transition-only exit holds until transitionend", () => {
    const panel = mount()
    const spy = stubStyle({ transitionDuration: "0.15s" })
    const onRemove = vi.fn()

    exitPresence(panel, { onRemove })
    expect(onRemove).not.toHaveBeenCalled()

    panel.dispatchEvent(new Event("transitionend", { bubbles: true }))
    expect(onRemove).toHaveBeenCalledTimes(1)

    spy.mockRestore()
  })

  it("the safety timeout removes even when the end event never fires", () => {
    vi.useFakeTimers()
    const panel = mount()
    const spy = stubStyle({ animationName: "poetry-exit", animationDuration: "0.2s" })
    const onRemove = vi.fn()

    exitPresence(panel, { onRemove })
    expect(onRemove).not.toHaveBeenCalled()

    vi.advanceTimersByTime(301) // 200ms duration + the 100ms grace
    expect(onRemove).toHaveBeenCalledTimes(1)

    spy.mockRestore()
    vi.useRealTimers()
  })

  it("cancel() abandons the wait without removing (an exit interrupted by a re-open)", () => {
    const panel = mount()
    const spy = stubStyle({ animationName: "poetry-exit", animationDuration: "0.2s" })
    const onRemove = vi.fn()

    const cancel = exitPresence(panel, { onRemove })
    cancel()

    panel.dispatchEvent(new Event("animationend", { bubbles: true }))
    expect(onRemove).not.toHaveBeenCalled()

    spy.mockRestore()
  })

  // The Base UI transition hooks. No poetry class consumes
  // them yet - these pin the choreography for the theme layer.
  describe("starting/ending style hooks", () => {
    const twoFrames = () => new Promise((resolve) => {
      requestAnimationFrame(() => requestAnimationFrame(() => setTimeout(resolve, 0)))
    })

    it("enterPresence wears data-starting-style for one painted frame, then removes it", async () => {
      const panel = mount()

      enterPresence(panel)
      expect(panel.hasAttribute("data-starting-style")).toBe(true) // the first paint sees it

      await twoFrames()
      expect(panel.hasAttribute("data-starting-style")).toBe(false)
      expect(panel.hasAttribute("data-open")).toBe(true)
    })

    it("exitPresence wears data-ending-style until the exit settles", () => {
      const panel = mount()
      const spy = stubStyle({ animationName: "poetry-exit", animationDuration: "0.2s" })
      const onRemove = vi.fn()

      exitPresence(panel, { onRemove })
      expect(panel.hasAttribute("data-ending-style")).toBe(true)

      panel.dispatchEvent(new Event("animationend", { bubbles: true }))
      expect(onRemove).toHaveBeenCalledTimes(1)
      expect(panel.hasAttribute("data-ending-style")).toBe(false)

      spy.mockRestore()
    })

    it("a no-animation exit never leaves the attribute behind", () => {
      const panel = mount()

      exitPresence(panel, { onRemove: vi.fn() })
      expect(panel.hasAttribute("data-ending-style")).toBe(false)
    })

    it("cancel() (a re-open interrupt) strips data-ending-style; the next enter strips any leftover", () => {
      const panel = mount()
      const spy = stubStyle({ animationName: "poetry-exit", animationDuration: "0.2s" })

      const cancel = exitPresence(panel, { onRemove: vi.fn() })
      expect(panel.hasAttribute("data-ending-style")).toBe(true)
      cancel()
      expect(panel.hasAttribute("data-ending-style")).toBe(false)

      // Belt and braces: even a lingering attribute is cleared on entry.
      panel.setAttribute("data-ending-style", "")
      enterPresence(panel)
      expect(panel.hasAttribute("data-ending-style")).toBe(false)

      spy.mockRestore()
    })

    it("getAnimations().finished settles the exit (the Base UI end-detection)", async () => {
      const panel = mount()
      const spy = stubStyle({ animationName: "poetry-exit", animationDuration: "0.2s" })
      const onRemove = vi.fn()
      let resolveFinished
      panel.getAnimations = () => [{ finished: new Promise((resolve) => { resolveFinished = resolve }) }]

      exitPresence(panel, { onRemove })
      expect(onRemove).not.toHaveBeenCalled()

      resolveFinished()
      await Promise.resolve() // allSettled tick
      await Promise.resolve()
      expect(onRemove).toHaveBeenCalledTimes(1)
      expect(panel.hasAttribute("data-ending-style")).toBe(false)

      spy.mockRestore()
    })
  })
})
