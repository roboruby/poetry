import { afterEach, beforeEach, describe, expect, it, vi } from "vitest"
import fs from "node:fs"
import path from "node:path"
import { fileURLToPath } from "node:url"

import { teardown, hasScope } from "@poetry/controllers/helpers/scope"
import { useAnimate } from "@poetry/motion/behaviors/animate"
import { useStagger } from "@poetry/motion/behaviors/stagger"
import { useSpring } from "@poetry/motion/behaviors/spring"
import { useScrollValue } from "@poetry/motion/behaviors/scroll_value"
import { usePointer } from "@poetry/motion/behaviors/pointer"
import { useFrame } from "@poetry/motion/behaviors/frame"
import { useLayout } from "@poetry/motion/behaviors/layout"
import { useDrag } from "@poetry/motion/behaviors/drag"
import { useGesture } from "@poetry/motion/behaviors/gesture"
import { useCanvas } from "@poetry/motion/behaviors/canvas"
import { loadEngine } from "@poetry/motion/load_engine"

// The M2 gate: every behavior under reduced motion, at teardown, and on a
// return visit, against the real vendored engine in jsdom.

const ROOT = path.dirname(path.dirname(path.dirname(fileURLToPath(import.meta.url))))
const BEHAVIORS = path.join(ROOT, "app/javascript/poetry/motion/behaviors")

let reduce = false
let coarse = false
const controller = () => ({})
const wait = (ms) => new Promise((resolve) => setTimeout(resolve, ms))
const box = () => {
  const element = document.createElement("div")
  element.getBoundingClientRect = () => ({ left: 0, top: 0, width: 200, height: 100, right: 200, bottom: 100 })
  document.body.append(element)
  return element
}
const pointer = (element, type, init = {}) =>
  element.dispatchEvent(Object.assign(new Event(type, { bubbles: true }),
    { clientX: 0, clientY: 0, pointerId: 1, pointerType: "mouse", button: 0, ...init }))

beforeEach(() => {
  reduce = false
  coarse = false
  window.matchMedia = vi.fn((query) => ({
    get matches() { return query.includes("reduced-motion") ? reduce : query.includes("coarse") ? coarse : false },
    addEventListener: () => {},
  }))
  const root = document.documentElement
  delete root.dataset.motion
  root.removeAttribute("data-turbo-preview")
  root.style.setProperty("--motion-duration-normal", "300ms")
  root.style.setProperty("--motion-duration-slow", "600ms")
  root.style.setProperty("--motion-ease-standard", "cubic-bezier(0.2, 0, 0, 1)")
  root.style.setProperty("--motion-spring-snappy", "400 30 1")
})

afterEach(() => {
  document.body.innerHTML = ""
})

describe("the teardown gate", () => {
  it("every behavior registers its undo in the controller's scope", () => {
    const files = fs.readdirSync(BEHAVIORS).filter((file) => file.endsWith(".js"))
    expect(files).toHaveLength(10)
    for (const file of files) {
      expect(fs.readFileSync(path.join(BEHAVIORS, file), "utf8"), file).toMatch(/scopeOf\(controller\)/)
    }
  })

  it("leaves no scope, listener, loop or inline style behind", async () => {
    const host = controller()
    const element = box()
    const moves = vi.fn()
    const frames = vi.fn()

    useAnimate(host, element, { translate: ["-40px 0px", "0px 0px"] }, { duration: 5000 })
    usePointer(host, element, moves)
    const loop = useFrame(host, element, frames)
    useDrag(host, element)
    useGesture(host, element, { onSwipe: vi.fn() })
    await wait(80)

    expect(element.style.translate).not.toBe("")
    expect(loop.running()).toBe(true)
    teardown(host)

    expect(hasScope(host)).toBe(false)
    expect(element.style.translate).toBe("")
    expect(loop.running()).toBe(false)
    pointer(element, "pointermove", { clientX: 50 })
    const calls = frames.mock.calls.length
    await wait(50)
    expect(moves).not.toHaveBeenCalled()
    expect(frames.mock.calls.length).toBe(calls)
  })

  it("a teardown before the engine arrives cancels quietly", async () => {
    const host = controller()
    const element = box()
    useAnimate(host, element, { opacity: [0, 1] })
    teardown(host)
    await loadEngine()
    await wait(30)
    expect(element.style.opacity).toBe("")
  })
})

