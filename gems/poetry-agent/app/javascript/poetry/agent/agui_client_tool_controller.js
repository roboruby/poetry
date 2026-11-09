import { Controller } from "@hotwired/stimulus"
import { executeRegisteredTool } from "@poetry/agent/webmcp_controller"

/**
 * The AG-UI client-tool bridge: the relay appends one of these per tool
 * call the agent made to a FRONTEND tool - a component tool the page
 * declared - and this controller executes it through the registrar (the
 * same dispatch a WebMCP call takes, so it works in every browser,
 * modelContext or not), then POSTs the result to the continue URL. The
 * server folds the tool message into the transcript and answers with the
 * next run's streams, which Turbo renders. A tool declared to ask first
 * renders the host's approval prompt inside the element and waits: its
 * approve action runs the call, its deny action answers it as declined
 * without running it, and either answer hides the prompt. One element, one answer: the done flag makes a Turbo
 * re-render inert.
 */
export default class extends Controller {
  static values = {
    // The pending tool call: its id, name and arguments.
    call: Object,
    // Where the tool result is posted.
    url: String,
    // Whether the call has already been answered (a restored snapshot must not
    // answer twice).
    done: Boolean,
    // Whether the call waits for the user's approve or deny before anything runs.
    confirm: Boolean
  }

  static events = ["poetry:agui:client-tool-executed", "poetry:agui:client-tool-declined"]

  /**
   * Runs the pending client tool once, unless it waits for the user.
   */
  async connect() {
    if (this.doneValue || this.confirmValue) return
    await run(this)
  }

  /**
   * Runs the call the user approved.
   */
  async approve() {
    if (this.doneValue) return
    await run(this)
  }

  /**
   * Answers the call as declined: the tool never runs, and the agent is told so.
   */
  async deny() {
    if (this.doneValue) return
    this.doneValue = true
    this.element.hidden = true

    const { toolCallId, name } = this.callValue
    const body = { toolCallId, name, declined: true }
    this.dispatch("client-tool-declined", { prefix: "poetry:agui", detail: { ...body } })
    await post(this, body)
  }
}

// Executes the bridge's call through the registrar, once, and posts what it
// answered (its content, and its error when it failed).
const run = async (bridge) => {
  bridge.doneValue = true
  bridge.element.hidden = true

  const { toolCallId, name, args } = bridge.callValue
  let content
  let error
  try {
    content = await executeRegisteredTool(bridge.application, name, args ?? {})
  } catch (failure) {
    error = failure?.message ?? String(failure)
  }
  if (typeof content === "string" && content.startsWith("Error:")) error = content
  const text = typeof content === "string" ? content : JSON.stringify(content ?? null)

  const body = { toolCallId, name, content: text }
  if (error) body.error = error
  bridge.dispatch("client-tool-executed", { prefix: "poetry:agui", detail: { ...body } })
  await post(bridge, body)
}

// Posts an answer to the bridge's continue URL and renders the Turbo Streams
// the response carries.
const post = async (bridge, body) => {
  const response = await fetch(bridge.urlValue, {
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
