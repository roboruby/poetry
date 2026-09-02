import { Controller } from "@hotwired/stimulus"
import { executeRegisteredTool } from "@poetry/agent/webmcp_controller"

// The AG-UI client-tool bridge: the relay appends one of these (hidden)
// per tool call the agent made to a FRONTEND tool - a component tool the
// page declared - and this controller executes it through the registrar
// (the same dispatch a WebMCP call takes, so it works in every browser,
// modelContext or not), then POSTs the result to the continue URL. The
// server folds the tool message into the transcript and answers with the
// next run's streams, which Turbo renders. One element, one execution:
// the done flag makes a Turbo re-render inert.
export default class extends Controller {
  static values = {
    call: Object,
    url: String,
    done: Boolean
  }

  static events = ["poetry:agui:client-tool-executed"]

  async connect() {
    if (this.doneValue) return
    this.doneValue = true

    const { toolCallId, name, args } = this.callValue
    let content
    let error
    try {
      content = await executeRegisteredTool(this.application, name, args ?? {})
    } catch (failure) {
      error = failure?.message ?? String(failure)
    }
    if (typeof content === "string" && content.startsWith("Error:")) error = content
    const text = typeof content === "string" ? content : JSON.stringify(content ?? null)

    const body = { toolCallId, name, content: text }
    if (error) body.error = error
    this.dispatch("client-tool-executed", { prefix: "poetry:agui", detail: { ...body } })

    const response = await fetch(this.urlValue, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Accept: "text/vnd.turbo-stream.html, text/html",
        "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content ?? ""
      },
      body: JSON.stringify(body)
    })
    const streams = await response.text()
    const type = response.headers.get("content-type") || ""
    if (response.ok && type.includes("text/vnd.turbo-stream.html")) globalThis.Turbo?.renderStreamMessage?.(streams)
  }
}
