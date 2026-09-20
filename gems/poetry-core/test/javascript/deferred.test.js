import { beforeEach, describe, expect, it } from "vitest"
import { Application } from "@hotwired/stimulus"
import { registerPoetryControllers } from "@poetry/controllers"

// poetry--core--deferred JS-unit: failure becomes a visible, retryable
// state. What this file proves: turbo:frame-missing is intercepted
// (preventDefault - Turbo's own "Content missing" swap never runs), the
// frame reflects data-error, the placeholder hides, the error template
// stamps ONCE (a second failure doesn't duplicate it), and retry()
// restores the loading posture and re-arms src (the no-Turbo fallback
// path - real hosts get FrameElement#reload()).

const nextFrame = () => new Promise((resolve) => setTimeout(resolve, 0))

const markup = () => `
  <turbo-frame id="region" loading="lazy"
               data-controller="poetry--core--deferred"
               data-poetry--core--deferred-src-value="/fragment">
    <div id="ph" data-poetry--core--deferred-target="placeholder">loading…</div>
    <template data-poetry--core--deferred-target="error">
      <div data-slot="deferred-error">
        failed
        <button id="again" type="button"
                data-action="click->poetry--core--deferred#retry">Retry</button>
      </div>
    </template>
  </turbo-frame>`

const fail = (type = "turbo:frame-missing") => {
  const event = new CustomEvent(type, { bubbles: true, cancelable: true })
  document.getElementById("region").dispatchEvent(event)
  return event
}

describe("poetry--core--deferred", () => {
  let application

  beforeEach(async () => {
    document.body.innerHTML = markup()
    application = Application.start()
    registerPoetryControllers(application)
    await nextFrame()
    return async () => {
      document.body.replaceChildren()
      await nextFrame()
      application.stop()
    }
  })

  it("turns frame-missing into the error state and cancels Turbo's default", async () => {
    const event = fail()

    expect(event.defaultPrevented).toBe(true)
    const region = document.getElementById("region")
    expect(region.hasAttribute("data-error")).toBe(true)
    expect(document.getElementById("ph").hidden).toBe(true)
    expect(region.querySelectorAll("[data-slot=deferred-error]").length).toBe(1)
  })

  it("handles network errors and never stamps the error content twice", () => {
    fail("turbo:fetch-request-error")
    fail("turbo:fetch-request-error")

    const region = document.getElementById("region")
    expect(region.hasAttribute("data-error")).toBe(true)
    expect(region.querySelectorAll("[data-slot=deferred-error]").length).toBe(1)
  })

  it("connect arms src from the value - no fetch can predate the instance", () => {
    const region = document.getElementById("region")

    expect(region.getAttribute("src")).toBe("/fragment")
  })

  it("a 4xx/5xx frame response is cancelled and becomes the error state", () => {
    // Turbo 8 fires NO frame-missing for error responses - it promotes
    // them to a full-page visit unless before-fetch-response is cancelled.
    const region = document.getElementById("region")
    const event = new CustomEvent("turbo:before-fetch-response", {
      bubbles: true, cancelable: true, detail: { fetchResponse: { succeeded: false } }
    })
    region.dispatchEvent(event)

    expect(event.defaultPrevented).toBe(true)
    expect(region.hasAttribute("data-error")).toBe(true)
    expect(region.querySelectorAll("[data-slot=deferred-error]").length).toBe(1)

    // A successful response passes through untouched.
    const ok = new CustomEvent("turbo:before-fetch-response", {
      bubbles: true, cancelable: true, detail: { fetchResponse: { succeeded: true } }
    })
    region.dispatchEvent(ok)

    expect(ok.defaultPrevented).toBe(false)
  })

  it("retry restores the loading posture and re-arms src", async () => {
    fail()
    await nextFrame() // Stimulus binds the stamped button's action via MutationObserver
    document.getElementById("again").click()
    await nextFrame()

    const region = document.getElementById("region")
    expect(region.hasAttribute("data-error")).toBe(false)
    expect(region.querySelector("[data-slot=deferred-error]")).toBeNull()
    expect(document.getElementById("ph").hidden).toBe(false)
    expect(region.getAttribute("src")).toBe("/fragment")

    // A failure AFTER retry stamps again - the cycle is repeatable.
    fail()
    expect(region.querySelectorAll("[data-slot=deferred-error]").length).toBe(1)
  })
})
