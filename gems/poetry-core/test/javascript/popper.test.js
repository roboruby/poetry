import { afterEach, beforeEach, describe, expect, it, vi } from "vitest"
import { Application } from "@hotwired/stimulus"
import PopperController from "@poetry/controllers/popper_controller"

// The wiring contract, with the vendored @floating-ui/dom MOCKED - jsdom
// computes no layout, so REAL positioning (collision flips, shift clamping,
// scroll-tracked autoUpdate) is the browser-verification suite's job, never
// asserted here. What this file CAN prove: values flow into computePosition
// options, the middleware pipeline is assembled in Radix's order, the
// resolved placement (not the requested one) is mirrored to data-side /
// data-align, the radix-compat CSS vars are written, the arrow target is
// positioned + rotated, autoUpdate starts on connect / stops on disconnect,
// and reposition() re-runs the computation.

const ID = "poetry--core--popper"

const nextFrame = () => new Promise((resolve) => setTimeout(resolve, 0))

// Middleware factories return { name, options } so tests can assert the
// assembled pipeline; computePosition's mock replays size.apply the way the
// real pipeline would, then resolves with a scriptable result.
vi.mock("@poetry/controllers/vendor/floating_ui_dom", () => {
  const middleware = (name) => vi.fn((options = {}) => ({ name, options }))

  return {
    computePosition: vi.fn(),
    autoUpdate: vi.fn(),
    offset: middleware("offset"),
    shift: middleware("shift"),
    flip: middleware("flip"),
    size: middleware("size"),
    arrow: middleware("arrow"),
    hide: middleware("hide"),
    limitShift: vi.fn(() => ({ name: "limitShift" }))
  }
})

const floating = await import("@poetry/controllers/vendor/floating_ui_dom")

let application
let stopAutoUpdate
let result

const defaultResult = () => ({
  x: 5,
  y: 7,
  placement: "bottom",
  strategy: "fixed",
  middlewareData: {}
})

beforeEach(() => {
  vi.clearAllMocks()
  result = defaultResult()

  // Real autoUpdate fires the callback once immediately; the mock does too,
  // so connect performs an initial position pass.
  stopAutoUpdate = vi.fn()
  floating.autoUpdate.mockImplementation((_anchor, _content, callback) => {
    callback()
    return stopAutoUpdate
  })

  floating.computePosition.mockImplementation(async (_anchor, content, options) => {
    const sizeMiddleware = options.middleware.find((entry) => entry.name === "size")

    sizeMiddleware?.options.apply({
      elements: { floating: content },
      rects: { reference: { width: 42, height: 24 } },
      availableWidth: 111,
      availableHeight: 222
    })

    return { ...result, strategy: options.strategy }
  })
})

afterEach(() => {
  application?.stop()
  application = null
  document.body.innerHTML = ""
})

const valueAttributes = (values) =>
  Object.entries(values)
    .map(([name, value]) => `data-${ID}-${name}-value="${value}"`)
    .join(" ")

async function mount({ values = {}, arrow = false, anchor = "sibling" } = {}) {
  const arrowHTML = arrow ? `<span data-slot="popper-arrow"></span>` : ""
  const anchorHTML = anchor === "sibling" ? `<button id="trigger">open</button>` : ""

  document.body.innerHTML = `
    ${anchorHTML}
    <div id="root" data-controller="${ID}" ${valueAttributes(values)}>
      <div id="content" data-${ID}-target="content">hello${arrowHTML}</div>
    </div>
  `

  application = Application.start()
  application.register(ID, PopperController)
  await nextFrame()

  const root = document.getElementById("root")

  return {
    root,
    content: document.getElementById("content"),
    controller: application.getControllerForElementAndIdentifier(root, ID)
  }
}

