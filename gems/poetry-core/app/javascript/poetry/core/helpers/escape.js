// Capture-phase Escape handling (Tier 1): the primitive under dismissable's
// topmost-only Esc behavior. Returns the unsubscribe function.

// An Escape that cancels IME composition must never reach dismissal: CJK
// users press Escape to drop an in-progress composition, and closing the
// overlay under them destroys the field they were typing into. Chromium
// reports isComposing on the cancel keydown; some engines only mark it
// with the legacy 229 keyCode - check both. Every Escape consumer
// (dismissable via onEscapeKeydown, plus controllers with their own
// Escape branches) gates through this predicate.
export function isImeKeydown(event) {
  return event.isComposing || event.keyCode === 229
}

export function onEscapeKeydown(callback, { capture = true, target = window } = {}) {
  const listener = (event) => {
    if (event.key === "Escape" && !isImeKeydown(event)) callback(event)
  }
  target.addEventListener("keydown", listener, { capture })
  return () => target.removeEventListener("keydown", listener, { capture })
}
