import { describe, it, expect, beforeEach, afterEach, vi } from "vitest"

// The page's half of the MCP Apps bridge, driven by a fake host: the
// window is the host (every message it posts is captured; every reply
// arrives as a message event whose source is the window).
window.__poetryMcpAppManual = true
const { Bridge, STRUCTURAL_TOKENS, ACCENT_TOKENS, PROTOCOL_VERSION } = await import("@poetry/agent/mcp_app")

const flush = () => new Promise((resolve) => setTimeout(resolve, 0))
const deliver = (data) => window.dispatchEvent(new MessageEvent("message", { data, source: window }))
const posted = () => window.postMessage.mock.calls.map(([message]) => message)
const lastRequest = (method) => posted().filter((m) => m.method === method).at(-1)

const HOST_CONTEXT = {
  theme: "dark",
  styles: { variables: { "--color-background-primary": "#111", "--color-text-primary": "#eee", "--color-background-inverse": "#fff", "--border-radius-md": "8px" } },
  safeAreaInsets: { top: 4, right: 0, bottom: 12, left: 0 }
}

const connect = async (bridge) => {
  const promise = bridge.connect()
  await flush()
  const init = lastRequest("ui/initialize")
  deliver({ jsonrpc: "2.0", id: init.id, result: { protocolVersion: PROTOCOL_VERSION, hostInfo: { name: "fake", version: "1" }, hostCapabilities: { serverTools: {} }, hostContext: HOST_CONTEXT } })
  return promise
}

