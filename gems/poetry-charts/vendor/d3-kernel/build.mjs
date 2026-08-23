// Builds the committed @poetry/charts/d3 kernel bundle from
// vendor/d3-kernel/entry.js (the vendoring pattern).
//
//   npm run vendor:d3          rebuild app/javascript/poetry/charts/d3.js
//   npm run vendor:d3:verify   rebuild in memory and fail on drift
//
// The build is deterministic for a given dependency set; KERNEL_VERSIONS
// is injected so the vitest gate can prove the committed bundle matches
// the installed packages.
import { build } from "esbuild"
import { readFileSync, writeFileSync } from "node:fs"
import { fileURLToPath } from "node:url"
import path from "node:path"

const ROOT = path.dirname(path.dirname(path.dirname(fileURLToPath(import.meta.url))))
const OUTFILE = path.join(ROOT, "app/javascript/poetry/charts/d3.js")

const PACKAGES = [
  "d3-array", "d3-scale", "d3-shape", "d3-interpolate", "d3-format",
  "d3-time", "d3-time-format", "decimal.js-light",
]
const versions = Object.fromEntries(
  PACKAGES.map((name) => [
    name,
    JSON.parse(readFileSync(path.join(ROOT, "node_modules", name, "package.json"), "utf8")).version,
  ])
)

const banner = `/*!
 * @poetry/charts/d3 - the vendored DOM-free geometry kernel (the opt-in live mode).
 * Bundles, unmodified:
 *   d3-array ${versions["d3-array"]}, d3-scale ${versions["d3-scale"]}, d3-shape ${versions["d3-shape"]},
 *   d3-interpolate ${versions["d3-interpolate"]}, d3-format ${versions["d3-format"]},
 *   d3-time ${versions["d3-time"]}, d3-time-format ${versions["d3-time-format"]}
 *     - Copyright 2010-2023 Mike Bostock, ISC license (https://github.com/d3)
 *   decimal.js-light ${versions["decimal.js-light"]}
 *     - Copyright Michael Mclaughlin, MIT license
 *   getNiceTickValues from recharts v3.9.2 (verbatim)
 *     - Copyright (c) Recharts Group, MIT license (https://github.com/recharts/recharts)
 * Rebuild: npm run vendor:d3 (source: vendor/d3-kernel/).
 */`

const result = await build({
  entryPoints: [path.join(ROOT, "vendor/d3-kernel/entry.js")],
  bundle: true,
  format: "esm",
  minify: true,
  legalComments: "none",
  banner: { js: banner },
  define: { __KERNEL_VERSIONS__: JSON.stringify(versions) },
  write: false,
})

const fresh = result.outputFiles[0].text

if (process.argv.includes("--verify")) {
  const committed = readFileSync(OUTFILE, "utf8")
  if (committed !== fresh) {
    console.error("DRIFT: app/javascript/poetry/charts/d3.js does not match a fresh build - run `npm run vendor:d3` and commit.")
    process.exit(1)
  }
  console.log(`vendor:d3 verified (${(fresh.length / 1024).toFixed(1)} KB, ${Object.entries(versions).map(([k, v]) => `${k}@${v}`).join(", ")})`)
} else {
  writeFileSync(OUTFILE, fresh)
  console.log(`vendored ${OUTFILE} (${(fresh.length / 1024).toFixed(1)} KB)`)
}
