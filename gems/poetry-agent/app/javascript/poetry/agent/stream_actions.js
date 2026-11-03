/**
 * The versioned replace Turbo Stream action the AG-UI relay and the A2UI
 * surface streams emit: a streamed frame re-renders the SAME element from
 * a server stream, which inherits an out-of-order delivery race, so every
 * payload carries data-version and this action applies only strictly-newer
 * frames - older or duplicate frames are dropped silently. With
 * method="morph" the newer frame morphs the element through Turbo's own
 * replace action (idiomorph), so local state survives an update. Installed
 * on Turbo by registerPoetryAgent when the host has Turbo and no vreplace
 * of its own.
 *
 * @param {Object} [turbo] the Turbo global; a host with no Turbo installs nothing
 * @returns {boolean} true when the action was installed
 */
export const installVersionedReplace = (turbo = globalThis.Turbo) => {
  if (!turbo?.StreamActions || turbo.StreamActions.vreplace) return false

  turbo.StreamActions.vreplace = function () {
    const incoming = this.templateContent.firstElementChild
    const version = Number(incoming?.dataset?.version || 0)
    const targets = this.targetElements.filter((element) => version > Number(element.dataset.version || -1))
    if (targets.length === 0) return

    const method = typeof this.getAttribute === "function" ? this.getAttribute("method") : null
    if (method === "morph" && typeof turbo.StreamActions.replace === "function") {
      turbo.StreamActions.replace.call({ getAttribute: () => "morph", targetElements: targets, templateContent: this.templateContent })
    } else {
      targets.forEach((element) => element.replaceWith(this.templateContent.cloneNode(true)))
    }
  }
  return true
}

// The local state a surface holds (tab selection, dialog state, expanded
// popups, edited controls) is kept across a morph by Poetry's morph guard
// in core (helpers/morph_guard.js, installed by registerPoetryControllers):
// what the client changed on an element survives, what it never touched
// follows the server. This file keeps only what is the agent runtime's
// own: an MCP App's frame.

/**
 * Whether a morph must leave an element alone: the frame holder of an MCP
 * App (`data-mcp-app-host`) and everything inside it, which the host
 * controller owns. A stream morph would replace the holder outright (even
 * a `data-turbo-permanent` one) or strip its frame, and the app would
 * reload and handshake again.
 *
 * @param {Element} element the element being morphed
 * @returns {boolean} true to keep the element as it is
 */
export const preservesElement = (element) => !!element?.closest?.("[data-mcp-app-host]")

/**
 * Installs the frame guard once per document, so a streamed re-render
 * morphs without reloading an MCP App's frame. A surface's local state is
 * Poetry's morph guard's work, installed with the core controllers.
 *
 * @param {Document} [doc] the document to guard
 * @returns {boolean} true when installed, false when absent or already guarded
 */
export const installMorphStateGuard = (doc = globalThis.document) => {
  if (!doc || doc.__poetryA2uiMorphGuard) return false
  doc.__poetryA2uiMorphGuard = true
  doc.addEventListener("turbo:before-morph-element", (event) => {
    if (preservesElement(event.target)) event.preventDefault()
  })
  return true
}
