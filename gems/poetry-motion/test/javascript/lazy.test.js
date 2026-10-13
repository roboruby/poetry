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

  it("the entrypoint imports no controller statically", () => {
    const index = fs.readFileSync(path.join(TREE, "index.js"), "utf8")
    expect(index).not.toMatch(/^import .*_controller"/m)
    expect(index).toMatch(/import\("@poetry\/motion\/marquee_controller"\)/)
  })

  it("registers a controller only when its identifier appears", async () => {
    const { Application } = await import("@hotwired/stimulus")
    const { registerPoetryMotionControllers } = await import("@poetry/motion")
    const application = Application.start()
    const registered = []
    const register = application.register.bind(application)
    application.register = (identifier, controller) => { registered.push(identifier); register(identifier, controller) }

    document.body.innerHTML = `<div data-controller="poetry--motion--marquee"></div>`
    await registerPoetryMotionControllers(application)
    expect(registered).toEqual(["poetry--motion--marquee"])

    const later = document.createElement("span")
    later.setAttribute("data-controller", "poetry--motion--tilt-card other")
    document.body.append(later)
    for (let i = 0; i < 100 && registered.length < 2; i++) await new Promise((resolve) => setTimeout(resolve, 10))
    expect(registered).toEqual(["poetry--motion--marquee", "poetry--motion--tilt-card"])

    later.setAttribute("data-controller", "poetry--motion--tilt-card")
    await new Promise((resolve) => setTimeout(resolve, 30))
    expect(registered).toHaveLength(2)
    application.stop()
    document.body.innerHTML = ""
  })

  it("loadEngine fetches once and hands the engine to the policy", async () => {
    const { loadEngine } = await import("@poetry/motion/load_engine")
    const first = loadEngine()
    expect(loadEngine()).toBe(first)
    const engine = await first
    expect(typeof engine.animate).toBe("function")
  })
})
