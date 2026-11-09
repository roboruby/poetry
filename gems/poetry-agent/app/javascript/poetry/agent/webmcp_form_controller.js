import { Controller } from "@hotwired/stimulus"
import { acquire, release, announce } from "@poetry/controllers/helpers/announce"

/**
 * The declarative-form companion: a form declared with poetry_webmcp_form
 * (toolname/tooldescription on the <form>) is registered by the BROWSER;
 * this controller only answers an agent-invoked submit with the outcome.
 * Chrome's SubmitEvent carries agentInvoked + respondWith(promise): we
 * submit the form ourselves (fetch, same method/action, Turbo-Stream
 * accepting) and respond with a short descriptive result instead of
 * navigating, so the agent learns whether the submission succeeded and
 * what the server said (validation errors included - it can self-correct).
 *
 * The person's page then catches up with the answer (a beat after the
 * result is handed to the browser, so a navigation can never swallow
 * it): a GET answer is the page at that URL - a Turbo visit, or a plain
 * navigation without Turbo; a Turbo-Stream answer renders; a redirected
 * POST (redirect-after-create) visits where the redirect went. An HTML
 * re-render of a failed POST stays put - the agent already holds the
 * errors, and the person keeps their filled form.
 *
 * Submits without agentInvoked (a person pressed Submit) pass through
 * untouched: the human path stays the human path.
 *
 * The browser also tells the page when an agent runs a tool: toolactivated
 * fires on document.modelContext once the agent has filled a declarative
 * form, and toolcancel when the agent abandons the call because the person
 * moved on to another turn. For its own tool this controller marks the form
 * (`data-webmcp-agent="active"`), dispatches poetry:webmcp:tool-activated
 * and poetry:webmcp:tool-cancelled on it, and announces the fill and the
 * cancel through the shared live region - the agent's fill is a change the
 * person did not make. The marker lasts until the cancel, the person's own
 * submit, or the delivered answer of an agent-invoked submit: Chrome 156
 * (measured 2026-10-30) fires toolactivated AFTER the submit of an
 * autosubmit form, so a submit alone cannot end it. An autosubmit form's
 * fill is announced by nothing here - its submit's answer, and the page
 * catching up, are what the person perceives. The browser's pseudo-classes
 * carry the visual; a browser without a model context hears nothing and
 * loses nothing.
 */
export default class extends Controller {
  static values = {
    // What screen-reader users hear once an agent has filled this form.
    activatedMessage: { type: String, default: "Your agent filled this form. Review it, then submit." },
    // What they hear when the agent abandons the fill.
    cancelledMessage: { type: String, default: "Your agent stopped filling this form." }
  }

  static events = ["poetry:webmcp:form-submitted", "poetry:webmcp:tool-activated", "poetry:webmcp:tool-cancelled"]

  /**
   * Listens for the form's submit, and for the browser's tool events when
   * it exposes a model context.
   */
  connect() {
    this.element.addEventListener("submit", this.submit)
    const context = document.modelContext
    if (typeof context?.addEventListener !== "function") return
    this.#context = context
    acquire()
    context.addEventListener("toolactivated", this.activated)
    context.addEventListener("toolcancel", this.cancelled)
  }