describe("poetry--core--popper", () => {
  it("starts autoUpdate on connect (anchor = previousElementSibling) and positions once", async () => {
    const { content } = await mount()

    expect(floating.autoUpdate).toHaveBeenCalledTimes(1)
    const [anchorArg, contentArg] = floating.autoUpdate.mock.calls[0]
    expect(anchorArg).toBe(document.getElementById("trigger"))
    expect(contentArg).toBe(content)

    expect(floating.computePosition).toHaveBeenCalledTimes(1)
    expect(content.style.position).toBe("fixed")
    expect(content.style.left).toBe("5px")
    expect(content.style.top).toBe("7px")
  })

  it("stops autoUpdate on disconnect", async () => {
    const { root } = await mount()

    expect(stopAutoUpdate).not.toHaveBeenCalled()
    root.remove()
    await nextFrame()
    expect(stopAutoUpdate).toHaveBeenCalledTimes(1)
  })

  it("resolves the anchor from the anchor value selector when no target exists", async () => {
    document.body.innerHTML = `<button id="elsewhere">open</button>`
    const anchorless = document.createElement("div")
    anchorless.id = "root"
    anchorless.setAttribute("data-controller", ID)
    anchorless.setAttribute(`data-${ID}-anchor-value`, "#elsewhere")
    anchorless.innerHTML = `<div data-${ID}-target="content"></div>`
    document.body.prepend(anchorless) // no previousElementSibling

    application = Application.start()
    application.register(ID, PopperController)
    await nextFrame()

    expect(floating.autoUpdate.mock.calls[0][0]).toBe(document.getElementById("elsewhere"))
  })

  it("prefers an explicit anchor target over the sibling fallback", async () => {
    document.body.innerHTML = `
      <button id="not-me">open</button>
      <div id="root" data-controller="${ID}">
        <span id="real-anchor" data-${ID}-target="anchor"></span>
        <div data-${ID}-target="content"></div>
      </div>
    `
    application = Application.start()
    application.register(ID, PopperController)
    await nextFrame()

    expect(floating.autoUpdate.mock.calls[0][0]).toBe(document.getElementById("real-anchor"))
  })

  it("does nothing without a resolvable anchor", async () => {
    document.body.innerHTML = `<div id="root" data-controller="${ID}"><div data-${ID}-target="content"></div></div>`
    application = Application.start()
    application.register(ID, PopperController)
    await nextFrame()

    expect(floating.autoUpdate).not.toHaveBeenCalled()
    expect(floating.computePosition).not.toHaveBeenCalled()
  })

  it("flows side/align/offsets/strategy values into computePosition options", async () => {
    await mount({
      values: {
        side: "left",
        align: "end",
        "side-offset": 4,
        "align-offset": 8,
        strategy: "absolute"
      }
    })

    const [, , options] = floating.computePosition.mock.calls[0]
    expect(options.placement).toBe("left-end")
    expect(options.strategy).toBe("absolute")
    expect(floating.offset).toHaveBeenCalledWith({ mainAxis: 4, alignmentAxis: 8 })
  })

  it("requests a bare side placement when align is center", async () => {
    await mount({ values: { side: "top", align: "center" } })

    expect(floating.computePosition.mock.calls[0][2].placement).toBe("top")
  })

  it("assembles the middleware pipeline in Radix's order", async () => {
    await mount({ arrow: true })

    const names = floating.computePosition.mock.calls[0][2].middleware.map((entry) => entry.name)
    expect(names).toEqual(["offset", "shift", "flip", "size", "arrow", "hide"])
    expect(floating.shift).toHaveBeenCalledWith({
      mainAxis: true,
      crossAxis: false,
      limiter: { name: "limitShift" }
    })
  })

  it("drops shift + flip when avoidCollisions is false and arrow when absent", async () => {
    await mount({ values: { "avoid-collisions": false } })

    const names = floating.computePosition.mock.calls[0][2].middleware.map((entry) => entry.name)
    expect(names).toEqual(["offset", "size", "hide"])
  })

  it("mirrors the RESOLVED placement (after flip) to data-side / data-align", async () => {
    result.placement = "top-end" // requested bottom, flipped by collision
    const { content } = await mount({ values: { side: "bottom" } })

    expect(content.getAttribute("data-side")).toBe("top")
    expect(content.getAttribute("data-align")).toBe("end")
  })

  it("defaults data-align to center for a bare resolved side", async () => {
    result.placement = "right"
    const { content } = await mount()

    expect(content.getAttribute("data-side")).toBe("right")
    expect(content.getAttribute("data-align")).toBe("center")
  })

  it("writes the radix-compat sizing vars from the size middleware", async () => {
    const { content } = await mount()

    expect(content.style.getPropertyValue("--radix-popper-available-width")).toBe("111px")
    expect(content.style.getPropertyValue("--radix-popper-available-height")).toBe("222px")
    expect(content.style.getPropertyValue("--radix-popper-anchor-width")).toBe("42px")
    expect(content.style.getPropertyValue("--radix-popper-anchor-height")).toBe("24px")
  })

  it("writes --radix-popper-transform-origin from the resolved side/align", async () => {
    result.placement = "bottom-start"
    const { content } = await mount()

    // Anchor-facing edge: bottom placement puts the origin on the top edge,
    // at the align fraction (no arrow, so no arrow-centering).
    expect(content.style.getPropertyValue("--radix-popper-transform-origin")).toBe("0% 0px")

    result.placement = "top"
    const controller = application.getControllerForElementAndIdentifier(
      document.getElementById("root"), ID
    )
    await controller.reposition()

    // jsdom rects are all-zero; the browser sees "50% <height>px".
    expect(content.style.getPropertyValue("--radix-popper-transform-origin")).toBe("50% 0px")
  })

  it("toggles visibility from the hide middleware's referenceHidden", async () => {
    result.middlewareData = { hide: { referenceHidden: true } }
    const { content, controller } = await mount()

    expect(content.style.visibility).toBe("hidden")
    expect(content.style.pointerEvents).toBe("none")

    result.middlewareData = { hide: { referenceHidden: false } }
    await controller.reposition()

    expect(content.style.visibility).toBe("")
    expect(content.style.pointerEvents).toBe("")
  })

  it("positions and rotates a [data-slot=popper-arrow] target", async () => {
    result.placement = "bottom"
    result.middlewareData = { arrow: { x: 3 } }
    const { content } = await mount({ arrow: true })

    const arrowElement = content.querySelector("[data-slot=popper-arrow]")
    expect(arrowElement.style.position).toBe("absolute")
    expect(arrowElement.style.left).toBe("3px")
    expect(arrowElement.style.top).toBe("0px") // pinned to the anchor-facing edge
    expect(arrowElement.style.transform).toBe("rotate(180deg)")
    expect(arrowElement.getAttribute("data-side")).toBe("bottom")
    expect(floating.arrow).toHaveBeenCalledWith({ element: arrowElement })
  })

  it("reposition() re-runs computePosition", async () => {
    const { controller } = await mount()

    expect(floating.computePosition).toHaveBeenCalledTimes(1)
    await controller.reposition()
    expect(floating.computePosition).toHaveBeenCalledTimes(2)
  })

  // --- virtual-anchor mode (the ContextMenu contract) ---

  describe("virtual anchor (anchorPoint)", () => {
    it("floats against a zero-size VirtualElement at (x,y) with the element anchor as contextElement", async () => {
      await mount({ values: { "anchor-point": "12,34" } })

      const trigger = document.getElementById("trigger")

      for (const reference of [
        floating.autoUpdate.mock.calls[0][0],
        floating.computePosition.mock.calls[0][0]
      ]) {
        expect(reference).not.toBe(trigger)
        expect(reference.contextElement).toBe(trigger)
        expect(reference.getBoundingClientRect()).toEqual({
          x: 12, y: 34, width: 0, height: 0, top: 34, right: 12, bottom: 34, left: 12
        })
      }
    })

    it("setAnchor(x, y) writes the canonical attribute and re-runs positioning", async () => {
      const { root, controller } = await mount()

      expect(floating.computePosition.mock.calls[0][0]).toBe(document.getElementById("trigger"))
      const callsBefore = floating.computePosition.mock.calls.length

      await controller.setAnchor(512, 384)
      await nextFrame() // the value-changed restart (MutationObserver timing)

      expect(root.getAttribute(`data-${ID}-anchor-point-value`)).toBe("512,384")
      expect(floating.computePosition.mock.calls.length).toBeGreaterThan(callsBefore)

      const reference = floating.computePosition.mock.calls.at(-1)[0]
      expect(reference.getBoundingClientRect()).toMatchObject({ x: 512, y: 384, width: 0, height: 0 })

      // The re-armed autoUpdate tracks the virtual reference too.
      expect(floating.autoUpdate.mock.calls.at(-1)[0].contextElement).toBe(
        document.getElementById("trigger")
      )
    })

    it("clearing the value returns to the element anchor", async () => {
      const { controller } = await mount({ values: { "anchor-point": "12,34" } })

      controller.anchorPointValue = ""
      await nextFrame() // the value-changed restart

      const trigger = document.getElementById("trigger")
      expect(floating.autoUpdate.mock.calls.at(-1)[0]).toBe(trigger)
      expect(floating.computePosition.mock.calls.at(-1)[0]).toBe(trigger)
    })

    it("a moved point is picked up by the live-read rect without rebuilding the reference", async () => {
      const { root } = await mount({ values: { "anchor-point": "1,2" } })

      const reference = floating.autoUpdate.mock.calls[0][0]
      root.setAttribute(`data-${ID}-anchor-point-value`, "9,8")

      // autoUpdate re-reads getBoundingClientRect on every pass (contract:
      // re-anchoring while open works for free).
      expect(reference.getBoundingClientRect()).toMatchObject({ x: 9, y: 8 })
    })
  })
})
