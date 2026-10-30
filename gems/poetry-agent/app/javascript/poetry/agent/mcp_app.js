// @poetry/agent/mcp_app - the page's half of the MCP Apps bridge: the
// spec's JSON-RPC 2.0 over postMessage between a Poetry-rendered document
// in a host's sandbox and the host. It initializes, takes the tool's input
// and result, applies the fragments a result carries to the regions of the
// page (the way Turbo Streams apply), calls the server's tools from marked
// buttons and forms, posts a message to the chat, reports the page's size,
// follows the host's theme, and maps the host's style variables onto
// Poetry's tokens. No SDK, no imports: the same file runs from the app's
// origin or inlined in the document.
//
// Markup it reads:
//   data-mcp-region="plans"          a region a fragment targets
//   data-mcp-tool="choose_plan"      a button (or form) that calls a tool
//   data-mcp-args='{"plan":"pro"}'   the button's arguments (a form sends its fields)
//   data-mcp-message="..."           a button that posts a user message
//   data-mcp-link="https://..."      a button that opens a link
//   <html data-host-styles="structural|all|none">  the token mapping
//
// Events it dispatches on document (detail carries the payload):
//   poetry:mcp-app:connect, :input, :result, :fragments, :context, :error

/** The protocol version the bridge speaks. */
export const PROTOCOL_VERSION = "2026-01-26"

/** The display modes the extension names. */
export const DISPLAY_MODES = ["inline", "fullscreen", "pip"]

/** Poetry's tokens that take the host's structural variables (backgrounds, text, borders, fonts). */
export const STRUCTURAL_TOKENS = {
  "--background": "--color-background-primary",
  "--foreground": "--color-text-primary",
  "--card": "--color-background-primary",
  "--card-foreground": "--color-text-primary",
  "--popover": "--color-background-primary",
  "--popover-foreground": "--color-text-primary",
  "--muted": "--color-background-secondary",
  "--muted-foreground": "--color-text-secondary",
  "--secondary": "--color-background-secondary",
  "--secondary-foreground": "--color-text-primary",
  "--accent": "--color-background-tertiary",
  "--accent-foreground": "--color-text-primary",
  "--border": "--color-border-primary",
  "--input": "--color-border-secondary",
  "--ring": "--color-ring-primary",
  "--font-sans": "--font-sans",
  "--font-mono": "--font-mono"
}

/** The accent tokens `all` maps on top of the structural ones. */
export const ACCENT_TOKENS = {
  "--primary": "--color-background-inverse",
  "--primary-foreground": "--color-text-inverse",
  "--destructive": "--color-text-danger"
}

const REQUEST_ERROR = -32000

/**
 * The bridge over one host window.
 */
export class Bridge {
  /**
   * @param {Object} [options]
   * @param {Window} [options.target] the host window (the parent by default)
   * @param {Document} [options.document] the page (the global document by default)
   * @param {Object} [options.appInfo] the app's name and version
   * @param {Array<string>} [options.displayModes] the display modes the page handles; the document's
   *   `data-mcp-display-modes` by default, else inline alone
   */
  constructor({ target = window.parent, document: page = document, appInfo = { name: "poetry-app", version: "1" }, displayModes } = {}) {
    this.target = target
    this.document = page
    this.appInfo = appInfo
    this.displayModes = displayModes
    this.pending = new Map()
    this.nextId = 1
    this.context = {}
    this.capabilities = {}
    this.connected = false
    this.lastSize = null
    this.onMessage = (event) => this.receive(event)
    this.onClick = (event) => this.click(event)
    this.onSubmit = (event) => this.submit(event)
  }

