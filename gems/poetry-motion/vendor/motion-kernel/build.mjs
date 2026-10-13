// Builds the committed @poetry/motion/engine bundle from
// vendor/motion-kernel/entry.js (the vendoring pattern of the charts d3
// kernel).
//
//   npm run vendor:motion          rebuild app/javascript/poetry/motion-kernel/engine.js
//   npm run vendor:motion:verify   rebuild in memory and fail on drift
//
// The build is deterministic for a given dependency set; KERNEL_VERSIONS
// is injected so the vitest gate can prove the committed bundle matches
// the installed package.
import { build } from "esbuild"
import { readFileSync, writeFileSync } from "node:fs"
import { fileURLToPath } from "node:url"
import path from "node:path"

const ROOT = path.dirname(path.dirname(path.dirname(fileURLToPath(import.meta.url))))
const OUTFILE = path.join(ROOT, "app/javascript/poetry/motion-kernel/engine.js")

const PACKAGES = ["motion", "motion-dom", "motion-utils"]
const versions = Object.fromEntries(
  PACKAGES.map((name) => [
    name,
    JSON.parse(readFileSync(path.join(ROOT, "node_modules", name, "package.json"), "utf8")).version,
  ])
)

const banner = `/*!
 * @poetry/motion/engine - the vendored animation engine, loaded on demand.
 * Bundles, unmodified:
 *   motion ${versions.motion}, motion-dom ${versions["motion-dom"]}, motion-utils ${versions["motion-utils"]}
 *     - Copyright (c) 2024 Motion B.V., MIT license (https://github.com/motiondivision/motion)
 * Rebuild: npm run vendor:motion (source: vendor/motion-kernel/).
 */`

const result = await build({
  entryPoints: [path.join(ROOT, "vendor/motion-kernel/entry.js")],
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
    console.error("DRIFT: app/javascript/poetry/motion-kernel/engine.js does not match a fresh build - " +
      "run `npm run vendor:motion` and commit.")
    process.exit(1)
  }
  console.log(`vendor:motion verified (${(fresh.length / 1024).toFixed(1)} KB, ` +
    `${Object.entries(versions).map(([k, v]) => `${k}@${v}`).join(", ")})`)
} else {
  writeFileSync(OUTFILE, fresh)
  console.log(`vendored ${OUTFILE} (${(fresh.length / 1024).toFixed(1)} KB)`)
}