  /**
   * Stops listening, drops the agent marker and releases the live region.
   */
  disconnect() {
    this.element.removeEventListener("submit", this.submit)
    if (!this.#context) return
    this.#context.removeEventListener("toolactivated", this.activated)
    this.#context.removeEventListener("toolcancel", this.cancelled)
    this.#context = null
    this.#clear()
    release()
  }

  submit = (event) => {
    if (!event.agentInvoked || typeof event.respondWith !== "function") {
      this.#clear()
      return
    }

    event.preventDefault()
    const delivery = this.#deliver()
    event.respondWith(delivery)
    delivery.finally(() => this.#clear())
  }

  activated = (event) => {
    if (!this.#own(event)) return
    this.element.setAttribute("data-webmcp-agent", "active")
    this.dispatch("tool-activated", { prefix: "poetry:webmcp", detail: { tool: event.toolName } })
    if (!this.element.hasAttribute("toolautosubmit")) announce(this.activatedMessageValue)
  }

  cancelled = (event) => {
    if (!this.#own(event)) return
    this.#clear()
    this.dispatch("tool-cancelled", { prefix: "poetry:webmcp", detail: { tool: event.toolName } })
    announce(this.cancelledMessageValue)
  }

  /**
   * Whether a tool event names this form's own tool.
   *
   * @param {Event} event a toolactivated or toolcancel event
   * @returns {boolean} true when its toolName is the form's toolname
   */
  #own(event) {
    return typeof event.toolName === "string" && event.toolName === this.element.getAttribute("toolname")
  }

  /**
   * Drops the agent marker.
   */
  #clear() {
    this.element.removeAttribute("data-webmcp-agent")
  }

  /**
   * Submits the form on the agent's behalf: a fetch with the form's method
   * and data (the query string for GET, the body otherwise), accepting a
   * Turbo Stream, HTML or JSON; tells the page it was submitted and reflects
   * the answer on it.
   *
   * @returns {Promise<string>} a one-line summary of the answer for the agent, or of the failure
   */
  async #deliver() {
    const form = this.element
    const method = (form.getAttribute("method") || "get").toUpperCase()
    const data = new FormData(form)
    let url = form.action
    const init = { method, headers: { Accept: "text/vnd.turbo-stream.html, text/html, application/json" } }

    if (method === "GET") {
      const target = new URL(url, document.baseURI)
      for (const [key, value] of data.entries()) target.searchParams.append(key, value)
      url = target.toString()
    } else {
      init.body = data
    }

    try {
      const response = await fetch(url, init)
      const text = await response.text()
      const outcome = response.ok ? "succeeded" : "failed"
      const summary = `${form.getAttribute("toolname")} ${outcome} (${response.status})${excerpt(text, response.headers.get("content-type") || "")}`
      this.dispatch("form-submitted", { prefix: "poetry:webmcp", detail: { status: response.status, ok: response.ok } })
      setTimeout(() => reflect(method, url, response, text), 0)
      return summary
    } catch (error) {
      return `${form.getAttribute("toolname")} failed - ${error?.message ?? error}`
    }
  }

  #context = null
}

// The page shows what the agent read.
const reflect = (method, url, response, text) => {
  const turbo = window.Turbo
  const type = response.headers.get("content-type") || ""

  if (type.includes("text/vnd.turbo-stream.html")) {
    turbo?.renderStreamMessage?.(text)
  } else if (method === "GET") {
    if (turbo?.visit) turbo.visit(url, { action: "replace" })
    else window.location.assign(url)
  } else if (response.redirected && response.url) {
    if (turbo?.visit) turbo.visit(response.url)
    else window.location.assign(response.url)
  }
}

// A short excerpt of the response for the agent. HTML answers are parsed:
// scripts, styles, and chrome are dropped, and a region the app marks
// `data-webmcp-result` wins over <main>, which wins over the body - so a
// search page answers with its results, not its navigation.
const excerpt = (text, contentType = "") => {
  const plain = contentType.includes("html") || /^\s*</.test(text) ? htmlText(text) : text.replace(/\s+/g, " ").trim()
  return plain ? `: ${plain.slice(0, 500)}` : ""
}

/**
 * Declarative tool attributes never reach an inert document: Chrome 151
 * crashes the renderer when a DOMParser (or createHTMLDocument) document
 * holds a <form toolname> - the answer page usually IS the page with the
 * form - so they are stripped from the text before parsing. Turbo's own
 * visit parse adopts the form into the live document and is unaffected.
 *
 * @param {string} html the answer page's markup
 * @returns {string} the markup without tool attributes
 */
export const stripToolAttributes = (html) =>
  html.replace(/\stool(?:name|description|autosubmit|paramdescription)(?:=(?:"[^"]*"|'[^']*'|[^\s>]*))?/gi, "")

const htmlText = (html) => {
  const doc = new DOMParser().parseFromString(stripToolAttributes(html), "text/html")
  for (const node of doc.querySelectorAll("script, style, noscript, template, nav, header, footer, aside")) node.remove()
  const region = doc.querySelector("[data-webmcp-result]") || doc.querySelector("main") || doc.body
  // Element boundaries become spaces (textContent runs adjacent items together).
  const spaced = new DOMParser().parseFromString((region?.innerHTML || "").replace(/<[^>]+>/g, " "), "text/html")
  return (spaced.body.textContent || "").replace(/\s+/g, " ").trim()
}
