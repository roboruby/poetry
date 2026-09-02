import { describe, it, expect, beforeEach, afterEach, vi } from "vitest"
import { Application, Controller } from "@hotwired/stimulus"
import { registerPoetryAgent, executeRegisteredTool, installVersionedReplace, _registrations } from "@poetry/agent"

// The bridge executes a client tool through the registrar's in-page path
// (no modelContext needed) and POSTs the result to the continue URL; the
// response's Turbo Streams render when Turbo is present.
class FakeTabs extends Controller {
  static values = { value: String }
  setValue(value) { this.valueValue = String(value); return { value: this.valueValue, changed: true } }
}

const TOOLS = [
  { name: "set_value", description: "Activate.", inputSchema: { type: "object", properties: { value: { type: "string", enum: ["overview", "pricing"] } }, required: ["value"], additionalProperties: false },
    annotations: { readOnlyHint: false, untrustedContentHint: false }, executes: "poetry--core--fake-tabs#setValue" }
]

const flush = () => new Promise((resolve) => setTimeout(resolve, 0))

const mountPage = () => {
  document.head.innerHTML = '<meta name="csrf-token" content="tok">'
  document.body.innerHTML = `
    <div id="tabs" data-controller="poetry--core--fake-tabs poetry--agent--webmcp"
         data-poetry--agent--webmcp-name-value="sections"
         data-poetry--agent--webmcp-tools-value='${JSON.stringify(TOOLS)}'></div>
    <div id="chat"></div>`
}

const bridge = (call, url = "/agent/continue") => {
  const element = document.createElement("div")
  element.id = "bridge"
  element.setAttribute("data-controller", "poetry--agent--agui-client-tool")
  element.setAttribute("data-poetry--agent--agui-client-tool-call-value", JSON.stringify(call))
  element.setAttribute("data-poetry--agent--agui-client-tool-url-value", url)
  document.getElementById("chat").append(element)
  return element
}

describe("poetry--agent--agui-client-tool", () => {
  let application

  beforeEach(async () => {
    delete document.modelContext // no WebMCP in this browser: the in-page path must still work
    mountPage()
    application = Application.start()
    application.register("poetry--core--fake-tabs", FakeTabs)
    registerPoetryAgent(application)
    await flush()
  })

  afterEach(async () => {
    application.stop()
    document.body.innerHTML = ""
    document.head.innerHTML = ""
    delete globalThis.Turbo
    vi.restoreAllMocks()
    _registrations.clear()
    await flush()
  })

  it("executes the named tool through the registrar without modelContext", async () => {
    expect(await executeRegisteredTool(application, "poetry.sections.set_value", { value: "pricing" })).toEqual({ value: "pricing", changed: true })
    expect(document.getElementById("tabs").getAttribute("data-poetry--core--fake-tabs-value-value")).toBe("pricing")
    expect(await executeRegisteredTool(application, "poetry.sections.set_value", { value: "nope" })).toMatch(/must be one of/)
    expect(await executeRegisteredTool(application, "poetry.other.open", {})).toMatch(/no registered tool named poetry\.other\.open/)
  })

  it("posts the result to the continue URL and renders the streamed answer", async () => {
    globalThis.Turbo = { StreamActions: {}, renderStreamMessage: vi.fn() }
    const fetchMock = vi.spyOn(globalThis, "fetch").mockResolvedValue(
      new Response("<turbo-stream action=\"append\" target=\"chat\"><template>x</template></turbo-stream>",
        { status: 200, headers: { "content-type": "text/vnd.turbo-stream.html" } }))
    const executed = vi.fn()
    document.addEventListener("poetry:agui:client-tool-executed", (event) => executed(event.detail))

    bridge({ toolCallId: "c1", name: "poetry.sections.set_value", args: { value: "pricing" } })
    await flush()
    await flush()

    const [url, init] = fetchMock.mock.calls[0]
    expect(url).toBe("/agent/continue")
    expect(init.method).toBe("POST")
    expect(init.headers["X-CSRF-Token"]).toBe("tok")
    expect(JSON.parse(init.body)).toEqual({ toolCallId: "c1", name: "poetry.sections.set_value", content: '{"value":"pricing","changed":true}' })
    expect(executed).toHaveBeenCalledWith(expect.objectContaining({ toolCallId: "c1" }))
    expect(globalThis.Turbo.renderStreamMessage).toHaveBeenCalledWith(expect.stringContaining("turbo-stream"))
    expect(document.getElementById("bridge").getAttribute("data-poetry--agent--agui-client-tool-done-value")).toBe("true")
  })

  it("reports a tool problem as error and runs only once", async () => {
    const fetchMock = vi.spyOn(globalThis, "fetch").mockResolvedValue(new Response("", { status: 200 }))

    const element = bridge({ toolCallId: "c2", name: "poetry.sections.set_value", args: { value: "nope" } })
    await flush()
    await flush()
    const body = JSON.parse(fetchMock.mock.calls[0][1].body)
    expect(body.error).toMatch(/must be one of/)

    // A Turbo re-render reconnects the element; the done flag keeps it inert.
    element.remove()
    document.getElementById("chat").append(element)
    await flush()
    await flush()
    expect(fetchMock).toHaveBeenCalledTimes(1)
  })

  it("installs the versioned replace stream action once when Turbo is present", () => {
    const turbo = { StreamActions: {} }
    expect(installVersionedReplace(turbo)).toBe(true)
    expect(installVersionedReplace(turbo)).toBe(false)

    document.body.innerHTML = '<div id="row" data-version="3">old</div>'
    const template = document.createElement("template")
    template.innerHTML = '<div id="row" data-version="2">stale</div>'
    turbo.StreamActions.vreplace.call({ targetElements: [document.getElementById("row")], templateContent: template.content })
    expect(document.getElementById("row").textContent).toBe("old")
    template.innerHTML = '<div id="row" data-version="4">new</div>'
    turbo.StreamActions.vreplace.call({ targetElements: [document.getElementById("row")], templateContent: template.content })
    expect(document.getElementById("row").textContent).toBe("new")
  })
})
