import { describe, it, expect, beforeEach, afterEach, vi } from "vitest"
import {
  unregisteredPoetryControllers,
  checkPoetryRegistration,
  guardPoetryRegistration,
  resetPoetryRegistrationGuard
} from "@poetry/controllers/helpers/registration_guard"

// A Stimulus application's registry, as the guard reads it.
function application(...identifiers) {
  return { router: { modulesByIdentifier: new Map(identifiers.map((id) => [id, {}])) } }
}

describe("registration guard", () => {
  let warn

  beforeEach(() => {
    resetPoetryRegistrationGuard()
    warn = vi.spyOn(console, "warn").mockImplementation(() => {})
    document.body.innerHTML = `
      <div data-controller="poetry--core--dialog"></div>
      <div data-controller="poetry--core--nope host--lazy"></div>
      <div data-controller="poetry--charts--adapter"></div>`
  })

  afterEach(() => warn.mockRestore())

  it("lists poetry identifiers the application has not registered, never host ones", () => {
    const app = application("poetry--core--dialog")

    expect(unregisteredPoetryControllers(app)).toEqual(["poetry--charts--adapter", "poetry--core--nope"])
  })

  it("is empty when everything poetry-owned is registered", () => {
    const app = application("poetry--core--dialog", "poetry--core--nope", "poetry--charts--adapter")

    expect(unregisteredPoetryControllers(app)).toEqual([])
  })

  it("warns once per identifier with the identifiers in the message", () => {
    const app = application("poetry--core--dialog")

    expect(checkPoetryRegistration(app)).toEqual(["poetry--charts--adapter", "poetry--core--nope"])
    expect(warn).toHaveBeenCalledTimes(1)
    expect(warn.mock.calls[0][0]).toContain("poetry--core--nope")
    expect(warn.mock.calls[0][0]).not.toContain("host--lazy")

    expect(checkPoetryRegistration(app)).toEqual([])
    expect(warn).toHaveBeenCalledTimes(1)
  })

  it("stays quiet without a readable registry", () => {
    expect(checkPoetryRegistration({})).toEqual([])
    expect(checkPoetryRegistration(null)).toEqual([])
    expect(warn).not.toHaveBeenCalled()
  })

  it("schedules the check for a parsed document and re-runs it on turbo:load", async () => {
    const app = application("poetry--core--dialog")
    guardPoetryRegistration(app)
    await new Promise((resolve) => setTimeout(resolve, 0))
    expect(warn).toHaveBeenCalledTimes(1)

    app.router.modulesByIdentifier.set("poetry--core--nope", {})
    document.body.insertAdjacentHTML("beforeend", '<div data-controller="poetry--core--later"></div>')
    document.dispatchEvent(new Event("turbo:load"))
    expect(warn).toHaveBeenCalledTimes(2)
    expect(warn.mock.calls[1][0]).toContain("poetry--core--later")
  })
})
