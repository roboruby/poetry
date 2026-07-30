import { Controller } from "@hotwired/stimulus"
import {
  arrow,
  autoUpdate,
  computePosition,
  flip,
  hide,
  limitShift,
  offset,
  shift,
  size
} from "@poetry/controllers/vendor/floating_ui_dom"

// The anchored-positioning primitive (Tier 2, P4): Radix's popper as one
// controller over the VENDORED @floating-ui/dom. Same middleware pipeline in
// Radix's order - offset -> shift -> flip (both gated on avoidCollisions, as
// in Radix) -> size -> arrow (when an arrow target exists) -> hide - and the
// same output contract: data-side / data-align mirror the RESOLVED placement
// (after flip), and the content gets the Base UI CSS vars
// (--transform-origin / -available-width / -available-height /
// -anchor-width / -anchor-height) so ported Tailwind classes like
// data-[side=top]:slide-in-from-bottom-2 and
// max-h-[var(--available-height)] work unchanged.
//
// The Arrow stays a markup primitive (Tier 4): any [data-slot=popper-arrow]
// marked as the arrow target is positioned + given data-side here; the SVG
// itself is poetry-ui's business.
//
// VIRTUAL-ANCHOR mode (the ContextMenu contract): a non-empty anchorPoint
// value - canonically the data-poetry--core--popper-anchor-point="x,y"
// attribute on the controller root (the DOM is the store) - floats against a
// floating-ui VirtualElement: a zero-size rect at (x,y) client coords,
// Radix's virtualRef verbatim. The resolved ELEMENT anchor rides along as
// contextElement so autoUpdate still tracks ancestor scroll/resize.
// setAnchor(x, y) is the ergonomics wrapper ContextMenu calls from its
// contextmenu / long-press handlers; clearing the value returns to plain
// element anchoring.
//
// Consumers: Popover, Dropdown/Context Menu, Tooltip, HoverCard, Select,
// Combobox, Menubar.
const SIDES = ["top", "right", "bottom", "left"]
const ALIGNS = ["start", "center", "end"]

// The side the arrow sits on / the transform-origin edge is the OPPOSITE of
// where the content was placed.
const OPPOSITE_SIDE = { top: "bottom", right: "left", bottom: "top", left: "right" }

// Radix's arrow rotation table: the arrow component points down by default;
// these transforms swing it toward the anchor for each resolved side.
const ARROW_TRANSFORM = {
  top: "translateY(100%)",
  right: "translateY(50%) rotate(90deg) translateX(-50%)",
  bottom: "rotate(180deg)",
  left: "translateY(50%) rotate(-90deg) translateX(50%)"
}

const ARROW_TRANSFORM_ORIGIN = { top: "", right: "0 0", bottom: "center 0", left: "100% 0" }

const NO_ARROW_ALIGN_ORIGIN = { start: "0%", center: "50%", end: "100%" }

export default class PopperController extends Controller {
  static targets = ["anchor", "content", "arrow"]
  static values = {
    // Anchor fallback chain: anchor target -> this selector -> the element's
    // previousElementSibling (the natural trigger-then-content markup shape).
    anchor: { type: String, default: "" },
    // "x,y" client coords -> virtual-anchor mode (see the header). Empty =
    // element anchoring. Reactive: changing it re-arms autoUpdate.
    anchorPoint: { type: String, default: "" },
    side: { type: String, default: "bottom" }, // top | right | bottom | left
    align: { type: String, default: "center" }, // start | center | end
    sideOffset: { type: Number, default: 0 },
    alignOffset: { type: Number, default: 0 },
    avoidCollisions: { type: Boolean, default: true },
    strategy: { type: String, default: "fixed" } // fixed | absolute
  }

  #stopAutoUpdate = null
  #anchorElement = null
  #contentElement = null
  #generation = 0
  #connected = false
  #hidPointerEvents = false
  #pointerEventsBeforeHide = ""

  connect() {
    this.#connected = true
    this.#start()
  }

  disconnect() {
    this.#connected = false
    this.#generation += 1 // strand any in-flight #update await
    this.#stop()
  }

