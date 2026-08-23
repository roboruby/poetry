// Every event a controller dispatches must appear in its OWN `static
// events` declaration, full name as emitted - the manifest / registry /
// llms surfaces render the declaration, this scan keeps it honest
// against the source. Options are read from the 8 lines following each
// dispatch call (calls in this codebase are short); a dispatch with a
// non-literal event name fails the count check on purpose - give it a
// literal, or extend this scan alongside it.
import { describe, it, expect } from "vitest"
import fs from "node:fs"
import path from "node:path"
import { fileURLToPath } from "node:url"
import { controllers } from "@poetry/controllers"

const DIR = path.join(
  path.dirname(fileURLToPath(import.meta.url)), "../../app/javascript/poetry/core"
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
  for (const [identifier, controller] of Object.entries(controllers)) {
    it(`${identifier} declares exactly what it dispatches`, () => {
      const file = path.join(
        DIR, `${identifier.replace("poetry--core--", "").replaceAll("-", "_")}_controller.js`
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
