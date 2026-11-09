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
 * moves the frame between the display modes (inline in the page,
 * fullscreen over it, pip in a corner), and tears the app down when the
 * element leaves.
 *
 * What the page hears: `poetry:mcp-app-host:connect` (the app's info),
 * `poetry:mcp-app-host:message` (a message for the chat, `detail.params`),
 * `poetry:mcp-app-host:context` (a model-context update),
 * `poetry:mcp-app-host:display-mode` (a mode about to be entered, by the
 * app's request or the page's call: `detail.requested`, `detail.mode` the
 * controller is granting, which the handler may change, `inline` to
 * refuse), `poetry:mcp-app-host:authorize` (the endpoint wants the person
 * signed in to the server first: `detail.url`), and with `debug`,
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
    // The most the frame grows to inline, in pixels.
    maxHeight: { type: Number, default: 4000 },
    // The display modes this page offers: inline, fullscreen and pip, in any subset.
    displayModes: { type: Array, default: ["inline", "fullscreen", "pip"] },
    // The pip panel's width, in pixels.
    pipWidth: { type: Number, default: 360 },
    // The most the frame grows to in the pip panel, in pixels.
    pipHeight: { type: Number, default: 480 },
    // Whether every message both ways is announced as a `poetry:mcp-app-host:trace` event, for a log.
    debug: { type: Boolean, default: false }
  }

  static targets = ["frame", "status"]

  /**
   * Mounts the frame and starts the handshake.
   */
  connect() {
    this.mode = "inline"
    this.onMessage = (event) => this.receive(event)
    window.addEventListener("message", this.onMessage)
    this.onThemeChange = () => this.themeChanged()
    this.mount()
  }

  /**
   * Tears the app down, puts the element back inline and removes the frame.
   */
  disconnect() {
    window.removeEventListener("message", this.onMessage)
    if (this.mode !== "inline") this.leaveMode()
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
        requestDisplayMode: (params) => ({ mode: this.setDisplayMode(params.mode, { by: "app" }) }),
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
   * Sends one of the app's requests to the endpoint. An answer that asks
   * for the person's authorization first is announced to the page as
   * `poetry:mcp-app-host:authorize` with the URL to send them to.
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
    if (data.error) {
      const url = data.error.data?.authorizationUrl
      if (url) this.emit("authorize", { server: this.call.server, url, message: data.error.message })
      throw new HostError(data.error.code ?? -32000, data.error.message ?? "refused")
    }
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
   * Sizes the frame to what the app reports: the height within the mode's
   * cap (fullscreen fills the viewport whatever the app says), the width
   * as a floor that still shrinks with the container.
   *
   * @param {Object} size what the app reported
   * @param {number} [size.height] the height
   * @param {number} [size.width] the width
   */
  resize({ height, width }) {
    if (!this.frame || this.mode === "fullscreen") return
    const cap = this.mode === "pip" ? this.pipHeightValue : this.maxHeightValue
    if (height !== undefined) this.frame.style.height = `${Math.min(Math.max(40, Math.round(height)), cap)}px`
    if (width !== undefined) this.frame.style.minWidth = `min(${Math.round(width)}px, 100%)`
  }

  /**
   * A page action putting the frame in a mode: `data-action="click->poetry--agent--mcp-app-host#displayMode"`
   * with `data-poetry--agent--mcp-app-host-mode-param="fullscreen"`.
   *
   * @param {Event} event the click, with `params.mode`
   */
  displayMode(event) {
    this.setDisplayMode(event.params?.mode ?? "inline")
  }

  /**
   * Puts the frame in a display mode: fullscreen (the element over the
   * whole viewport), pip (a fixed panel in the corner, the page's row kept
   * at its height) or inline (back in the page), the frame staying put so
   * the app never reloads. A mode the page does not offer, or the app did
   * not declare, is refused; the page hears `display-mode` first and may
   * change `detail.mode`. The app is told through the host context.
   *
   * @param {string} mode inline, fullscreen or pip
   * @param {Object} [options]
   * @param {string} [options.by] `app` for the app's request, `page` otherwise
   * @returns {string} the mode in effect
   */
  setDisplayMode(mode, { by = "page" } = {}) {
    const current = this.mode ?? "inline"
    if (!this.availableDisplayModes().includes(mode)) return current
    const declared = this.bridge?.appCapabilities?.availableDisplayModes
    if (Array.isArray(declared) && !declared.includes(mode)) return current
    const detail = this.emit("display-mode", { requested: mode, mode, by })
    const granted = this.availableDisplayModes().includes(detail.mode) ? detail.mode : current
    if (granted === current) return current
    this.applyDisplayMode(granted)
    if (this.bridge?.initialized) this.bridge.sendHostContextChange({ displayMode: granted, containerDimensions: this.containerDimensions() })
    return granted
  }

  /**
   * Moves the element into a mode: fixed over the page or in its corner
   * with a placeholder holding the row's height and a button back, or
   * back into the page's flow.
   *
   * @param {string} mode inline, fullscreen or pip
   */
  applyDisplayMode(mode) {
    const element = this.element
    if (this.mode === "inline") {
      this.inlineBox = { height: element.getBoundingClientRect().height, frameHeight: this.frame?.style.height, style: element.getAttribute("style") }
    }
    this.leaveMode()
    this.mode = mode
    if (mode === "inline") {
      if (this.frame && this.inlineBox?.frameHeight) this.frame.style.height = this.inlineBox.frameHeight
      return
    }
    element.dataset.displayMode = mode
    this.placeholder = document.createElement("div")
    this.placeholder.setAttribute("data-mcp-app-host-placeholder", "")
    this.placeholder.style.height = `${this.inlineBox?.height ?? 0}px`
    element.before(this.placeholder)
    Object.assign(element.style, mode === "fullscreen" ? FULLSCREEN_STYLE : { ...PIP_STYLE, width: `${this.pipWidthValue}px` })
    this.closeButton = buildCloseButton(() => this.setDisplayMode("inline"))
    element.prepend(this.closeButton)
    this.onKeydown = (event) => { if (event.key === "Escape") this.setDisplayMode("inline") }
    document.addEventListener("keydown", this.onKeydown)
    if (mode === "fullscreen") {
      this.bodyOverflow = document.body.style.overflow
      document.body.style.overflow = "hidden"
      if (this.frame) this.frame.style.height = "100%"
    } else if (this.frame) {
      this.resize({ height: parseFloat(this.frame.style.height) || this.heightValue })
    }
  }

  /**
   * Undoes what a mode put in place: the placeholder, the button, the key
   * listener, the page's scroll lock and the element's styles.
   */
  leaveMode() {
    this.placeholder?.remove()
    this.placeholder = null
    this.closeButton?.remove()
    this.closeButton = null
    if (this.onKeydown) document.removeEventListener("keydown", this.onKeydown)
    this.onKeydown = null
    if (this.mode === "fullscreen") document.body.style.overflow = this.bodyOverflow ?? ""
    if (this.inlineBox?.style) this.element.setAttribute("style", this.inlineBox.style)
    else this.element.removeAttribute("style")
    delete this.element.dataset.displayMode
  }

  /**
   * The display modes this page offers, in the spec's names.
   *
   * @returns {Array<string>} a subset of inline, fullscreen and pip, inline always
   */
  availableDisplayModes() {
    const offered = this.displayModesValue.filter((mode) => MODES.includes(mode))
    return offered.includes("inline") ? offered : ["inline", ...offered]
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
   * @returns {Object} theme, platform, locale, time zone, display modes, dimensions and styles
   */
  hostContext() {
    return {
      theme: this.theme(), platform: "web",
      locale: navigator.language, timeZone: Intl.DateTimeFormat().resolvedOptions().timeZone,
      displayMode: this.mode ?? "inline", availableDisplayModes: this.availableDisplayModes(),
      containerDimensions: this.containerDimensions(),
      styles: { variables: styleVariables() }
    }
  }

  /**
   * What the frame may grow to in the mode in effect.
   *
   * @returns {Object} width and maxHeight
   */
  containerDimensions() {
    const maxHeight = this.mode === "fullscreen" ? window.innerHeight : this.mode === "pip" ? this.pipHeightValue : this.maxHeightValue
    return { width: this.element.clientWidth || undefined, maxHeight }
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

/** The display modes the extension names. */
const MODES = ["inline", "fullscreen", "pip"]

/** The element over the whole viewport. */
const FULLSCREEN_STYLE = {
  position: "fixed", top: "0", right: "0", bottom: "0", left: "0", zIndex: "60", width: "auto", height: "auto",
  maxWidth: "none", maxHeight: "none", margin: "0", borderRadius: "0", overflow: "auto", background: "var(--background, #fff)"
}

/** The element as a panel in the corner. */
const PIP_STYLE = {
  position: "fixed", right: "16px", bottom: "16px", zIndex: "60", maxWidth: "calc(100vw - 32px)", margin: "0",
  boxShadow: "0 12px 40px rgba(0, 0, 0, 0.25)", background: "var(--background, #fff)"
}

/**
 * The button that brings the frame back inline, floating in the element's
 * corner and styled from the page's tokens, so it works outside Poetry's
 * CSS too.
 *
 * @param {function(): void} back what the button does
 * @returns {HTMLButtonElement}
 */
const buildCloseButton = (back) => {
  const button = document.createElement("button")
  button.type = "button"
  button.setAttribute("aria-label", "Back to the page")
  button.setAttribute("data-mcp-app-host-close", "")
  button.textContent = "✕"
  Object.assign(button.style, {
    position: "absolute", top: "8px", right: "8px", zIndex: "1", width: "32px", height: "32px", padding: "0",
    borderRadius: "9999px", border: "1px solid var(--border, #ccc)", background: "var(--background, #fff)",
    color: "var(--foreground, #000)", font: "16px/1 system-ui, sans-serif", cursor: "pointer"
  })
  button.addEventListener("click", back)
  return button
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
