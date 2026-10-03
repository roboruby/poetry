// The per-connect teardown scope: everything a controller sets up in
// connect() that must be undone in disconnect() registers its undo here,
// and disconnect() is one line, `teardown(this)`. Explicit, never a
// patched disconnect: a controller that imports a behavior owns the
// teardown call, the source-scan gate (behaviors_teardown.test.js) keeps
// it there, and a subclass that overrides disconnect calls super.
//
// Stimulus keeps one instance per element and re-runs connect() each time
// the element re-enters the document (pinned in
// reconnect_semantics.test.js), so a scope is created on first use per
// connect and dropped at teardown; the next connect starts clean. The
// scope's AbortSignal is renewed with it - a listener added to an
// already-aborted signal is silently never added, so a scope is never
// reused across connects.

const scopes = new WeakMap()

/**
 * The controller's current scope, created on first use since its last
 * teardown. A behavior registers its undo here; a controller may use it
 * directly for one-off listeners.
 *
 * @param {Object} controller - a Stimulus controller instance
 * @returns {{ signal: AbortSignal, defer: (undo: () => void) => () => void,
 *   listen: (target: EventTarget, type: string, listener: EventListener,
 *   options?: AddEventListenerOptions | boolean) => () => void }}
 */
export function scopeOf(controller) {
  let scope = scopes.get(controller)

  if (!scope) {
    scope = createScope()
    scopes.set(controller, scope)
  }

  return scope
}

/**
 * Runs every undo the controller's scope holds, newest first, aborts the
 * scope's signal and drops the scope. The one line a `disconnect()` needs.
 * A controller without a scope (nothing registered since connect) is a
 * no-op.
 *
 * @param {Object} controller - a Stimulus controller instance
 * @returns {void}
 */
export function teardown(controller) {
  const scope = scopes.get(controller)

  if (!scope) return

  scopes.delete(controller)
  scope.dispose()
}

/**
 * Whether the controller holds a scope right now - a test seam, so a
 * suite can assert a disconnect left nothing behind.
 *
 * @param {Object} controller - a Stimulus controller instance
 * @returns {boolean}
 */
export function hasScope(controller) {
  return scopes.has(controller)
}

/**
 * One scope: a disposer stack and a fresh AbortController.
 *
 * @returns {Object} the scope
 */
function createScope() {
  const aborter = new AbortController()
  const disposers = []

  // An undo run early leaves the stack, so a listener bound and unbound
  // many times within one connect (a once-listener per pointerdown) never
  // grows the scope.
  const defer = (undo) => {
    const entry = () => {
      const index = disposers.indexOf(entry)

      if (index >= 0) disposers.splice(index, 1)
      undo()
    }

    disposers.push(entry)

    return entry
  }

  // Explicit removal, mirrored as a disposer, so the undo works on any
  // EventTarget whether or not it honours the signal option; the signal
  // is passed too for the engines that do, which also covers a target
  // that is gone by teardown.
  const listen = (target, type, listener, options = {}) => {
    const resolved = typeof options === "boolean" ? { capture: options } : { ...options }
    const capture = Boolean(resolved.capture)
    let entry = null

    // A once-listener leaves the stack the moment it fires, so a
    // pointerdown that binds its pointerup a thousand times costs nothing.
    const handler = resolved.once
      ? (event) => {
        entry?.()

        return listener(event)
      }
      : listener

    target.addEventListener(type, handler, { ...resolved, signal: aborter.signal })
    entry = defer(() => target.removeEventListener(type, handler, { capture }))

    return entry
  }

  const dispose = () => {
    aborter.abort()
    while (disposers.length > 0) disposers.pop()()
  }

  return { signal: aborter.signal, defer, listen, dispose }
}
