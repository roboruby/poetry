// The BYO-engine seam (Door 2): adapters register by name and
// implement the duck-typed protocol over the FROZEN chart-spec v1 -
//
//   {
//     render(el, spec, helpers)  -> instance   (required)
//     destroy(instance, el)                    (required)
//     update(instance, spec)                   (optional - Phase B)
//     themeChanged(instance, spec, helpers)    (optional - dark-mode repaint)
//     degradations: ["..."]                    (declared, never discovered)
//     supports: ["area", "bar", ...]           (optional type allowlist)
//   }
//
// The spec is closed: no engine-specific key ever enters it (the pass-through options-bag
// library:{} lesson). Engine-specific styling lives INSIDE the adapter.

const adapters = new Map()

export function registerChartAdapter(name, adapter) {
  if (typeof adapter?.render !== "function" || typeof adapter?.destroy !== "function") {
    throw new Error(`chart adapter ${name} must implement render(el, spec) and destroy(instance, el)`)
  }
  adapters.set(name, adapter)
}

export function chartAdapter(name) {
  return adapters.get(name)
}

export function registeredAdapters() {
  return [...adapters.keys()]
}