  /**
   * Starts listening, initializes with the host and reports the first size.
   *
   * @returns {Promise<Object>} the host's initialize result
   */
  async connect() {
    window.addEventListener("message", this.onMessage)
    this.document.addEventListener("click", this.onClick)
    this.document.addEventListener("submit", this.onSubmit)
    const result = await this.request("ui/initialize", {
      appInfo: this.appInfo,
      appCapabilities: { availableDisplayModes: this.availableDisplayModes() },
      protocolVersion: PROTOCOL_VERSION
    })
    this.capabilities = result.hostCapabilities || {}
    this.applyContext(result.hostContext || {})
    this.notify("ui/notifications/initialized", {})
    this.connected = true
    this.observe()
    this.reportSize()
    this.emit("connect", result)
    return result
  }

  /**
   * The display modes the page declares: the option, else the document's
   * `data-mcp-display-modes` (space-separated), else inline alone.
   *
   * @returns {Array<string>} a subset of inline, fullscreen and pip, inline always
   */
  availableDisplayModes() {
    const named = this.displayModes || (this.document.documentElement.dataset.mcpDisplayModes || "").split(/\s+/)
    const modes = named.filter((mode) => DISPLAY_MODES.includes(mode))
    return modes.includes("inline") ? modes : ["inline", ...modes]
  }

  /** Stops listening and observing. */
  disconnect() {
    window.removeEventListener("message", this.onMessage)
    this.document.removeEventListener("click", this.onClick)
    this.document.removeEventListener("submit", this.onSubmit)
    this.observer?.disconnect()
    this.connected = false
  }

  /**
   * Calls a server tool through the host and applies the result's fragments.
   *
   * @param {string} name the tool
   * @param {Object} [args] the arguments
   * @returns {Promise<Object>} the tool result
   */
  async call(name, args = {}) {
    const result = await this.request("tools/call", { name, arguments: args })
    this.applyResult(result)
    return result
  }

  /**
   * Posts a user message into the host's chat.
   *
   * @param {string} text the message
   * @returns {Promise<Object>} the host's answer
   */
  message(text) {
    return this.request("ui/message", { role: "user", content: [{ type: "text", text }] })
  }

  /**
   * Asks the host to open a link.
   *
   * @param {string} url the URL
   * @returns {Promise<Object>} the host's answer
   */
  openLink(url) {
    return this.request("ui/open-link", { url })
  }

  /**
   * Replaces the context the model sees on its next turn.
   *
   * @param {Object} params `content` blocks and/or `structuredContent`
   * @returns {Promise<Object>} the host's answer
   */
  updateModelContext(params) {
    return this.request("ui/update-model-context", params)
  }

  /**
   * Asks for a display mode.
   *
   * @param {string} mode inline, fullscreen or pip
   * @returns {Promise<Object>} the mode the host set
   */
  requestDisplayMode(mode) {
    return this.request("ui/request-display-mode", { mode })
  }

  /**
   * Applies a result's fragments to the page's regions.
   *
   * @param {Object} result a tool result
   * @returns {Array<Object>} the fragments applied
   */
  applyResult(result) {
    const fragments = result?._meta?.poetry?.fragments || []
    for (const fragment of fragments) this.applyFragment(fragment)
    this.emit("result", result)
    if (fragments.length) this.emit("fragments", fragments)
    this.reportSize()
    return fragments
  }

  /**
   * Applies one fragment to its region.
   *
   * @param {Object} fragment the fragment
   * @param {string} fragment.target the region
   * @param {string} [fragment.action] replace (the default), append, prepend or remove
   * @param {string} [fragment.html] the HTML
   */
  applyFragment({ target, action = "replace", html = "" }) {
    const region = this.document.querySelector(`[data-mcp-region="${CSS.escape(target)}"]`)
    if (!region) return
    switch (action) {
      case "append": region.insertAdjacentHTML("beforeend", html); break
      case "prepend": region.insertAdjacentHTML("afterbegin", html); break
      case "remove": region.replaceChildren(); break
      default: region.innerHTML = html
    }
  }

