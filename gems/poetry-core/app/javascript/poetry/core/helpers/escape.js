// Capture-phase Escape handling (Tier 1): the primitive under dismissable's
// topmost-only Esc behavior. Returns the unsubscribe function.

export function onEscapeKeydown(callback, { capture = true, target = window } = {}) {
  const listener = (event) => {
    if (event.key === "Escape") callback(event)
  }
  target.addEventListener("keydown", listener, { capture })
  return () => target.removeEventListener("keydown", listener, { capture })
}
