// The registration guard: Stimulus never errors on a data-controller
// identifier nothing registered - the element simply stays inert - and one
// failed import in the host's controllers graph silently takes every poetry
// controller down with it. After the page is ready (and again on every
// Turbo navigation) this compares the poetry-prefixed identifiers on the
// page with the application's registry and warns ONCE per identifier. Host
// controllers are never inspected (they may lazy-load); poetry's cannot.

const PREFIX = "poetry--"
const warned = new Set()

// The poetry identifiers on the page that `application` has not registered.
export function unregisteredPoetryControllers(application, root = document) {
  const registry = application && application.router && application.router.modulesByIdentifier
  if (!registry || !root || !root.querySelectorAll) return []
  const missing = new Set()
  for (const element of root.querySelectorAll("[data-controller]")) {
    for (const identifier of element.getAttribute("data-controller").split(/\s+/)) {
      if (identifier.startsWith(PREFIX) && !registry.has(identifier)) missing.add(identifier)
    }
  }
  return Array.from(missing).sort()
}

// One console warning per newly-seen unregistered identifier; returns them.
export function checkPoetryRegistration(application, root = document) {
  const fresh = unregisteredPoetryControllers(application, root).filter((identifier) => !warned.has(identifier))
  if (fresh.length === 0) return fresh
  fresh.forEach((identifier) => warned.add(identifier))
  console.warn(
    `[poetry] ${fresh.length} poetry controller(s) on this page are not registered on the Stimulus application: ` +
      `${fresh.join(", ")}. The elements stay inert - check the importmap pins and that every poetry gem's ` +
      `register call runs in controllers/index.js.`
  )
  return fresh
}

let scheduled = false

// Runs the check once the DOM is parsed (registration usually happens
// while the document is still loading) and after every Turbo navigation.
// Idempotent: the first registrar to call it wires the listeners.
export function guardPoetryRegistration(application) {
  if (scheduled || typeof document === "undefined") return
  scheduled = true
  const run = () => checkPoetryRegistration(application)
  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", run, { once: true })
  } else {
    setTimeout(run, 0)
  }
  document.addEventListener("turbo:load", run)
}

// Test seam: forget what has been warned about and re-arm the scheduler.
export function resetPoetryRegistrationGuard() {
  warned.clear()
  scheduled = false
}
