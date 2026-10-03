// useScrollLock: the body scroll lock for one connect, over the
// scroll_lock helper. Idempotent per instance (the dialog's `#locked`
// flag, generalized): lock twice holds one refcount, unlock when not
// locked is a no-op, and teardown balances a lock still held.
import { scopeOf } from "@poetry/controllers/helpers/scope"
import { lockScroll, unlockScroll } from "@poetry/controllers/helpers/scroll_lock"

/**
 * A per-instance scroll lock, balanced at teardown(controller).
 *
 * @param {Object} controller - the Stimulus controller instance
 * @returns {{ lock: () => void, unlock: () => void, locked: () => boolean }}
 */
export function useScrollLock(controller) {
  let locked = false

  const unlock = () => {
    if (!locked) return

    locked = false
    unlockScroll()
  }

  scopeOf(controller).defer(unlock)

  return {
    /** Takes the instance's one refcount on the body lock. */
    lock() {
      if (locked) return

      locked = true
      lockScroll()
    },
    unlock,
    /**
     * Whether this instance holds its refcount.
     * @returns {boolean}
     */
    locked: () => locked
  }
}
