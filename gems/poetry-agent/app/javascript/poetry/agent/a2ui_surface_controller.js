import { Controller } from "@hotwired/stimulus"

const EMAIL = /^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$/

// What v1.0's email says of an address it refuses.
const EMAIL_FAILURE = { valid: false, code: "INVALID_EMAIL", message: "Please enter a valid email address (e.g. user@example.com).", severity: "error" }

/**
 * The client side of an A2UI surface's checks: the server renders the
 * program (every checked component's rules, spelled as v1.0 spells them
 * whatever the surface speaks: `{"@path"}` bindings made absolute,
 * `{"@call", args}` calls, a literal `@` key doubled; the path each
 * checked control binds; the bound inputs by path with their kinds; and
 * the data model) and this controller evaluates it as the user types.
 *
 * A button whose own checks fail is disabled from the start. What the
 * user sees of a failure waits for them: an input's message and invalid
 * state appear once its path has been edited, a button's reason once any
 * input has. Until then the server's rendering stands, including the
 * failures it rendered after a rejected action; one the browser cannot
 * judge (a rule on a function it does not know) stands until the server
 * judges it again. A morph keeps the element and this controller, so the
 * edited inputs are judged again once the morph is over.
 *
 * The five validators and the three combinators are the checks
 * vocabulary; anything else passes here and is judged by the server,
 * which re-runs every rule on the action.
 */
export default class extends Controller {
  static values = {
    // The check program the server compiled: the checks (each with the path its control binds), the bound inputs by path, and the data model.
    program: Object
  }

  /**
   * Starts with nothing touched: the paths the user has edited since the
   * surface mounted.
   */
  initialize() {
    this.touched = new Set()
  }

  /**
   * Evaluates every check at mount and again when a server render
   * changes the program.
   */
  programValueChanged() {
    this.evaluate()
  }

  /**
   * Marks the edited input's path touched and evaluates every check.
   *
   * @param {Event} event the input or change event
   */
  touch(event) {
    const path = pathOf(event.target)
    if (path) this.touched.add(path)
    this.evaluate()
  }

  /**
   * Evaluates every check once a morph of the surface is over: the morph
   * left the slots and attributes as the server rendered them, and the
   * edited inputs keep their values. One pass per morph, however many
   * elements it touched.
   */
  morphed() {
    if (this.pending) return
    this.pending = true
    queueMicrotask(() => {
      this.pending = false
      this.evaluate()
    })
  }

  /**
   * Runs every check in the program and applies its failures.
   */
  evaluate() {
    const checks = this.programValue?.checks || {}
    for (const [key, entry] of Object.entries(checks)) {
      const verdicts = (entry.rules || []).map((rule) => this.failure(rule))
      this.apply(key, entry, verdicts.filter((verdict) => typeof verdict === "string"), verdicts.includes(undefined))
    }
  }

  /**
   * A rule's failure message, null when it passes, or undefined when it
   * cannot be decided here.
   *
   * @param {Object} rule the check rule with its condition and message
   * @returns {string|null|undefined} the failure message, null, or undefined
   */
  failure(rule) {
    const result = this.resolve(rule.condition)
    if (result === null) return undefined // unknown here; the server decides
    const valid = result && typeof result === "object" ? result.valid === true : truthy(result)
    if (valid) return null
    return (result && typeof result === "object" && result.message) || rule.message || "Check failed"
  }

  /**
   * Reflects a check's verdict on the elements bound to a key. A button
   * disables while its checks fail. The message and the invalid state
   * follow the verdict only once the user has touched the input (any
   * input, for a button); before that, and for a server failure the
   * browser cannot judge, the server's rendering stands.
   *
   * @param {string} key the bound key the elements carry
   * @param {Object} entry the check entry: its kind (button or input) and the path its control binds
   * @param {string[]} failures the failure messages, empty when every decided rule passes
   * @param {boolean} undecided whether a rule could not be decided here
   */
  apply(key, entry, failures, undecided) {
    const failing = failures.length > 0
    const button = entry.kind === "button"
    const controls = [...this.element.querySelectorAll(`[data-a2ui-key="${escapeAttribute(key)}"]`)]
    if (button) for (const control of controls) control.disabled = failing
    if (!(button ? this.touched.size > 0 : this.touched.has(entry.path))) return

    const slot = this.element.querySelector(`[data-a2ui-error-for="${escapeAttribute(key)}"]`)
    if (!failing && undecided && serverVerdict(slot)) return

    if (!button) for (const control of controls) control.setAttribute("aria-invalid", failing ? "true" : "false")
    if (slot) {
      slot.textContent = failures[0] || ""
      slot.hidden = !failing
      slot.dataset.a2uiVerdict = "browser"
    }
  }

