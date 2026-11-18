import { describe, it, expect, beforeEach, afterEach, vi } from "vitest"

// The host's half of the MCP Apps bridge: the SDK's wire-compat fixtures
// (a 1.x view against a 2.x host) replayed through it, and a loopback where
// Poetry's own app bridge talks to it in one window.
window.__poetryMcpAppManual = true
const { HostBridge, HostError, PROTOCOL_VERSION, buildAllowAttribute, STYLE_TOKENS } = await import("@poetry/agent/mcp_app_host")
const { Bridge } = await import("@poetry/agent/mcp_app")

const flush = () => new Promise((resolve) => setTimeout(resolve, 0))
const hostInfo = { name: "TestHost", version: "9.9.9" }
const hostCapabilities = { openLinks: {}, serverTools: {}, serverResources: {}, logging: {}, updateModelContext: {} }
const hostContext = { theme: "dark", displayMode: "inline", locale: "en-US" }

// Shaped like ext-apps 1.7.x view traffic, as the SDK's wire-compat test shapes it.
const v1View = {
  initialize: { method: "ui/initialize", params: { appCapabilities: { tools: { listChanged: true } }, appInfo: { name: "TestView", version: "1.2.3" }, protocolVersion: "2026-01-26" }, jsonrpc: "2.0", id: 0 },
  initialized: { method: "ui/notifications/initialized", jsonrpc: "2.0" },
  callTool: { method: "tools/call", params: { name: "echo", arguments: { a: 1 }, _meta: { progressToken: 6 } }, jsonrpc: "2.0", id: 6 },
  readResource: { method: "resources/read", params: { uri: "test://x" }, jsonrpc: "2.0", id: 12 },
  toolsListResult: (id) => ({ result: { tools: [{ name: "viewtool", description: "view tool", inputSchema: { type: "object", properties: { x: { type: "number" } } } }] }, jsonrpc: "2.0", id })
}

const channel = (handlers = {}) => {
  const sent = []
  const bridge = new HostBridge({ post: (m) => sent.push(m), hostInfo, hostCapabilities, hostContext, handlers })
  return { bridge, sent, since: (n) => sent.slice(n) }
}
const handshake = async (handlers = {}) => {
  let initialized = 0
  const held = channel({ ...handlers, initialized: () => initialized++ })
  held.bridge.receive(v1View.initialize)
  await flush()
  held.bridge.receive(v1View.initialized)
  await flush()
  return { ...held, initialized: () => initialized }
}

