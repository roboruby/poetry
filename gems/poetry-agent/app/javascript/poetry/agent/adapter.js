// The document.modelContext adapter - the ONE file that knows the WebMCP
// surface's shape, so API churn (the spec has changed twice this summer)
// stays a one-file fix. Everything else in the runtime talks to this.
//
// Current surface (spec rev 2ac94f5): document.modelContext with
// registerTool(tool, {signal, exposedTo}), getTools({fromOrigins}),
// executeTool(tool, inputObject, {signal}), and the toolchange event.

// The live ModelContext, or null where the browser exposes none - callers
// treat null as "do nothing", exactly like an edge bridge would.
export const modelContext = () =>
  (typeof document !== "undefined" && document.modelContext) || null

export const supported = () => modelContext() !== null

// Registers one tool; resolves when the browser accepted it, rejects on a
// duplicate name, an empty name/description, or an invalid schema.
export const registerTool = (definition, { signal } = {}) =>
  modelContext().registerTool(definition, signal ? { signal } : {})

export const getTools = (options = {}) => modelContext().getTools(options)

// The spec takes an object; the current Chrome build may still want a JSON
// string - try the spec shape first, fall back once on a TypeError.
export const executeTool = async (tool, args = {}, options = {}) => {
  const context = modelContext()
  try {
    return await context.executeTool(tool, args, options)
  } catch (error) {
    if (error instanceof TypeError) return context.executeTool(tool, JSON.stringify(args), options)
    throw error
  }
}

// WebMCP tool-name grammar: 1-128 chars of ASCII alphanumerics, "_", "-", ".".
export const TOOL_NAME = /^[A-Za-z0-9_.-]{1,128}$/
export const validToolName = (name) => TOOL_NAME.test(name)
