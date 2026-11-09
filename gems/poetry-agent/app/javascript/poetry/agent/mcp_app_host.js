// @poetry/agent/mcp_app_host - the host half of the MCP Apps bridge, written
// from the specification (2026-01-26) with no SDK: the JSON-RPC bookkeeping,
// the method table, the parameter checks, and the host's own requests to
// the view. The DOM (the sandbox frame, postMessage, resizing) stays in the
// controller; this class only needs `post(message)`. Its answers match the
// SDK's wire-compat fixtures, which the tests replay.

/** The protocol version this host speaks. */
export const PROTOCOL_VERSION = "2026-01-26"

/** The versions this host answers as asked. */
export const KNOWN_VERSIONS = [PROTOCOL_VERSION]

/** The sandbox proxy's notification that it can take the app's HTML. */
export const SANDBOX_PROXY_READY = "ui/notifications/sandbox-proxy-ready"

/** The host's notification carrying the app's HTML, policy and permissions to the proxy. */
export const SANDBOX_RESOURCE_READY = "ui/notifications/sandbox-resource-ready"

/** How long a host waits for the view to answer a request, in milliseconds. */
export const REQUEST_TIMEOUT = 30_000

/**
 * A JSON-RPC error: what a handler throws to refuse, and what a failed host
 * request rejects with.
 */
export class HostError extends Error {
  /**
   * @param {number} code the JSON-RPC code
   * @param {string} message the message
   * @param {*} [data] optional data
   */
  constructor(code, message, data) {
    super(message)
    this.code = code
    this.data = data
  }
}

const invalid = (message) => new HostError(-32602, `Invalid params: ${message}`)

// The shapes a host checks before a handler runs; a trailing ? marks an optional member.
const SHAPES = {
  "ui/initialize": { protocolVersion: "string" },
  "ui/open-link": { url: "string" },
  "ui/message": { role: "string", content: "array" },
  "ui/request-display-mode": { mode: "string" },
  "ui/update-model-context": { content: "array?", structuredContent: "object?" },
  "tools/call": { name: "string", arguments: "object?" },
  "resources/read": { uri: "string" },
  "ui/notifications/size-changed": { width: "number?", height: "number?" },
  "notifications/message": { level: "string" }
}

/**
 * Checks a request's params against its shape, when one is known.
 *
 * @param {string} method the method
 * @param {*} params the params
 * @throws {HostError} -32602 when a member is missing or mistyped
 */
const checkShape = (method, params) => {
  const shape = SHAPES[method]
  if (!shape) return
  if (params === null || typeof params !== "object" || Array.isArray(params)) throw invalid("params must be an object")
  for (const [key, spec] of Object.entries(shape)) {
    const optional = spec.endsWith("?")
    const type = optional ? spec.slice(0, -1) : spec
    const value = params[key]
    if (value === undefined) {
      if (optional) continue
      throw invalid(`${key} is required`)
    }
    const ok = type === "array" ? Array.isArray(value)
      : type === "object" ? (value !== null && typeof value === "object" && !Array.isArray(value))
      : typeof value === type
    if (!ok) throw invalid(`${key} must be ${type === "array" ? "an array" : `a ${type}`}`)
  }
}

/**
 * The bridge: receives the view's messages, answers its requests through the
 * host's handlers, and sends the host's notifications and requests.
 */
export class HostBridge {
  /**
   * @param {Object} options
   * @param {function(Object): void} options.post sends a message to the view
   * @param {Object} options.hostInfo the host's name and version
   * @param {Object} [options.hostCapabilities] what the host supports
   * @param {Object} [options.hostContext] theme, styles, dimensions and the rest
   * @param {Object} [options.handlers] `initialized`, `callTool`, `readResource`, `message`, `openLink`,
   *   `updateModelContext`, `requestDisplayMode`, `sizeChanged`, `loggingMessage`, `toolsListChanged`
   * @param {function(...*): void} [options.log] where notes go
   */
  constructor({ post, hostInfo, hostCapabilities = {}, hostContext = {}, handlers = {}, log = () => {} }) {
    this.post = post
    this.hostInfo = hostInfo
    this.hostCapabilities = hostCapabilities
    this.hostContext = { ...hostContext }
    this.handlers = handlers
    this.log = log
    this.appInfo = null
    this.appCapabilities = null
    this.protocolVersion = null
    this.initialized = false
    this.pending = new Map()
    this.nextId = 0
  }

  /**
   * Takes a message from the view: a request is answered, a notification
   * handled, a reply settles the host's own request.
   *
   * @param {Object} message the JSON-RPC message
   * @returns {Promise<void>|undefined} the request's handling, when it was one
   */
  receive(message) {
    if (!message || message.jsonrpc !== "2.0") return
    if (typeof message.method === "string") {
      return message.id === undefined ? this.handleNotification(message) : this.handleRequest(message)
    }
    if (message.id !== undefined) this.settle(message)
  }

