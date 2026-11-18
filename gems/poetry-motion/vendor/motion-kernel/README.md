# motion-kernel

The source of `app/javascript/poetry/motion-kernel/engine.js`, the vendored
animation engine poetry-motion's behaviors load on demand.

- `entry.js` names the exports the behaviors use from the framework-free
  `motion` package (MIT). Nothing comes from Motion+, the paid package.
- `build.mjs` bundles them with esbuild into one minified ESM file with a
  version and license banner and an injected `KERNEL_VERSIONS`.
- `npm run vendor:motion` rewrites the committed file; `npm test` runs
  `vendor:motion:verify` first and fails on drift.

The engine stays out of the preloaded importmap tree: it is pinned on its
own with `preload: false`, and only `loadEngine()` imports it. The JS suite
holds it to 30 KB gzipped.

Pin `motion` exactly in package.json. It moved from 14.0.0 to 14.1.0 in a
week; an upgrade is a deliberate bump, a rebuild and a re-measure.