  /**
   * Follows the host's theme and style variables.
   *
   * @param {Object} context the host context
   */
  applyContext(context) {
    this.context = { ...this.context, ...context }
    const root = this.document.documentElement
    if (context.theme) {
      root.classList.toggle("dark", context.theme === "dark")
      root.style.colorScheme = context.theme
    }
    if (context.displayMode) root.dataset.displayMode = context.displayMode
    if (context.styles?.variables) this.applyStyles(context.styles.variables)
    if (context.styles?.css?.fonts) this.applyFonts(context.styles.css.fonts)
    const insets = context.safeAreaInsets
    if (insets) {
      for (const side of ["top", "right", "bottom", "left"]) {
        root.style.setProperty(`--poetry-app-safe-${side}`, `${insets[side] || 0}px`)
      }
    }
    this.emit("context", this.context)
  }

  /**
   * Maps the host's variables onto Poetry's tokens, per the document's mode.
   *
   * @param {Object} variables the host's style variables
   */
  applyStyles(variables) {
    const root = this.document.documentElement
    const mode = root.dataset.hostStyles || "structural"
    const mapping = mode === "none" ? {} : mode === "all" ? { ...STRUCTURAL_TOKENS, ...ACCENT_TOKENS } : STRUCTURAL_TOKENS
    for (const token of Object.keys({ ...STRUCTURAL_TOKENS, ...ACCENT_TOKENS })) {
      const value = mapping[token] ? variables[mapping[token]] : null
      if (value) root.style.setProperty(token, value); else root.style.removeProperty(token)
    }
    const radius = mode === "none" ? null : variables["--border-radius-md"]
    if (radius) root.style.setProperty("--radius", radius); else root.style.removeProperty("--radius")
  }

  /**
   * Adds the host's font-face rules to the page.
   *
   * @param {string} css the host's font CSS
   */
  applyFonts(css) {
    let style = this.document.getElementById("poetry-app-host-fonts")
    if (!style) {
      style = this.document.createElement("style")
      style.id = "poetry-app-host-fonts"
      this.document.head.append(style)
    }
    style.textContent = css
  }

  /** Watches the page's size and reports changes to the host. */
  observe() {
    if (typeof ResizeObserver === "undefined") return
    this.observer = new ResizeObserver(() => this.reportSize())
    this.observer.observe(this.document.body)
  }

  /** Reports the page's size to the host when it changed. */
  reportSize() {
    const rect = this.document.body.getBoundingClientRect()
    const size = { width: Math.ceil(rect.width), height: Math.ceil(rect.height) }
    if (this.lastSize && this.lastSize.width === size.width && this.lastSize.height === size.height) return
    this.lastSize = size
    this.notify("ui/notifications/size-changed", size)
  }

  /**
   * Sends a request and waits for its reply.
   *
   * @param {string} method the method
   * @param {Object} params the params
   * @returns {Promise<Object>} the result
   */
  request(method, params) {
    return new Promise((resolve, reject) => {
      const id = this.nextId++
      this.pending.set(id, { resolve, reject })
      this.post({ jsonrpc: "2.0", id, method, params })
    })
  }

  /**
   * Sends a notification.
   *
   * @param {string} method the method
   * @param {Object} params the params
   */
  notify(method, params) {
    this.post({ jsonrpc: "2.0", method, params })
  }

  /**
   * Posts a message to the host.
   *
   * @param {Object} message a JSON-RPC message
   */
  post(message) {
    this.target.postMessage(message, "*")
  }

