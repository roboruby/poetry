import { afterEach, beforeEach, describe, expect, it, vi } from "vitest"

import {
  prefersReducedMotion, onReducedMotionChange, track, flush, canAnimateView, visitInFlight,
  duration, easing, spring, configureEngine,
} from "@poetry/motion/policy"

// The policy, with matchMedia stubbed: reduced motion from the query and
// from data-motion, the tokens, the Turbo cache flush and the one
// view-transition slot.

let reduce = false
const changeListeners = new Set()

beforeEach(() => {
  reduce = false
  window.matchMedia = vi.fn(() => ({
    get matches() { return reduce },
    addEventListener: (_type, fn) => changeListeners.add(fn),
  }))
  const root = document.documentElement
  delete root.dataset.motion
  root.style.setProperty("--motion-duration-fast", "150ms")
  root.style.setProperty("--motion-duration-slow", "0.6s")
  root.style.setProperty("--motion-ease-standard", "cubic-bezier(0.2, 0, 0, 1)")
  root.style.setProperty("--motion-spring-snappy", "400 30 1")
  document.startViewTransition = () => ({})
})

afterEach(() => {
  delete document.startViewTransition
})

const animation = () => {
  let finish
  const finished = new Promise((resolve) => { finish = resolve })
  return { finished, complete: vi.fn(() => finish()), stop: vi.fn(), finish }
}

describe("reduced motion", () => {
  it("follows the media query", () => {
    expect(prefersReducedMotion()).toBe(false)
    reduce = true
    expect(prefersReducedMotion()).toBe(true)
  })

  it("data-motion forces it either way", () => {
    document.documentElement.dataset.motion = "reduce"
    expect(prefersReducedMotion()).toBe(true)
    reduce = true
    document.documentElement.dataset.motion = "full"
    expect(prefersReducedMotion()).toBe(false)
  })

  it("sets the engine's skip flag, now and on change", async () => {
    const engine = { MotionGlobalConfig: { skipAnimations: false } }
    configureEngine(engine)
    expect(engine.MotionGlobalConfig.skipAnimations).toBe(false)

    const seen = []
    const stop = onReducedMotionChange((reduced) => seen.push(reduced))
    document.documentElement.dataset.motion = "reduce"
    await new Promise((resolve) => setTimeout(resolve, 0))
    expect(engine.MotionGlobalConfig.skipAnimations).toBe(true)
    expect(seen).toEqual([true])

    delete document.documentElement.dataset.motion
    reduce = true
    for (const fn of changeListeners) fn()
    expect(engine.MotionGlobalConfig.skipAnimations).toBe(true)
    stop()
  })
})

describe("tokens", () => {
  it("durations in seconds, from a name or milliseconds; zero when reduced", () => {
    expect(duration("fast")).toBe(0.15)
    expect(duration("slow")).toBe(0.6)
    expect(duration(250)).toBe(0.25)
    reduce = true
    expect(duration("fast")).toBe(0)
  })

  it("easings and springs", () => {
    expect(easing("standard")).toEqual([0.2, 0, 0, 1])
    expect(spring("snappy")).toEqual({ type: "spring", stiffness: 400, damping: 30, mass: 1 })
  })

  it("an unknown token raises with its name", () => {
    expect(() => duration("glacial")).toThrow(/glacial/)
    expect(() => easing("wobbly")).toThrow(/wobbly/)
    expect(() => spring("limp")).toThrow(/limp/)
  })
})

describe("the Turbo cache", () => {
  it("returns inline-animated elements to their own style before the snapshot", () => {
    const postRender = vi.fn()
    configureEngine({ MotionGlobalConfig: {}, frame: { postRender } })
    const element = document.createElement("div")
    element.style.translate = "120px 0px"
    element.style.color = "red"
    const inline = track(animation(), { element, properties: ["translate"] })

    document.dispatchEvent(new Event("turbo:before-cache"))

    expect(inline.stop).toHaveBeenCalledOnce()
    expect(element.style.translate).toBe("")
    expect(element.style.color).toBe("red")
    element.style.translate = "119px 0px" // the engine's next render writes the stopped value back
    postRender.mock.calls[0][0]()
    expect(element.style.translate).toBe("")
  })

  it("completes a Web Animation, which leaves no inline style", () => {
    const one = track(animation())
    const two = track(animation())
    document.dispatchEvent(new Event("turbo:before-cache"))
    expect(one.complete).toHaveBeenCalledOnce()
    expect(two.complete).toHaveBeenCalledOnce()
  })

  it("forgets an animation once it finishes", async () => {
    const done = track(animation())
    done.finish()
    await done.finished
    await Promise.resolve()
    flush()
    expect(done.complete).not.toHaveBeenCalled()
  })
})

describe("the view-transition slot", () => {
  it("is closed while a Turbo visit is in flight", () => {
    expect(canAnimateView()).toBe(true)
    document.dispatchEvent(new Event("turbo:visit"))
    expect(visitInFlight()).toBe(true)
    expect(canAnimateView()).toBe(false)
    document.dispatchEvent(new Event("turbo:load"))
    expect(canAnimateView()).toBe(true)
  })

  it("is closed without View Transitions or under reduced motion", () => {
    reduce = true
    expect(canAnimateView()).toBe(false)
    reduce = false
    delete document.startViewTransition
    expect(canAnimateView()).toBe(false)
  })
})
