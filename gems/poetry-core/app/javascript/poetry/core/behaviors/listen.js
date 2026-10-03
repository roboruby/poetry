// useListen: a DOM listener that lives for one connect. Replaces the
// hand-rolled `#wired` list seven controllers copied: the listener is
// added now and removed at teardown(controller), newest first.
import { scopeOf } from "@poetry/controllers/helpers/scope"

/**
 * Adds `listener` to `target` for the controller's current connect.
 *
 * @param {Object} controller - the Stimulus controller instance
 * @param {EventTarget} target - the element, document or window to listen on
 * @param {string} type - the event type
 * @param {EventListener} listener - the handler
 * @param {AddEventListenerOptions | boolean} [options] - addEventListener's options
 * @returns {() => void} removes the listener early; teardown removes it otherwise
 */
export function useListen(controller, target, type, listener, options) {
  return scopeOf(controller).listen(target, type, listener, options)
}