  // Reactive re-anchor: switching between element and virtual anchoring (or
  // moving the point) re-arms autoUpdate against the new reference. Fires
  // during initialization too, before connect - the #connected guard skips
  // that first call.
  anchorPointValueChanged() {
    if (!this.#connected) return

    this.#stop()
    this.#start()
  }

  // Reactive strategy (the portal seam, docs/portal-on-open.md D3): a
  // consumer flips fixed <-> absolute when it portals/restores content;
  // re-arming repositions in the new coordinate space immediately.
  strategyValueChanged() {
    if (!this.#connected) return

    this.#stop()
    this.#start()
  }

  // Manual re-run for consumers whose geometry changed outside autoUpdate's
  // sensors (e.g. content swapped by a Turbo Stream). Returns the update
  // promise so callers can await settlement.
  reposition() {
    return this.#update()
  }

  // The ContextMenu entry point: store the pointer coords (the ATTRIBUTE is
  // canonical - inspectable, server-settable) and reposition immediately;
  // the value-changed callback then re-arms autoUpdate's tracking.
  setAnchor(x, y) {
    this.anchorPointValue = `${x},${y}`

    return this.reposition()
  }

  // The NavigationMenu viewport entry point (D3): float against a caller-
  // supplied element (the active trigger) instead of a target/selector.
  // Re-arms autoUpdate so the new reference's ancestors are tracked, then
  // repositions - the positioner's inset transition turns that write into
  // the position morph.
  setAnchorElement(element) {
    this.#anchorElement = element
    this.#stop()
    this.#start()

    return this.reposition()
  }

  // --- positioning ---

  #start() {
    const reference = this.#reference()
    const content = this.#content()

    if (!reference || !content) return

    // autoUpdate re-runs positioning on scroll / resize / anchor movement and
    // fires once immediately, so start needs no separate first update.
    this.#stopAutoUpdate = autoUpdate(reference, content, () => this.#update())
  }

  #stop() {
    this.#stopAutoUpdate?.()
    this.#stopAutoUpdate = null
  }

  async #update() {
    const anchor = this.#reference()
    const content = this.#content()

    if (!anchor || !content) return
    // Select's alignItemWithTrigger mode (N13 W2) fixed-positions the
    // content itself; while the attribute is on, popper must not fight it.
    if (content.hasAttribute("data-align-item-with-trigger")) return

    const arrowElement = this.#arrow()
    const generation = this.#generation

    const { x, y, placement, strategy, middlewareData } = await computePosition(anchor, content, {
      strategy: this.strategyValue,
      placement: this.#placement(),
      middleware: this.#middleware(arrowElement)
    })

    // Disconnected (or superseded) while awaiting: never write to a dead node.
    if (generation !== this.#generation) return

    const [side, align = "center"] = placement.split("-")

    content.style.position = strategy
    content.style.left = `${x}px`
    content.style.top = `${y}px`

    // The RESOLVED side/align (after flip) - what the ported data-[side=...]
    // Tailwind variants key off.
    content.setAttribute("data-side", side)
    content.setAttribute("data-align", align)

    content.style.setProperty(
      "--transform-origin",
      this.#transformOrigin({ side, align, content, arrowElement, middlewareData })
    )

    if (middlewareData.hide) {
      // Never write the hide verdict onto CLOSED content: a closed-era
      // pass measures a display:none box (garbage geometry), and its
      // stale visibility:hidden lingers into the open MICROTASK, where
      // Chrome silently refuses focus-scope's mount focus (the popover
      // first-open race - pre-existing, surfaced by the S2 portal
      // proofs). While content is hidden the verdict resolves to
      // visible, which routes through the clear/restore branch below so
      // every open starts clean.
      const hidden = !content.hidden && Boolean(middlewareData.hide.referenceHidden)

      content.style.visibility = hidden ? "hidden" : ""

      // Save/restore, never clear: the dismissable scrim opts this SAME
      // element back in (pointer-events: auto) while body is none -
      // blanking it on every position pass left modal popovers click-dead.
      // Found by the tester proofs (the first real-pointer gate;
      // dommy dispatches synthetically, so pointer-events was invisible
      // to it).
      if (hidden && !this.#hidPointerEvents) {
        this.#hidPointerEvents = true
        this.#pointerEventsBeforeHide = content.style.pointerEvents
        content.style.pointerEvents = "none"
      } else if (!hidden && this.#hidPointerEvents) {
        this.#hidPointerEvents = false
        content.style.pointerEvents = this.#pointerEventsBeforeHide
      }
    }

    if (arrowElement) this.#positionArrow(arrowElement, side, middlewareData)
  }

  // Radix PopperContent's pipeline, verbatim order. offset folds the arrow's
  // height into the main axis exactly as Radix does, so the gap accounts for
  // the arrow between anchor and content.
  #middleware(arrowElement) {
    const { height: arrowHeight } = this.#arrowSize(arrowElement)
    const middleware = [
      offset({ mainAxis: this.sideOffsetValue + arrowHeight, alignmentAxis: this.alignOffsetValue })
    ]

    if (this.avoidCollisionsValue) {
      middleware.push(shift({ mainAxis: true, crossAxis: false, limiter: limitShift() }))
      middleware.push(flip())
    }

    middleware.push(
      size({
        apply: ({ elements, rects, availableWidth, availableHeight }) => {
          // The Base UI sizing vars, written from inside the pipeline so
          // they reflect post-flip geometry (as in Radix's size.apply).
          const style = elements.floating.style

          style.setProperty("--available-width", `${availableWidth}px`)
          style.setProperty("--available-height", `${availableHeight}px`)
          style.setProperty("--anchor-width", `${rects.reference.width}px`)
          style.setProperty("--anchor-height", `${rects.reference.height}px`)
        }
      })
    )

