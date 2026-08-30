// The mobile breakpoint: shadcn's use-mobile hook as a helper -
// matchMedia below Tailwind's md (768px), with a change listener. The
// first poetry consumer is the Sidebar's mobile-Sheet mode. Environments
// without matchMedia (the dommy QuickJS engine, bare jsdom) report
// DESKTOP - the server-rendered desktop shell is the safe default.
/** The mobile cutoff (px): viewports strictly narrower are mobile. */
export const MOBILE_BREAKPOINT = 768

/**
 * Watches the mobile breakpoint: calls `onChange(isMobile)` immediately
 * with the current state and again on every crossing. Environments
 * without matchMedia report desktop once and never call again.
 *
 * @param {(isMobile: boolean) => void} onChange
 * @returns {() => void} unwatch
 */
export function watchMobile(onChange) {
  if (typeof window === "undefined" || typeof window.matchMedia !== "function") {
    onChange(false)
    return () => {}
  }

  const query = window.matchMedia(`(max-width: ${MOBILE_BREAKPOINT - 1}px)`)
  const listener = () => onChange(query.matches)
  query.addEventListener("change", listener)
  onChange(query.matches)
  return () => query.removeEventListener("change", listener)
}
