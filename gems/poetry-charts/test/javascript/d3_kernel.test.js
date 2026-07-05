import { describe, expect, it } from "vitest"
import fs from "node:fs"
import path from "node:path"
import { fileURLToPath } from "node:url"

import {
  ticks, tickIncrement, tickStep,
  scaleLinear, scaleBand, scalePoint,
  line, area, stack,
  curveLinear, curveNatural, curveStep, curveStepBefore, curveStepAfter, curveMonotoneX,
  stackOffsetNone, stackOffsetExpand, stackOffsetDiverging,
  getNiceTickValues, getTickValuesFixedDomain,
  KERNEL_VERSIONS,
} from "../../app/javascript/poetry/charts/d3.js"

// The Phase B kernel parity gate: the COMMITTED bundle (the exact bytes
// hosts load) is run against test/fixtures/geometry_fixtures.json - the
// same ground truth the Ruby geometry port is fixture-tested against - so
// client and server geometry agree with one oracle by construction. The
// nice-ticks cases are the recharts v3.9.2 spec, 1:1 with the Ruby
// NiceTicksTest. KERNEL_VERSIONS pins the bundle to package.json.

const ROOT = path.dirname(path.dirname(path.dirname(fileURLToPath(import.meta.url))))
const FIXTURES = JSON.parse(fs.readFileSync(path.join(ROOT, "test/fixtures/geometry_fixtures.json"), "utf8"))

const CURVES = {
  linear: curveLinear, natural: curveNatural, step: curveStep,
  step_before: curveStepBefore, step_after: curveStepAfter, monotone_x: curveMonotoneX,
}

describe("the vendored kernel reproduces the committed oracle fixtures", () => {
  it("d3-array ticks / tickIncrement / tickStep", () => {
    // The fixtures went through JSON, where NaN and +-Infinity encode as
    // null - normalize the live scalars the same way before comparing.
    const jsonSafe = (v) => (typeof v === "number" && !Number.isFinite(v) ? null : v)
    for (const { args, expected } of FIXTURES.ticks) expect(ticks(...args)).toEqual(expected)
    for (const { args, expected } of FIXTURES.tick_increment) expect(jsonSafe(tickIncrement(...args))).toEqual(expected)
    for (const { args, expected } of FIXTURES.tick_step) expect(jsonSafe(tickStep(...args))).toEqual(expected)
  })

  it("scaleLinear mapping, nice, and the axis recipe", () => {
    for (const { domain, range, expected } of FIXTURES.scale_linear) {
      const s = scaleLinear().domain(domain).range(range)
      for (const [input, output] of expected) expect(s(input)).toEqual(output)
    }
    for (const { domain, count, expected } of FIXTURES.scale_linear_nice) {
      expect(scaleLinear().domain(domain).nice(count).domain()).toEqual(expected)
    }
    for (const { domain, count, expected } of FIXTURES.nice_ticks_d3) {
      expect(scaleLinear().domain(domain).nice(count).ticks(count)).toEqual(expected)
    }
  })

  it("scaleBand / scalePoint", () => {
    for (const c of FIXTURES.scale_band) {
      const s = scaleBand().domain(c.domain).range(c.range)
        .paddingInner(c.paddingInner).paddingOuter(c.paddingOuter).align(c.align)
      expect(s.step()).toEqual(c.expected.step)
      expect(s.bandwidth()).toEqual(c.expected.bandwidth)
      expect(c.domain.map((v) => s(v))).toEqual(c.expected.positions)
    }
    for (const c of FIXTURES.scale_point) {
      const s = scalePoint().domain(c.domain).range(c.range).padding(c.padding)
      expect(s.step()).toEqual(c.expected.step)
      expect(c.domain.map((v) => s(v))).toEqual(c.expected.positions)
    }
  })

  it("line and area paths across every curve, byte-for-byte", () => {
    const gapDefined = (d, i) => i !== 2
    for (const { points, curve, expected } of FIXTURES.line_paths) {
      expect(line().curve(CURVES[curve])(FIXTURES.point_sets[points])).toEqual(expected)
    }
    for (const { points, curve, expected } of FIXTURES.line_paths_gap) {
      expect(line().defined(gapDefined).curve(CURVES[curve])(FIXTURES.point_sets[points])).toEqual(expected)
    }
    for (const { points, curve, expected } of FIXTURES.area_paths) {
      expect(area().y0(120).y1((d) => d[1]).curve(CURVES[curve])(FIXTURES.point_sets[points])).toEqual(expected)
    }
    for (const { points, curve, expected } of FIXTURES.area_paths_gap) {
      expect(area().defined(gapDefined).y0(120).y1((d) => d[1]).curve(CURVES[curve])(FIXTURES.point_sets[points]))
        .toEqual(expected)
    }
  })

  it("stack offsets (none / expand / diverging)", () => {
    const OFFSETS = { none: stackOffsetNone, expand: stackOffsetExpand, diverging: stackOffsetDiverging }
    const serialize = (sz) => sz.map((s) => ({ key: s.key, index: s.index, points: s.map((p) => [p[0], p[1]]) }))
    for (const { offset, keys, expected } of FIXTURES.stack) {
      expect(serialize(stack().keys(keys).offset(OFFSETS[offset])(FIXTURES.stack_data))).toEqual(expected)
    }
    for (const { offset, keys, expected } of FIXTURES.stack_diverging) {
      expect(serialize(stack().keys(keys).offset(OFFSETS[offset])(FIXTURES.stack_diverging_data))).toEqual(expected)
    }
  })
})

