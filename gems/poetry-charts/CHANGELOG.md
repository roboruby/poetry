# Changelog

## [Unreleased]

- Polar calibration against the live ui.shadcn.com/charts render (the
   upstream comparison): the pie/radar/radial families move to the
  square 250x250 viewBox upstream's `aspect-square max-h-[250px]` blocks
  use, so recharts' absolute-px options (`innerRadius: 60`, `outerRadius:
  110`, dot `r: 4`, `+10` pop-outs, the `+24` center-label offset) mean
  the identical proportion. Legends now stack under (or over, `align:
  :top`) the chart inside the container's flex column instead of parking
  beside the SVG. Pie slices meet flush by default (`stroke_width:` opts
  back into the background-colored separators); named slice labels
  resolve through the config. Radar: the radius domain is `[0, dataMax]`
  divided evenly (rings at 25/50/75/100% - the max vertex touches the
  rim), and `with_grid fill:` tints EVERY ring, compounding toward the
  center (the fill attribute previously lost to the class's `fill-none`).
  RadialBar: the angle domain is `[0, dataMax]` exactly (nicing left a
  notch in the closing ring and cut every sweep ~2% short), insideStart
  arc labels rotate onto the sweep tangent and read right-side-up (the
  old `90 - angle` pointed them the OPPOSITE way: mirrored and upside
  down), auto grid circles ride the ring centerlines with d3-tick value
  spokes (`radial_lines:` defaults on, as recharts), and the gauge center
  number is text-4xl with true vertical centering. All 59 baselines
  re-recorded; the interaction, axe, dommy and vitest gates hold.
- Chart tokens follow upstream's current site default: a monochromatic
  ramp of Tailwind's blue-300/500/600/700/800, identical in light and
  dark (flipped in poetry-core's tokens; previews inherit).

- The dommy middle tier (`rake test:dommy`, joins the default gate): the
  real chart controllers - vendored d3 kernel and live renderer included -
  running headlessly on QuickJS. Proven there: the tooltip keyboard layer
  + sync groups, BOTH live channels (event API and the turbo-stream
  payload-script replacement) re-rendering through the kernel with the
  FLIP tween settling on the pumped rAF clock, legend rescale-on-hide,
  the window slice seam, and the adapter door's late-mount/destroy
  lifecycle. Pointer geometry (bisect, brush drag, box positioning)
  stays with the browser pass - dommy has no layout engine.
- Hosts running poetry-ui can wire the gem in one shot:
  `bin/rails g poetry:install --charts` (copies the motion stylesheet,
  registers the controllers).

- N10 W1: gem skeleton (engine, dummy host, gates bootstrap).
