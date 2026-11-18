import { describe, it, expect, beforeEach, afterEach, vi } from "vitest"
import { Application } from "@hotwired/stimulus"
import { registerPoetryAgent } from "@poetry/agent"
import { stripToolAttributes } from "@poetry/agent/webmcp_form_controller"
import { announce } from "@poetry/controllers/helpers/announce"

// The live region is poetry-core's; what matters here is what the controller says into it.
vi.mock("@poetry/controllers/helpers/announce", () => ({ acquire: vi.fn(), release: vi.fn(), announce: vi.fn() }))

const flush = () => new Promise((resolve) => setTimeout(resolve, 0))

describe("poetry--agent--webmcp-form", () => {
  let application

  beforeEach(async () => {
    document.body.innerHTML = `
      <form id="f" action="/search" method="get" toolname="find_contact" tooldescription="Find."
            data-controller="poetry--agent--webmcp-form">
        <input name="q" value="ada">
      </form>`
    // A Turbo host by default: the page catch-up is a visit, never a jsdom navigation.
    window.Turbo = { visit: vi.fn(), renderStreamMessage: vi.fn() }
    application = Application.start()
    registerPoetryAgent(application)
    await flush()
  })

  afterEach(async () => {
    await flush() // let a scheduled page catch-up run against the stub, not jsdom
    document.body.innerHTML = "" // disconnect while the observers are alive, so listeners never leak
    await flush()
    application.stop()
    delete window.Turbo
    vi.restoreAllMocks()
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

  it("answers with the marked result region of an HTML page, scripts and chrome dropped", async () => {
    const page = `<html><head><script>localStorage.getItem("x")</script><title>Docs</title></head>
      <body><nav>Home Docs</nav><main><h1>WebMCP</h1><p>intro</p>
      <div data-webmcp-result><ul><li>Combobox - components</li><li>Combobox testing - docs</li></ul></div></main>
      <footer>poetry 0.0.1</footer></body></html>`
    vi.spyOn(globalThis, "fetch").mockResolvedValue(new Response(page, { status: 200, headers: { "content-type": "text/html" } }))
    const { promise } = agentSubmit()

    expect(await promise).toBe("find_contact succeeded (200): Combobox - components Combobox testing - docs")
  })

  it("reports failures with the status and server text", async () => {
    vi.spyOn(globalThis, "fetch").mockResolvedValue(new Response("Email can't be blank", { status: 422 }))
    const { promise } = agentSubmit()

    expect(await promise).toBe("find_contact failed (422): Email can't be blank")
  })

  it("catches the page up after a GET answer: a Turbo visit to the result URL, one beat after the answer", async () => {
    window.Turbo = { visit: vi.fn(), renderStreamMessage: vi.fn() }
    vi.spyOn(globalThis, "fetch").mockResolvedValue(new Response("<p>3 results</p>", { status: 200 }))
    const { promise } = agentSubmit()

    await promise
    expect(window.Turbo.visit).not.toHaveBeenCalled() // the answer is handed to the browser first
    await flush()

    expect(window.Turbo.visit).toHaveBeenCalledWith(expect.stringMatching(/\/search\?q=ada$/), { action: "replace" })
    expect(window.Turbo.renderStreamMessage).not.toHaveBeenCalled()
  })

  it("renders a Turbo-Stream answer in place", async () => {
    window.Turbo = { visit: vi.fn(), renderStreamMessage: vi.fn() }
    const stream = '<turbo-stream action="replace" target="results"><template>ok</template></turbo-stream>'
    vi.spyOn(globalThis, "fetch").mockResolvedValue(new Response(stream, { status: 200, headers: { "content-type": "text/vnd.turbo-stream.html" } }))
    const { promise } = agentSubmit()

    await promise
    await flush()

    expect(window.Turbo.renderStreamMessage).toHaveBeenCalledWith(stream)
    expect(window.Turbo.visit).not.toHaveBeenCalled()
  })

  it("visits where a POST redirected, and stays put on a re-rendered failure", async () => {
    window.Turbo = { visit: vi.fn(), renderStreamMessage: vi.fn() }
    document.getElementById("f").setAttribute("method", "post")
    const redirected = new Response("<main>Created</main>", { status: 200, headers: { "content-type": "text/html" } })
    Object.defineProperty(redirected, "redirected", { value: true })
    Object.defineProperty(redirected, "url", { value: "http://localhost/contacts/7" })
    vi.spyOn(globalThis, "fetch").mockResolvedValue(redirected)
    let { promise } = agentSubmit()

    await promise
    await flush()
    expect(window.Turbo.visit).toHaveBeenCalledWith("http://localhost/contacts/7")

    window.Turbo.visit.mockClear()
    vi.spyOn(globalThis, "fetch").mockResolvedValue(new Response("<main>Email can't be blank</main>", { status: 422, headers: { "content-type": "text/html" } }))
    ;({ promise } = agentSubmit())

    expect(await promise).toBe("find_contact failed (422): Email can't be blank")
    await flush()
    expect(window.Turbo.visit).not.toHaveBeenCalled()
  })

  it("never parses declarative tool attributes into an inert document (the Chrome 151 renderer crash)", async () => {
    const page = `<html><body><form toolname="search_docs" tooldescription="Search." toolautosubmit>
      <input name="q" toolparamdescription="Words."></form>
      <ul data-webmcp-result><li>Combobox - components</li></ul></body></html>`
    vi.spyOn(globalThis, "fetch").mockResolvedValue(new Response(page, { status: 200, headers: { "content-type": "text/html" } }))
    const parsed = []
    const parse = DOMParser.prototype.parseFromString
    vi.spyOn(DOMParser.prototype, "parseFromString").mockImplementation(function (text, type) { parsed.push(text); return parse.call(this, text, type) })
    const { promise } = agentSubmit()

    expect(await promise).toBe("find_contact succeeded (200): Combobox - components")
    expect(parsed.join("\n")).not.toMatch(/tool(name|description|autosubmit|paramdescription)/i)
    expect(stripToolAttributes(`<form toolname="a" tooldescription='b c' toolautosubmit><input toolparamdescription=z>`))
      .toBe("<form><input>")
  })

  it("leaves a human submit untouched", () => {
    const event = new Event("submit", { cancelable: true })
    document.getElementById("f").dispatchEvent(event)

    expect(event.defaultPrevented).toBe(false)
  })
})

describe("poetry--agent--webmcp-form and the browser's tool events", () => {
  let application, context, events, listeners

  const fire = (type, toolName) => {
    const event = new Event(type)
    event.toolName = toolName
    context.dispatchEvent(event)
  }
  const form = () => document.getElementById("f")

  beforeEach(async () => {
    context = new EventTarget()
    document.modelContext = context
    events = []
    listeners = new AbortController()
    for (const type of ["poetry:webmcp:tool-activated", "poetry:webmcp:tool-cancelled"]) {
      document.addEventListener(type, (event) => events.push([type, event.detail.tool]), { signal: listeners.signal })
    }
    document.body.innerHTML = `
      <form id="f" action="/search" method="get" toolname="find_contact" tooldescription="Find."
            data-controller="poetry--agent--webmcp-form"
            data-poetry--agent--webmcp-form-activated-message-value="Filled."
            data-poetry--agent--webmcp-form-cancelled-message-value="Stopped.">
        <input name="q" value="ada">
      </form>`
    window.Turbo = { visit: vi.fn(), renderStreamMessage: vi.fn() }
    application = Application.start()
    registerPoetryAgent(application)
    await flush()
    announce.mockClear()
  })

  afterEach(async () => {
    await flush()
    document.body.innerHTML = ""
    await flush()
    application.stop()
    listeners.abort()
    delete document.modelContext
    delete window.Turbo
    vi.restoreAllMocks()
  })

  it("marks the form, tells the page and announces when an agent fills its tool", () => {
    fire("toolactivated", "find_contact")

    expect(form().getAttribute("data-webmcp-agent")).toBe("active")
    expect(events).toEqual([["poetry:webmcp:tool-activated", "find_contact"]])
    expect(announce).toHaveBeenCalledWith("Filled.")
  })

  it("ignores another tool's events", () => {
    fire("toolactivated", "other_tool")
    fire("toolcancel", "other_tool")

    expect(form().hasAttribute("data-webmcp-agent")).toBe(false)
    expect(events).toEqual([])
    expect(announce).not.toHaveBeenCalled()
  })

  it("drops the marker on the agent's cancel and says so", () => {
    fire("toolactivated", "find_contact")
    fire("toolcancel", "find_contact")

    expect(form().hasAttribute("data-webmcp-agent")).toBe(false)
    expect(events.map(([type]) => type)).toEqual(["poetry:webmcp:tool-activated", "poetry:webmcp:tool-cancelled"])
    expect(announce).toHaveBeenLastCalledWith("Stopped.")
  })

  it("keeps the marker through an agent-invoked submit and drops it once the answer is delivered", async () => {
    vi.spyOn(globalThis, "fetch").mockResolvedValue(new Response("ok", { status: 200 }))
    const event = new Event("submit", { cancelable: true })
    event.agentInvoked = true
    let answer
    event.respondWith = (promise) => { answer = promise }
    form().dispatchEvent(event)
    fire("toolactivated", "find_contact") // Chrome 156's order: the submit first, the event after

    expect(form().getAttribute("data-webmcp-agent")).toBe("active")
    await answer
    await flush()
    expect(form().hasAttribute("data-webmcp-agent")).toBe(false)
  })

  it("drops the marker at once when the person submits the filled form", () => {
    fire("toolactivated", "find_contact")
    form().dispatchEvent(new Event("submit", { cancelable: true }))

    expect(form().hasAttribute("data-webmcp-agent")).toBe(false)
  })

  it("says nothing for an autosubmit form's fill, whose answer the page shows", () => {
    form().setAttribute("toolautosubmit", "")
    fire("toolactivated", "find_contact")

    expect(form().getAttribute("data-webmcp-agent")).toBe("active")
    expect(events).toEqual([["poetry:webmcp:tool-activated", "find_contact"]])
    expect(announce).not.toHaveBeenCalled()
  })

  it("stops listening once disconnected", async () => {
    document.body.innerHTML = ""
    await flush()
    fire("toolactivated", "find_contact")

    expect(events).toEqual([])
    expect(announce).not.toHaveBeenCalled()
  })
})