// The recharts v3.9.2 getNiceTickValues spec - the same cases the Ruby
// NiceTicksTest transcribes, so both ports answer to one contract.
const INF = Infinity

const NICE_CASES = [
  [[[5, 5], 3], [4, 5, 6]],
  [[[5, 5], 4], [4, 5, 6, 7]],
  [[[-5, -5], 5], [-7, -6, -5, -4, -3]],
  [[[-5, -5], 2], [-5, -4]],
  [[[0, 0], 5], [0, 1, 2, 3, 4]],
  [[[0, 0], 4], [0, 1, 2, 3]],
  [[[0.05, 0.05], 3], [0.04, 0.05, 0.06]],
  [[[0.05, 0.05], 3, false], [-1, 0, 1]],
  [[[0.8, 0.8], 4], [0.7, 0.8, 0.9, 1]],
  [[[5.2, 5.2], 3], [4, 5, 6]],
  [[[5.2, 5.2], 3, false], [4, 5, 6]],
  [[[3.92, 3.92], 2], [3, 4]],
  [[[-0.053, -0.053], 5], [-0.08, -0.07, -0.06, -0.05, -0.04]],
  [[[-0.053, -0.053], 5, false], [-3, -2, -1, 0, 1]],
  [[[-0.832, -0.832], 4], [-1, -0.9, -0.8, -0.7]],
  [[[-5.2, -5.2], 3], [-7, -6, -5]],
  [[[-3.92, -3.92], 2], [-4, -3]],
  [[[INF, INF], 5], [INF, INF, INF, INF, INF]],
  [[[-INF, -INF], 5], [-INF, -INF, -INF, -INF, -INF]],
  [[[1, 5], 5], [1, 2, 3, 4, 5]],
  [[[-5, 95], 7], [-20, 0, 20, 40, 60, 80, 100]],
  [[[-105, -25], 6], [-120, -100, -80, -60, -40, -20]],
  [[[67, 5], 5], [80, 60, 40, 20, 0]],
  [[[67, 5], 4], [75, 50, 25, 0]],
  [[[39.9156, 42.5401], 5], [39.9, 40.6, 41.3, 42, 42.7]],
  [[[0.3885416666666666, 0.04444444444444451], 5], [0.4, 0.3, 0.2, 0.1, 0]],
  [[[-4.10389, 0.59414], 7], [-4.25, -3.4, -2.55, -1.7, -0.85, 0, 0.85]],
  [[[-4.10389, 0.59414], 7, false], [-5, -4, -3, -2, -1, 0, 1]],
  [[[0, 14], 5], [0, 4, 8, 12, 16]],
  [[[0, 1], 5], [0, 0.25, 0.5, 0.75, 1]],
  [[[0, 1e100], 6], [0, 2e99, 4e99, 6e99, 8e99, 1e100]],
  [[[-INF, INF], 5], [-INF, INF, INF, INF, INF]],
  [[[-INF, 100], 5], [-INF, -INF, -INF, -INF, 100]],
  [[[-100, INF], 5], [-100, INF, INF, INF, INF]],
  [[[0, 0.000013202017268238587], 5], [0, 0.0000035, 0.000007, 0.0000105, 0.000014]],
]