  /**
   * A value with its bindings read and its calls run, recursively; a
   * literal object's doubled `@@` keys read as their literal.
   *
   * @param {*} value a literal, a binding, a call, an object or an array of them
   * @returns {*} the resolved value
   */
  resolve(value) {
    if (value === null || typeof value !== "object") return value
    if (Array.isArray(value)) return value.map((item) => this.resolve(item))
    if (typeof value["@path"] === "string") return this.read(value["@path"])
    if (typeof value["@call"] === "string") return this.call(value["@call"], value.args || {})
    return Object.fromEntries(Object.entries(value).map(([key, item]) => [unescapeKey(key), this.resolve(item)]))
  }

  /**
   * Runs a catalog function by name with its arguments resolved; an unknown
   * name resolves to null.
   *
   * @param {string} name the catalog function
   * @param {Object} rawArgs the arguments, bindings and calls unresolved
   * @returns {*} the function's result, or null for an unknown name
   */
  call(name, rawArgs) {
    const fn = FUNCTIONS[name]
    if (!fn) return null
    const args = {}
    for (const [key, raw] of Object.entries(rawArgs)) args[key] = this.resolve(raw)
    return fn(args, !String(this.programValue?.version ?? "1.0").startsWith("v0."))
  }

  /**
   * The current value of a bound path from the form's inputs, falling back to
   * the data model.
   *
   * @param {string} path the bound pointer
   * @returns {*} the input's current value, or the model's
   */
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

// The bound path an input's name carries (`a2ui[values][/email]`, with a
// trailing `[]` for a list), or null for any other element.
const pathOf = (element) => {
  const match = /^a2ui\[values\]\[(.+?)\](\[\])?$/.exec(element?.name || "")
  return match ? match[1] : null
}

// Whether a slot shows a failure the server rendered (one the browser wrote carries its mark).
const serverVerdict = (slot) => Boolean(slot && !slot.hidden && slot.textContent !== "" && slot.dataset.a2uiVerdict !== "browser")

// A literal object's key: v1.0 doubles a leading @ ("@@type" is "@type").
const unescapeKey = (key) => (key.startsWith("@@") ? key.slice(1) : key)

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

// A value's boolean reading: in v1.0 a ValidationResult reads as its verdict,
// in v0.9 an object is simply present.
const truthy = (value, v1 = true) => {
  if (value && typeof value === "object" && !Array.isArray(value)) return v1 && typeof value.valid === "boolean" ? value.valid : true
  if (typeof value === "string") return value !== "" && !["false", "0"].includes(value.toLowerCase())
  return value !== null && value !== undefined && value !== false
}

const present = (value) => {
  if (value === null || value === undefined) return false
  if (typeof value === "string") return value.trim() !== ""
  if (Array.isArray(value)) return value.length > 0
  return true
}

// A validator's answer: v1.0's ValidationResult, v0.9's boolean.
const result = (valid, v1) => (v1 ? { valid } : valid)

// The length length checks: a list's items, nothing's zero, any other value's characters.
const lengthOf = (value) => {
  if (Array.isArray(value)) return value.length
  if (value === null || value === undefined) return 0
  return typeof value === "object" ? JSON.stringify(value).length : String(value).length
}

// A combinator's operands, or null when there are fewer than two (the server decides).
const operands = (values) => (Array.isArray(values) && values.length >= 2 ? values : null)

const within = (n, min, max) => (min === undefined || min === null || n >= min) && (max === undefined || max === null || n <= max)

const number = (value) => {
  if (typeof value === "number") return Number.isFinite(value) ? value : null
  if (typeof value !== "string" || value.trim() === "") return null
  const parsed = Number(value)
  return Number.isFinite(parsed) ? parsed : null
}

const FUNCTIONS = {
  required: ({ value }, v1) => result(present(value), v1),
  regex: ({ value, pattern }, v1) => {
    try { return result(new RegExp(pattern).test(String(value ?? "")), v1) } catch { return null }
  },
  length: ({ value, min, max }, v1) => result(within(lengthOf(value), min, max), v1),
  numeric: ({ value, min, max }, v1) => {
    const n = number(value)
    return result(n !== null && within(n, min, max), v1)
  },
  email: ({ value }, v1) => {
    const valid = typeof value === "string" && EMAIL.test(value)
    return v1 && !valid ? { ...EMAIL_FAILURE } : result(valid, v1)
  },
  and: ({ values }, v1) => operands(values)?.every((value) => truthy(value, v1)) ?? null,
  or: ({ values }, v1) => operands(values)?.some((value) => truthy(value, v1)) ?? null,
  not: ({ value }, v1) => !truthy(value, v1)
}