    if (arrowElement) middleware.push(arrow({ element: arrowElement }))

    middleware.push(hide({ strategy: "referenceHidden" }))

    return middleware
  }

  #placement() {
    const side = SIDES.includes(this.sideValue) ? this.sideValue : "bottom"
    const align = ALIGNS.includes(this.alignValue) ? this.alignValue : "center"

    return align === "center" ? side : `${side}-${align}`
  }

  // Radix's transformOrigin middleware, applied post-compute: the origin sits
  // on the anchor-facing edge, at the arrow's center when there is an arrow,
  // else at the resolved align fraction.
  #transformOrigin({ side, align, content, arrowElement, middlewareData }) {
    const { width: arrowWidth, height: arrowHeight } = this.#arrowSize(arrowElement)
    const alignOrigin = NO_ARROW_ALIGN_ORIGIN[align] ?? "50%"
    const arrowX = (middlewareData.arrow?.x ?? 0) + arrowWidth / 2
    const arrowY = (middlewareData.arrow?.y ?? 0) + arrowHeight / 2
    const across = arrowElement ? `${arrowX}px` : alignOrigin
    const down = arrowElement ? `${arrowY}px` : alignOrigin
    const rect = typeof content.getBoundingClientRect === "function"
      ? content.getBoundingClientRect()
      : { width: 0, height: 0 }

    switch (side) {
      case "top": return `${across} ${rect.height + arrowHeight}px`
      case "bottom": return `${across} ${-arrowHeight}px`
      case "left": return `${rect.width + arrowHeight}px ${down}`
      case "right": return `${-arrowHeight}px ${down}`
      default: return `${alignOrigin} ${alignOrigin}`
    }
  }

  #positionArrow(arrowElement, side, middlewareData) {
    const { x, y } = middlewareData.arrow ?? {}

    arrowElement.style.position = "absolute"
    arrowElement.style.left = x != null ? `${x}px` : ""
    arrowElement.style.top = y != null ? `${y}px` : ""
    // Pin the arrow to the content's anchor-facing edge, then rotate it to
    // point at the anchor (Radix's table); data-side is ALSO written so
    // ported CSS can restyle per side.
    arrowElement.style[OPPOSITE_SIDE[side]] = "0"
    arrowElement.style.transformOrigin = ARROW_TRANSFORM_ORIGIN[side]
    arrowElement.style.transform = ARROW_TRANSFORM[side]
    arrowElement.setAttribute("data-side", side)
  }

  #arrowSize(arrowElement) {
    if (!arrowElement || typeof arrowElement.getBoundingClientRect !== "function") {
      return { width: 0, height: 0 }
    }

    const { width, height } = arrowElement.getBoundingClientRect()

    return { width, height }
  }

  // --- elements ---

  // What computePosition / autoUpdate float against: with a stored anchor
  // point, a VirtualElement whose rect is zero-size at (x,y) - live-read, so
  // a moved point is picked up on every autoUpdate re-read - else the
  // element anchor itself.
  #reference() {
    const anchor = this.#anchor()
    const point = this.#anchorPoint()

    if (!point) return anchor

    const reference = {
      getBoundingClientRect: () => {
        const { x, y } = this.#anchorPoint() ?? point

        return { x, y, width: 0, height: 0, top: y, right: x, bottom: y, left: x }
      }
    }

    // The element anchor rides along so autoUpdate observes scroll / resize
    // of the trigger surface's ancestors (the ContextMenu contract).
    if (anchor) reference.contextElement = anchor

    return reference
  }

  #anchorPoint() {
    const raw = this.anchorPointValue.trim()

    if (!raw) return null

    const [x, y] = raw.split(",").map((part) => Number.parseFloat(part))

    if (!Number.isFinite(x) || !Number.isFinite(y)) return null

    return { x, y }
  }

  #anchor() {
    if (this.#anchorElement) return this.#anchorElement
    if (this.hasAnchorTarget) return this.anchorTarget
    if (this.anchorValue) return document.querySelector(this.anchorValue)

    return this.element.previousElementSibling
  }

  #content() {
    if (this.hasContentTarget) {
      this.#contentElement = this.contentTarget
      return this.contentTarget
    }

    // The portal seam (docs/portal-on-open.md): while content is portaled
    // out, the Stimulus target no longer matches (targets scope to the
    // controller's subtree) - the cached node keeps being positioned.
    // Without the cache the fallback would position the ROOT.
    if (this.#contentElement?.isConnected) return this.#contentElement

    return this.element
  }

  // The Tier-4 Arrow is markup-only: an explicit arrow target wins, else any
  // [data-slot=popper-arrow] inside the content is positioned.
  #arrow() {
    if (this.hasArrowTarget) return this.arrowTarget

    return this.#content()?.querySelector("[data-slot=popper-arrow]") ?? null
  }
}
