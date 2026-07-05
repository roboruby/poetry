import { describe, expect, it } from "vitest"
import fs from "node:fs"
import path from "node:path"
import { fileURLToPath } from "node:url"

import ChartTooltipController from "../../app/javascript/poetry/charts/tooltip_controller.js"
import ChartAdapterController from "../../app/javascript/poetry/charts/adapter_controller.js"

// The controllers manifest, self-drift-gating (the poetry-core
// pattern, charts-sized): the JS surface (targets / values / public
// methods) is introspected from the LIVE controller classes and committed;
// the Ruby action-contract test validates every rendered data-action /
// target token against this file. Regenerate with `npm run manifest`.

const ROOT = path.dirname(path.dirname(path.dirname(fileURLToPath(import.meta.url))))
const MANIFEST_PATH = path.join(ROOT, "config", "controllers_manifest.json")

const CONTROLLERS = {
  "poetry--charts--tooltip": ChartTooltipController,
  "poetry--charts--adapter": ChartAdapterController,
}

function publicMethods(klass) {
  return Object.getOwnPropertyNames(klass.prototype)
    .filter((name) => name !== "constructor" && !name.startsWith("#"))
    .sort()
}

function introspect() {
  return Object.fromEntries(
    Object.entries(CONTROLLERS).map(([identifier, klass]) => [
      identifier,
      {
        targets: [...(klass.targets ?? [])].sort(),
        values: Object.keys(klass.values ?? {}).sort(),
        methods: publicMethods(klass),
      },
    ])
  )
}

describe("controllers manifest", () => {
  it("matches the committed config/controllers_manifest.json", () => {
    const live = introspect()

    if (process.env.MANIFEST_WRITE === "1") {
      fs.mkdirSync(path.dirname(MANIFEST_PATH), { recursive: true })
      fs.writeFileSync(MANIFEST_PATH, `${JSON.stringify(live, null, 2)}\n`)
      return
    }

    const committed = JSON.parse(fs.readFileSync(MANIFEST_PATH, "utf8"))
    expect(live).toEqual(committed)
  })
})
