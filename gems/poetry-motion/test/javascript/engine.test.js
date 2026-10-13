import { describe, expect, it } from "vitest"
import fs from "node:fs"
import path from "node:path"
import zlib from "node:zlib"
import { fileURLToPath } from "node:url"

import * as engine from "@poetry/motion/engine"

// The engine gate: the COMMITTED bundle (the bytes hosts load) carries the
// API the behaviors use, matches the installed packages, and stays inside
// the plan's budget.

const ROOT = path.dirname(path.dirname(path.dirname(fileURLToPath(import.meta.url))))
const ENGINE = path.join(ROOT, "app/javascript/poetry/motion-kernel/engine.js")
const BUDGET = 30 * 1024

describe("the vendored engine", () => {
  it("exports the API the behaviors use", () => {
    for (const name of ["animate", "scroll", "inView", "hover", "press", "stagger", "spring", "transform",
      "cancelFrame", "resize", "animateView"]) {
      expect(typeof engine[name], name).toBe("function")
    }
    expect(typeof engine.frame.update).toBe("function")
    expect(typeof engine.MotionGlobalConfig).toBe("object")
  })

  it("was built from the installed packages", () => {
    const installed = (name) =>
      JSON.parse(fs.readFileSync(path.join(ROOT, "node_modules", name, "package.json"), "utf8")).version
    expect(engine.KERNEL_VERSIONS).toEqual({
      motion: installed("motion"), "motion-dom": installed("motion-dom"), "motion-utils": installed("motion-utils"),
    })
  })

  it("pins motion exactly", () => {
    const pkg = JSON.parse(fs.readFileSync(path.join(ROOT, "package.json"), "utf8"))
    expect(pkg.devDependencies.motion).toMatch(/^\d+\.\d+\.\d+$/)
  })

  it(`stays within ${BUDGET / 1024} KB gzipped`, () => {
    const gzipped = zlib.gzipSync(fs.readFileSync(ENGINE), { level: 9 }).length
    expect(gzipped).toBeLessThanOrEqual(BUDGET)
  })
})
