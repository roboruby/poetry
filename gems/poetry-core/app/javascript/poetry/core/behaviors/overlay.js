// useOverlay: the popup machine the layered overlays share (popover,
// menu, select, combobox): show and hide sequencing, the late portal on
// reconcile, the layer tokens, the dismiss, interact-outside and
// auto-focus vetoes, and the focus-restore suppression rule. The
// policies that make each component itself stay in the controller and
// come in as hooks: how the content and the trigger resolve, which
// layers go on, what happens on open, what to settle before a hide, how
// the open event reads. Rendered markup and sequencing are what the six
// controllers did by hand; this is the skeleton, not the product.
import { useLayers } from "@poetry/controllers/behaviors/layers"
import { useListen } from "@poetry/controllers/behaviors/listen"
import { usePortal } from "@poetry/controllers/behaviors/portal"
import { usePresence } from "@poetry/controllers/behaviors/presence"
import { resolvePortalContainer } from "@poetry/controllers/helpers/portal"
import { setState, stateOf } from "@poetry/controllers/helpers/state"

const POPPER_STRATEGY = "data-poetry--core--popper-strategy-value"
const DISMISS_EVENT = "poetry--core--dismissable:dismiss"
const INTERACT_OUTSIDE_EVENT = "poetry--core--dismissable:interact-outside"
const MOUNT_AUTO_FOCUS_EVENT = "poetry--core--focus-scope:mount-auto-focus"
const UNMOUNT_AUTO_FOCUS_EVENT = "poetry--core--focus-scope:unmount-auto-focus"

/**
 * The overlay machine for one controller, over the controller's
 * current scope (its behaviors tear down with `teardown(controller)`).
 *
 * @param {Object} controller - the Stimulus controller instance; reads
 *   and writes `openValue`, dispatches through `controller.dispatch`
 * @param {Object} options
 * @param {() => Element | null} options.content - the popup element
 * @param {() => Element | null} options.trigger - the element whose
 *   press toggles the popup, the interact-outside veto's inside
 * @param {() => Element | null} [options.expander] - the element that
 *   carries aria-expanded and the popup-open state; the trigger by default
 * @param {string[]} options.layers - the layer controllers the content
 *   wears while open
 * @param {string} options.eventPrefix - the prefix of the open and closed events
 * @param {() => boolean} [options.modal] - whether the popup is modal;
 *   decides the suppression of focus restore after an outside press
 * @param {boolean} [options.reasons=false] - whether the content carries
 *   data-open-reason and data-open-seed while open
 * @param {boolean} [options.expandedWhenPresent=false] - write
 *   aria-expanded only when the expander already carries it
 * @param {boolean} [options.vetoMountAutoFocus=false] - keep focus-scope
 *   from moving focus on mount (the controller places it itself)
 * @param {(content: Element) => void} [options.activateLayers] - writes
 *   the layer values before the tokens go on; the tokens go on either way
 * @param {(content: Element, strategy: string) => void} [options.strategy]
 *   - writes the popper strategy; the root's attribute by default
 * @param {(content: Element, open: Object) => void} [options.onOpen] -
 *   runs on the microtask after a show, before the open event
 * @param {(reason: string, seed: string | null) => Object} [options.openDetail]
 *   - the open event's detail
 * @param {(content: Element, reason: string) => void} [options.beforeHide]
 *   - settles what a hide must settle first (sub levels, a typeahead)
 * @param {(content: Element) => void} [options.beforeExit] - runs after
 *   the state flips closed and before the exit presence starts
 * @param {(content: Element) => void} [options.onHidden] - runs once the
 *   exit finished and the content is home, before the closed event
 * @param {(origin: Element) => boolean} [options.insideAlso] - more
 *   elements an outside press must not dismiss from (a chips field)
 * @param {(event: Event) => void} [options.onDismiss] - sees every
 *   dismiss event on the content before the machine acts
 * @param {(target: Element, escaped: boolean) => void} [options.onDismissElsewhere]
 *   - a dismiss from a node inside the content that is not the content
 * @returns {Object} the machine: connect, show, hide, isOpen, portalPinned
 */