describe("reduced motion", () => {
  beforeEach(() => { reduce = true })

  it("useAnimate and useStagger leave every element at its own style", async () => {
    const host = controller()
    const one = box()
    const two = box()
    await useAnimate(host, one, { translate: ["-40px 0px", "0px 0px"] }).finished
    await useStagger(host, [one, two], { opacity: [0, 1] }).finished
    expect(one.getAttribute("style")).toBeNull()
    expect(two.getAttribute("style")).toBeNull()
  })

  it("useSpring writes the target at once", async () => {
    const element = box()
    await useSpring(controller(), element, "--tilt", { unit: "deg" }).set(12)
    expect(element.style.getPropertyValue("--tilt")).toBe("12deg")
  })

  it("useScrollValue reports the finished state once", () => {
    const seen = []
    useScrollValue(controller(), (progress) => seen.push(progress))
    expect(seen).toEqual([1])
  })

  it("usePointer and useFrame stay inert", async () => {
    const element = box()
    const moves = vi.fn()
    usePointer(controller(), element, moves)
    const loop = useFrame(controller(), element, vi.fn())
    pointer(element, "pointermove", { clientX: 50 })
    await wait(40)
    expect(moves).not.toHaveBeenCalled()
    expect(loop.running()).toBe(false)
  })

  it("useLayout applies the change without a transition", async () => {
    document.startViewTransition = vi.fn()
    const update = vi.fn()
    await useLayout(controller())(update)
    expect(update).toHaveBeenCalledOnce()
    expect(document.startViewTransition).not.toHaveBeenCalled()
    delete document.startViewTransition
  })

  it("useDrag still drags and settles without a spring", () => {
    const element = box()
    useDrag(controller(), element, { axis: "x", bounds: { left: -20, right: 20 } })
    pointer(element, "pointerdown", { clientX: 10 })
    pointer(element, "pointermove", { clientX: 60 })
    expect(element.style.getPropertyValue("--motion-drag-x")).toBe("20px")
    pointer(element, "pointerup", { clientX: 60 })
    expect(element.getAttribute("style")).toBe("")
  })

  it("useCanvas draws one static frame and runs no loop", () => {
    const canvas = document.createElement("canvas")
    canvas.getBoundingClientRect = () => ({ width: 100, height: 50 })
    const context = { setTransform: vi.fn(), clearRect: vi.fn() }
    canvas.getContext = () => context
    const draw = vi.fn()
    useCanvas(controller(), canvas, draw)
    expect(draw).toHaveBeenCalledOnce()
    expect(canvas.width).toBe(100 * (window.devicePixelRatio || 1))
  })

  it("turning on mid-run sends a running animation to its end state", async () => {
    reduce = false
    const element = box()
    useAnimate(controller(), element, { translate: ["-40px 0px", "0px 0px"] }, { duration: 5000 })
    await wait(80)
    expect(element.style.translate).not.toBe("")
    document.documentElement.dataset.motion = "reduce"
    await wait(0)
    expect(element.style.translate).toBe("")
  })
})

describe("return visits", () => {
  it("an entrance does not play on a cache preview", async () => {
    document.documentElement.setAttribute("data-turbo-preview", "")
    const element = box()
    await useAnimate(controller(), element, { opacity: [0, 1] }, { entrance: true }).finished
    expect(element.getAttribute("style")).toBeNull()
  })

  it("an entrance does not play while a restore visit renders, and plays after", async () => {
    document.dispatchEvent(new CustomEvent("turbo:visit", { detail: { action: "restore" } }))
    const restored = box()
    await useAnimate(controller(), restored, { opacity: [0, 1] }, { entrance: true }).finished
    expect(restored.getAttribute("style")).toBeNull()

    document.dispatchEvent(new Event("turbo:load"))
    const fresh = box()
    useAnimate(controller(), fresh, { translate: ["-40px 0px", "0px 0px"] }, { entrance: true, duration: 5000 })
    await wait(80)
    expect(fresh.style.translate).not.toBe("")
  })
})