describe("the host bridge against the SDK's wire-compat fixtures", () => {
  it("sends nothing on connect: no initialize toward the view", async () => {
    const { sent } = channel()
    await flush()
    expect(sent).toEqual([])
  })

  it("answers a 1.x ui/initialize with the 1.x result shape and the same id", async () => {
    const { bridge, sent } = channel()
    bridge.receive(v1View.initialize)
    await flush()
    expect(sent).toEqual([{ jsonrpc: "2.0", id: 0, result: { protocolVersion: PROTOCOL_VERSION, hostCapabilities, hostInfo, hostContext } }])
    expect(bridge.appCapabilities).toEqual({ tools: { listChanged: true } })
    expect(bridge.appInfo).toEqual({ name: "TestView", version: "1.2.3" })
  })

  it("accepts initialized without params and never starts a handshake of its own", async () => {
    const { sent, initialized } = await handshake()
    expect(initialized()).toBe(1)
    expect(sent).toHaveLength(1)
    expect(sent.some((m) => "method" in m)).toBe(false)
  })

  it("answers a 1.x tools/call through the handler", async () => {
    const { bridge, sent, since } = await handshake({ callTool: async (params) => ({ content: [{ type: "text", text: `echo ${params.arguments?.a}` }] }) })
    const mark = sent.length
    bridge.receive(v1View.callTool)
    await flush()
    expect(since(mark)).toEqual([{ jsonrpc: "2.0", id: 6, result: { content: [{ type: "text", text: "echo 1" }] } }])
  })

  it("re-encodes a handler-thrown -32002 as -32602 without a prefix", async () => {
    const { bridge, sent, since } = await handshake({ readResource: async () => { throw new HostError(-32002, "Resource not found (host-thrown -32002)") } })
    const mark = sent.length
    bridge.receive(v1View.readResource)
    await flush()
    const [reply] = since(mark)
    expect(reply).toMatchObject({ jsonrpc: "2.0", id: 12, error: { code: -32602, message: "Resource not found (host-thrown -32002)" } })
  })

  it("rejects invalid params on a ui/* request with -32602", async () => {
    const { bridge, sent, since } = await handshake({ openLink: async () => ({}) })
    const mark = sent.length
    bridge.receive({ method: "ui/open-link", params: { url: 42 }, jsonrpc: "2.0", id: 14 })
    await flush()
    expect(since(mark)).toHaveLength(1)
    expect(since(mark)[0]).toMatchObject({ jsonrpc: "2.0", id: 14, error: { code: -32602 } })
  })

  it("lists and calls the view's tools with 1.x-shaped requests", async () => {
    const { bridge, sent, since } = await handshake()
    const mark = sent.length
    const listing = bridge.listTools({})
    await flush()
    expect(since(mark)[0]).toEqual({ jsonrpc: "2.0", method: "tools/list", id: 0 })
    bridge.receive(v1View.toolsListResult(0))
    expect((await listing).tools[0].name).toBe("viewtool")
    const calling = bridge.callTool({ name: "viewtool", arguments: { x: 7 } })
    await flush()
    expect(since(mark)[1]).toEqual({ jsonrpc: "2.0", method: "tools/call", params: { name: "viewtool", arguments: { x: 7 } }, id: 1 })
    bridge.receive({ jsonrpc: "2.0", id: 1, result: { content: [{ type: "text", text: "7" }] } })
    expect((await calling).content[0].text).toBe("7")
    expect(sent.every((m) => m.jsonrpc === "2.0")).toBe(true)
    expect(sent.some((m) => m.method === "initialize")).toBe(false)
  })

  it("refuses to speak before initialized, answers ping and unknown methods, times out and closes", async () => {
    vi.useFakeTimers()
    const { bridge, sent } = channel()
    expect(() => bridge.sendToolInput({ a: 1 })).toThrow(HostError)
    bridge.receive({ jsonrpc: "2.0", id: 2, method: "ping" })
    bridge.receive({ jsonrpc: "2.0", id: 3, method: "ui/nope" })
    await vi.runAllTimersAsync()
    expect(sent[0]).toEqual({ jsonrpc: "2.0", id: 2, result: {} })
    expect(sent[1].error.code).toBe(-32601)
    bridge.initialized = true
    const slow = expect(bridge.request("tools/list", {}, { timeout: 50 })).rejects.toMatchObject({ code: -32001 })
    await vi.advanceTimersByTimeAsync(60)
    await slow
    const dropped = bridge.request("tools/list", {})
    bridge.close()
    await expect(dropped).rejects.toMatchObject({ code: -32000 })
    vi.useRealTimers()
  })

  it("diffs host context changes and sends the tool's input, result and cancellation", async () => {
    const { bridge, sent, since } = await handshake()
    const mark = sent.length
    expect(bridge.sendHostContextChange({ theme: "dark" })).toBe(false)
    expect(bridge.sendHostContextChange({ theme: "light", displayMode: "inline" })).toBe(true)
    bridge.sendToolInput({ location: "NYC" })
    bridge.sendToolResult({ content: [{ type: "text", text: "sunny" }], isError: false })
    bridge.sendToolCancelled({ reason: "user" })
    await flush()
    expect(since(mark).map((m) => m.method)).toEqual(["ui/notifications/host-context-changed", "ui/notifications/tool-input", "ui/notifications/tool-result", "ui/notifications/tool-cancelled"])
    expect(since(mark)[0].params).toEqual({ theme: "light" })
    expect(since(mark)[1]).toEqual({ jsonrpc: "2.0", method: "ui/notifications/tool-input", params: { arguments: { location: "NYC" } } })
  })

  it("builds the allow attribute and maps the extension's style names onto Poetry's tokens", () => {
    expect(buildAllowAttribute({ camera: {}, clipboardWrite: {}, nope: {} })).toBe("camera; clipboard-write")
    expect(buildAllowAttribute(undefined)).toBe("")
    expect(STYLE_TOKENS["--color-background-primary"]).toBe("--background")
  })
})

describe("the host bridge and Poetry's app bridge in one window", () => {
  let app, host, calls

  beforeEach(() => {
    document.body.innerHTML = `<div data-mcp-region="plans"><p>waiting</p></div><button id="choose" data-mcp-tool="choose_plan" data-mcp-args='{"plan":"pro"}'>Choose</button>`
    calls = []
    // The app posts to the window (its host); the host answers through a message event whose source is the window.
    host = new HostBridge({
      post: (message) => window.dispatchEvent(new MessageEvent("message", { data: message, source: window })),
      hostInfo, hostCapabilities, hostContext,
      handlers: { callTool: async (params) => { calls.push(params); return { content: [{ type: "text", text: "chosen" }], _meta: { poetry: { fragments: [{ target: "plans", action: "replace", html: "<p>Pro chosen</p>" }] } } } } }
    })
    vi.spyOn(window, "postMessage").mockImplementation((message) => host.receive(message))
    app = new Bridge({ target: window, appInfo: { name: "loopback-app", version: "0" } })
  })

  afterEach(() => {
    app.disconnect()
    host.close()
    vi.restoreAllMocks()
  })

  it("handshakes, delivers the result's fragments, and routes the app's tool call to the host's handler", async () => {
    const result = await app.connect()
    await flush()
    expect(result.hostInfo).toEqual(hostInfo)
    expect(host.appInfo).toEqual({ name: "loopback-app", version: "0" })
    expect(host.initialized).toBe(true)
    host.sendToolInput({ team_size: 8 })
    host.sendToolResult({ content: [{ type: "text", text: "plans" }], _meta: { poetry: { fragments: [{ target: "plans", action: "replace", html: "<table><tr><td>Pro</td></tr></table>" }] } } })
    await flush()
    expect(document.querySelector("[data-mcp-region='plans']").innerHTML).toContain("<table>")
    document.querySelector("#choose").click()
    await flush()
    await flush()
    expect(calls).toEqual([{ name: "choose_plan", arguments: { plan: "pro" } }])
    expect(document.querySelector("[data-mcp-region='plans']").textContent).toBe("Pro chosen")
  })
})
