import { Controller } from "@hotwired/stimulus"

// The client side of an A2UI surface's checks: the server renders the
// program (every checked component's rules with absolute bindings, the
// bound inputs by path with their kinds, and the data model) and this
// controller evaluates it as the user types - a button whose own checks
// fail is disabled, a failing input is marked invalid and its error slot
// carries the message. The five validators and the three combinators are
// the checks vocabulary; anything else passes here and is judged by the
// server, which re-runs every rule on the action.
const EMAIL = /^[^\s@]+@[^\s@]+\.[^\s@]+$/

export default class extends Controller {
  static values = { program: Object }

  connect() {
    this.evaluate()
  }

  evaluate() {
    const checks = this.programValue?.checks || {}
    for (const [key, entry] of Object.entries(checks)) {
      const failures = (entry.rules || []).map((rule) => this.failure(rule)).filter(Boolean)
      this.apply(key, entry.kind, failures)
    }
  }

  // The message of a failing rule, or null when it passes.
  failure(rule) {
    const result = this.resolve(rule.condition)
    if (result === null) return null // unknown here; the server decides
    const valid = result && typeof result === "object" ? result.valid === true : truthy(result)
    if (valid) return null
    return (result && typeof result === "object" && result.message) || rule.message || "Check failed"
  }

  apply(key, kind, failures) {
    for (const element of this.element.querySelectorAll(`[data-a2ui-key="${escapeAttribute(key)}"]`)) {
      if (kind === "button") {
        element.disabled = failures.length > 0
      } else {
        element.setAttribute("aria-invalid", failures.length > 0 ? "true" : "false")
      }
    }
    const slot = this.element.querySelector(`[data-a2ui-error-for="${escapeAttribute(key)}"]`)
    if (slot) {
      slot.textContent = failures[0] || ""
      slot.hidden = failures.length === 0
    }
  }

  resolve(value) {
    if (value === null || typeof value !== "object") return value
    if (Array.isArray(value)) return value.map((item) => this.resolve(item))
    if (typeof value.path === "string") return this.read(value.path)
    if (typeof value.call === "string") return this.call(value.call, value.args || {})
    return value
  }

  call(name, rawArgs) {
    const fn = FUNCTIONS[name]
    if (!fn) return null
    const args = {}
    for (const [key, raw] of Object.entries(rawArgs)) args[key] = this.resolve(raw)
    return fn(args)
  }

  // The current value of a bound path: the form control first, the
  // server's model when no control carries it.
  read(path) {
    const kind = this.programValue?.inputs?.[path]
    const name = `a2ui[values][${path}]`
    if (kind === "boolean") {
      const box = this.element.querySelector(`input[type="checkbox"][name="${escapeAttribute(name)}"]`)
      return box ? box.checked : pointer(this.programValue?.model, path)
    }
    if (kind === "string_list") {
      const boxes = [...this.element.querySelectorAll(`input[name="${escapeAttribute(name + "[]")}"]:checked`)].map((box) => box.value).filter((v) => v !== "")
      if (boxes.length) return boxes
      const picked = this.element.querySelector(`input[type="radio"][name="${escapeAttribute(name)}"]:checked`)
      if (picked) return [picked.value]
      const select = this.element.querySelector(`select[name="${escapeAttribute(name)}"], select[name="${escapeAttribute(name + "[]")}"]`)
      if (select) return [...select.selectedOptions].map((option) => option.value).filter((v) => v !== "")
      return this.element.querySelector(`[name="${escapeAttribute(name + "[]")}"], [name="${escapeAttribute(name)}"]`) ? [] : pointer(this.programValue?.model, path)
    }
    const control = this.element.querySelector(`[name="${escapeAttribute(name)}"]:not([type="hidden"])`)
    if (!control) return pointer(this.programValue?.model, path)
    if (kind === "number") return control.value === "" ? null : Number(control.value)
    return control.value
  }
}

// An attribute-selector value (jsdom has no CSS.escape; quoting is enough).
const escapeAttribute = (value) => String(value).replace(/["\\]/g, "\\$&")

const pointer = (document, path) => {
  if (!document || path === "" || path === "/") return document
  return path.replace(/^\//, "").split("/").reduce((node, token) => {
    if (node === null || node === undefined) return undefined
    const key = token.replace(/~1/g, "/").replace(/~0/g, "~")
    return Array.isArray(node) ? node[Number(key)] : node[key]
  }, document)
}

const truthy = (value) => {
  if (value && typeof value === "object" && !Array.isArray(value)) return value.valid === true
  if (typeof value === "string") return value !== "" && !["false", "0"].includes(value.toLowerCase())
  return value !== null && value !== undefined && value !== false
}

const present = (value) => {
  if (value === null || value === undefined) return false
  if (typeof value === "string") return value.trim() !== ""
  if (Array.isArray(value)) return value.length > 0
  return true
}

const within = (n, min, max) => (min === undefined || min === null || n >= min) && (max === undefined || max === null || n <= max)

const number = (value) => {
  if (typeof value === "number") return Number.isFinite(value) ? value : null
  if (typeof value !== "string" || value.trim() === "") return null
  const parsed = Number(value)
  return Number.isFinite(parsed) ? parsed : null
}

const FUNCTIONS = {
  required: ({ value }) => ({ valid: present(value) }),
  regex: ({ value, pattern }) => {
    try { return { valid: new RegExp(pattern).test(String(value ?? "")) } } catch { return null }
  },
  length: ({ value, min, max }) => ({ valid: within(String(value ?? "").length, min, max) }),
  numeric: ({ value, min, max }) => {
    const n = number(value)
    return { valid: n !== null && within(n, min, max) }
  },
  email: ({ value }) => ({ valid: EMAIL.test(String(value ?? "")) }),
  and: ({ values }) => (Array.isArray(values) ? values : []).every(truthy),
  or: ({ values }) => (Array.isArray(values) ? values : []).some(truthy),
  not: ({ value }) => !truthy(value)
}
