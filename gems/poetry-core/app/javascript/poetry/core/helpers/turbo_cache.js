// Turbo snapshots the page BEFORE caching it (turbo:before-cache), and an
// overlay still open at that moment serializes INTO the snapshot: the
// restoration visit then renders a de-modalized zombie dialog (the open
// attribute survives HTML serialization, top-layer/modal state does not)
// over a body whose inline scroll-lock / pointer-events-scrim styles came
// back frozen - a page that can never scroll, or never be clicked, again
// (both reproduced live against the docs app). Overlay controllers
// subscribe their synchronous teardown here; no-op when Turbo is absent.
export function onBeforeCache(callback) {
  document.addEventListener("turbo:before-cache", callback)
  return () => document.removeEventListener("turbo:before-cache", callback)
}
