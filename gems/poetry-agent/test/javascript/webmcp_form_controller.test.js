import { describe, it, expect, beforeEach, afterEach, vi } from "vitest"
import { Application } from "@hotwired/stimulus"
import { registerPoetryAgent } from "@poetry/agent"

const flush = () => new Promise((resolve) => setTimeout(resolve, 0))

describe("poetry--agent--webmcp-form", () => {
  let application

  beforeEach(async () => {
    document.body.innerHTML = `
      <form id="f" action="/search" method="get" toolname="find_contact" tooldescription="Find."
            data-controller="poetry--agent--webmcp-form">
        <input name="q" value="ada">
      </form>`
    application = Application.start()
    registerPoetryAgent(application)
    await flush()
  })

  afterEach(async () => {
    application.stop()
    document.body.innerHTML = ""
    vi.restoreAllMocks()
    await flush()
  })

  const agentSubmit = () => {
    const event = new Event("submit", { cancelable: true })
    event.agentInvoked = true
    let promise
    event.respondWith = (p) => { promise = p }
    document.getElementById("f").dispatchEvent(event)
    return { event, promise }
  }

  it("answers an agent-invoked submit with the fetched outcome instead of navigating", async () => {
    const fetchMock = vi.spyOn(globalThis, "fetch").mockResolvedValue(new Response("<p>3 results</p>", { status: 200 }))
    const { event, promise } = agentSubmit()

    expect(event.defaultPrevented).toBe(true)
    expect(await promise).toBe("find_contact succeeded (200): 3 results")
    expect(fetchMock.mock.calls[0][0]).toMatch(/\/search\?q=ada$/)
    expect(fetchMock.mock.calls[0][1].method).toBe("GET")
  })

  it("reports failures with the status and server text", async () => {
    vi.spyOn(globalThis, "fetch").mockResolvedValue(new Response("Email can't be blank", { status: 422 }))
    const { promise } = agentSubmit()

    expect(await promise).toBe("find_contact failed (422): Email can't be blank")
  })

  it("leaves a human submit untouched", () => {
    const event = new Event("submit", { cancelable: true })
    document.getElementById("f").dispatchEvent(event)

    expect(event.defaultPrevented).toBe(false)
  })
})