describe("the behaviors with the engine", () => {
  it("useStagger starts each element a step after the last", async () => {
    const elements = [box(), box(), box()]
    useStagger(controller(), elements, { translate: ["-40px 0px", "0px 0px"] }, { step: 200, duration: 5000 })
    await wait(120)
    expect(elements[0].style.translate).not.toBe("")
    expect(["", "-40px 0px", "-40px"]).toContain(elements[2].style.translate)
  })

  it("useSpring retargets toward each new value", async () => {
    const element = box()
    const value = useSpring(controller(), element, "--glow")
    value.set(100)
    await wait(60)
    const midway = Number(element.style.getPropertyValue("--glow"))
    expect(midway).toBeGreaterThan(0)
    await value.set(10)
    expect(Number(element.style.getPropertyValue("--glow"))).toBeCloseTo(10, 0)
  })

  it("usePointer reports the position from -1 to 1, once a frame, fine pointers only", async () => {
    const element = box()
    const moves = vi.fn()
    const leave = vi.fn()
    usePointer(controller(), element, moves, { onLeave: leave })
    pointer(element, "pointermove", { clientX: 150, clientY: 25 })
    pointer(element, "pointermove", { clientX: 200, clientY: 100, pointerType: "touch" })
    await wait(40)
    expect(moves.mock.calls).toEqual([[{ x: 0.5, y: -0.5 }]])
    pointer(element, "pointerleave")
    expect(leave).toHaveBeenCalledOnce()
  })

  it("usePointer ignores coarse pointers", async () => {
    coarse = true
    const element = box()
    const moves = vi.fn()
    usePointer(controller(), element, moves)
    pointer(element, "pointermove", { clientX: 150 })
    await wait(40)
    expect(moves).not.toHaveBeenCalled()
  })

  it("useFrame pauses in a hidden tab", async () => {
    const element = box()
    const loop = useFrame(controller(), element, vi.fn())
    await wait(40)
    expect(loop.running()).toBe(true)
    Object.defineProperty(document, "hidden", { configurable: true, get: () => true })
    document.dispatchEvent(new Event("visibilitychange"))
    expect(loop.running()).toBe(false)
    delete document.hidden
  })

  it("useLayout holds back during a Turbo visit", async () => {
    document.startViewTransition = vi.fn()
    document.dispatchEvent(new Event("turbo:visit"))
    const update = vi.fn()
    await useLayout(controller())(update)
    expect(update).toHaveBeenCalledOnce()
    expect(document.startViewTransition).not.toHaveBeenCalled()
    document.dispatchEvent(new Event("turbo:load"))
    delete document.startViewTransition
  })

  it("useDrag springs back to the element's own style unless onEnd keeps it", async () => {
    const element = box()
    useDrag(controller(), element)
    pointer(element, "pointerdown", { clientX: 0, clientY: 0 })
    pointer(element, "pointermove", { clientX: 30, clientY: 10 })
    expect(element.dataset.dragging).toBe("")
    pointer(element, "pointerup", { clientX: 30, clientY: 10 })
    await wait(1500)
    expect(element.style.translate).toBe("")

    const kept = box()
    useDrag(controller(), kept, { onEnd: () => true })
    pointer(kept, "pointerdown", { clientX: 0 })
    pointer(kept, "pointermove", { clientX: 30 })
    pointer(kept, "pointerup", { clientX: 30 })
    expect(kept.style.getPropertyValue("--motion-drag-x")).toBe("30px")
  })

  it("useGesture reports a swipe past the threshold", () => {
    const element = box()
    const swipes = []
    useGesture(controller(), element, { onSwipe: (direction) => swipes.push(direction), threshold: 20 })
    pointer(element, "pointerdown", { clientX: 100, clientY: 0 })
    pointer(element, "pointerup", { clientX: 40, clientY: 5 })
    pointer(element, "pointerdown", { clientX: 0, clientY: 0 })
    pointer(element, "pointerup", { clientX: 5, clientY: 10 })
    expect(swipes).toEqual(["left"])
  })
})
