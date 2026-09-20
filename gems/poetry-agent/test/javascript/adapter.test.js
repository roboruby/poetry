import { describe, it, expect, beforeEach, afterEach, vi } from "vitest"
import { getTools, executeTool, _resetArgumentShape } from "@poetry/agent"

// A Chrome-151-shaped ModelContext: getTools() serializes inputSchema and
// executeTool() parses only a JSON-string argument (spec issue #278).
const chrome151 = () => {
  const calls = []
  return {
    calls,
    getTools: vi.fn(async () => [
      {
        name: "poetry.sections.set_value", description: "Activate.", title: "",
        inputSchema: JSON.stringify({ type: "object", properties: { value: { type: "string", enum: ["a"] } } }),
        annotations: { readOnlyHint: false, untrustedContentHint: false }
      },
      { name: "broken", description: "Broken.", title: "", inputSchema: "{not json", annotations: null }
    ]),
    executeTool: vi.fn(async (tool, args) => {
      calls.push(args)
      if (typeof args !== "string") {
        const error = new Error("Failed to parse input arguments")
        error.name = "UnknownError"
        throw error
      }
      return `ran ${tool.name} with ${args}`
    })
  }
}

// A spec-shaped ModelContext: objects in, the stringified result out.
const specShaped = () => ({
  getTools: vi.fn(async () => [
    { name: "t", description: "T.", title: "", inputSchema: { type: "object", properties: {} },
      annotations: { readOnlyHint: true, untrustedContentHint: false } }
  ]),
  executeTool: vi.fn(async (tool, args) => {
    if (typeof args !== "object") throw new TypeError("object expected")
    return JSON.stringify(args)
  })
})

describe("the modelContext adapter", () => {
  beforeEach(() => _resetArgumentShape())

  afterEach(() => {
    delete document.modelContext
    _resetArgumentShape()
  })

  it("normalizes a serialized inputSchema to an object (null when the text is not JSON)", async () => {
    document.modelContext = chrome151()

    const [tool, broken] = await getTools()

    expect(tool.inputSchema).toEqual({ type: "object", properties: { value: { type: "string", enum: ["a"] } } })
    expect(broken.inputSchema).toBeNull()
  })

  it("falls back to JSON-string arguments when the browser rejects the object shape, then remembers", async () => {
    const context = chrome151()
    document.modelContext = context

    expect(await executeTool({ name: "x" }, { value: "a" })).toBe('ran x with {"value":"a"}')
    expect(context.calls).toEqual([{ value: "a" }, '{"value":"a"}'])

    await executeTool({ name: "x" }, { value: "b" })
    expect(context.calls.slice(2)).toEqual(['{"value":"b"}'])
  })

  it("goes string-first once getTools() reported serialized schemas", async () => {
    const context = chrome151()
    document.modelContext = context

    await getTools()
    await executeTool({ name: "x" }, {})

    expect(context.calls).toEqual(["{}"])
  })

  it("keeps the spec's object arguments on a spec-shaped browser and surfaces the original rejection", async () => {
    const context = specShaped()
    document.modelContext = context

    expect(await executeTool({ name: "t" }, { a: 1 })).toBe('{"a":1}')

    context.executeTool = vi.fn(async () => { throw new Error("no such tool") })
    await expect(executeTool({ name: "nope" }, {})).rejects.toThrow("no such tool")
  })
})
