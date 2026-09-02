// The versioned replace Turbo Stream action the AG-UI relay emits:
// a streamed frame re-morphs the SAME row from a server stream, which
// inherits an out-of-order delivery race, so every payload carries
// data-version and this action applies only strictly-newer frames -
// older or duplicate frames are dropped silently. Installed on Turbo by
// registerPoetryAgent when the host has Turbo and no vreplace of its own.
export const installVersionedReplace = (turbo = globalThis.Turbo) => {
  if (!turbo?.StreamActions || turbo.StreamActions.vreplace) return false

  turbo.StreamActions.vreplace = function () {
    this.targetElements.forEach((element) => {
      const incoming = this.templateContent.firstElementChild
      const version = Number(incoming?.dataset?.version || 0)
      const current = Number(element.dataset.version || -1)
      if (version > current) element.replaceWith(this.templateContent.cloneNode(true))
    })
  }
  return true
}
