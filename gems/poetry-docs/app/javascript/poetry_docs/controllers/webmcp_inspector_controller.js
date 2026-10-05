import { Controller } from "@hotwired/stimulus"
import { modelContext, getTools, executeTool } from "@poetry/agent"

// The in-page agent, minus the model: lists every tool registered on this
// document through document.modelContext.getTools() and lets a person call
// one with executeTool() - the same two calls a browser agent makes. The
// demo components above this panel register their tools; the panel is
// how you watch it happen without an agent.
export default class extends Controller {
  static targets = ["status", "list", "log"]

  connect() {
    this.refresh = this.refresh.bind(this)
    const context = modelContext()
    if (!context) {
      this.statusTarget.textContent =
        "This browser exposes no document.modelContext. Enable chrome://flags/#enable-webmcp-testing " +
        "(Chrome 149+), or open this page in ChatGPT Desktop's browser, then reload."
      return
    }
    context.addEventListener("toolchange", this.refresh)
    this.refresh()
  }

  disconnect() {
    modelContext()?.removeEventListener("toolchange", this.refresh)
  }

  async refresh() {
    const tools = await getTools()
    this.statusTarget.textContent = tools.length === 0
      ? "No tools registered on this page yet."
      : `${tools.length} tool${tools.length === 1 ? "" : "s"} registered on this page - the same list a browser agent sees.`
    this.listTarget.replaceChildren(...tools.map((tool) => this.#row(tool)))
  }

  #row(tool) {
    const row = document.createElement("li")
    row.className = "flex flex-col gap-2 rounded-lg border p-3"

    const head = document.createElement("div")
    head.className = "flex flex-wrap items-baseline gap-2"
    const name = document.createElement("code")
    name.className = "font-mono text-sm"
    name.textContent = tool.name
    const hint = document.createElement("span")
    hint.className = "text-xs text-muted-foreground"
    hint.textContent = tool.annotations?.readOnlyHint ? "read-only" : "mutating"
    head.append(name, hint)

    const description = document.createElement("p")
    description.className = "text-sm text-muted-foreground"
    description.textContent = tool.description

    // Not a <form>: these controls drive a tool, they are not one - a
    // form here would read as an unannotated tool to an agentic audit.
    const form = document.createElement("div")
    form.className = "flex flex-wrap items-center gap-2"
    form.setAttribute("role", "group")
    form.setAttribute("aria-label", `Execute ${tool.name}`)
    const input = document.createElement("input")
    input.className = "cn-input min-w-64 flex-1 rounded-md border bg-background px-2 py-1 font-mono text-xs"
    input.setAttribute("aria-label", `Arguments for ${tool.name} as JSON`)
    input.value = JSON.stringify(this.#exampleArgs(tool))
    const button = document.createElement("button")
    button.type = "button"
    button.className = "rounded-md border px-3 py-1 text-sm hover:bg-accent"
    button.textContent = "Execute"
    form.append(input, button)
    const execute = async () => {
      let args = {}
      try { args = input.value.trim() ? JSON.parse(input.value) : {} } catch { this.#log(`${tool.name}: arguments must be JSON`); return }
      try {
        const result = await executeTool(tool, args)
        this.#log(`${tool.name}(${JSON.stringify(args)}) → ${typeof result === "string" ? result : JSON.stringify(result)}`)
      } catch (error) {
        this.#log(`${tool.name} rejected: ${error?.message ?? error}`)
      }
    }
    button.addEventListener("click", execute)
    input.addEventListener("keydown", (event) => { if (event.key === "Enter") execute() })

    row.append(head, description, form)
    return row
  }

  #exampleArgs(tool) {
    const properties = tool.inputSchema?.properties ?? {}
    return Object.fromEntries(Object.entries(properties).map(([key, schema]) => [
      key, schema.enum ? schema.enum[0] : (schema.type === "number" || schema.type === "integer" ? 0 : "")
    ]))
  }

  #log(line) {
    const item = document.createElement("li")
    item.className = "font-mono text-xs"
    item.textContent = line
    this.logTarget.prepend(item)
  }
}
