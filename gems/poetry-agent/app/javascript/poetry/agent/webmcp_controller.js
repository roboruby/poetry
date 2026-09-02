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
//   are still open spec issues; a string lets the agent self-correct):
//   a missing or unknown parameter, a value of the wrong type or outside
//   the enum, a missing action, a throwing action.
// - A result is the action's return value when it is JSON-serializable
//   (the contract's actions return their resulting state, so an answer
//   says what happened rather than "done"); the done marker covers
//   actions that return nothing.
// - Parameters map positionally onto the action in declared order; the
//   execute callback's {signal} is not forwarded (the actions are
//   synchronous UI operations).

// element -> { hash, controller: AbortController, names: string[] }
const registrations = new Map()

// element -> the registrar instance, for every connected root whether or
// not the browser exposes modelContext: in-page callers (the AG-UI
// client-tool bridge) execute a declared tool by its registered name.
const instances = new Map()

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
    instances.set(this.element, this)
    this.register()
  }

  disconnect() {
    instances.delete(this.element)
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
    const pending = []

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
        execute: (args) => this.#execute(tool, args ?? {})
      }
      if (tool.title) definition.title = tool.title
      if (tool.inputSchema) definition.inputSchema = tool.inputSchema

      entry.names.push(name)
      pending.push(registerTool(definition, { signal: controller.signal }).catch((error) => {
        entry.names = entry.names.filter((registered) => registered !== name)
        console.warn(`[poetry-agent] webmcp: could not register ${name}: ${error?.message ?? error}`)
      }))
    }

    // The registered event carries what the browser ACCEPTED, so it fires
    // once every registration settled (and not at all if this instance
    // unregistered meanwhile).
    Promise.allSettled(pending).then(() => {
      if (registrations.get(this.element) !== entry) return
      this.dispatch("registered", { prefix: "poetry:webmcp", detail: { name: this.nameValue, tools: [...entry.names] } })
    })
  }

  // Executes one of this instance's declared tools by its full registered
  // name (`poetry.{instance}.{tool}`) or its bare tool name, with the same
  // validation and dispatch a WebMCP call takes; unknown names answer with
  // an error string like any other problem.
  execute(name, args = {}) {
    const tool = this.toolsValue.find((candidate) =>
      `poetry.${this.nameValue}.${candidate.name}` === name || candidate.name === name)
    if (!tool) return Promise.resolve(`Error: no tool named ${name} on ${this.nameValue}`)
    return this.#execute(tool, args ?? {})
  }

  // Aborts every registration of this instance.
  unregister() {
    const entry = registrations.get(this.element)
    if (!entry) return

    registrations.delete(this.element)
    entry.controller.abort()
    this.dispatch("unregistered", { prefix: "poetry:webmcp", detail: { name: this.nameValue, tools: entry.names } })
  }

  async #execute(tool, args) {
    const [identifier, method] = String(tool.executes).split("#")
    const target = this.application.getControllerForElementAndIdentifier(this.element, identifier)
    if (!target || typeof target[method] !== "function") {
      return `Error: ${tool.name} cannot run - no ${identifier}#${method} on this element`
    }

    const problem = validate(tool, args)
    if (problem) return problem

    try {
      const positional = Object.keys(tool.inputSchema?.properties ?? {}).map((key) => args[key])
      const result = await target[method](...positional)
      const value = serializable(result) ? result : `${tool.name}: done`
      this.dispatch("executed", { prefix: "poetry:webmcp", detail: { tool: tool.name, args, result: value } })
      return value ?? `${tool.name}: done`
    } catch (error) {
      return `Error: ${tool.name} failed - ${error?.message ?? error}`
    }
  }

  #connected = false
}

// Strict validation in code, loose in schema (Chrome's rule): the schema
// is a hint the agent may miss, so every call is checked here and answered
// with a string it can act on - which parameter, what it takes.
const validate = (tool, args) => {
  const schema = tool.inputSchema ?? {}
  const properties = schema.properties ?? {}
  const missing = (schema.required ?? []).filter((key) => args[key] === undefined)
  if (missing.length > 0) return `Error: missing required parameter(s) ${missing.join(", ")}`

  if (schema.additionalProperties === false) {
    const unknown = Object.keys(args).filter((key) => !(key in properties))
    if (unknown.length > 0) {
      const takes = Object.keys(properties).join(", ") || "no parameters"
      return `Error: unknown parameter(s) ${unknown.join(", ")} - ${tool.name} takes ${takes}`
    }
  }

  for (const [key, spec] of Object.entries(properties)) {
    const value = args[key]
    if (value === undefined) continue
    if (!matchesType(value, spec.type)) return `Error: ${key} must be ${describeType(spec.type)}`
    if (spec.enum && !spec.enum.includes(value)) return `Error: ${key} must be one of ${spec.enum.join(", ")}`
  }
  return null
}

const matchesType = (value, type) => {
  if (!type) return true
  const types = Array.isArray(type) ? type : [type]
  return types.some((expected) => {
    switch (expected) {
      case "string": return typeof value === "string"
      case "number": return typeof value === "number" && Number.isFinite(value)
      case "integer": return Number.isInteger(value)
      case "boolean": return typeof value === "boolean"
      case "array": return Array.isArray(value)
      case "object": return value !== null && typeof value === "object" && !Array.isArray(value)
      case "null": return value === null
      default: return true
    }
  })
}

const describeType = (type) => (Array.isArray(type) ? type.join(" or ") : `${/^[aeiou]/.test(type) ? "an" : "a"} ${type}`)

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

// Executes a declared tool by its full registered name on whichever
// connected root declares it - the in-page dispatch path (no
// modelContext needed). Answers an error string when no root does.
export const executeRegisteredTool = (application, name, args = {}) => {
  for (const [element, controller] of instances) {
    const owns = controller.toolsValue.some((tool) => `poetry.${controller.nameValue}.${tool.name}` === name)
    if (owns && application.getControllerForElementAndIdentifier(element, "poetry--agent--webmcp") === controller) {
      return controller.execute(name, args)
    }
  }
  return Promise.resolve(`Error: no registered tool named ${name} on this page`)
}

// Test seam: the live registration table.
export const _registrations = registrations
