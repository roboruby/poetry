// The sector path, ported from lib/poetry/charts/polar.rb so both
// sides emit identical path strings. Angles are degrees
// counterclockwise from 3 o'clock, negated into SVG's y-down plane; the
// delta clamps at 359.999 so a full circle's endpoints never coincide.
// 4-decimal formatting matches the Ruby fmt (native JS stringification IS
// the reference Geometry.js_number emulates), so mid-sweep paths and the
// server's plain paths are byte-compatible.

const RADIAN = Math.PI / 180

const sign = (value) => (value === 0 ? 0 : value < 0 ? -1 : 1)
const fmt = (value) => String(Math.round(value * 1e4) / 1e4)

export function polarToCartesian(cx, cy, radius, angle) {
  return [cx + Math.cos(-RADIAN * angle) * radius, cy + Math.sin(-RADIAN * angle) * radius]
}

export function sectorPath(cx, cy, innerRadius, outerRadius, startAngle, endAngle) {
  const delta = sign(endAngle - startAngle) * Math.min(Math.abs(endAngle - startAngle), 359.999)
  const tempEnd = startAngle + delta
  const large = Math.abs(delta) > 180 ? 1 : 0

  const [ox0, oy0] = polarToCartesian(cx, cy, outerRadius, startAngle)
  const [ox1, oy1] = polarToCartesian(cx, cy, outerRadius, tempEnd)

  let path = `M${fmt(ox0)},${fmt(oy0)}` +
    `A${fmt(outerRadius)},${fmt(outerRadius)},0,` +
    `${large},${startAngle > tempEnd ? 1 : 0},${fmt(ox1)},${fmt(oy1)}`

  if (innerRadius > 0) {
    const [ix0, iy0] = polarToCartesian(cx, cy, innerRadius, startAngle)
    const [ix1, iy1] = polarToCartesian(cx, cy, innerRadius, tempEnd)
    path += `L${fmt(ix1)},${fmt(iy1)}` +
      `A${fmt(innerRadius)},${fmt(innerRadius)},0,` +
      `${large},${startAngle <= tempEnd ? 1 : 0},${fmt(ix0)},${fmt(iy0)}Z`
  } else {
    path += `L${fmt(cx)},${fmt(cy)}Z`
  }

  return path
}
