import { describe, it, expect, beforeEach, afterEach, vi } from "vitest"
import { Application, Controller } from "@hotwired/stimulus"
import { registerPoetryAgent, _registrations } from "@poetry/agent"

// A fake document.modelContext that records registrations and honors the
// AbortSignal unregistration contract.
const fakeContext = () => {
  const tools = new Map()
  return {
    tools,
    registerTool: vi.fn(async (definition, options = {}) => {
      if (tools.has(definition.name)) throw new Error(`duplicate ${definition.name}`)
      tools.set(definition.name, definition)
      options.signal?.addEventListener("abort", () => tools.delete(definition.name))
    }),
    getTools: vi.fn(async () => [...tools.values()]),
    executeTool: vi.fn(async (tool, args) => tools.get(tool.name).execute(args, { signal: new AbortController().signal }))
  }
}

// A stand-in component controller with the action shapes the skeleton
// components expose: setValue(value), clear(), open().
class FakeComponent extends Controller {
  static values = { value: String, opened: Boolean }
  setValue(value) { this.valueValue = String(value); return { value: this.valueValue } }
  clear() { this.valueValue = "" }
  open() { this.openedValue = true }
  fail() { throw new Error("boom") }
  element_result() { return this.element }
}

const TOOLS = [
  { name: "set_value", description: "Select.", inputSchema: { type: "object", properties: { value: { type: "string", enum: ["a", "b"] } }, required: ["value"] },
    annotations: { readOnlyHint: false, untrustedContentHint: false }, executes: "poetry--core--fake#setValue" },
  { name: "clear", description: "Clear.", annotations: { readOnlyHint: false, untrustedContentHint: false }, executes: "poetry--core--fake#clear" },
  { name: "open", description: "Open.", annotations: { readOnlyHint: false, untrustedContentHint: false }, executes: "poetry--core--fake#open" },
  { name: "fail", description: "Fail.", annotations: { readOnlyHint: true, untrustedContentHint: false }, executes: "poetry--core--fake#fail" },
  { name: "node", description: "Node result.", annotations: { readOnlyHint: true, untrustedContentHint: false }, executes: "poetry--core--fake#element_result" },
  { name: "ghost", description: "Missing action.", annotations: { readOnlyHint: true, untrustedContentHint: false }, executes: "poetry--core--fake#nope" }
]

const mount = (name, tools = TOOLS, extra = "") => {
  document.body.innerHTML = `
    <div id="root" data-controller="poetry--core--fake poetry--agent--webmcp"
         data-poetry--agent--webmcp-name-value="${name}"
         data-poetry--agent--webmcp-tools-value='${JSON.stringify(tools).replace(/'/g, "&#39;")}' ${extra}></div>`
  return document.getElementById("root")
}

const flush = () => new Promise((resolve) => setTimeout(resolve, 0))

describe("poetry--agent--webmcp", () => {
  let application, context

  beforeEach(async () => {
    context = fakeContext()
    document.modelContext = context
    application = Application.start()
    application.register("poetry--core--fake", FakeComponent)
    registerPoetryAgent(application)
    await flush()
  })

  afterEach(async () => {
    application.stop()
    document.body.innerHTML = ""
    document.documentElement.removeAttribute("data-turbo-preview")
    delete document.modelContext
    _registrations.clear()
    await flush()
  })

  it("registers each declared tool under poetry.{instance}.{tool} with the MCP fields", async () => {
    mount("country")
    await flush()

    expect([...context.tools.keys()]).toEqual(["poetry.country.set_value", "poetry.country.clear", "poetry.country.open", "poetry.country.fail", "poetry.country.node", "poetry.country.ghost"])
    const tool = context.tools.get("poetry.country.set_value")
    expect(tool.description).toBe("Select.")
    expect(tool.inputSchema.required).toEqual(["value"])
    expect(tool.annotations).toEqual({ readOnlyHint: false, untrustedContentHint: false })
  })

  it("dispatches positionally to the component's own controller and returns the result", async () => {
    const root = mount("country")
    await flush()
    const executed = vi.fn()
    root.addEventListener("poetry:webmcp:executed", (event) => executed(event.detail))

    const result = await context.executeTool({ name: "poetry.country.set_value" }, { value: "b" })

    expect(result).toEqual({ value: "b" })
    expect(root.getAttribute("data-poetry--core--fake-value-value")).toBe("b")
    expect(executed).toHaveBeenCalledWith(expect.objectContaining({ tool: "set_value", args: { value: "b" } }))
  })

  it("returns descriptive error strings instead of throwing", async () => {
    mount("country")
    await flush()

    expect(await context.executeTool({ name: "poetry.country.set_value" }, {})).toMatch(/missing required parameter\(s\) value/)
    expect(await context.executeTool({ name: "poetry.country.set_value" }, { value: "z" })).toMatch(/must be one of a, b/)
    expect(await context.executeTool({ name: "poetry.country.fail" }, {})).toMatch(/fail failed - boom/)
    expect(await context.executeTool({ name: "poetry.country.ghost" }, {})).toMatch(/no poetry--core--fake#nope/)
  })

  it("collapses unserializable results to a done marker", async () => {
    mount("country")
    await flush()

    expect(await context.executeTool({ name: "poetry.country.clear" }, {})).toBe("clear: done")
    expect(await context.executeTool({ name: "poetry.country.node" }, {})).toBe("node: done")
  })

  it("unregisters through the AbortSignal on disconnect", async () => {
    const root = mount("country")
    await flush()
    expect(context.tools.size).toBe(6)

    root.remove()
    await flush()

    expect(context.tools.size).toBe(0)
    expect(_registrations.size).toBe(0)
  })

  it("skips re-registration while the payload is unchanged and re-registers on change", async () => {
    const root = mount("country")
    await flush()
    const calls = context.registerTool.mock.calls.length

    const controller = application.getControllerForElementAndIdentifier(root, "poetry--agent--webmcp")
    controller.register()
    await flush()
    expect(context.registerTool.mock.calls.length).toBe(calls)

    root.setAttribute("data-poetry--agent--webmcp-name-value", "region")
    await flush()
    expect([...context.tools.keys()].every((name) => name.startsWith("poetry.region."))).toBe(true)
  })

  it("never registers under Turbo's cache preview", async () => {
    document.documentElement.setAttribute("data-turbo-preview", "")
    mount("country")
    await flush()

    expect(context.tools.size).toBe(0)
  })

  it("enforces the per-document budget", async () => {
    mount("country", TOOLS, 'data-poetry--agent--webmcp-budget-value="2"')
    await flush()

    expect(context.tools.size).toBe(2)
  })

  it("warns and skips a name the browser rejects as a duplicate", async () => {
    const warn = vi.spyOn(console, "warn").mockImplementation(() => {})
    context.tools.set("poetry.country.open", { name: "poetry.country.open", execute: async () => "taken" })
    mount("country")
    await flush()

    expect(warn).toHaveBeenCalledWith(expect.stringMatching(/could not register poetry\.country\.open/))
    expect(_registrations.get(document.getElementById("root")).names).not.toContain("poetry.country.open")
    warn.mockRestore()
  })

  it("does nothing where the browser has no modelContext", async () => {
    delete document.modelContext
    mount("country")
    await flush()

    expect(_registrations.size).toBe(0)
  })
})
