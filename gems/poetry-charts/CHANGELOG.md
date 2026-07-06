# Changelog

## [Unreleased]

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
