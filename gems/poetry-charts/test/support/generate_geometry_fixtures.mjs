// Oracle-fixture generator for poetry-charts: every expected value comes
// from the REAL d3 modules (the exact packages recharts vendors), so the
// Ruby geometry port is tested against ground truth, not our own reading.
import { ticks, tickIncrement, tickStep } from "d3-array";
import { scaleLinear, scaleBand, scalePoint } from "d3-scale";
import {
  line, area, stack,
  curveLinear, curveNatural, curveStep, curveStepBefore, curveStepAfter, curveMonotoneX,
  stackOffsetNone, stackOffsetExpand, stackOffsetDiverging,
} from "d3-shape";
import { writeFileSync } from "node:fs";

const out = {};

// --- d3-array ticks / tickIncrement / tickStep -----------------------------
const tickCases = [
  [0, 1, 10], [0, 1, 5], [0, 100, 10], [0, 97, 5], [-5, 95, 7], [1, 5, 5],
  [0, 14, 5], [-105, -25, 6], [0.001, 0.013, 5], [-1.5, 1.5, 4], [100, 200, 5],
  [200, 100, 5], [0, 0.000013202017268238587, 5], [5, 5, 5], [0, 10, 1],
  [1e6, 2e6, 8], [-0.5, 0.5, 10], [3, 97, 4],
];
out.ticks = tickCases.map(([a, b, c]) => ({ args: [a, b, c], expected: ticks(a, b, c) }));
out.tick_increment = tickCases.map(([a, b, c]) => ({ args: [a, b, c], expected: tickIncrement(a, b, c) }));
out.tick_step = tickCases.map(([a, b, c]) => ({ args: [a, b, c], expected: tickStep(a, b, c) }));

// --- scaleLinear: mapping + nice --------------------------------------------
const linearCases = [
  { domain: [0, 100], range: [0, 500], inputs: [0, 25, 50, 99.5, 100, 120, -10] },
  { domain: [0, 97], range: [250, 0], inputs: [0, 48.5, 97] },
  { domain: [-50, 50], range: [0, 300], inputs: [-50, 0, 13.7, 50] },
  { domain: [10, 10], range: [0, 100], inputs: [5, 10, 15] }, // degenerate
  { domain: [100, 0], range: [0, 400], inputs: [0, 25, 100] }, // descending
];
out.scale_linear = linearCases.map(({ domain, range, inputs }) => ({
  domain, range,
  expected: inputs.map((x) => [x, scaleLinear().domain(domain).range(range)(x)]),
}));

const niceCases = [
  { domain: [0, 97], count: 10 }, { domain: [0, 97], count: 5 },
  { domain: [0.201479, 0.996679], count: 10 }, { domain: [-5, 95], count: 7 },
  { domain: [132, 876], count: 10 }, { domain: [98, 102], count: 10 },
  { domain: [1.1, 10.9], count: 10 }, { domain: [123.456, 234.567], count: 4 },
  { domain: [97, 0], count: 10 }, // descending stays descending
];
out.scale_linear_nice = niceCases.map(({ domain, count }) => ({
  domain, count, expected: scaleLinear().domain(domain).nice(count).domain(),
}));

// nice + ticks together (the axis recipe)
out.nice_ticks_d3 = niceCases.map(({ domain, count }) => {
  const s = scaleLinear().domain(domain).nice(count);
  return { domain, count, expected: s.ticks(count) };
});

// --- scaleBand / scalePoint --------------------------------------------------
const bandCases = [
  { domain: ["a", "b", "c", "d"], range: [0, 400], paddingInner: 0, paddingOuter: 0, align: 0.5 },
  { domain: ["a", "b", "c", "d"], range: [0, 400], paddingInner: 0.2, paddingOuter: 0.1, align: 0.5 },
  { domain: ["Jan", "Feb", "Mar", "Apr", "May", "Jun"], range: [0, 552], paddingInner: 0.32, paddingOuter: 0.32, align: 0.5 },
  { domain: ["x"], range: [0, 100], paddingInner: 0.1, paddingOuter: 0.1, align: 0.5 },
  { domain: ["a", "b", "c"], range: [300, 0], paddingInner: 0.25, paddingOuter: 0.25, align: 0.5 }, // reversed range
  { domain: ["a", "b", "c"], range: [0, 300], paddingInner: 0.5, paddingOuter: 0, align: 0 },
];
out.scale_band = bandCases.map((c) => {
  const s = scaleBand().domain(c.domain).range(c.range)
    .paddingInner(c.paddingInner).paddingOuter(c.paddingOuter).align(c.align);
  return { ...c, expected: { step: s.step(), bandwidth: s.bandwidth(), positions: c.domain.map((v) => s(v)) } };
});

