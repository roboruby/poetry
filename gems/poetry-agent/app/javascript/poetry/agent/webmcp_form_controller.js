import { Controller } from "@hotwired/stimulus"

// The declarative-form companion: a form declared with poetry_webmcp_form
// (toolname/tooldescription on the <form>) is registered by the BROWSER;
// this controller only answers an agent-invoked submit with the outcome.
// Chrome's SubmitEvent carries agentInvoked + respondWith(promise): we
// submit the form ourselves (fetch, same method/action, Turbo-Stream
// accepting) and respond with a short descriptive result instead of
// navigating, so the agent learns whether the submission succeeded and
// what the server said (validation errors included - it can self-correct).
//
// The person's page then catches up with the answer (a beat after the
// result is handed to the browser, so a navigation can never swallow
// it): a GET answer is the page at that URL - a Turbo visit, or a plain
// navigation without Turbo; a Turbo-Stream answer renders; a redirected
// POST (redirect-after-create) visits where the redirect went. An HTML
// re-render of a failed POST stays put - the agent already holds the
// errors, and the person keeps their filled form.
//
// Submits without agentInvoked (a person pressed Submit) pass through
// untouched: the human path stays the human path.
export default class extends Controller {
  static events = ["poetry:webmcp:form-submitted"]

  connect() {
    this.element.addEventListener("submit", this.submit)
  }

  disconnect() {
    this.element.removeEventListener("submit", this.submit)
  }

  submit = (event) => {
    if (!event.agentInvoked || typeof event.respondWith !== "function") return

    event.preventDefault()
    event.respondWith(this.#deliver())
  }

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

// Declarative tool attributes never reach an inert document: Chrome 151
// crashes the renderer when a DOMParser (or createHTMLDocument) document
// holds a <form toolname> - the answer page usually IS the page with the
// form - so they are stripped from the text before parsing. Turbo's own
// visit parse adopts the form into the live document and is unaffected.
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