describe("the MCP App bridge", () => {
  let bridge

  beforeEach(() => {
    document.body.innerHTML = `
      <div data-mcp-region="plans"><p>waiting</p></div>
      <button id="choose" data-mcp-tool="choose_plan" data-mcp-args='{"plan":"pro"}'>Choose</button>
      <button id="tell" data-mcp-message="I chose Pro">Tell</button>
      <button id="link" data-mcp-link="https://shop.example/pro">More</button>
      <form id="seats" data-mcp-tool="set_seats" data-mcp-args='{"plan":"pro"}'><input name="seats" value="8"><button>Save</button></form>`
    document.documentElement.removeAttribute("data-host-styles")
    document.documentElement.className = ""
    document.documentElement.removeAttribute("style")
    vi.spyOn(window, "postMessage").mockImplementation(() => {})
    bridge = new Bridge({ target: window, appInfo: { name: "test-app", version: "0" } })
  })

  afterEach(() => {
    bridge.disconnect()
    vi.restoreAllMocks()
  })

  it("initializes with the spec's handshake and follows the host context", async () => {
    const events = []
    document.addEventListener("poetry:mcp-app:connect", (event) => events.push(event.detail.hostInfo.name))
    const result = await connect(bridge)

    const init = lastRequest("ui/initialize")
    expect(init.params).toEqual({ appInfo: { name: "test-app", version: "0" }, appCapabilities: { availableDisplayModes: ["inline"] }, protocolVersion: PROTOCOL_VERSION })
    expect(posted().some((m) => m.method === "ui/notifications/initialized")).toBe(true)
    expect(result.hostInfo.name).toBe("fake")
    expect(events).toEqual(["fake"])
    expect(bridge.connected).toBe(true)
    expect(document.documentElement.classList.contains("dark")).toBe(true)
    expect(document.documentElement.style.colorScheme).toBe("dark")
    expect(document.documentElement.style.getPropertyValue("--background")).toBe("#111")
    expect(document.documentElement.style.getPropertyValue("--foreground")).toBe("#eee")
    expect(document.documentElement.style.getPropertyValue("--primary")).toBe("")
    expect(document.documentElement.style.getPropertyValue("--radius")).toBe("8px")
    expect(document.documentElement.style.getPropertyValue("--poetry-app-safe-bottom")).toBe("12px")
    expect(lastRequest("ui/notifications/size-changed").params).toEqual({ width: 0, height: 0 })
  })

  it("maps all tokens or none as the document says", async () => {
    document.documentElement.dataset.hostStyles = "all"
    await connect(bridge)

    expect(document.documentElement.style.getPropertyValue("--primary")).toBe("#fff")
    expect(Object.keys(ACCENT_TOKENS)).toContain("--primary")
    expect(Object.keys(STRUCTURAL_TOKENS)).not.toContain("--primary")

    document.documentElement.dataset.hostStyles = "none"
    bridge.applyContext({ styles: { variables: { "--color-background-primary": "#222" } } })

    expect(document.documentElement.style.getPropertyValue("--background")).toBe("")
  })

  it("applies a tool result's fragments to their regions and reports the result", async () => {
    await connect(bridge)
    const seen = []
    document.addEventListener("poetry:mcp-app:fragments", (event) => seen.push(event.detail.length))
    deliver({ jsonrpc: "2.0", method: "ui/notifications/tool-input", params: { arguments: { team_size: 8 } } })
    deliver({ jsonrpc: "2.0", method: "ui/notifications/tool-result", params: {
      content: [{ type: "text", text: "Three plans" }], structuredContent: { recommended: "pro" },
      _meta: { poetry: { fragments: [{ target: "plans", action: "replace", html: "<p>Pro</p>" }, { target: "missing", html: "x" }] } }
    } })

    expect(document.querySelector("[data-mcp-region=plans]").innerHTML).toBe("<p>Pro</p>")
    expect(seen).toEqual([2])
    bridge.applyFragment({ target: "plans", action: "append", html: "<i>+</i>" })
    bridge.applyFragment({ target: "plans", action: "prepend", html: "<b>-</b>" })

    expect(document.querySelector("[data-mcp-region=plans]").innerHTML).toBe("<b>-</b><p>Pro</p><i>+</i>")
    bridge.applyFragment({ target: "plans", action: "remove" })

    expect(document.querySelector("[data-mcp-region=plans]").innerHTML).toBe("")
  })

  it("calls a tool from a marked button and applies the answer", async () => {
    await connect(bridge)
    document.getElementById("choose").click()
    await flush()
    const call = lastRequest("tools/call")

    expect(call.params).toEqual({ name: "choose_plan", arguments: { plan: "pro" } })
    expect(document.getElementById("choose").getAttribute("aria-busy")).toBe("true")
    deliver({ jsonrpc: "2.0", id: call.id, result: { content: [], _meta: { poetry: { fragments: [{ target: "plans", html: "<p>chosen</p>" }] } } } })
    await flush()

    expect(document.querySelector("[data-mcp-region=plans]").innerHTML).toBe("<p>chosen</p>")
    expect(document.getElementById("choose").hasAttribute("aria-busy")).toBe(false)
  })

  it("sends a form's fields as the tool's arguments", async () => {
    await connect(bridge)
    document.getElementById("seats").requestSubmit()
    await flush()

    expect(lastRequest("tools/call").params).toEqual({ name: "set_seats", arguments: { plan: "pro", seats: "8" } })
  })

  it("posts a message, opens a link, and surfaces a refusal as an error event", async () => {
    await connect(bridge)
    const errors = []
    document.addEventListener("poetry:mcp-app:error", (event) => errors.push(event.detail.error.message))
    document.getElementById("tell").click()
    await flush()
    const message = lastRequest("ui/message")

    expect(message.params).toEqual({ role: "user", content: [{ type: "text", text: "I chose Pro" }] })
    deliver({ jsonrpc: "2.0", id: message.id, result: {} })
    document.getElementById("link").click()
    await flush()
    const link = lastRequest("ui/open-link")

    expect(link.params).toEqual({ url: "https://shop.example/pro" })
    deliver({ jsonrpc: "2.0", id: link.id, error: { code: -32000, message: "Link opening denied by user" } })
    await flush()

    expect(errors).toEqual(["Link opening denied by user"])
  })

  it("answers the host's requests and ignores strangers", async () => {
    await connect(bridge)
    deliver({ jsonrpc: "2.0", id: 77, method: "ui/resource-teardown", params: {} })
    deliver({ jsonrpc: "2.0", id: 78, method: "ping" })
    deliver({ jsonrpc: "2.0", id: 79, method: "ui/unknown" })
    deliver({ jsonrpc: "2.0", method: "ui/notifications/host-context-changed", params: { theme: "light" } })
    window.dispatchEvent(new MessageEvent("message", { data: { jsonrpc: "2.0", id: 80, method: "ping" }, source: null }))

    const replies = posted().filter((m) => m.id !== undefined && m.method === undefined)
    expect(replies.map((m) => m.id)).toEqual([77, 78, 79])
    expect(replies[2].error.code).toBe(-32601)
    expect(document.documentElement.classList.contains("dark")).toBe(false)
  })

  it("exposes the calls for a page's own script", async () => {
    await connect(bridge)
    const mode = bridge.requestDisplayMode("fullscreen")
    await flush()
    deliver({ jsonrpc: "2.0", id: lastRequest("ui/request-display-mode").id, result: { mode: "inline" } })

    expect((await mode).mode).toBe("inline")
    const context = bridge.updateModelContext({ content: [{ type: "text", text: "Pro selected" }] })
    await flush()
    deliver({ jsonrpc: "2.0", id: lastRequest("ui/update-model-context").id, result: {} })

    expect(await context).toEqual({})
  })
})
