// Focus guards (Tier 3): two visually-hidden tabindex=0 sentinels at the
// body edges so focusin/focusout fire predictably at the document boundary
// while any trapped overlay is open - a Tab out of the last real element
// lands on a guard (which focus-scope yanks back), never on nothing.
// Refcounted module state: one pair per page no matter how many overlays.

export const FOCUS_GUARD_SELECTOR = "[data-poetry-focus-guard]"

let guardCount = 0

export function ensureFocusGuards() {
  if (guardCount === 0) {
    document.body.insertAdjacentElement("afterbegin", createGuard())
    document.body.insertAdjacentElement("beforeend", createGuard())
  }
  guardCount += 1
}

export function removeFocusGuards() {
  if (guardCount === 0) return

  guardCount -= 1

  if (guardCount === 0) {
    for (const guard of document.querySelectorAll(FOCUS_GUARD_SELECTOR)) guard.remove()
  }
}

function createGuard() {
  const guard = document.createElement("span")
  guard.setAttribute("data-poetry-focus-guard", "")
  guard.setAttribute("tabindex", "0")
  guard.setAttribute("aria-hidden", "true")
  guard.style.cssText = "position: fixed; opacity: 0; pointer-events: none; outline: none;"
  return guard
}
