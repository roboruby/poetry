// The mobile breakpoint (N9 W5b): shadcn's use-mobile hook as a helper -
// matchMedia below Tailwind's md (768px), with a change listener. The
// first poetry consumer is the Sidebar's mobile-Sheet mode. Environments
// without matchMedia (the dommy QuickJS engine, bare jsdom) report
// DESKTOP - the server-rendered desktop shell is the safe default.
export const MOBILE_BREAKPOINT = 768

// Calls onChange(isMobile) immediately with the current state and again on
// every crossing; returns an unwatch().
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