  /**
   * Answers one request from the view with its result or its error.
   *
   * @param {Object} message the request
   * @param {number|string} message.id its id
   * @param {string} message.method its method
   * @param {Object} [message.params] its params
   * @returns {Promise<void>}
   */
  async handleRequest({ id, method, params }) {
    try {
      const result = await this.dispatch(method, params ?? {})
      this.post({ jsonrpc: "2.0", id, result: result ?? {} })
    } catch (error) {
      this.post({ jsonrpc: "2.0", id, error: this.errorFor(error) })
    }
  }

  /**
   * Takes one notification from the view: the handshake's end, a size,
   * a log line, a tools change.
   *
   * @param {Object} message the notification
   * @param {string} message.method its method
   * @param {Object} [message.params] its params
   */
  handleNotification({ method, params }) {
    try {
      switch (method) {
        case "ui/notifications/initialized":
          this.initialized = true
          this.handlers.initialized?.()
          break
        case "ui/notifications/size-changed":
          checkShape(method, params ?? {})
          this.handlers.sizeChanged?.(params ?? {})
          break
        case "notifications/message":
          checkShape(method, params ?? {})
          this.handlers.loggingMessage?.(params)
          break
        case "notifications/tools/list_changed":
          this.handlers.toolsListChanged?.()
          break
        default:
          this.log("ignored notification", method)
      }
    } catch (error) {
      this.log("notification refused", method, error.message)
    }
  }

  /**
   * Routes a request to its handler after the shape check.
   *
   * @param {string} method the method
   * @param {Object} params the params
   * @returns {Promise<*>} the result
   */
  async dispatch(method, params) {
    checkShape(method, params)
    switch (method) {
      case "ui/initialize": return this.initialize(params)
      case "ping": return {}
      case "tools/call": return this.handle("callTool", params)
      case "resources/read": return this.handle("readResource", params)
      case "ui/message": return this.handle("message", params)
      case "ui/open-link": return this.handle("openLink", params)
      case "ui/update-model-context": return this.handle("updateModelContext", params)
      case "ui/request-display-mode": return this.handle("requestDisplayMode", params, { mode: this.hostContext.displayMode ?? "inline" })
      default: throw new HostError(-32601, `Method not found: ${method}`)
    }
  }

  /**
   * Runs a named handler, or answers the fallback, or refuses.
   *
   * @param {string} name the handler's name
   * @param {Object} params the params
   * @param {*} [fallback] what a host without the handler answers
   * @returns {Promise<*>} the result
   */
  async handle(name, params, fallback) {
    const handler = this.handlers[name]
    if (!handler) {
      if (fallback !== undefined) return fallback
      throw new HostError(-32601, `Method not found: the host does not handle ${name}`)
    }
    return handler(params)
  }

  /**
   * Answers `ui/initialize`: remembers the view and names the version.
   *
   * @param {Object} params the view's info, capabilities and version
   * @returns {Object} the host's version, capabilities, info and context
   */
  initialize(params) {
    this.appInfo = params.appInfo ?? null
    this.appCapabilities = params.appCapabilities ?? {}
    this.protocolVersion = KNOWN_VERSIONS.includes(params.protocolVersion) ? params.protocolVersion : PROTOCOL_VERSION
    return { protocolVersion: this.protocolVersion, hostCapabilities: this.hostCapabilities, hostInfo: this.hostInfo, hostContext: this.hostContext }
  }

  /**
   * The JSON-RPC error for a thrown value.
   *
   * @param {*} error what a handler threw
   * @returns {Object} code, message and data
   */
  errorFor(error) {
    if (error instanceof HostError) {
      // A 2.x host never puts -32002 on the wire (the SDK's documented delta).
      const code = error.code === -32002 ? -32602 : error.code
      return error.data === undefined ? { code, message: error.message } : { code, message: error.message, data: error.data }
    }
    return { code: -32603, message: error?.message || String(error) }
  }

  /**
   * Sends a notification to the view, once the view is initialized.
   *
   * @param {string} method the method
   * @param {Object} [params] the params
   */
  notify(method, params) {
    this.assertInitialized(method)
    this.post(params === undefined ? { jsonrpc: "2.0", method } : { jsonrpc: "2.0", method, params })
  }

  /**
   * Sends a request to the view and waits for its answer.
   *
   * @param {string} method the method
   * @param {Object} [params] the params
   * @param {Object} [options]
   * @param {number} [options.timeout] milliseconds before the request fails
   * @returns {Promise<*>} the result
   */
  request(method, params, { timeout = REQUEST_TIMEOUT } = {}) {
    this.assertInitialized(method)
    const id = this.nextId++
    const message = params === undefined || (typeof params === "object" && Object.keys(params).length === 0)
      ? { jsonrpc: "2.0", method, id }
      : { jsonrpc: "2.0", method, params, id }
    return new Promise((resolve, reject) => {
      const timer = setTimeout(() => {
        this.pending.delete(id)
        reject(new HostError(-32001, `${method} timed out after ${timeout}ms`))
      }, timeout)
      this.pending.set(id, { resolve, reject, timer })
      this.post(message)
    })
  }

