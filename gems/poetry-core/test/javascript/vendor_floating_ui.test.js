import { describe, expect, it } from "vitest"

// The vendoring gate: the four vendored floating-ui ESM dists (specifiers
// rewritten to @poetry/controllers/vendor/*) must parse and expose the API
// the popper controller consumes. Versions: vendor/floating-ui/ (repo root).
describe("vendored @floating-ui modules", () => {
  it("floating_ui_dom parses and exports the popper surface", async () => {
    const dom = await import("@poetry/controllers/vendor/floating_ui_dom")

    for (const name of [
      "computePosition", "autoUpdate", "offset", "shift", "flip", "size",
      "arrow", "hide", "limitShift", "autoPlacement", "inline", "detectOverflow"
    ]) {
      expect(dom[name], name).toBeTypeOf("function")
    }

    expect(dom.platform).toBeTypeOf("object")
  })

  it("floating_ui_core / utils parse and export their surfaces", async () => {
    const core = await import("@poetry/controllers/vendor/floating_ui_core")
    expect(core.computePosition).toBeTypeOf("function")
    expect(core.rectToClientRect).toBeTypeOf("function")

    const utils = await import("@poetry/controllers/vendor/floating_ui_utils")
    expect(utils.getSide).toBeTypeOf("function")
    expect(utils.placements).toBeInstanceOf(Array)

    const utilsDom = await import("@poetry/controllers/vendor/floating_ui_utils_dom")
    expect(utilsDom.getWindow).toBeTypeOf("function")
    expect(utilsDom.getOverflowAncestors).toBeTypeOf("function")
  })

  it("computePosition runs end-to-end against jsdom elements", async () => {
    // A zero-geometry smoke run (jsdom computes no layout): proves the real
    // module graph executes, not that the coordinates are meaningful.
    const { computePosition, offset } = await import("@poetry/controllers/vendor/floating_ui_dom")

    const anchor = document.createElement("button")
    const content = document.createElement("div")
    document.body.append(anchor, content)

    const { x, y, placement, strategy } = await computePosition(anchor, content, {
      placement: "top-start",
      strategy: "fixed",
      middleware: [offset(6)]
    })

    expect(typeof x).toBe("number")
    expect(typeof y).toBe("number")
    expect(placement).toBe("top-start")
    expect(strategy).toBe("fixed")

    anchor.remove()
    content.remove()
  })
})