const pointCases = [
  { domain: ["a", "b", "c", "d"], range: [0, 300], padding: 0 },
  { domain: ["a", "b", "c", "d"], range: [0, 300], padding: 0.5 },
  { domain: ["Jan", "Feb", "Mar"], range: [10, 510], padding: 0.25 },
];
out.scale_point = pointCases.map((c) => {
  const s = scalePoint().domain(c.domain).range(c.range).padding(c.padding);
  return { ...c, expected: { step: s.step(), positions: c.domain.map((v) => s(v)) } };
});

// --- line / area paths --------------------------------------------------------
const CURVES = {
  linear: curveLinear, natural: curveNatural, step: curveStep,
  step_before: curveStepBefore, step_after: curveStepAfter, monotone_x: curveMonotoneX,
};
const pointSets = {
  simple: [[0, 80], [50, 30], [100, 55], [150, 10], [200, 70]],
  two: [[0, 10], [100, 90]],
  one: [[42, 42]],
  fractional: [[0, 66.666], [61.5, 12.345678], [123.25, 88.8], [200.125, 41.01]],
  wavy: [[0, 50], [40, 20], [80, 95], [120, 15], [160, 60], [200, 60], [240, 5]],
};
out.line_paths = [];
for (const [setName, pts] of Object.entries(pointSets)) {
  for (const [curveName, curve] of Object.entries(CURVES)) {
    out.line_paths.push({
      points: setName, curve: curveName,
      expected: line().curve(curve)(pts),
    });
  }
}
// defined-gap: drop index 2
const gapDefined = (d, i) => i !== 2;
out.line_paths_gap = Object.entries(CURVES).map(([curveName, curve]) => ({
  points: "wavy", curve: curveName,
  expected: line().defined(gapDefined).curve(curve)(pointSets.wavy),
}));
out.point_sets = pointSets;

// areas: x = p[0], y1 = p[1], y0 = constant 120
out.area_paths = [];
for (const [setName, pts] of Object.entries(pointSets)) {
  for (const [curveName, curve] of Object.entries(CURVES)) {
    out.area_paths.push({
      points: setName, curve: curveName,
      expected: area().y0(120).y1((d) => d[1]).curve(curve)(pts),
    });
  }
}
out.area_paths_gap = Object.entries(CURVES).map(([curveName, curve]) => ({
  points: "wavy", curve: curveName,
  expected: area().defined(gapDefined).y0(120).y1((d) => d[1]).curve(curve)(pointSets.wavy),
}));

// --- stack ---------------------------------------------------------------------
const stackData = [
  { month: "Jan", desktop: 186, mobile: 80, tablet: 40 },
  { month: "Feb", desktop: 305, mobile: 200, tablet: 60 },
  { month: "Mar", desktop: 237, mobile: 120, tablet: 0 },
  { month: "Apr", desktop: 73, mobile: 190, tablet: 30 },
];
const divergingData = [
  { m: "a", p: 5, q: -3, r: 2 },
  { m: "b", p: -2, q: 4, r: -1 },
  { m: "c", p: 0, q: 0, r: 3 },
];
const OFFSETS = { none: stackOffsetNone, expand: stackOffsetExpand, diverging: stackOffsetDiverging };
const serialize = (sz) => sz.map((s) => ({ key: s.key, index: s.index, points: s.map((p) => [p[0], p[1]]) }));
out.stack = Object.entries(OFFSETS).map(([name, offset]) => ({
  offset: name, keys: ["desktop", "mobile", "tablet"],
  expected: serialize(stack().keys(["desktop", "mobile", "tablet"]).offset(offset)(stackData)),
}));
out.stack_diverging = Object.entries(OFFSETS).map(([name, offset]) => ({
  offset: name, keys: ["p", "q", "r"],
  expected: serialize(stack().keys(["p", "q", "r"]).offset(offset)(divergingData)),
}));
out.stack_data = stackData;
out.stack_diverging_data = divergingData;

writeFileSync(new URL("./geometry_fixtures.json", import.meta.url), JSON.stringify(out, null, 2));
console.log("fixtures written:", Object.keys(out).join(", "));
