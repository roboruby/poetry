// The controllers manifest drift gate (the poetry-core shape): the JS
// surface introspected from the real controller classes must equal the
// committed config/controllers_manifest.json that poetry-core's Builder
// validates `webmcp:` roots against. Regenerate with: npm run manifest
import { describe, it, expect } from "vitest"
import fs from "node:fs"
import path from "node:path"
import { fileURLToPath } from "node:url"
import { Controller } from "@hotwired/stimulus"
import { controllers } from "@poetry/agent"

const MANIFEST_PATH = path.join(path.dirname(fileURLToPath(import.meta.url)), "../../config/controllers_manifest.json")

const serializeValues = (values = {}) =>
  Object.fromEntries(Object.entries(values).map(([name, definition]) => {
    const expanded = typeof definition === "function" ? { type: definition } : definition
    return [name, { type: expanded.type.name, ...(Object.hasOwn(expanded, "default") ? { default: expanded.default } : {}) }]
  }))

const methods = (controller) =>
  Object.getOwnPropertyNames(controller.prototype)
    .filter((name) => name !== "constructor" && !name.startsWith("#") && !name.endsWith("ValueChanged"))
    .filter((name) => typeof controller.prototype[name] === "function")
    .sort()

// Arrow-function class fields (the form controller's `submit`) live on the
// instance, not the prototype - construct once to see them.
const instanceMethods = (controller) => {
  const instance = Object.create(controller.prototype)
  try { controller.call(instance) } catch { /* fields need the constructor; fall back below */ }
  return []
}

const introspect = () =>
  Object.fromEntries(Object.entries(controllers).map(([identifier, controller]) => [identifier, {
    targets: [...(controller.targets ?? [])].sort(),
    values: serializeValues(controller.values),
    classes: [...(controller.classes ?? [])].sort(),
    methods: [...new Set([...methods(controller), ...instanceMethods(controller), ...(controller.publicMethods ?? [])])].sort(),
    events: [...(controller.events ?? [])].sort()
  }]))

describe("controllers manifest", () => {
  it("matches the committed manifest (npm run manifest to regenerate)", () => {
    const live = introspect()
    if (process.env.MANIFEST_WRITE) fs.writeFileSync(MANIFEST_PATH, `${JSON.stringify(live, null, 2)}\n`)
    const committed = JSON.parse(fs.readFileSync(MANIFEST_PATH, "utf8"))
    expect(committed).toEqual(live)
  })

  it("covers only Stimulus controllers", () => {
    for (const controller of Object.values(controllers)) expect(controller.prototype).toBeInstanceOf(Controller)
  })
})
