import { describe, expect, it } from "vitest"
import { Application } from "@hotwired/stimulus"
import { controllers, registerPoetryControllers } from "@poetry/controllers"

const nextFrame = () => new Promise((resolve) => setTimeout(resolve, 0))

// The M3 DoD: a sidecar Stimulus controller auto-registers under a JS
// bundler via the npm channel's one-liner (the importmap channel serves the
// identical source through the engine's pins).
describe("registerPoetryControllers", () => {
  it("registers every shipped controller and they connect against live DOM", async () => {
    document.body.innerHTML = `<div id="subject" data-controller="poetry--core--state"></div>`

    const application = Application.start()
    registerPoetryControllers(application)
    await nextFrame()

    const subject = document.getElementById("subject")
    expect(subject.dataset.state).toBe("closed") // seeded by the Value default on connect

    subject.dispatchEvent(new CustomEvent("noop")) // sanity: element is live
    application
      .getControllerForElementAndIdentifier(subject, "poetry--core--state")
      .toggle()
    expect(subject.dataset.state).toBe("open")

    application.stop()
  })

  it("does not seed data-state when another layer already owns it", async () => {
    document.body.innerHTML = `<div id="owned" data-controller="poetry--core--state" data-state="open"></div>`

    const application = Application.start()
    registerPoetryControllers(application)
    await nextFrame()

    expect(document.getElementById("owned").dataset.state).toBe("open")
    application.stop()
  })

  it("exports the identifier map for hosts that register selectively", () => {
    expect(Object.keys(controllers)).toContain("poetry--core--state")
  })
})
