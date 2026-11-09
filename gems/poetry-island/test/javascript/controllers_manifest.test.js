import { describe, expect, it } from "vitest"
import fs from "node:fs"
import path from "node:path"
import { fileURLToPath } from "node:url"

import IslandController from "../../app/javascript/poetry/island/island_controller.js"
import { mergedDocs, withDocs } from "./support/controller_docs.js"

// The controllers manifest, self-drift-gating (the poetry-motion pattern):
// targets, values, public methods and events introspected from the live
// controller class and committed; the component's use_stimulus declaration
// validates against it at class load. Regenerate with `npm run manifest`.

const ROOT = path.dirname(path.dirname(path.dirname(fileURLToPath(import.meta.url))))
const MANIFEST_PATH = path.join(ROOT, "config", "controllers_manifest.json")
const FILE = path.join(ROOT, "app/javascript/poetry/island/island_controller.js")

const CONTROLLERS = { "poetry--island--island": IslandController }

const publicMethods = (klass) =>
  Object.getOwnPropertyNames(klass.prototype).filter((name) => name !== "constructor" && !name.startsWith("#")).sort()

const serializeValues = (values = {}) =>
  Object.fromEntries(Object.entries(values).map(([name, definition]) => {
    const expanded = typeof definition === "function" ? { type: definition } : definition
    return [name, {
      type: expanded.type.name,
      ...(Object.hasOwn(expanded, "default") ? { default: expanded.default } : {})
    }]
  }))

const introspect = () => Object.fromEntries(
  Object.entries(CONTROLLERS).map(([identifier, klass]) => [
    identifier,
    withDocs({
      targets: [...(klass.targets ?? [])].sort(),
      values: serializeValues(klass.values),
      methods: publicMethods(klass),
      events: [...(klass.events ?? [])].sort(),
    }, mergedDocs([FILE])),
  ])
)

describe("controllers manifest", () => {
  it("matches the committed config/controllers_manifest.json", () => {
    const live = introspect()

    if (process.env.MANIFEST_WRITE === "1") {
      fs.writeFileSync(MANIFEST_PATH, `${JSON.stringify(live, null, 2)}\n`)
      return
    }

    expect(live).toEqual(JSON.parse(fs.readFileSync(MANIFEST_PATH, "utf8")))
  })

  it("the controller is registered by the package entrypoint", () => {
    const index = fs.readFileSync(path.join(ROOT, "app/javascript/poetry/island/index.js"), "utf8")
    expect(index).toContain(`"poetry--island--island"`)
  })
})
