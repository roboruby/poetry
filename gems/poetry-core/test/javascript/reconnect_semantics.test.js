import { afterEach, beforeEach, describe, expect, it } from "vitest"
import { Application, Controller } from "@hotwired/stimulus"

// S1 of the behaviors plan: the per-connect scope assumes Stimulus keeps
// ONE controller instance per element and re-runs connect() each time the
// element re-enters the document - so a scope renewed in connect and torn
// down in disconnect is the whole lifecycle story, and a listener bound
// in connect through the scope's signal can never double-bind. Pinned
// here against the installed Stimulus, not the docs.

class ProbeController extends Controller {
  static instances = []

  connects = 0
  disconnects = 0

  initialize() {
    ProbeController.instances.push(this)
  }

  connect() {
    this.connects += 1
  }

  disconnect() {
    this.disconnects += 1
  }
}

const nextFrame = () => new Promise((resolve) => setTimeout(resolve, 0))

describe("Stimulus reconnect semantics (S1)", () => {
  let application

  beforeEach(async () => {
    ProbeController.instances = []
    document.body.innerHTML = `<div id="host"><div id="probe" data-controller="probe"></div></div>`
    application = Application.start()
    application.register("probe", ProbeController)
    await nextFrame()
  })

  afterEach(() => {
    application.stop()
    document.body.innerHTML = ""
  })

  it("reuses the instance and re-runs connect when the element leaves and re-enters twice", async () => {
    const host = document.getElementById("host")
    const probe = document.getElementById("probe")

    expect(ProbeController.instances).toHaveLength(1)
    const [controller] = ProbeController.instances
    expect(controller.connects).toBe(1)

    for (const round of [1, 2]) {
      probe.remove()
      await nextFrame()
      expect(controller.disconnects).toBe(round)

      host.append(probe)
      await nextFrame()
      expect(controller.connects).toBe(round + 1)
    }

    // The same instance throughout - no second controller was built.
    expect(ProbeController.instances).toHaveLength(1)
    expect(application.getControllerForElementAndIdentifier(probe, "probe")).toBe(controller)
  })

  it("does not run connect again for an element that never left the document", async () => {
    const probe = document.getElementById("probe")
    const [controller] = ProbeController.instances

    // What a morph does to an unchanged root: attributes and children
    // churn, the element itself stays put.
    probe.setAttribute("data-foo", "bar")
    probe.innerHTML = "<span>child</span>"
    await nextFrame()

    expect(controller.connects).toBe(1)
    expect(controller.disconnects).toBe(0)
  })
})
