import { Controller } from "@hotwired/stimulus"
import { HostBridge, HostError, SANDBOX_PROXY_READY, SANDBOX_RESOURCE_READY, buildAllowAttribute, styleVariables } from "@poetry/agent/mcp_app_host"

/**
 * The frame another server's MCP App renders in, and the host's half of
 * the bridge. The element carries the call (server, tool, input, result,
 * the app's resource) and where the sandbox page and the RPC endpoint
 * are; the controller reads the app's HTML through the endpoint, mounts
 * the sandbox proxy frame (on the apps origin, or as an opaque frame of
 * the page's own in the inline mode), answers `ui/initialize` with the
 * page's theme and tokens, delivers the input and the result, sends the
 * app's own requests to the endpoint, resizes to what the app reports,
 * and tears the app down when the element leaves.
 *
 * What the page hears: `poetry:mcp-app-host:connect` (the app's info),
 * `poetry:mcp-app-host:message` (a message for the chat, `detail.params`),
 * `poetry:mcp-app-host:context` (a model-context update), and
 * `poetry:mcp-app-host:display-mode` (a request; the handler may set
 * `detail.mode` to grant one; `inline` otherwise), and with `debug`,
 * `poetry:mcp-app-host:trace` for every message both ways. A link is
 * opened in a new tab after the person confirms it.
 */
export default class extends Controller {
  static values = {
    // The server's id in the host's registry.
    server: String,
    // The tool the app belongs to.
    tool: String,
    // The app's resource uri.
    resource: String,
    // The tool's input, as JSON.
    input: String,
    // The tool's result (a CallToolResult), as JSON.
    result: String,
    // Where the app's own requests go: a POST taking { server, method, params }.
    rpcUrl: String,
    // The sandbox page's URL on the apps origin; absent in the inline mode.
    sandboxUrl: String,
    // The apps origin, the only origin the frame's messages are accepted from.
    sandboxOrigin: String,
    // The sandbox page's HTML for the inline mode, written into an opaque frame of the page's own.
    sandboxPage: String,
    // The frame's height before the app reports its size, in pixels.
    height: { type: Number, default: 160 },
    // The most the frame grows to, in pixels.
    maxHeight: { type: Number, default: 4000 },
    // Whether every message both ways is announced as a `poetry:mcp-app-host:trace` event, for a log.
    debug: { type: Boolean, default: false }
  }

  static targets = ["frame", "status"]

  /**
   * Mounts the frame and starts the handshake.
   */
  connect() {
    this.onMessage = (event) => this.receive(event)
    window.addEventListener("message", this.onMessage)
    this.onThemeChange = () => this.themeChanged()
    this.mount()
  }

  /**
   * Tears the app down and removes the frame.
   */
  disconnect() {
    window.removeEventListener("message", this.onMessage)
    this.unmount()
  }

  /**
   * Reads the app's HTML through the endpoint, builds the bridge and the
   * frame, and starts the sandbox.
   *
   * @returns {Promise<void>}
   */
  async mount() {
    this.call = { server: this.serverValue, tool: this.toolValue, resource: this.resourceValue,
                  input: parse(this.inputValue, {}), result: parse(this.resultValue, {}) }
    this.inline = !this.hasSandboxUrlValue || !this.sandboxUrlValue
    this.status("Loading the app")
    try {
      const contents = (await this.rpc("resources/read", { uri: this.call.resource })).contents
      const item = Array.isArray(contents) ? contents[0] : null
      if (!item) throw new HostError(-32002, "no resource")
      this.html = item.text ?? (item.blob ? atob(item.blob) : "")
      this.ui = item._meta?.ui ?? {}
    } catch (error) {
      return this.status(`The app could not be read: ${error.message}`)
    }
    this.bridge = new HostBridge({
      post: (message) => this.post(message),
      hostInfo: { name: "poetry-agent", version: "0.2.0" },
      hostCapabilities: { openLinks: {}, serverTools: {}, serverResources: {}, logging: {}, updateModelContext: { text: {} }, message: { text: {} } },
      hostContext: this.hostContext(),
      handlers: {
        initialized: () => this.initialized(),
        callTool: (params) => this.rpc("tools/call", params),
        readResource: (params) => this.rpc("resources/read", params),
        message: (params) => { this.emit("message", { params }); return {} },
        openLink: (params) => this.openLink(params),
        updateModelContext: (params) => { this.emit("context", { params }); return {} },
        requestDisplayMode: (params) => ({ mode: this.emit("display-mode", { requested: params.mode, mode: "inline" }).mode || "inline" }),
        sizeChanged: (params) => this.resize(params),
        loggingMessage: (params) => this.emit("log", { params })
      }
    })
    const frame = document.createElement("iframe")
    frame.className = "block w-full border-0"
    frame.style.height = `${this.heightValue}px`
    frame.title = `${this.call.tool} app`
    frame.setAttribute("sandbox", this.inline ? "allow-scripts allow-forms" : "allow-scripts allow-same-origin allow-forms")
    const allow = buildAllowAttribute(this.ui.permissions)
    if (allow) frame.setAttribute("allow", allow)
    frame.setAttribute("data-mcp-app-host-target", "frame")
    this.frame = frame
    this.element.append(frame)
    if (this.inline) frame.srcdoc = this.sandboxPageValue
    else frame.src = this.sandboxUrlValue
    document.addEventListener("poetry:theme-change", this.onThemeChange)
  }