const SNAP_CASES = [
  [[[0, 14], 5], [0, 5, 10, 15, 20]],
  [[[0, 1], 5], [0, 0.25, 0.5, 0.75, 1]],
  [[[-5, 95], 7], [-20, 0, 20, 40, 60, 80, 100]],
  [[[-105, -25], 6], [-120, -100, -80, -60, -40, -20]],
  [[[67, 5], 5], [80, 60, 40, 20, 0]],
  [[[1, 5], 5], [1, 2, 3, 4, 5]],
  [[[39.9156, 42.5401], 5], [39, 40, 41, 42, 43]],
  [[[-4.10389, 0.59414], 7], [-5, -4, -3, -2, -1, 0, 1]],
  [[[0, 0.000013202017268238587], 5], [0, 0.000005, 0.00001, 0.000015, 0.00002]],
  [[[0, 1e100], 6], [0, 2e99, 4e99, 6e99, 8e99, 1e100]],
  [[[-1000, 1000], 5], [-1000, -500, 0, 500, 1000]],
]

const FIXED_SNAP_CASES = [
  [[[0, 14], 5], [0, 5, 10, 14]],
  [[[0, 1], 5], [0, 0.25, 0.5, 0.75, 1]],
  [[[-5, 95], 7], [-5, 15, 35, 55, 75, 95]],
  [[[0, 100], 6], [0, 20, 40, 60, 80, 100]],
  [[[1, 1000], 5], [1, 251, 501, 751, 1000]],
]

describe("the vendored getNiceTickValues matches the recharts spec (and so the Ruby port)", () => {
  it("auto mode", () => {
    for (const [[domain, count, allow], expected] of NICE_CASES) {
      expect(getNiceTickValues(domain, count, allow ?? true), `(${domain}, ${count}, ${allow})`).toEqual(expected)
    }
  })

  it("snap125 mode", () => {
    for (const [[domain, count], expected] of SNAP_CASES) {
      expect(getNiceTickValues(domain, count, true, "snap125"), `(${domain}, ${count})`).toEqual(expected)
    }
  })

  it("fixed-domain snap125", () => {
    for (const [[domain, count], expected] of FIXED_SNAP_CASES) {
      expect(getTickValuesFixedDomain(domain, count, true, "snap125"), `(${domain}, ${count})`).toEqual(expected)
    }
  })
})

describe("the bundle drift gate", () => {
  it("KERNEL_VERSIONS matches the installed packages", () => {
    for (const [name, version] of Object.entries(KERNEL_VERSIONS)) {
      const installed = JSON.parse(
        fs.readFileSync(path.join(ROOT, "node_modules", name, "package.json"), "utf8")
      ).version
      expect(version, name).toEqual(installed)
    }
    expect(Object.keys(KERNEL_VERSIONS).sort()).toEqual([
      "d3-array", "d3-format", "d3-interpolate", "d3-scale", "d3-shape",
      "d3-time", "d3-time-format", "decimal.js-light",
    ])
  })
})
