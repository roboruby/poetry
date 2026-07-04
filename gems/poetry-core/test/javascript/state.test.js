import { describe, it, expect } from "vitest"
import { Application } from "@hotwired/stimulus"
import StateController from "@poetry/controllers/state_controller"

describe("reflection targets (the Collapsible contract)", () => {
  async function mountWithTargets(state = "closed") {
    document.body.innerHTML = `
      <div data-controller="poetry--core--state" data-poetry--core--state-state-value="${state}">
        <button data-poetry--core--state-target="trigger"
                data-action="poetry--core--state#toggle">Toggle</button>
        <div data-poetry--core--state-target="content">panel</div>
      </div>`
    const application = Application.start()
    application.register("poetry--core--state", StateController)
    await Promise.resolve()
    return application
  }

  it("mirrors aria-expanded on the trigger and hidden on the content", async () => {
    const application = await mountWithTargets("closed")
    const trigger = document.querySelector("button")
    const content = document.querySelector('[data-poetry--core--state-target="content"]')

    expect(trigger.getAttribute("aria-expanded")).toBe("false")
    expect(content.hidden).toBe(true)

    trigger.click()
    expect(trigger.getAttribute("aria-expanded")).toBe("true")
    expect(content.hidden).toBe(false)
    expect(content.hasAttribute("data-open")).toBe(true)
    expect(content.hasAttribute("data-closed")).toBe(false)

    trigger.click()
    expect(trigger.getAttribute("aria-expanded")).toBe("false")
    // presence defers hidden through animationend; jsdom reports no
    // animation, so the helper's fast path applies it synchronously.
    expect(content.hidden).toBe(true)
    application.stop()
  })

  it("works without targets exactly as before", async () => {
    document.body.innerHTML = `<div data-controller="poetry--core--state"></div>`
    const application = Application.start()
    application.register("poetry--core--state", StateController)
    await Promise.resolve()

    expect(document.querySelector("div").hasAttribute("data-closed")).toBe(true)
    application.stop()
  })
})
