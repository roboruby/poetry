// The controllers manifest: the JS-side API surface (targets / values /
// classes / methods) introspected from the REAL controller classes and
// committed at config/controllers_manifest.json. Ruby consumes it - the
// Stimulus attributes builder validates against it and the registry /
// llms.txt surface it - so a controller rename can never silently strand
// a gem-rendered data-action (the Ruby<->JS seam five of the 2026-07-01
// browser-pass bugs lived on).
//
// This test IS the drift gate. Regenerate with: npm run manifest
import { describe, it, expect } from "vitest"
import fs from "node:fs"
import path from "node:path"
import { fileURLToPath } from "node:url"
import { controllers } from "@poetry/controllers"

const MANIFEST_PATH = path.join(
  path.dirname(fileURLToPath(import.meta.url)), "../../config/controllers_manifest.json"
)

const serializeValues = (values = {}) =>
  Object.fromEntries(Object.entries(values).map(([name, definition]) => {
    const expanded = typeof definition === "function" ? { type: definition } : definition
    return [name, {
      type: expanded.type.name,
      ...(Object.hasOwn(expanded, "default") ? { default: expanded.default } : {})
    }]
  }))

const methodNames = (controller) =>
  Object.getOwnPropertyNames(controller.prototype)
    .filter((name) => name !== "constructor" && typeof controller.prototype[name] === "function")
    .sort()

const buildManifest = () =>
  Object.fromEntries(Object.entries(controllers).sort().map(([identifier, controller]) => [
    identifier,
    {
      targets: [...(controller.targets ?? [])].sort(),
      values: serializeValues(controller.values),
      classes: [...(controller.classes ?? [])].sort(),
      methods: methodNames(controller)
    }
  ]))

describe("controllers manifest", () => {
  it("config/controllers_manifest.json matches the live controller classes", () => {
    const fresh = `${JSON.stringify(buildManifest(), null, 2)}\n`

    if (process.env.MANIFEST_WRITE === "1") {
      fs.writeFileSync(MANIFEST_PATH, fresh)
      console.log(`wrote ${MANIFEST_PATH}`)
    }

    expect(fs.existsSync(MANIFEST_PATH), "missing manifest - run `npm run manifest`").toBe(true)
    expect(fs.readFileSync(MANIFEST_PATH, "utf8"), "stale manifest - run `npm run manifest` and commit").toBe(fresh)
  })
})
