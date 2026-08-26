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
      const summary = `${form.getAttribute("toolname")} ${outcome} (${response.status})${excerpt(text)}`
      this.dispatch("form-submitted", { prefix: "poetry:webmcp", detail: { status: response.status, ok: response.ok } })
      return summary
    } catch (error) {
      return `${form.getAttribute("toolname")} failed - ${error?.message ?? error}`
    }
  }
}

// A short, tag-stripped excerpt of the response body for the agent.
const excerpt = (text) => {
  const plain = text.replace(/<[^>]+>/g, " ").replace(/\s+/g, " ").trim()
  return plain ? `: ${plain.slice(0, 500)}` : ""
}
