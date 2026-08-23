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
import { Controller } from "@hotwired/stimulus"
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

// A controller may EXTEND another (Drawer extends Dialog) -
// Stimulus merges statics up the chain at registration, so the manifest
// must too, or the subclass's inherited surface (values, targets, action
// methods) validates as unknown on the Ruby side. Child-first; stops at
// the Stimulus Controller base so framework internals stay out.
const classChain = (controller) => {
  const chain = []
  for (let klass = controller; klass && klass !== Controller; klass = Object.getPrototypeOf(klass)) {
    chain.push(klass)
  }
  return chain
}

const mergedValues = (controller) =>
  classChain(controller).reverse().reduce(
    (merged, klass) => (Object.hasOwn(klass, "values") ? { ...merged, ...klass.values } : merged),
    {}
  )

const mergedList = (controller, key) => {
  const items = new Set()
  for (const klass of classChain(controller)) {
    if (Object.hasOwn(klass, key)) for (const item of klass[key]) items.add(item)
  }
  return [...items].sort()
}

const methodNames = (controller) => {
  const names = new Set()
  for (const klass of classChain(controller)) {
    for (const name of Object.getOwnPropertyNames(klass.prototype)) {
      if (name !== "constructor" && typeof klass.prototype[name] === "function") names.add(name)
    }
  }
  return [...names].sort()
}

const buildManifest = () =>
  Object.fromEntries(Object.entries(controllers).sort().map(([identifier, controller]) => [
    identifier,
    {
      targets: mergedList(controller, "targets"),
      values: serializeValues(mergedValues(controller)),
      classes: mergedList(controller, "classes"),
      methods: methodNames(controller),
      events: mergedList(controller, "events")
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
