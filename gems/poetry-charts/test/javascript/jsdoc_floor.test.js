// The JSDoc floor: the ratchet for controller documentation, the shape of
// the Ruby side's yard:coverage. ESLint's jsdoc/require-jsdoc counts the
// classes and methods without a docstring; this test compares the count to
// the committed .jsdoc_floor and fails when it rises. Lower the floor after
// a documentation pass with: npm run jsdoc:floor
import { describe, it, expect } from "vitest"
import fs from "node:fs"
import path from "node:path"
import { fileURLToPath } from "node:url"
import { ESLint } from "eslint"

const ROOT = path.join(path.dirname(fileURLToPath(import.meta.url)), "../..")
const FLOOR_PATH = path.join(ROOT, ".jsdoc_floor")

describe("the JSDoc floor", () => {
  it("never rises above the committed count", async () => {
    const eslint = new ESLint({ cwd: ROOT })
    const results = await eslint.lintFiles(["app/javascript/**/*.js"])
    const count = results.reduce(
      (sum, file) => sum + file.messages.filter((m) => m.ruleId === "jsdoc/require-jsdoc").length, 0
    )
    if (process.env.JSDOC_FLOOR_WRITE === "1") {
      fs.writeFileSync(FLOOR_PATH, `${count}\n`)
      console.log(`recorded JSDoc floor: ${count}`)
      return
    }
    expect(fs.existsSync(FLOOR_PATH), ".jsdoc_floor missing - run npm run jsdoc:floor").toBe(true)
    const floor = Number(fs.readFileSync(FLOOR_PATH, "utf8").trim())
    expect(count, `${count} undocumented classes/methods (floor ${floor})`).toBeLessThanOrEqual(floor)
  }, 60_000)
})
