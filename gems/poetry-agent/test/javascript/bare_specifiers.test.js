import { describe, it, expect } from "vitest"
import fs from "node:fs"
import path from "node:path"
import { fileURLToPath } from "node:url"

// Relative imports bypass the importmap: in an importmap host they resolve
// to undigested asset URLs that 404 and take the WHOLE import graph down
// (the docs site lost every Stimulus controller to one "./adapter.js").
// Every internal import is a bare "@poetry/agent/..." specifier, which the
// importmap pins (pin_all_from) and the npm exports map both resolve.
const dir = path.join(path.dirname(fileURLToPath(import.meta.url)), "../../app/javascript/poetry/agent")

describe("module specifiers", () => {
  it("never use relative imports", () => {
    for (const file of fs.readdirSync(dir).filter((f) => f.endsWith(".js"))) {
      const source = fs.readFileSync(path.join(dir, file), "utf8")
      const relative = [...source.matchAll(/from\s+"(\.{1,2}\/[^"]+)"/g)].map((m) => m[1])
      expect(relative, `${file} imports ${relative.join(", ")}`).toEqual([])
    }
  })
})
