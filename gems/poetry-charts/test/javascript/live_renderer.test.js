import { describe, expect, it } from "vitest"
import fs from "node:fs"
import path from "node:path"
import { fileURLToPath } from "node:url"

import { applyCartesian, displayValue } from "../../app/javascript/poetry/charts/live/renderer.js"

// The Phase B-W2 parity gate: load the SERVER render of dataset A, apply
// the CLIENT renderer with dataset B, and compare every geometry attribute
// against the SERVER render of dataset B - the live renderer is proven
// byte-equal to the Ruby engine (paths, positions, ticks, the regenerated
// tooltip payload), the same discipline as the geometry fixtures. The
// line case grows the window (6 -> 7 rows, one nil) so the
// reconcile-by-clone path and defined-gaps are covered.

const ROOT = path.dirname(path.dirname(path.dirname(fileURLToPath(import.meta.url))))
const FIXTURES = JSON.parse(fs.readFileSync(path.join(ROOT, "test/fixtures/live_fixtures.json"), "utf8"))

const GEOMETRY_ATTRS = ["d", "x", "y", "x1", "x2", "y1", "y2", "cx", "cy", "data-motion-origin"]

// A structural snapshot of everything the live renderer owns, keyed
// order-independently where the engine may reorder (active dots).
function snapshot(frame) {
  const svg = frame.querySelector('[data-slot="chart-svg"]')
  const out = {}
  const add = (key, el, { text = false } = {}) => {
    const attrs = {}
    for (const name of GEOMETRY_ATTRS) {
      if (el.hasAttribute(name)) attrs[name] = el.getAttribute(name)
    }
    if (text) attrs.text = el.textContent.trim()
    out[key] = attrs
  }

  for (const slot of ["chart-area", "chart-area-stroke", "chart-line"]) {
    for (const el of svg.querySelectorAll(`[data-slot="${slot}"]`)) add(`${slot}|${el.dataset.key}`, el)
  }
  for (const el of svg.querySelectorAll('[data-slot="chart-bar"]')) {
    add(`bar|${el.dataset.key}|${el.dataset.index}`, el)
  }
  for (const group of svg.querySelectorAll('g[data-slot="chart-dots"]')) {
    ;[...group.querySelectorAll('[data-slot="chart-dot"]')].forEach((el, i) => {
      add(`dot|${group.dataset.key}|${i}`, el)
    })
  }
  for (const el of svg.querySelectorAll('[data-slot="chart-active-dot"]')) {
    add(`active|${el.dataset.key}|${el.dataset.index}`, el)
  }

  const grid = svg.querySelector('g[data-slot="chart-grid"]')
  if (grid) {
    const lines = [...grid.querySelectorAll("line")]
    lines.filter((l) => l.getAttribute("y1") === l.getAttribute("y2"))
      .forEach((el, i) => add(`grid-h|${i}`, el))
    lines.filter((l) => l.getAttribute("y1") !== l.getAttribute("y2"))
      .forEach((el, i) => add(`grid-v|${i}`, el))
  }

  svg.querySelectorAll('g[data-slot="chart-x-axis"] text')
    .forEach((el, i) => add(`x-tick|${i}`, el, { text: true }))
  svg.querySelectorAll('g[data-slot="chart-y-axis"] text')
    .forEach((el, i) => add(`y-tick|${i}`, el, { text: true }))

  const coordinates = frame.querySelector('script[data-slot="chart-coordinates"]')
  out.coordinates = coordinates ? JSON.parse(coordinates.textContent) : null
  return out
}

function mount(html) {
  const host = document.createElement("div")
  host.innerHTML = html
  return host.firstElementChild
}

describe("the live renderer is byte-equal to the Ruby engine", () => {
  for (const testCase of FIXTURES.cases) {
    it(testCase.name, () => {
      const frame = mount(testCase.frame_a)
      const expected = mount(testCase.frame_b)

      const payload = structuredClone(testCase.payload)
      payload.spec.data = testCase.data_b
      applyCartesian(frame, payload)

      expect(snapshot(frame)).toEqual(snapshot(expected))
    })
  }
})

describe("displayValue mirrors ActiveSupport number_to_delimited", () => {
  it("delimits numerics and passes everything else through", () => {
    expect(displayValue(1234567)).toBe("1,234,567")
    expect(displayValue(1234.5678)).toBe("1,234.5678")
    expect(displayValue(-98765)).toBe("-98,765")
    expect(displayValue(90.25)).toBe("90.25")
    expect(displayValue(0)).toBe("0")
    expect(displayValue("March")).toBe("March")
    expect(displayValue(null)).toBe(null)
  })
})
