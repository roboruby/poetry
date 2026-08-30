// Body scroll-lock with scrollbar-width compensation: bare
// `overflow: hidden` shifts the whole layout by the scrollbar width the
// moment an overlay opens on a scrollable page.
// The gap is measured BEFORE locking and paid back as body padding-right.
// Refcounted so stacked overlays (a dialog opened from a sheet) lock once
// and restore only when the LAST one closes - per-instance saved values
// break on out-of-order closes.
//
// Why not scrollbar-gutter: stable (this helper's original primary)?
// Measured 2026-08-01 with classic
// scrollbars: Chrome drops the viewport's rail AND its reserved gutter
// the moment the viewport's used overflow computes to hidden - whether
// the pair sits on the root, propagates from body, or the gutter was set
// permanently - so the page shifted by the scrollbar width anyway (the
// exact wiggle the strategy existed to stop). The body-padding payback
// is the only compensation the viewport honors; its known cost
// (position:fixed elements aren't compensated) matches the source's
// RemoveScroll behavior.
let locks = 0
let previous = null

/**
 * Locks body scrolling, paying the measured scrollbar gap back as body
 * padding-right so the layout never shifts. Refcounted: stacked overlays
 * lock once; only the first call writes styles.
 */
export function lockScroll() {
  locks += 1
  if (locks > 1) return

  const gap = window.innerWidth - document.documentElement.clientWidth
  // Never save a value the lock itself writes: a Turbo-restored snapshot
  // arrives with the serialized "hidden" already inline (no refcount
  // behind it), and saving it would re-freeze scrolling on every later
  // unlock (the poisoned-previous restore class).
  const overflow = document.body.style.overflow
  previous = {
    overflow: overflow === "hidden" ? "" : overflow,
    paddingRight: document.body.style.paddingRight
  }
  if (gap > 0) {
    const current = parseFloat(getComputedStyle(document.body).paddingRight) || 0
    document.body.style.paddingRight = `${current + gap}px`
  }
  document.body.style.overflow = "hidden"
}

/**
 * Releases one scroll lock; the LAST release restores the body's saved
 * overflow and padding-right.
 */
export function unlockScroll() {
  if (locks === 0) return

  locks -= 1
  if (locks > 0) return

  document.body.style.overflow = previous.overflow
  document.body.style.paddingRight = previous.paddingRight
  previous = null
}

/** Test seam: vitest suites run many overlays in one document. */
export function resetScrollLock() {
  locks = 0
  previous = null
}
