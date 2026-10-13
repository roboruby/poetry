import { describe, expect, it } from "vitest"
import fs from "node:fs"
import path from "node:path"
import { fileURLToPath } from "node:url"

// The lazy-loading contract: the engine sits outside the pinned tree, and
// only load_engine.js imports it, dynamically. A static import anywhere
// would make every page that loads the motion controllers fetch it.

const ROOT = path.dirname(path.dirname(path.dirname(fileURLToPath(import.meta.url))))
const TREE = path.join(ROOT, "app/javascript/poetry/motion")

const files = (dir) => fs.readdirSync(dir, { withFileTypes: true }).flatMap((entry) =>
  entry.isDirectory() ? files(path.join(dir, entry.name)) : entry.name.endsWith(".js") ? [path.join(dir, entry.name)] : [])

describe("the engine loads on demand", () => {
  it("is never imported statically", () => {
    const offenders = files(TREE).filter((file) => /^\s*(import|export)[^;]*from\s+"@poetry\/motion\/engine"/m.test(fs.readFileSync(file, "utf8")))
    expect(offenders).toEqual([])
  })

  it("is imported dynamically by load_engine.js alone", () => {
    const dynamic = files(TREE).filter((file) => fs.readFileSync(file, "utf8").includes('import("@poetry/motion/engine")'))
    expect(dynamic.map((file) => path.relative(TREE, file))).toEqual(["load_engine.js"])
  })

  it("lives outside the pinned tree", () => {
    expect(fs.existsSync(path.join(TREE, "engine.js"))).toBe(false)
    expect(fs.existsSync(path.join(ROOT, "app/javascript/poetry/motion-kernel/engine.js"))).toBe(true)
  })

  it("internal imports use the package specifier", () => {
    const relative = files(TREE).filter((file) => /^import .* from "\.\.?\//m.test(fs.readFileSync(file, "utf8")))
    expect(relative).toEqual([])
  })

  it("loadEngine fetches once and hands the engine to the policy", async () => {
    const { loadEngine } = await import("@poetry/motion/load_engine")
    const first = loadEngine()
    expect(loadEngine()).toBe(first)
    const engine = await first
    expect(typeof engine.animate).toBe("function")
  })
})
