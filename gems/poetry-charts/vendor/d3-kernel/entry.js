// The @poetry/charts/d3 kernel surface: the DOM-free d3
// modules the live tier computes geometry with - the EXACT packages that
// generated test/fixtures/geometry_fixtures.json, so the client kernel and
// the Ruby geometry port share one ground truth - plus recharts' own
// getNiceTickValues (copied verbatim; v3 keeps it internal) so client
// ticks match Geometry::NiceTicks decimal-for-decimal.
//
// Not a public d3 distribution: this is an implementation detail of live
// mode behind a host-remappable importmap pin.
// Rebuild with `npm run vendor:d3`; CI drift-gates the committed bundle.

export { ticks, tickIncrement, tickStep, bisector, extent, max, min, range } from "d3-array"
export { scaleLinear, scaleBand, scalePoint, scaleTime } from "d3-scale"
export {
  line, area, stack, arc, pie,
  curveLinear, curveNatural, curveStep, curveStepBefore, curveStepAfter, curveMonotoneX,
  stackOffsetNone, stackOffsetExpand, stackOffsetDiverging, stackOrderNone,
} from "d3-shape"
export { interpolate, interpolateNumber, interpolateArray } from "d3-interpolate"
export { format } from "d3-format"
export { timeFormat, timeParse } from "d3-time-format"
export { getNiceTickValues, getTickValuesFixedDomain } from "./recharts/util/scale/getNiceTickValues"

// Injected at bundle time (vendor/d3-kernel/build.mjs): the exact package
// versions inside this bundle - the vitest drift gate compares them to
// package.json so a dependency bump can never outrun a rebuild.
export const KERNEL_VERSIONS = __KERNEL_VERSIONS__
