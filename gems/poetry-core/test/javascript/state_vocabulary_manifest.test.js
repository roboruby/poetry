// The state-vocabulary manifest: the attribute names poetry's state layer
// can emit, introspected from the REAL helpers/state.js VOCABULARY and
// committed at config/state_vocabulary.json. Ruby consumes it - poetry-ui's
// vocabulary-drift gate asserts every data-* attribute a Style dictionary
// STYLES is an attribute something actually EMITS (the N6 W2 accordion
// chevron was a dictionary selector whose attribute had lost its writer -
// this manifest makes that bug class mechanically impossible).
//
// This test IS the drift gate. Regenerate with: npm run manifest
import { describe, it, expect } from "vitest"
import fs from "node:fs"
import path from "node:path"
import { fileURLToPath } from "node:url"
import { VOCABULARY } from "@poetry/controllers/helpers/state"

const MANIFEST_PATH = path.join(
  path.dirname(fileURLToPath(import.meta.url)), "../../config/state_vocabulary.json"
)

const buildManifest = () => {
  const attributes = new Set()
  for (const writes of Object.values(VOCABULARY)) {
    if (writes.add) attributes.add(writes.add)
    for (const removed of writes.remove) attributes.add(removed)
  }
  return {
    keys: Object.keys(VOCABULARY).sort(),
    attributes: [...attributes].sort()
  }
}

describe("state vocabulary manifest", () => {
  it("config/state_vocabulary.json matches helpers/state.js", () => {
    const fresh = `${JSON.stringify(buildManifest(), null, 2)}\n`

    if (process.env.MANIFEST_WRITE === "1") {
      fs.writeFileSync(MANIFEST_PATH, fresh)
    }

    expect(fs.readFileSync(MANIFEST_PATH, "utf8"), "drifted - run `npm run manifest`").toBe(fresh)
  })
})