export function useOverlay(controller, options) {
  const presence = usePresence(controller)
  const portal = usePortal(controller)
  const layers = useLayers(controller)
  const element = controller.element
  const content = options.content
  const trigger = options.trigger
  const expander = options.expander ?? trigger
  const modal = options.modal ?? (() => false)
  const setStrategy = options.strategy ?? ((_content, strategy) => element.setAttribute(POPPER_STRATEGY, strategy))
  const openDetail = options.openDetail ?? ((reason, seed) => (seed ? { reason, seed } : { reason }))

  let connected = false
  let suppressRestore = false

  const isOpen = () => {
    const node = content()

    return Boolean(node) && stateOf(node) === "open"
  }

  const activateLayers = (node) => {
    options.activateLayers?.(node)
    layers.activate(node, options.layers)
  }

  // The reconcile path portals ONE FRAME LATE: connect order within a
  // boot is unordered, and portaling before the sibling popper's connect
  // would rob it of its content target before it could cache the node.
  const portalPinned = (node) => {
    window.requestAnimationFrame(() => {
      if (!connected || !isOpen()) return

      portal.portal(node, { container: resolvePortalContainer(element) })
      setStrategy(node, "absolute")
    })
  }

  const show = (reason, { seed = null, focus = true } = {}) => {
    const node = content()

    if (!node || isOpen()) return

    presence.cancel(node)
    suppressRestore = false

    const opener = expander()

    // Portal-on-open: move BEFORE the enter presence (reparenting
    // mid-animation restarts it), re-anchor absolute - static under
    // compositor scroll, transform-immune.
    portal.portal(node, { container: resolvePortalContainer(element) })
    setStrategy(node, "absolute")

    node.hidden = false
    if (options.reasons) {
      node.setAttribute("data-open-reason", reason)
      if (seed) node.setAttribute("data-open-seed", seed)
      else node.removeAttribute("data-open-seed")
    }
    if (opener && (!options.expandedWhenPresent || opener.hasAttribute("aria-expanded"))) {
      opener.setAttribute("aria-expanded", "true")
    }
    if (opener) setState(opener, "popup-open")
    presence.enter(node)
    activateLayers(node)
    controller.openValue = true

    queueMicrotask(() => {
      if (!isOpen()) return

      options.onOpen?.(node, { reason, seed, focus })
      controller.dispatch("open", { prefix: options.eventPrefix, detail: openDetail(reason, seed) })
    })
  }

  const hide = (reason, { restoreFocus = true } = {}) => {
    const node = content()

    if (!node || !isOpen()) return

    options.beforeHide?.(node, reason)
    suppressRestore = !restoreFocus || (reason === "outside-press" && !modal())

    const opener = expander()

    if (opener && (!options.expandedWhenPresent || opener.hasAttribute("aria-expanded"))) {
      opener.setAttribute("aria-expanded", "false")
    }
    if (opener) setState(opener, "popup-closed")
    if (options.reasons) {
      node.removeAttribute("data-open-reason")
      node.removeAttribute("data-open-seed")
    }
    options.beforeExit?.(node)
    controller.openValue = false

    presence.exit(node, {
      onRemove: () => {
        node.hidden = true
        // Home AFTER the exit finished and hidden landed; focus return is
        // focus-scope's ref-based job, indifferent to the move.
        portal.restore(node)
        setStrategy(node, "fixed")
        layers.deactivate(node, options.layers)
        options.onHidden?.(node)
        controller.dispatch("closed", { prefix: options.eventPrefix, detail: { reason } })
      }
    })
  }

  // A press on the popup's OWN trigger is the toggle's job, not an
  // outside press: veto the dismissal so the toggle can close it.
  const onInteractOutside = (event) => {
    if (event.target !== content()) return

    const origin = event.detail?.originalEvent?.target

    if (!(origin instanceof Element)) return
    if (trigger()?.contains(origin) || options.insideAlso?.(origin)) event.preventDefault()
  }

  const onDismiss = (event) => {
    const target = event.target instanceof Element ? event.target : null

    if (!target) return

    options.onDismiss?.(event)

    const escaped = event.detail?.originalEvent?.type === "keydown"

    if (target === content()) hide(escaped ? "escape-key" : "outside-press")
    else options.onDismissElsewhere?.(target, escaped)
  }

  const onMountAutoFocus = (event) => {
    if (event.target === content()) event.preventDefault()
  }

  const onUnmountAutoFocus = (event) => {
    if (event.target === content() && suppressRestore) event.preventDefault()
  }

  const wire = (node) => {
    useListen(controller, node, DISMISS_EVENT, onDismiss)
    useListen(controller, node, INTERACT_OUTSIDE_EVENT, onInteractOutside)
    if (options.vetoMountAutoFocus) useListen(controller, node, MOUNT_AUTO_FOCUS_EVENT, onMountAutoFocus)
    useListen(controller, node, UNMOUNT_AUTO_FOCUS_EVENT, onUnmountAutoFocus)
  }

  return {
    /**
     * Wires the content's layer events now; `connect()` reconciles later.
     * @returns {void}
     */
    wire() {
      const node = content()

      if (node) wire(node)
    },
    /**
     * Marks the machine connected and reconciles: server-open content
     * adopts the layer stack and re-portals one frame late (the DOM
     * wins); an open value with closed markup shows.
     * @param {Object} [initial] - the show call for an open value
     * @param {string} [initial.reason="trigger-press"]
     * @param {boolean} [initial.focus=true]
     * @returns {void}
     */
    connect({ reason = "trigger-press", focus = true } = {}) {
      connected = true

      const node = content()

      if (isOpen()) {
        if (node) {
          activateLayers(node)
          portalPinned(node)
        }
        controller.openValue = true
      } else if (controller.openValue) {
        show(reason, { focus })
      }
    },
    /**
     * Marks the machine disconnected; the behaviors tear down with the
     * controller's scope.
     * @returns {void}
     */
    disconnect() {
      connected = false
    },
    /**
     * Whether the machine has connected and not yet disconnected.
     * @returns {boolean}
     */
    connected: () => connected,
    show,
    hide,
    isOpen,
    portalPinned,
    // The behaviors under the machine, for a controller with more levels
    // than the root popup (a menu's sub levels ride the same instances,
    // so teardown restores them newest first, subs before the root).
    presence,
    portal,
    layers,
    /**
     * Wires the dismiss and interact-outside handlers onto another node
     * (a portaled sub level, which no longer bubbles through the root);
     * a dismiss from it reaches `onDismissElsewhere`.
     * @param {Element} node
     * @returns {Array<() => void>} the unlisten handles
     */
    wireLevel(node) {
      return [
        useListen(controller, node, DISMISS_EVENT, onDismiss),
        useListen(controller, node, INTERACT_OUTSIDE_EVENT, onInteractOutside)
      ]
    }
  }
}
