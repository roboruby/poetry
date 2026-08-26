import { Controller } from "@hotwired/stimulus"
import { supported, registerTool, validToolName } from "@poetry/agent/adapter"

// The registrar: one controller on an opted-in component root
// (`webmcp: "country"` on the helper call renders it beside the
// component's own controllers) registers that instance's declared tools
// with document.modelContext on connect and aborts them on disconnect.
// Components gain zero runtime code - each tool dispatches to the
// component's OWN controller action (the `executes` descriptor the Ruby
// contract validated at class load), passing the tool's parameters
// positionally in declared order.
//
// Correctness rules the spec makes load-bearing:
// - Re-registration is skipped while the payload is unchanged (the spec
//   documents an unregister/quick-re-register race where in-flight args
//   for the old tool can hit the new tool's schema).
// - Never register under Turbo's cache preview.
// - Duplicate names are rejected by the browser; we warn and skip.
// - A per-document budget caps registrations (each tool costs the agent
//   context; overlap confuses tool choice).
// - Errors come back as descriptive result strings (granular exceptions
//   are still open spec issues; a string lets the agent self-correct).

// element -> { hash, controller: AbortController, names: string[] }
const registrations = new Map()

const registeredCount = () =>
  [...registrations.values()].reduce((sum, entry) => sum + entry.names.length, 0)

export default class extends Controller {
  static values = {
    name: String,
    tools: Array,
    budget: { type: Number, default: 20 }
  }

  static events = [
    "poetry:webmcp:registered",
    "poetry:webmcp:executed",
    "poetry:webmcp:unregistered"
  ]

  connect() {
    this.register()
  }

  disconnect() {
    this.unregister()
  }

  nameValueChanged() {
    if (this.#connected) this.register()
  }

  toolsValueChanged() {
    if (this.#connected) this.register()
  }

  // Registers this instance's tools; idempotent for an unchanged payload.
  register() {
    this.#connected = true
    if (!supported()) return
    if (document.documentElement.hasAttribute("data-turbo-preview")) return
    if (!this.nameValue || !validToolName(this.nameValue)) {
      console.warn(`[poetry-agent] webmcp: invalid instance name ${JSON.stringify(this.nameValue)}`)
      return
    }

    const hash = JSON.stringify([this.nameValue, this.toolsValue])
    const existing = registrations.get(this.element)
    if (existing?.hash === hash) return
    if (existing) this.unregister()

    const controller = new AbortController()
    const entry = { hash, controller, names: [] }
    registrations.set(this.element, entry)

    for (const tool of this.toolsValue) {
      const name = `poetry.${this.nameValue}.${tool.name}`
      if (!validToolName(name)) {
        console.warn(`[poetry-agent] webmcp: skipping invalid tool name ${name}`)
        continue
      }
      if (registeredCount() >= this.budgetValue) {
        console.warn(`[poetry-agent] webmcp: registration budget (${this.budgetValue}) reached; skipping ${name}`)
        break
      }

      const definition = {
        name,
        description: tool.description,
        annotations: tool.annotations,
        execute: (args, options) => this.#execute(tool, args ?? {}, options)
      }
      if (tool.title) definition.title = tool.title
      if (tool.inputSchema) definition.inputSchema = tool.inputSchema

      entry.names.push(name)
      registerTool(definition, { signal: controller.signal }).catch((error) => {
        entry.names = entry.names.filter((registered) => registered !== name)
        console.warn(`[poetry-agent] webmcp: could not register ${name}: ${error?.message ?? error}`)
      })
    }

    this.dispatch("registered", { prefix: "poetry:webmcp", detail: { name: this.nameValue, tools: [...entry.names] } })
  }

  // Aborts every registration of this instance.
  unregister() {
    const entry = registrations.get(this.element)
    if (!entry) return

    registrations.delete(this.element)
    entry.controller.abort()
    this.dispatch("unregistered", { prefix: "poetry:webmcp", detail: { name: this.nameValue, tools: entry.names } })
  }

  async #execute(tool, args, options) {
    const [identifier, method] = String(tool.executes).split("#")
    const target = this.application.getControllerForElementAndIdentifier(this.element, identifier)
    if (!target || typeof target[method] !== "function") {
      return `Error: ${tool.name} cannot run - no ${identifier}#${method} on this element`
    }

    const properties = tool.inputSchema?.properties ?? {}
    const missing = (tool.inputSchema?.required ?? []).filter((key) => args[key] === undefined)
    if (missing.length > 0) return `Error: missing required parameter(s) ${missing.join(", ")}`
    for (const [key, schema] of Object.entries(properties)) {
      if (schema.enum && args[key] !== undefined && !schema.enum.includes(args[key])) {
        return `Error: ${key} must be one of ${schema.enum.join(", ")}`
      }
    }

    try {
      const positional = Object.keys(properties).map((key) => args[key])
      const result = await target[method](...positional, options)
      const value = serializable(result) ? result : `${tool.name}: done`
      this.dispatch("executed", { prefix: "poetry:webmcp", detail: { tool: tool.name, args, result: value } })
      return value ?? `${tool.name}: done`
    } catch (error) {
      return `Error: ${tool.name} failed - ${error?.message ?? error}`
    }
  }

  #connected = false
}

// A tool result must survive JSON serialization (the spec stringifies it);
// DOM objects and undefined collapse to a done-marker instead.
const serializable = (value) => {
  if (value === undefined || value === null) return false
  if (typeof value === "object" && (value instanceof Node || value instanceof Event)) return false
  try {
    JSON.stringify(value)
    return true
  } catch {
    return false
  }
}

// Test seam: the live registration table.
export const _registrations = registrations
