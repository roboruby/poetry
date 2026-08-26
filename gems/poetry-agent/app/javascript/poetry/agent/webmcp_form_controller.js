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
      return summary
    } catch (error) {
      return `${form.getAttribute("toolname")} failed - ${error?.message ?? error}`
    }
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

const htmlText = (html) => {
  const doc = new DOMParser().parseFromString(html, "text/html")
  for (const node of doc.querySelectorAll("script, style, noscript, template, nav, header, footer, aside")) node.remove()
  const region = doc.querySelector("[data-webmcp-result]") || doc.querySelector("main") || doc.body
  return (region?.textContent || "").replace(/\s+/g, " ").trim()
}
