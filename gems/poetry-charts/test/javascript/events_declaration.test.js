// Every event a controller dispatches must appear in its OWN `static
// events` declaration, full name as emitted (the poetry-core
// pattern, charts-sized) - the manifest / registry surfaces render the
// declaration, this scan keeps it honest against the source.
import { describe, it, expect } from "vitest"
import fs from "node:fs"
import path from "node:path"
import { fileURLToPath } from "node:url"

import ChartTooltipController from "../../app/javascript/poetry/charts/tooltip_controller.js"
import ChartAdapterController from "../../app/javascript/poetry/charts/adapter_controller.js"
import ChartMotionController from "../../app/javascript/poetry/charts/motion_controller.js"
import ChartLiveController from "../../app/javascript/poetry/charts/live_controller.js"
import ChartWindowController from "../../app/javascript/poetry/charts/window_controller.js"

const CONTROLLERS = {
  "poetry--charts--tooltip": ChartTooltipController,
  "poetry--charts--adapter": ChartAdapterController,
  "poetry--charts--motion": ChartMotionController,
  "poetry--charts--live": ChartLiveController,
  "poetry--charts--window": ChartWindowController,
}

const DIR = path.join(
  path.dirname(fileURLToPath(import.meta.url)), "../../app/javascript/poetry/charts"
)

const scanDispatches = (source, eventPrefix, identifier) => {
  const lines = source.split("\n")
  const found = new Set()
  let count = 0
  lines.forEach((line, index) => {
    for (const match of line.matchAll(/this\.dispatch\(\s*"([\w:-]+)"/g)) {
      count += 1
      const window = lines.slice(index, index + 8).join("\n")
      const prefix = window.match(/prefix:\s*(EVENT_PREFIX|"[^"]*"|false)/)?.[1]
      if (prefix === "EVENT_PREFIX") found.add(`${eventPrefix}:${match[1]}`)
      else if (prefix === "false") found.add(match[1])
      else if (prefix) {
        const literal = prefix.slice(1, -1)
        found.add(literal ? `${literal}:${match[1]}` : match[1])
      } else found.add(`${identifier}:${match[1]}`)
    }
  })
  return { events: [...found].sort(), count }
}

describe("events declarations", () => {
  for (const [identifier, controller] of Object.entries(CONTROLLERS)) {
    it(`${identifier} declares exactly what it dispatches`, () => {
      const file = path.join(
        DIR, `${identifier.replace("poetry--charts--", "").replaceAll("-", "_")}_controller.js`
      )
      const source = fs.readFileSync(file, "utf8")
      const eventPrefix = source.match(/const EVENT_PREFIX = "([^"]+)"/)?.[1]
      const scanned = scanDispatches(source, eventPrefix, identifier)

      const total = (source.match(/this\.dispatch\(/g) ?? []).length
      expect(scanned.count, "dispatch with a non-literal event name").toBe(total)

      const declared = Object.hasOwn(controller, "events") ? [...controller.events].sort() : []
      expect(declared).toEqual(scanned.events)
    })
  }
})
