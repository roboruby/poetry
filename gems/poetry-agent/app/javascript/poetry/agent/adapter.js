// The document.modelContext adapter - the ONE file that knows the WebMCP
// surface's shape, so API churn (the spec has changed twice this summer,
// and the shipping browser trails it) stays a one-file fix. Everything
// else in the runtime talks to this.
//
// Spec surface (rev 41d12f0): document.modelContext with
// registerTool(tool, {signal, exposedTo}), getTools({fromOrigins}) resolving
// RegisteredTool dictionaries whose inputSchema is an object,
// executeTool(tool, inputObject, {signal}) resolving the stringified
// result, and the toolchange event.
//
// Shipping-browser deltas this file absorbs (Chrome 151, measured
// 2026-09-01; spec issue #278 tracks them): getTools() reports inputSchema
// as a serialized JSON string, and executeTool() parses ONLY a JSON-string
// argument - an object rejects with UnknownError("Failed to parse input
// arguments"), not a TypeError.

/**
 * The live ModelContext, or null where the browser exposes none - callers
 * treat null as "do nothing", exactly like an edge bridge would.
 *
 * @returns {Object|null} the live ModelContext, or null
 */
export const modelContext = () =>
  (typeof document !== "undefined" && document.modelContext) || null

/**
 * Whether this browser exposes a ModelContext.
 *
 * @returns {boolean} true when document.modelContext exists
 */
export const supported = () => modelContext() !== null

/**
 * Registers one tool; resolves when the browser accepted it, rejects on a
 * duplicate name, an empty name/description, or an invalid schema.
 *
 * @param {Object} definition the tool definition (name, description, inputSchema, execute)
 * @param {Object} [root0] the options
 * @param {AbortSignal} [root0.signal] aborts the registration
 * @returns {Promise<void>} resolves once the browser accepted the tool
 */
export const registerTool = (definition, { signal } = {}) =>
  modelContext().registerTool(definition, signal ? { signal } : {})

// A serialized schema marks the string-argument build; remembering it lets
// executeTool go string-first without a wasted rejection.
let stringArguments = false

/**
 * The registered tools with inputSchema normalized to an object: parsed
 * when the browser serialized it, null when the text is not JSON.
 *
 * @param {Object} [options] the getTools options (fromOrigins)
 * @returns {Promise<Array<Object>>} the registered tools
 */
export const getTools = async (options = {}) => {
  const tools = await modelContext().getTools(options)
  for (const tool of tools) {
    if (typeof tool.inputSchema !== "string") continue
    stringArguments = true
    try {
      tool.inputSchema = JSON.parse(tool.inputSchema)
    } catch {
      tool.inputSchema = null
    }
  }
  return tools
}

/**
 * Executes a tool with the spec's object arguments, falling back to the
 * JSON-string form the current Chrome build parses; when both shapes
 * reject, the first rejection surfaces.
 *
 * @param {Object} tool the registered tool
 * @param {Object} [args] the input arguments
 * @param {Object} [options] the executeTool options (signal)
 * @returns {Promise<string>} the stringified result
 */
export const executeTool = async (tool, args = {}, options = {}) => {
  const context = modelContext()
  const asString = () => context.executeTool(tool, JSON.stringify(args), options)
  if (stringArguments) return asString()
  try {
    return await context.executeTool(tool, args, options)
  } catch (error) {
    try {
      const result = await asString()
      stringArguments = true
      return result
    } catch {
      throw error
    }
  }
}

/**
 * WebMCP tool-name grammar: 1-128 chars of ASCII alphanumerics, "_", "-", ".".
 */
export const TOOL_NAME = /^[A-Za-z0-9_.-]{1,128}$/
/**
 * Whether a name fits the WebMCP tool-name grammar.
 *
 * @param {string} name the candidate name
 * @returns {boolean} true when it matches TOOL_NAME
 */
export const validToolName = (name) => TOOL_NAME.test(name)

/**
 * Test seam: forget the argument shape the last browser taught us.
 */
export const _resetArgumentShape = () => {
  stringArguments = false
}
