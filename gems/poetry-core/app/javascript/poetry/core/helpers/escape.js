// Capture-phase Escape handling (Tier 1): the primitive under dismissable's
// topmost-only Esc behavior.

/**
 * True when a keydown belongs to an IME composition. An Escape that
 * cancels IME composition must never reach dismissal: CJK users press
 * Escape to drop an in-progress composition, and closing the overlay
 * under them destroys the field they were typing into. Chromium reports
 * isComposing on the cancel keydown; some engines only mark it with the
 * legacy 229 keyCode - check both. Every Escape consumer (dismissable via
 * onEscapeKeydown, plus controllers with their own Escape branches) gates
 * through this predicate.
 *
 * @param {KeyboardEvent} event
 * @returns {boolean}
 */
export function isImeKeydown(event) {
  return event.isComposing || event.keyCode === 229
}

/**
 * Subscribes `callback` to Escape keydowns, with IME-cancel presses
 * filtered out via {@link isImeKeydown}.
 *
 * @param {(event: KeyboardEvent) => void} callback
 * @param {Object} [options]
 * @param {boolean} [options.capture=true] - capture phase, so dismissal
 *   sees the key before bubble-phase consumers can swallow it
 * @param {EventTarget} [options.target=window]
 * @returns {() => void} unsubscribe
 */
export function onEscapeKeydown(callback, { capture = true, target = window } = {}) {
  const listener = (event) => {
    if (event.key === "Escape" && !isImeKeydown(event)) callback(event)
  }
  target.addEventListener("keydown", listener, { capture })
  return () => target.removeEventListener("keydown", listener, { capture })
}
