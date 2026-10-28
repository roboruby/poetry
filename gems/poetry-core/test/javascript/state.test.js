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
    expect(trigger.hasAttribute("data-panel-open")).toBe(true) // Base UI disclosure-trigger parity
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

describe("the panel size vars (Base UI's Collapsible.Panel contract)", () => {
  const HEIGHT = "--collapsible-panel-height"
  const WIDTH = "--collapsible-panel-width"
  const wait = (ms) => new Promise((resolve) => setTimeout(resolve, ms))

  async function mount(state = "closed") {
    document.body.innerHTML = `
      <div data-controller="poetry--core--state" data-poetry--core--state-state-value="${state}">
        <button data-poetry--core--state-target="trigger"
                data-action="poetry--core--state#toggle">Toggle</button>
        <div data-poetry--core--state-target="content">panel</div>
      </div>`
    const content = document.querySelector('[data-poetry--core--state-target="content"]')
    Object.defineProperty(content, "scrollHeight", { value: 120, configurable: true })
    Object.defineProperty(content, "scrollWidth", { value: 300, configurable: true })
    const application = Application.start()
    application.register("poetry--core--state", StateController)
    await Promise.resolve()
    return { application, content, trigger: document.querySelector("button") }
  }

  const ended = (element, propertyName) =>
    element.dispatchEvent(new TransitionEvent("transitionend", { propertyName, bubbles: true }))

  it("connect rests the vars at auto", async () => {
    const { application, content } = await mount("open")

    expect(content.style.getPropertyValue(HEIGHT)).toBe("auto")
    expect(content.style.getPropertyValue(WIDTH)).toBe("auto")
    application.stop()
  })

  it("open measures the panel into the vars, then rests them at auto", async () => {
    const { application, content, trigger } = await mount()

    trigger.click()
    expect(content.style.getPropertyValue(HEIGHT)).toBe("120px")
    expect(content.style.getPropertyValue(WIDTH)).toBe("300px")

    await wait(70) // no declared motion: rest after the starting-style frames
    expect(content.style.getPropertyValue(HEIGHT)).toBe("auto")
    application.stop()
  })

  it("a transition holds the measured size until its own height transitionend", async () => {
    const { application, content, trigger } = await mount()
    content.style.transitionDuration = "200ms"

    trigger.click()
    ended(content, "opacity") // another property finishing first must not cut it short
    expect(content.style.getPropertyValue(HEIGHT)).toBe("120px")

    ended(content, "height")
    expect(content.style.getPropertyValue(HEIGHT)).toBe("auto")
    application.stop()
  })

  it("close starts from the measured size and rests at auto once hidden", async () => {
    const { application, content, trigger } = await mount("open")
    content.style.transitionDuration = "200ms"

    trigger.click()
    expect(content.style.getPropertyValue(HEIGHT)).toBe("120px") // the exit's start value
    expect(content.hasAttribute("data-ending-style")).toBe(true)
    expect(content.hidden).toBe(false)

    ended(content, "height")
    expect(content.hidden).toBe(true)
    expect(content.style.getPropertyValue(HEIGHT)).toBe("auto")
    application.stop()
  })
})
