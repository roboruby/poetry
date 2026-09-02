// The versioned replace Turbo Stream action the AG-UI relay and the A2UI
// surface streams emit: a streamed frame re-renders the SAME element from
// a server stream, which inherits an out-of-order delivery race, so every
// payload carries data-version and this action applies only strictly-newer
// frames - older or duplicate frames are dropped silently. With
// method="morph" the newer frame morphs the element through Turbo's own
// replace action (idiomorph), so local state survives an update. Installed
// on Turbo by registerPoetryAgent when the host has Turbo and no vreplace
// of its own.
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

// Local state a morph must not reset inside an A2UI surface: the
// selection a tab strip holds, a dialog's open state, a popup's expanded
// state, and a control the user has edited (its value or checked state
// differs from what the server last rendered). The server does not know
// this state, so its frame would carry the defaults; canceling Turbo's
// before-morph-attribute event keeps the page's own.
const LOCAL_STATE = {
  "tabs-trigger": ["aria-selected", "tabindex", "data-active"],
  "tabs-content": ["hidden", "data-hidden"],
  "dialog-content": ["open", "data-closed"]
}
const EXPANDED = ["aria-expanded", "data-open", "data-state"]

export const preservesLocalState = (element, attributeName) => {
  if (!element?.closest?.("[data-a2ui-surface]")) return false
  if (attributeName === "value" || attributeName === "checked") return isDirty(element)
  if (EXPANDED.includes(attributeName)) return true
  return (LOCAL_STATE[element.dataset?.slot] || []).includes(attributeName)
}

const isDirty = (element) => {
  if (element instanceof HTMLInputElement) {
    if (element.type === "checkbox" || element.type === "radio") return element.checked !== element.defaultChecked
    return element.value !== element.defaultValue
  }
  if (element instanceof HTMLTextAreaElement) return element.value !== element.defaultValue
  return false
}

export const installMorphStateGuard = (doc = globalThis.document) => {
  if (!doc || doc.__poetryA2uiMorphGuard) return false
  doc.__poetryA2uiMorphGuard = true
  doc.addEventListener("turbo:before-morph-attribute", (event) => {
    if (preservesLocalState(event.target, event.detail?.attributeName)) event.preventDefault()
  })
  return true
}
