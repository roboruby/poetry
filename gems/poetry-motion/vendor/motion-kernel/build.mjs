// Builds the committed kernels poetry-motion loads on demand, each from
// one entry under vendor/motion-kernel/ (the vendoring pattern of the
// charts d3 kernel):
//
//   engine.js    the motion engine (entry.js)       - motion, motion-dom, motion-utils
//   confetti.js  canvas-confetti's create()         - canvas-confetti
//   globe.js     cobe's createGlobe                  - cobe
//
//   npm run vendor:motion          rebuild app/javascript/poetry/motion-kernel/*.js
//   npm run vendor:motion:verify   rebuild in memory and fail on drift
//
// The build is deterministic for a given dependency set; KERNEL_VERSIONS
// is injected so the vitest gate can prove each bundle matches the
// installed packages.
import { build } from "esbuild"
import { readFileSync, writeFileSync } from "node:fs"
import { fileURLToPath } from "node:url"
import path from "node:path"

const ROOT = path.dirname(path.dirname(path.dirname(fileURLToPath(import.meta.url))))
const OUT = path.join(ROOT, "app/javascript/poetry/motion-kernel")
const version = (name) => JSON.parse(readFileSync(path.join(ROOT, "node_modules", name, "package.json"), "utf8")).version

const KERNELS = [
  {
    name: "engine", entry: "entry.js", packages: ["motion", "motion-dom", "motion-utils"],
    what: "the vendored animation engine, loaded on demand",
    credit: (v) => `motion ${v.motion}, motion-dom ${v["motion-dom"]}, motion-utils ${v["motion-utils"]}\n` +
      " *     - Copyright (c) 2024 Motion B.V., MIT license (https://github.com/motiondivision/motion)",
  },
  {
    name: "confetti", entry: "confetti.js", packages: ["canvas-confetti"],
    what: "the confetti effect's canvas kernel, loaded on demand",
    credit: (v) => `canvas-confetti ${v["canvas-confetti"]}\n` +
      " *     - Copyright (c) 2020, Kiril Vatev, ISC license (https://github.com/catdad/canvas-confetti)",
  },
  {
    name: "globe", entry: "globe.js", packages: ["cobe"],
    what: "the globe effect's WebGL kernel, loaded on demand",
    credit: (v) => `cobe ${v.cobe}\n` +
      " *     - Copyright (c) 2021 Shu Ding, MIT license (https://github.com/shuding/cobe)",
  },
]

const verify = process.argv.includes("--verify")
let drift = false

for (const kernel of KERNELS) {
  const versions = Object.fromEntries(kernel.packages.map((name) => [name, version(name)]))
  const banner = `/*!
 * @poetry/motion/${kernel.name} - ${kernel.what}.
 * Bundles, unmodified:
 *   ${kernel.credit(versions)}
 * Rebuild: npm run vendor:motion (source: vendor/motion-kernel/).
 */`
  const result = await build({
    entryPoints: [path.join(ROOT, "vendor/motion-kernel", kernel.entry)],
    bundle: true,
    format: "esm",
    minify: true,
    legalComments: "none",
    banner: { js: banner },
    define: { __KERNEL_VERSIONS__: JSON.stringify(versions) },
    write: false,
  })
  const fresh = result.outputFiles[0].text
  const outfile = path.join(OUT, `${kernel.name}.js`)
  const label = `${(fresh.length / 1024).toFixed(1)} KB, ${Object.entries(versions).map(([k, v]) => `${k}@${v}`).join(", ")}`

  if (verify) {
    if (readFileSync(outfile, "utf8") !== fresh) {
      console.error(`DRIFT: app/javascript/poetry/motion-kernel/${kernel.name}.js does not match a fresh build - ` +
        "run `npm run vendor:motion` and commit.")
      drift = true
    } else {
      console.log(`vendor:motion ${kernel.name} verified (${label})`)
    }
  } else {
    writeFileSync(outfile, fresh)
    console.log(`vendored ${kernel.name}.js (${label})`)
  }
}

if (drift) process.exit(1)
