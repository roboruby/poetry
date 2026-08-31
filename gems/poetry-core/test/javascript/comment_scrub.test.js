// Comments in the shipped JS carry poetry's rules, never other
// libraries' names - attribution lives in THIRD_PARTY_NOTICES.md alone,
// and adapted files carry the generic pointer sentence (the scrubbed-
// comments convention). This scan holds the ban. Only COMMENT TEXT is
// inspected, so code identifiers (e.g. the --radix-* compatibility var
// names the select controller writes) stay legal.
import { describe, expect, it } from "vitest"
import fs from "node:fs"
import path from "node:path"
import { fileURLToPath } from "node:url"

const ROOT = path.join(
  path.dirname(fileURLToPath(import.meta.url)), "../../app/javascript/poetry/core"
)

const BANNED = /\b(Radix|Base ?UI|shadcn|Mantine|react-day-picker|react-aria|kumo|Embla|recharts|React)\b/

const files = []
const walk = (dir) => {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name)
    if (entry.isDirectory()) {
      if (entry.name !== "vendor") walk(full)
    } else if (entry.name.endsWith(".js")) {
      files.push(full)
    }
  }
}
walk(ROOT)

// Comment text only: /* */ blocks plus // to end-of-line (a :// skips
// URLs). A tripwire, not a parser - a false positive fails loudly at
// authoring time and is easy to see.
const commentsOf = (source) => {
  const comments = []
  for (const match of source.matchAll(/\/\*[\s\S]*?\*\//g)) comments.push(match[0])
  for (const match of source.matchAll(/(?:^|[^:])\/\/(.*)$/gm)) comments.push(match[1])
  return comments
}

describe("comment scrub", () => {
  for (const file of files) {
    it(`${path.relative(ROOT, file)} comments name no third-party libraries`, () => {
      const offenders = commentsOf(fs.readFileSync(file, "utf8"))
        .filter((comment) => BANNED.test(comment))
      expect(offenders).toEqual([])
    })
  }
})
