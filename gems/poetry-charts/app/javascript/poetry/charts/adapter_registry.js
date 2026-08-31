// The BYO-engine seam: adapters register by name and
// implement the duck-typed protocol over the FROZEN chart-spec v1 -
//
//   {
//     render(el, spec, helpers)  -> instance   (required)
//     destroy(instance, el)                    (required)
//     update(instance, spec)                   (optional - live updates)
//     themeChanged(instance, spec, helpers)    (optional - dark-mode repaint)
//     degradations: ["..."]                    (declared, never discovered)
//     supports: ["area", "bar", ...]           (optional type allowlist)
//   }
//
// The spec is closed: no engine-specific key ever enters it - a
// pass-through options bag would leak engine keys into every call site.
// Engine-specific styling lives INSIDE the adapter.

const adapters = new Map()

/**
 * Registers an engine adapter under a name. The adapter must implement
 * the duck-typed protocol above; a missing render/destroy throws at
 * registration, never at first chart.
 *
 * @param {string} name - the engine value charts declare
 * @param {Object} adapter
 * @throws {Error} when render or destroy is missing
 */
export function registerChartAdapter(name, adapter) {
  if (typeof adapter?.render !== "function" || typeof adapter?.destroy !== "function") {
    throw new Error(`chart adapter ${name} must implement render(el, spec) and destroy(instance, el)`)
  }
  adapters.set(name, adapter)
}

/**
 * The registered adapter for a name.
 *
 * @param {string} name
 * @returns {Object | undefined}
 */
export function chartAdapter(name) {
  return adapters.get(name)
}

/**
 * The registered adapter names, in registration order.
 *
 * @returns {string[]}
 */
export function registeredAdapters() {
  return [...adapters.keys()]
}