  /**
   * Handles a message from the host: a reply to a request, a notification,
   * or a request the page answers.
   *
   * @param {MessageEvent} event the message
   */
  receive(event) {
    if (event.source !== this.target) return
    const message = event.data
    if (!message || message.jsonrpc !== "2.0") return
    if (message.method === undefined) {
      this.settle(message)
      return
    }
    switch (message.method) {
      case "ui/notifications/tool-input":
        this.emit("input", message.params || {})
        break
      case "ui/notifications/tool-input-partial":
        this.emit("input-partial", message.params || {})
        break
      case "ui/notifications/tool-result":
        this.applyResult(message.params || {})
        break
      case "ui/notifications/tool-cancelled":
        this.emit("cancelled", message.params || {})
        break
      case "ui/notifications/host-context-changed":
        this.applyContext(message.params || {})
        break
      case "ui/resource-teardown":
      case "ping":
        this.post({ jsonrpc: "2.0", id: message.id, result: {} })
        break
      default:
        if (message.id !== undefined) {
          this.post({ jsonrpc: "2.0", id: message.id, error: { code: -32601, message: `Method not found: ${message.method}` } })
        }
    }
  }

  /**
   * Resolves or rejects the request a reply answers.
   *
   * @param {Object} message the reply
   */
  settle(message) {
    const waiter = this.pending.get(message.id)
    if (!waiter) return
    this.pending.delete(message.id)
    if (message.error) {
      waiter.reject(Object.assign(new Error(message.error.message || "request failed"), { code: message.error.code ?? REQUEST_ERROR }))
    } else {
      waiter.resolve(message.result)
    }
  }

  /**
   * A click on a marked button: a tool call, a message, a link or a display mode.
   *
   * @param {Event} event the click
   */
  async click(event) {
    const button = event.target.closest("[data-mcp-tool], [data-mcp-message], [data-mcp-link], [data-mcp-display-mode]")
    if (!button || button.tagName === "FORM") return
    event.preventDefault()
    try {
      if (button.dataset.mcpLink) await this.openLink(button.dataset.mcpLink)
      else if (button.dataset.mcpMessage) await this.message(button.dataset.mcpMessage)
      else if (button.dataset.mcpDisplayMode) await this.requestDisplayMode(button.dataset.mcpDisplayMode)
      else await this.busy(button, () => this.call(button.dataset.mcpTool, JSON.parse(button.dataset.mcpArgs || "{}")))
    } catch (error) {
      this.emit("error", { error, element: button })
    }
  }

  /**
   * A marked form's submission: its fields become the tool's arguments.
   *
   * @param {Event} event the submit
   */
  async submit(event) {
    const form = event.target
    if (!form?.dataset?.mcpTool) return
    event.preventDefault()
    const args = { ...JSON.parse(form.dataset.mcpArgs || "{}") }
    for (const [key, value] of new FormData(form).entries()) {
      if (key in args && !(form.dataset.mcpArgs || "").includes(`"${key}"`)) args[key] = [].concat(args[key], value)
      else args[key] = value
    }
    try {
      await this.busy(form, () => this.call(form.dataset.mcpTool, args))
    } catch (error) {
      this.emit("error", { error, element: form })
    }
  }

  /**
   * Marks an element busy while a call runs.
   *
   * @param {Element} element the button or form
   * @param {Function} work the call
   * @returns {Promise<Object>} the call's result
   */
  async busy(element, work) {
    element.setAttribute("aria-busy", "true")
    try { return await work() } finally { element.removeAttribute("aria-busy") }
  }

  /**
   * Dispatches a bridge event on the document.
   *
   * @param {string} name the event's short name
   * @param {*} detail the payload
   */
  emit(name, detail) {
    this.document.dispatchEvent(new CustomEvent(`poetry:mcp-app:${name}`, { detail }))
  }
}

/**
 * Connects a bridge to the host when the page runs in a frame, and keeps
 * it at `window.poetryMcpApp`.
 *
 * @param {Object} [options] the bridge's options
 * @returns {Bridge|null} the bridge, or null outside a frame
 */
export function connect(options = {}) {
  const target = options.target || window.parent
  if (target === window) return null
  const bridge = new Bridge({ ...options, target })
  window.poetryMcpApp = bridge
  const start = () => bridge.connect().catch((error) => bridge.emit("error", { error }))
  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", start, { once: true })
  else start()
  return bridge
}

if (typeof window !== "undefined" && !window.__poetryMcpAppManual) connect()