  /**
   * Asks the app to tear down, drops the bridge and removes the frame.
   *
   * @returns {Promise<void>}
   */
  async unmount() {
    document.removeEventListener("poetry:theme-change", this.onThemeChange)
    if (this.bridge?.initialized) {
      try { await this.bridge.teardown({ reason: "the frame is leaving" }, { timeout: 2000 }) } catch { /* the app had its chance */ }
    }
    this.bridge?.close()
    this.bridge = null
    this.frame?.remove()
    this.frame = null
  }

  /**
   * Takes a message from the frame: the proxy's ready note gets the app's
   * HTML, everything else goes to the bridge.
   *
   * @param {MessageEvent} event the window's message event
   */
  receive(event) {
    if (!this.frame || event.source !== this.frame.contentWindow) return
    const expected = this.inline ? "null" : this.sandboxOriginValue
    if (event.origin !== expected) return
    const message = event.data
    if (this.debugValue) this.emit("trace", { direction: "app", message })
    if (message?.method === SANDBOX_PROXY_READY) {
      this.post({ jsonrpc: "2.0", method: SANDBOX_RESOURCE_READY, params: { html: this.html, csp: this.ui.csp, permissions: this.ui.permissions } })
      this.status("The app is loading")
      return
    }
    this.bridge?.receive(message)
  }

  /**
   * Posts a message to the frame, to the apps origin only.
   *
   * @param {Object} message the JSON-RPC message
   */
  post(message) {
    if (this.debugValue) this.emit("trace", { direction: "host", message })
    this.frame?.contentWindow?.postMessage(message, this.inline ? "*" : this.sandboxOriginValue)
  }

  /**
   * Once the app is initialized: tells the page, delivers the input and
   * the result.
   */
  initialized() {
    this.status("")
    this.emit("connect", { app: this.bridge.appInfo, capabilities: this.bridge.appCapabilities })
    this.bridge.sendToolInput(this.call.input)
    this.bridge.sendToolResult(this.call.result)
  }

  /**
   * Sends one of the app's requests to the endpoint.
   *
   * @param {string} method the method
   * @param {Object} params the params
   * @returns {Promise<*>} the result
   * @throws {HostError} what the endpoint refused
   */
  async rpc(method, params) {
    const response = await fetch(this.rpcUrlValue, {
      method: "POST", credentials: "same-origin",
      headers: { "Content-Type": "application/json", "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content ?? "" },
      body: JSON.stringify({ server: this.call.server, method, params })
    })
    const data = await response.json()
    if (data.error) throw new HostError(data.error.code ?? -32000, data.error.message ?? "refused")
    return data.result
  }

  /**
   * Opens a link the app asks for, in a new tab, after the person
   * confirms it.
   *
   * @param {Object} params the request
   * @param {string} params.url the link
   * @returns {Object} an empty result
   * @throws {HostError} for a scheme this host does not open
   */
  openLink({ url }) {
    let target
    try { target = new URL(url, document.baseURI) } catch { throw new HostError(-32602, "not a URL") }
    if (!["http:", "https:", "mailto:"].includes(target.protocol)) throw new HostError(-32602, "not a link this host opens")
    if (window.confirm(`Open ${target.href}?`)) window.open(target.href, "_blank", "noopener,noreferrer")
    return {}
  }

  /**
   * Sizes the frame to what the app reports: the height within the cap,
   * the width as a floor that still shrinks with the container.
   *
   * @param {Object} size what the app reported
   * @param {number} [size.height] the height
   * @param {number} [size.width] the width
   */
  resize({ height, width }) {
    if (!this.frame) return
    if (height !== undefined) this.frame.style.height = `${Math.min(Math.max(40, Math.round(height)), this.maxHeightValue)}px`
    if (width !== undefined) this.frame.style.minWidth = `min(${Math.round(width)}px, 100%)`
  }

  /**
   * Tells the app the page's theme and tokens changed.
   */
  themeChanged() {
    if (!this.bridge?.initialized) return
    this.bridge.sendHostContextChange({ theme: this.theme(), styles: { variables: styleVariables() } })
  }

  /**
   * The host context the app is initialized with.
   *
   * @returns {Object} theme, platform, locale, time zone, display mode, dimensions and styles
   */
  hostContext() {
    return {
      theme: this.theme(), platform: "web",
      locale: navigator.language, timeZone: Intl.DateTimeFormat().resolvedOptions().timeZone,
      displayMode: "inline", availableDisplayModes: ["inline"],
      containerDimensions: { width: this.element.clientWidth || undefined, maxHeight: this.maxHeightValue },
      styles: { variables: styleVariables() }
    }
  }

  /**
   * The page's theme.
   *
   * @returns {string} light or dark
   */
  theme() {
    return document.documentElement.classList.contains("dark") ? "dark" : "light"
  }

  /**
   * Dispatches a page event under the controller's prefix.
   *
   * @param {string} name the event's name
   * @param {Object} detail the detail
   * @returns {Object} the detail, as the page may have changed it
   */
  emit(name, detail) {
    this.dispatch(name, { detail, prefix: "poetry:mcp-app-host", bubbles: true })
    return detail
  }

  /**
   * Shows a status line, when the element has one.
   *
   * @param {string} text the status
   */
  status(text) {
    if (this.hasStatusTarget) this.statusTarget.textContent = text
  }
}

/**
 * JSON, or a fallback for nothing or something else.
 *
 * @param {string} json the text
 * @param {*} fallback the value for no text
 * @returns {*}
 */
const parse = (json, fallback) => {
  try { return json ? JSON.parse(json) : fallback } catch { return fallback }
}