  /**
   * Settles the host's own request the reply answers.
   *
   * @param {Object} reply the view's reply
   * @param {number|string} reply.id the request's id
   * @param {*} [reply.result] the result
   * @param {Object} [reply.error] the error
   */
  settle({ id, result, error }) {
    const entry = this.pending.get(id)
    if (!entry) return
    this.pending.delete(id)
    clearTimeout(entry.timer)
    if (error) entry.reject(new HostError(error.code, error.message, error.data))
    else entry.resolve(result)
  }

  /**
   * Refuses to speak before the view said it is initialized.
   *
   * @param {string} method what the host wanted to send
   * @throws {HostError} -32002 before the handshake
   */
  assertInitialized(method) {
    if (!this.initialized) throw new HostError(-32002, `${method} before ui/notifications/initialized`)
  }

  /**
   * Delivers the tool's input.
   * @param {Object} args the arguments
   */
  sendToolInput(args) { this.notify("ui/notifications/tool-input", { arguments: args ?? {} }) }

  /**
   * Delivers a partial input while it streams.
   * @param {Object} args the arguments so far
   */
  sendToolInputPartial(args) { this.notify("ui/notifications/tool-input-partial", { arguments: args ?? {} }) }

  /**
   * Delivers the tool's result.
   * @param {Object} result the CallToolResult
   */
  sendToolResult(result) { this.notify("ui/notifications/tool-result", result) }

  /**
   * Tells the view the call was cancelled.
   * @param {Object} [options] the cancellation
   * @param {string} [options.reason] why
   */
  sendToolCancelled({ reason } = {}) { this.notify("ui/notifications/tool-cancelled", reason ? { reason } : {}) }

  /**
   * Notifies the view of what changed in the host context, and remembers it.
   *
   * @param {Object} partial the changed members
   * @returns {boolean} whether anything changed
   */
  sendHostContextChange(partial) {
    const changed = {}
    for (const [key, value] of Object.entries(partial)) {
      if (JSON.stringify(this.hostContext[key]) !== JSON.stringify(value)) changed[key] = value
    }
    if (Object.keys(changed).length === 0) return false
    Object.assign(this.hostContext, changed)
    this.notify("ui/notifications/host-context-changed", changed)
    return true
  }

  /**
   * Asks the view to tear down, and waits for it.
   *
   * @param {Object} [options] the teardown
   * @param {string} [options.reason] why
   * @param {Object} [requestOptions] the request's options
   * @returns {Promise<*>} the view's answer
   */
  teardown({ reason } = {}, requestOptions) { return this.request("ui/resource-teardown", reason ? { reason } : {}, requestOptions) }

  /**
   * Lists the view's own tools.
   * @param {Object} [params]
   * @returns {Promise<*>}
   */
  listTools(params = {}) { return this.request("tools/list", params) }

  /**
   * Calls one of the view's own tools.
   * @param {Object} params the name and arguments
   * @returns {Promise<*>}
   */
  callTool(params) { return this.request("tools/call", params) }

  /** Drops every pending request, for a frame going away. */
  close() {
    for (const [, entry] of this.pending) {
      clearTimeout(entry.timer)
      entry.reject(new HostError(-32000, "host closed"))
    }
    this.pending.clear()
  }
}

/**
 * The Permission Policy `allow` attribute for an app's requested permissions.
 *
 * @param {Object} [permissions] the resource's `_meta.ui.permissions`
 * @returns {string} the attribute value, empty for none
 */
export const buildAllowAttribute = (permissions) => {
  if (!permissions || typeof permissions !== "object") return ""
  const names = { camera: "camera", microphone: "microphone", geolocation: "geolocation", clipboardWrite: "clipboard-write" }
  return Object.keys(permissions).map((key) => names[key]).filter(Boolean).join("; ")
}

/**
 * The host context's style variables from a page's tokens: the extension's
 * names mapped onto Poetry's, read from the document element.
 *
 * @param {Document} [doc] the document
 * @returns {Object} variables by the extension's names
 */
export const styleVariables = (doc = globalThis.document) => {
  if (!doc?.documentElement) return {}
  const computed = getComputedStyle(doc.documentElement)
  return Object.fromEntries(Object.entries(STYLE_TOKENS)
    .map(([name, token]) => [name, computed.getPropertyValue(token).trim()])
    .filter(([, value]) => value))
}

/** The extension's style variables that Poetry's tokens answer. */
export const STYLE_TOKENS = {
  "--color-background-primary": "--background",
  "--color-background-secondary": "--card",
  "--color-background-tertiary": "--muted",
  "--color-text-primary": "--foreground",
  "--color-text-secondary": "--muted-foreground",
  "--color-text-link": "--primary",
  "--color-border-primary": "--border",
  "--color-border-secondary": "--input",
  "--color-background-info": "--primary",
  "--color-text-info": "--primary-foreground",
  "--color-background-danger": "--destructive",
  "--color-text-danger": "--destructive-foreground",
  "--font-sans": "--font-sans",
  "--font-mono": "--font-mono",
  "--border-radius-md": "--radius"
}
