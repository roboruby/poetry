import { Controller } from "@hotwired/stimulus"

// The host simulator behind the MCP App demo: the host's half of the
// bridge, over this site's own MCP server. It is a demo host, not a
// sandbox: the frame is same-origin and the CSP a real host builds from
// the resource's lists is not applied. The protocol it speaks is the
// spec's: ui/initialize answered with a host context, tool-input and
// tool-result delivered, the page's tools/call relayed to /mcp, its
// ui/message shown, its size reports honored.
const PROTOCOL_VERSION = "2026-01-26"

// This page's tokens, named the way a host names its style variables.
const TOKENS = {
  "--color-background-primary": "--background",
  "--color-text-primary": "--foreground",
  "--color-background-secondary": "--muted",
  "--color-text-secondary": "--muted-foreground",
  "--color-background-tertiary": "--accent",
  "--color-border-primary": "--border",
  "--color-border-secondary": "--input",
  "--color-ring-primary": "--ring",
  "--color-background-inverse": "--primary",
  "--color-text-inverse": "--primary-foreground",
  "--color-text-danger": "--destructive",
  "--font-sans": "--font-sans",
  "--font-mono": "--font-mono",
  "--border-radius-md": "--radius"
}

export default class extends Controller {
  static targets = ["frame", "log", "messages", "status", "teamSize"]
  static values = { endpoint: String, resource: String, tool: String }

  connect() {
    this.nextId = 1
    this.pending = new Map()
    this.onMessage = (event) => this.receive(event)
    window.addEventListener("message", this.onMessage)
    this.load()
  }

  disconnect() {
    window.removeEventListener("message", this.onMessage)
  }

  // Reads the document from the server and loads it into the frame.
  async load() {
    this.logTarget.replaceChildren()
    this.messagesTarget.replaceChildren()
    this.initialized = false
    try {
      const result = await this.rpc("resources/read", { uri: this.resourceValue })
      const html = result.contents?.[0]?.text
      this.log("host", `resources/read ${this.resourceValue} (${html?.length ?? 0} bytes)`)
      this.frameTarget.srcdoc = html
      this.status("The document is loading; the page will initialize with this host.")
    } catch (error) {
      this.status(`resources/read failed: ${error.message}`)
    }
  }

  reload() {
    this.load()
  }

  // Calls the model's tool and hands the page its input and result.
  async call(event) {
    event?.preventDefault()
    const teamSize = Number(this.teamSizeTarget.value) || null
    const args = teamSize ? { team_size: teamSize } : {}
    this.send({ jsonrpc: "2.0", method: "ui/notifications/tool-input", params: { arguments: args } })
    try {
      const result = await this.rpc("tools/call", { name: this.toolValue, arguments: args })
      this.send({ jsonrpc: "2.0", method: "ui/notifications/tool-result", params: result })
      this.status(`${this.toolValue} answered; the page applied its fragment.`)
    } catch (error) {
      this.status(`${this.toolValue} failed: ${error.message}`)
    }
  }

  // Tells the page the host's theme changed. This page's tokens only fit
  // its own theme, so a flipped host sends none and the page falls back
  // to Poetry's tokens for that theme.
  toggleTheme() {
    this.theme = this.theme === "dark" ? "light" : "dark"
    const variables = this.theme === this.pageTheme() ? this.variables() : {}
    this.send({ jsonrpc: "2.0", method: "ui/notifications/host-context-changed",
                params: { theme: this.theme, styles: { variables } } })
  }

  pageTheme() {
    return document.documentElement.classList.contains("dark") ? "dark" : "light"
  }

  // The messages the page posts.
  receive(event) {
    if (event.source !== this.frameTarget.contentWindow) return
    const message = event.data
    if (!message || message.jsonrpc !== "2.0") return
    if (message.method === undefined) return this.settle(message)
    this.log("app", message.id === undefined ? message.method : `${message.method} #${message.id}`)
    switch (message.method) {
      case "ui/initialize": return this.initialize(message)
      case "ui/notifications/initialized": this.initialized = true; return this.call()
      case "ui/notifications/size-changed": return this.resize(message.params)
      case "tools/call": return this.relay(message)
      case "resources/read": return this.relay(message)
      case "ui/message": return this.chat(message)
      case "ui/open-link": window.open(message.params?.url, "_blank", "noopener"); return this.reply(message, {})
      case "ui/update-model-context": this.log("host", "model context noted"); return this.reply(message, {})
      case "ui/request-display-mode": return this.reply(message, { mode: "inline" })
      case "notifications/message": return
      case "ping": return this.reply(message, {})
      default:
        if (message.id !== undefined) this.send({ jsonrpc: "2.0", id: message.id, error: { code: -32601, message: `Method not found: ${message.method}` } })
    }
  }

  initialize(message) {
    this.theme ||= this.pageTheme()
    this.reply(message, {
      protocolVersion: PROTOCOL_VERSION,
      hostInfo: { name: "poetry-docs-host-simulator", version: "1" },
      hostCapabilities: { serverTools: {}, serverResources: {}, logging: {}, openLinks: {} },
      hostContext: {
        theme: this.theme,
        displayMode: "inline",
        availableDisplayModes: ["inline"],
        containerDimensions: { width: this.frameTarget.clientWidth, maxHeight: 2000 },
        styles: { variables: this.variables() }
      }
    })
  }

  // The page's own tool call or resource read, relayed to the server.
  async relay(message) {
    try {
      this.reply(message, await this.rpc(message.method, message.params))
    } catch (error) {
      this.send({ jsonrpc: "2.0", id: message.id, error: { code: error.code ?? -32000, message: error.message } })
    }
  }

  chat(message) {
    const text = (message.params?.content || []).filter((part) => part.type === "text").map((part) => part.text).join(" ")
    const item = document.createElement("li")
    item.className = "rounded-md border bg-card px-3 py-2"
    item.textContent = text
    this.messagesTarget.append(item)
    this.reply(message, {})
  }

  resize(params) {
    if (params?.height) this.frameTarget.style.height = `${Math.max(120, params.height)}px`
  }

  // A JSON-RPC request to the server, answered as JSON.
  async rpc(method, params) {
    const id = this.nextId++
    this.log("host", `${method} #${id} -> /mcp`)
    const response = await fetch(this.endpointValue, {
      method: "POST",
      headers: { "content-type": "application/json", accept: "application/json" },
      body: JSON.stringify({ jsonrpc: "2.0", id, method, params })
    })
    const json = await response.json()
    if (json.error) throw Object.assign(new Error(json.error.message), { code: json.error.code })
    return json.result
  }

  settle(message) {
    this.log("app", `reply #${message.id}${message.error ? ` error ${message.error.message}` : ""}`)
  }

  reply(message, result) {
    this.send({ jsonrpc: "2.0", id: message.id, result })
  }

  send(message) {
    this.log("host", message.method ? message.method : `reply #${message.id}`)
    this.frameTarget.contentWindow?.postMessage(message, "*")
  }

  variables() {
    const computed = getComputedStyle(document.documentElement)
    return Object.fromEntries(Object.entries(TOKENS)
      .map(([name, token]) => [name, computed.getPropertyValue(token).trim()])
      .filter(([, value]) => value))
  }

  log(side, text) {
    const item = document.createElement("li")
    item.textContent = `${side === "host" ? "host" : "app "} ${text}`
    this.logTarget.append(item)
    this.logTarget.scrollTop = this.logTarget.scrollHeight
  }

  status(text) {
    this.statusTarget.textContent = text
  }
}
