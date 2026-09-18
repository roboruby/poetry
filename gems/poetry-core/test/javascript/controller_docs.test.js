import { describe, it, expect } from "vitest"
import fs from "node:fs"
import os from "node:os"
import path from "node:path"
import { harvestDocs, withDocs, commentText } from "./support/controller_docs.js"

const SOURCE = `import { Controller } from "@hotwired/stimulus"

// The purpose, written as line comments
// across two lines.
//
// A second paragraph.
export default class extends Controller {
  static targets = ["dialog"]
  static values = {
    // Set false to keep it open.
    dismissible: { type: Boolean, default: true },
    hotkey: { type: String, default: "" },
    // The delay
    // in milliseconds.
    delay: Number
  }

  /**
   * Opens the dialog.
   *
   * @param {Event} [event] the click
   */
  open(event) {}

  // not JSDoc
  close() {}

  #hidden() {}
}
`

describe("the controller docs harvest", () => {
  it("reads the class purpose, the value comments and the method summaries", () => {
    const file = path.join(fs.mkdtempSync(path.join(os.tmpdir(), "docs-")), "x_controller.js")
    fs.writeFileSync(file, SOURCE)
    const docs = harvestDocs(file)

    expect(docs.doc).toBe("The purpose, written as line comments across two lines.\n\nA second paragraph.")
    expect(docs.values).toEqual({ dismissible: "Set false to keep it open.", delay: "The delay in milliseconds." })
    expect(docs.methods).toEqual({ open: "Opens the dialog." })
  })

  it("folds the docs into a manifest entry, present only where prose exists", () => {
    const entry = { targets: [], values: { dismissible: { type: "Boolean", default: true }, hotkey: { type: "String" } },
                    classes: [], methods: ["close", "open"], events: [] }
    const folded = withDocs(entry, { doc: "Purpose.", values: { dismissible: "Meaning." }, methods: { open: "Opens." } })

    expect(folded.doc).toBe("Purpose.")
    expect(folded.values.dismissible).toEqual({ type: "Boolean", default: true, doc: "Meaning." })
    expect(folded.values.hotkey).toEqual({ type: "String" })
    expect(folded.method_docs).toEqual({ open: "Opens." })
    expect(Object.keys(folded)).toEqual(["doc", "targets", "values", "classes", "methods", "events", "method_docs"])
  })

  it("strips block markers and keeps paragraphs", () => {
    expect(commentText([{ type: "Block", value: "*\n   * One line.\n   *\n   * Two.\n   " }])).toBe("One line.\n\nTwo.")
  })
})
