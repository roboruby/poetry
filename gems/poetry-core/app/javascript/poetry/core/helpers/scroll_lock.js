// Body scroll-lock with scrollbar-gutter compensation (an upstream review
// finding, 2026-07-12): bare `overflow: hidden` shifts the whole layout by
// the scrollbar width the moment an overlay opens on a scrollable page.
// The gap is measured BEFORE locking and paid back as body padding-right.
// Refcounted so stacked overlays (a dialog opened from a sheet) lock once
// and restore only when the LAST one closes - per-instance saved values
// break on out-of-order closes.
let locks = 0
let previous = null

// Preferred gutter strategy (react-aria's rule): `scrollbar-gutter: stable`
// on the ROOT reserves the rail at the viewport itself, so position:fixed
// elements (toasts, floating headers) hold still too - body padding only
// compensates in-flow content. Feature-detected; the padding path stays as
// the fallback.
function supportsScrollbarGutter() {
  return typeof CSS !== "undefined" && CSS.supports?.("scrollbar-gutter: stable") === true
}

export function lockScroll() {
  locks += 1
  if (locks > 1) return

  const gap = window.innerWidth - document.documentElement.clientWidth
  // Never save a value the lock itself writes: a Turbo-restored snapshot
  // arrives with the serialized "hidden" already inline (no refcount
  // behind it), and saving it would re-freeze scrolling on every later
  // unlock (the poisoned-previous class).
  const overflow = document.body.style.overflow
  previous = {
    overflow: overflow === "hidden" ? "" : overflow,
    paddingRight: document.body.style.paddingRight,
    scrollbarGutter: document.documentElement.style.scrollbarGutter
  }
  if (gap > 0) {
    if (supportsScrollbarGutter()) {
      document.documentElement.style.scrollbarGutter = "stable"
    } else {
      const current = parseFloat(getComputedStyle(document.body).paddingRight) || 0
      document.body.style.paddingRight = `${current + gap}px`
    }
  }
  document.body.style.overflow = "hidden"
}

export function unlockScroll() {
  if (locks === 0) return

  locks -= 1
  if (locks > 0) return

  document.body.style.overflow = previous.overflow
  document.body.style.paddingRight = previous.paddingRight
  document.documentElement.style.scrollbarGutter = previous.scrollbarGutter
  previous = null
}

// Test seam: vitest suites run many overlays in one document.
export function resetScrollLock() {
  locks = 0
  previous = null
}
