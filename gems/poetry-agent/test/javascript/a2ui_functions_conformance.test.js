import { describe, it, expect, beforeAll, afterAll } from "vitest"
import { readFileSync } from "node:fs"
import path from "node:path"
import { fileURLToPath } from "node:url"
import { load } from "js-yaml"
import { Application } from "@hotwired/stimulus"
import Surface from "@poetry/agent/a2ui_surface_controller"

// A2UI's function conformance cases (the vendored functions.yaml) run
// through the browser's copy of the checks vocabulary: the eight functions
// the surface controller evaluates as the user types. The arguments go in
// as the server writes them into the program (v1.0's spelling), the
// version as the program carries it. A case the browser leaves to the
// server (it answers null) counts as an error.
const SUITE = path.join(path.dirname(fileURLToPath(import.meta.url)), "../fixtures/a2ui/upstream/conformance/core/functions.yaml")
const BROWSER = ["required", "regex", "length", "numeric", "email", "and", "or", "not"]
// Cases the browser does not pass yet, each with what closes it. A listed
// case that starts passing fails here: the list only shrinks.
const DIVERGENCES = {}

const cases = load(readFileSync(SUITE, "utf8")).filter((c) => BROWSER.includes(c.function) && !c.surface)
const versionOf = (c) => (String(c.protocolVersion ?? "v0.9").replace(/^v(?=1)/, "") === "1.0" ? "1.0" : "v0.9")

// A case's arguments in the program's spelling: v0.9's path and call keys become @path and @call.
const programForm = (value, v1) => {
  if (Array.isArray(value)) return value.map((item) => programForm(item, v1))
  if (value === null || typeof value !== "object") return value
  return Object.fromEntries(Object.entries(value).map(([key, item]) => [!v1 && (key === "path" || key === "call") ? `@${key}` : key, programForm(item, v1)]))
}

describe("A2UI function conformance in the browser", () => {
  let application
  beforeAll(() => {
    application = Application.start()
    application.register("poetry--agent--a2ui-surface", Surface)
  })
  afterAll(() => application.stop())

  const answer = async (c) => {
    const version = versionOf(c)
    document.body.innerHTML = `<form data-controller="poetry--agent--a2ui-surface"></form>`
    const form = document.querySelector("form")
    form.setAttribute("data-poetry--agent--a2ui-surface-program-value", JSON.stringify({ version, checks: {}, inputs: {}, model: c.dataModel ?? {} }))
    await new Promise((resolve) => setTimeout(resolve, 0))
    const controller = application.getControllerForElementAndIdentifier(form, "poetry--agent--a2ui-surface")
    return controller.call(c.function, programForm(c.args ?? {}, version === "1.0"))
  }

  it("covers the browser's functions", () => expect(cases.length).toBeGreaterThan(30))

  for (const c of cases) {
    it(c.name, async () => {
      const got = await answer(c)
      const passes = c.expectError ? got === null || got === undefined : JSON.stringify(got) === JSON.stringify(c.expect)
      if (DIVERGENCES[c.name]) {
        expect(passes, `${c.name} passes now (${DIVERGENCES[c.name]}): drop it from DIVERGENCES`).toBe(false)
      } else {
        expect(passes, `${c.name}: ${JSON.stringify(got)} vs ${JSON.stringify(c.expectError ?? c.expect)}`).toBe(true)
      }
    })
  }
})
