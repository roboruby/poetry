# The @poetry/charts/d3 kernel

The DOM-free geometry kernel poetry-charts' live tier computes with,
bundled into the committed `app/javascript/poetry/charts/d3.js` (ESM,
~26 KB gzip) behind the host-remappable `@poetry/charts/d3` importmap pin.
It is an implementation detail of live mode, not a public d3 distribution
(no poetry-d3 gem unless raw-d3 demand appears — the remappable pin
keeps that extraction non-breaking).

Contents, unmodified:

- **d3**: d3-array, d3-scale, d3-shape, d3-interpolate, d3-format,
  d3-time, d3-time-format (ISC, Mike Bostock) — the EXACT packages that
  generate `test/fixtures/geometry_fixtures.json`, so this kernel and the
  Ruby geometry port answer to one oracle.
- **decimal.js-light** (MIT, Michael Mclaughlin) — recharts' arbitrary-precision
  dependency.
- **recharts/** — `getNiceTickValues.ts` + `util/arithmetic.ts` copied
  VERBATIM from recharts v3.9.2 `src/util/scale/` (MIT, Recharts Group);
  the two sibling `.ts` files here are type-only shims at the original
  import paths so the copies bundle unmodified. This is the same algorithm
  `Poetry::Charts::Geometry::NiceTicks` transcribes to BigDecimal.

Rebuild: `npm run vendor:d3`. Drift gates: `npm run vendor:d3:verify`
(byte compare, part of `npm test`) and the KERNEL_VERSIONS check +
fixture-parity suite in `test/javascript/d3_kernel.test.js`.
