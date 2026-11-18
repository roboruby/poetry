import { describe, expect, it } from "vitest"
import fs from "node:fs"
import path from "node:path"
import { fileURLToPath } from "node:url"

// The loading contract: the controllers register eagerly from the entry
// (a press in the first moments after paint reaches a live controller),
// while the engine and the kernels sit outside the pinned tree and load
// on demand, through load_engine.js alone. A static import of a kernel
// anywhere would make every page that loads the entry fetch it.

const ROOT = path.dirname(path.dirname(path.dirname(fileURLToPath(import.meta.url))))
const TREE = path.join(ROOT, "app/javascript/poetry/motion")

const files = (dir) => fs.readdirSync(dir, { withFileTypes: true }).flatMap((entry) =>
  entry.isDirectory() ? files(path.join(dir, entry.name)) : entry.name.endsWith(".js") ? [path.join(dir, entry.name)] : [])

describe("the engine loads on demand", () => {
  it("is never imported statically", () => {
    const offenders = files(TREE).filter((file) => /^\s*(import|export)[^;]*from\s+"@poetry\/motion\/engine"/m.test(fs.readFileSync(file, "utf8")))
    expect(offenders).toEqual([])
  })

  it("each kernel is imported dynamically by load_engine.js alone", () => {
    for (const kernel of ["engine", "confetti", "globe"]) {
      const dynamic = files(TREE).filter((file) => fs.readFileSync(file, "utf8").includes(`import("@poetry/motion/${kernel}")`))
      expect(dynamic.map((file) => path.relative(TREE, file)), kernel).toEqual(["load_engine.js"])
      const statically = files(TREE).filter((file) =>
        new RegExp(`^\\s*(import|export)[^;]*from\\s+"@poetry/motion/${kernel}"`, "m").test(fs.readFileSync(file, "utf8")))
      expect(statically, kernel).toEqual([])
    }
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

describe("the controllers register eagerly", () => {
  it("the entrypoint imports every controller statically and registers each one", async () => {
    const index = fs.readFileSync(path.join(TREE, "index.js"), "utf8")
    const controllers = fs.readdirSync(TREE).filter((name) => name.endsWith("_controller.js"))
    for (const name of controllers) expect(index).toMatch(new RegExp(`^import \\w+ from "@poetry/motion/${name.replace(".js", "")}"`, "m"))
    expect(index).not.toMatch(/import\("@poetry\/motion\/\w+_controller"\)/)

    const { Application } = await import("@hotwired/stimulus")
    const { registerPoetryMotionControllers, CONTROLLERS } = await import("@poetry/motion")
    const application = Application.start()
    const registered = []
    const register = application.register.bind(application)
    application.register = (identifier, controller) => { registered.push(identifier); register(identifier, controller) }

    await registerPoetryMotionControllers(application)
    expect(registered.sort()).toEqual(Object.keys(CONTROLLERS).sort())
    expect(registered).toHaveLength(controllers.length)
    application.stop()
  })
})
