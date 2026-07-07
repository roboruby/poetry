import { Controller } from "@hotwired/stimulus"
import {
  EMPTY_MESSAGE_SCROLLER_SCROLLABLE,
  EMPTY_MESSAGE_SCROLLER_VISIBILITY_STATE,
  SCROLL_POSITION_EPSILON,
  areScrollStatesEqual,
  areVisibilityStatesEqual,
  getContentBottom,
  getElementScrollTop,
  getElementTop,
  getElementViewportTop,
  getFirstVisibleMessageItem,
  getFlexGap,
  getLastScrollAnchor,
  getMaxScrollTop,
  getMessageScrollerItems,
  getMessageScrollerScrollable,
  getMessageScrollerVisibilityState,
  getNewScrollAnchor,
  getTailSpacerHeight,
  getUnanchoredScrollAnchor,
  hasMultipleNewScrollAnchors
} from "@poetry/controllers/helpers/scroller_geometry"

// How long (ms) data-autoscrolling stays set during a programmatic scroll
// before clearing. While set, the follow-bottom RELEASE is suppressed so the
// auto-scroll animation cannot release itself.
const AUTOSCROLLING_CLEAR_DELAY = 180

// Viewport keys that count as deliberate scroll intent and release follow.
const USER_SCROLL_KEYS = new Set([
  "ArrowDown",
  "ArrowUp",
  "End",
  "Home",
  "PageDown",
  "PageUp",
  " " // Space key.
])

// The chat-transcript scroller (the centerpiece of the Gen-UI surface): a
// verbatim port of shadcn's message-scroller 4-mode machine - the React
// context tree collapsed into ONE controller, refs become instance fields,
// useSyncExternalStore stores become data-* attributes + dispatched events
// (the DOM is the store), and registerMessage is DELETED: the
// MutationObserver + data-message-id in DOM order IS registration. Rows are
// content children (Turbo Streams append them; the observer never knows the
// difference). Geometry lives in helpers/scroller_geometry - pure, tested.
//
// Modes (mirrored to data-mode on the root, a poetry addition - a
// value-carrying attribute like Base UI's data-swipe-direction; the mode
// set is not part of the presence-pair vocabulary):
//   following-bottom    autoScroll pinned to the latest message
//   free-scrolling      reader scrolled away; position left alone
//   anchored-to-message a turn held at the reading line while a reply streams
//   settling-jump       a programmatic jump animating; intent suppressed
//
// Viewport scroll/wheel/touchmove/keydown listeners are wired here (passive
// flags need addEventListener) - do NOT also declare them as data-actions.
// The jump button IS a data-action: click->...#jump.
export default class extends Controller {
  // The events this controller dispatches (manifest surface;
  // events_declaration.test.js enforces the list stays honest).
  static events = [
    "poetry--core--message-scroller:mode", "poetry--core--message-scroller:pinned", "poetry--core--message-scroller:scrollable",
    "poetry--core--message-scroller:unpinned", "poetry--core--message-scroller:visibility"
  ]

  static targets = ["viewport", "content", "spacer", "button"]
  static values = {
    // Source-faithful default (the contract): the poetry ViewComponent
    // wrapper opts INTO following by rendering the value true.
    autoScroll: { type: Boolean, default: false },
    defaultScrollPosition: { type: String, default: "end" }, // start | end | last-anchor
    preserveScrollOnPrepend: { type: Boolean, default: true },
    trackVisibility: { type: Boolean, default: false },
    scrollEdgeThreshold: { type: Number, default: 8 },
    scrollPreviousItemPeek: { type: Number, default: 64 },
    scrollMargin: { type: Number, default: 0 }
  }

  connect() {
    // The ref bag, as instance fields.
    this.mode = this.autoScrollValue ? "following-bottom" : "free-scrolling"
    this.autoscrolling = false
    this.autoscrollingTimeout = null
    this.stateFrame = null
    this.visibilityFrame = null
    this.itemCount = 0
    this.firstItem = null
    this.streamingTurn = null
    this.prependRestore = null
    this.pendingScrollToMessage = null
    this.defaultScrollPositionApplied = false
    this.spacerHeight = 0
    this.spacerGap = getFlexGap(this.#spacer()?.parentElement ?? null)
    this.handledScrollAnchors = new WeakSet()
    this.visibleMessageIds = new Set()
    this.observedRows = new Set()
    this.visibilityObserver = null
    this.scrollableState = EMPTY_MESSAGE_SCROLLER_SCROLLABLE
    this.visibilityState = EMPTY_MESSAGE_SCROLLER_VISIBILITY_STATE

    // Initial mirror, no transition - events fire on transitions only.
    this.element.dataset.mode = this.mode

    const viewport = this.#viewport()
    this.onScroll = () => this.syncAfterScroll()
    this.onWheel = () => this.userScrollIntent()
    this.onTouchMove = () => this.userScrollIntent()
    this.onKeydown = (event) => this.keydownIntent(event)
    viewport.addEventListener("scroll", this.onScroll, { passive: true })
    viewport.addEventListener("wheel", this.onWheel, { passive: true })
    viewport.addEventListener("touchmove", this.onTouchMove, { passive: true })
    viewport.addEventListener("keydown", this.onKeydown)

    const content = this.#content()
    this.contentObserver = null
    this.viewportResizeObserver = null
    this.contentResizeObserver = null

    // MutationObserver on content: streamed / Turbo-Stream-appended /
    // prepended / removed ROWS. Token growth inside an existing row is the
    // content ResizeObserver's job, not this one's.
    if (content && typeof MutationObserver !== "undefined") {
      this.contentObserver = new MutationObserver(() => this.#handleContentChange())
      this.contentObserver.observe(content, { childList: true })
    }

    if (typeof ResizeObserver !== "undefined") {
      this.viewportResizeObserver = new ResizeObserver(() => this.#handleResize())
      this.viewportResizeObserver.observe(viewport)

      if (content) {
        this.contentResizeObserver = new ResizeObserver(() => this.#handleResize())
        this.contentResizeObserver.observe(content)
      }
    }

    // Mount pass (the source's layout effect): counts rows, applies
    // defaultScrollPosition once, commits scrollable state.
    this.#handleContentChange()

    if (this.trackVisibilityValue) this.#observeVisibility()

    this.started = true
  }

  disconnect() {
    // Cancel and NULL every frame/timer id - a stale non-null id after a
    // Turbo cache restore / morph reconnect makes the scheduler think a
    // frame is still pending and never reschedule (the source's StrictMode
    // cleanup, verbatim).
    this.started = false

    if (this.stateFrame !== null) {
      window.cancelAnimationFrame(this.stateFrame)
      this.stateFrame = null
    }

    if (this.visibilityFrame !== null) {
      window.cancelAnimationFrame(this.visibilityFrame)
      this.visibilityFrame = null
    }

    if (this.autoscrollingTimeout !== null) {
      window.clearTimeout(this.autoscrollingTimeout)
      this.autoscrollingTimeout = null
    }

    this.contentObserver?.disconnect()
    this.contentObserver = null
    this.viewportResizeObserver?.disconnect()
    this.viewportResizeObserver = null
    this.contentResizeObserver?.disconnect()
    this.contentResizeObserver = null
    this.visibilityObserver?.disconnect()
    this.visibilityObserver = null
    this.observedRows.clear()
    this.visibleMessageIds.clear()

    const viewport = this.#viewport()
    viewport.removeEventListener("scroll", this.onScroll)
    viewport.removeEventListener("wheel", this.onWheel)
    viewport.removeEventListener("touchmove", this.onTouchMove)
    viewport.removeEventListener("keydown", this.onKeydown)
  }

  // Source: a defaultScrollPosition prop change re-arms the one-shot apply.
  defaultScrollPositionValueChanged() {
    if (!this.started) return
    this.defaultScrollPositionApplied = false
  }

  // Source: the autoScroll layout effect - re-pin if we were following.
  autoScrollValueChanged() {
    if (!this.started) return

    if (this.autoScrollValue && this.mode === "following-bottom" && this.itemCount > 0) {
      this.#scrollToEnd({ behavior: "auto" })
      return
    }

    this.#commitScrollState()
  }

  // --- viewport handlers (wired in connect; public for outlet callers) ---

  syncAfterScroll() {
    this.#commitScrollState()
    this.#scheduleVisibilitySync()
    this.#capturePrependAnchor()
  }

  // A deliberate gesture releases auto-follow, turn-anchoring, AND an
  // in-flight programmatic jump so re-pinning never fights the reader.
  userScrollIntent() {
    if (
      this.mode === "following-bottom" ||
      this.mode === "anchored-to-message" ||
      this.mode === "settling-jump"
    ) {
      this.streamingTurn = null
      this.#setMode("free-scrolling", { reason: "user-intent" })
    }
  }

  keydownIntent(event) {
    if (USER_SCROLL_KEYS.has(event.key)) this.userScrollIntent()
  }

  // --- actions / commands (the useMessageScroller hook surface) ---

  // Jump-button action. No-op while inactive; blurs so focus is not stranded
  // on a control about to inert itself.
  jump(event) {
    const button = event.currentTarget

    if (button.dataset.active !== "true") return

    button.blur()

    const behavior = button.dataset.behavior === "auto" ? "auto" : "smooth"

    if (button.dataset.direction === "start") this.#scrollToStart({ behavior })
    else this.#scrollToEnd({ behavior })
  }

  // Callable as a Stimulus action (options via params) or directly with an
  // options object (outlet callers).
  scrollToEnd(eventOrOptions = {}) {
    return this.#scrollToEnd(this.#optionsFrom(eventOrOptions))
  }

  scrollToStart(eventOrOptions = {}) {
    return this.#scrollToStart(this.#optionsFrom(eventOrOptions))
  }

  // scrollToMessage("id", options) programmatically, or as an action with
  // data-...-message-id-param (align/behavior/scrollMargin params pass through).
  scrollToMessage(eventOrId, options) {
    if (typeof eventOrId === "string") return this.#scrollToMessage(eventOrId, options)

    const { messageId, id, ...rest } = this.#optionsFrom(eventOrId)

    return this.#scrollToMessage(messageId ?? id, rest)
  }

  #optionsFrom(eventOrOptions) {
    if (!eventOrOptions) return {}
    if (eventOrOptions.params) return eventOrOptions.params
    if (typeof Event !== "undefined" && eventOrOptions instanceof Event) return {}
    return eventOrOptions
  }

  // --- elements (targets; viewport falls back to the controller root) ---

  #viewport() {
    return this.hasViewportTarget ? this.viewportTarget : this.element
  }

  #content() {
    return this.hasContentTarget ? this.contentTarget : null
  }

  #spacer() {
    return this.hasSpacerTarget ? this.spacerTarget : null
  }

  // --- mode machine ---

  // Mode transitions were internal-ref writes in source; poetry mirrors them
  // to data-mode and dispatches mode / pinned / unpinned.
  #setMode(next, { reason = "scroll-away" } = {}) {
    const previous = this.mode

    if (previous === next) return

    this.mode = next
    this.element.dataset.mode = next
    this.dispatch("mode", { detail: { from: previous, to: next, mode: next } })

    if (next === "following-bottom") this.dispatch("pinned")
    if (previous === "following-bottom") this.dispatch("unpinned", { detail: { reason } })
  }

  // Owns the one follow-bottom transition: ARM at the bottom (however you got
  // there), RELEASE on any scroll away (including a scrollbar drag) -
  // suppressed while autoscrolling so a programmatic scroll cannot release
  // itself, and never arming over an in-flight settling-jump.
  #reconcileFollowMode(scrollable) {
    if (this.autoScrollValue && !scrollable.end && this.mode !== "settling-jump") {
      this.#setMode("following-bottom")
    } else if (this.mode === "following-bottom" && scrollable.end && !this.autoscrolling) {
      this.#setMode("free-scrolling", { reason: "scroll-away" })
    }
  }

  #commitScrollState() {
    const nextState = getMessageScrollerScrollable({
      content: this.#content(),
      scrollEdgeThreshold: this.scrollEdgeThresholdValue,
      spacer: this.#spacer(),
      viewport: this.#viewport()
    })

    this.#reconcileFollowMode(nextState)
    this.#writeStateAttributes(nextState)

    if (!areScrollStatesEqual(this.scrollableState, nextState)) {
      this.scrollableState = nextState
      this.dispatch("scrollable", { detail: { ...nextState } })
    }
  }

  #scheduleStateCommit() {
    if (this.stateFrame !== null) return

    this.stateFrame = window.requestAnimationFrame(() => {
      this.stateFrame = null
      this.#commitScrollState()
    })
  }

  #writeStateAttributes(state) {
    const scrollable = [state.start && "start", state.end && "end"].filter(Boolean).join(" ")

    for (const element of new Set([this.element, this.#viewport()])) {
      if (scrollable) element.setAttribute("data-scrollable", scrollable)
      else element.removeAttribute("data-scrollable")

      element.toggleAttribute("data-autoscrolling", this.autoscrolling)
    }

    // The Button part's useSyncExternalStore, collapsed: active = overflow
    // toward the button's direction; inactive => inert + untabbable (no
    // ghost focus stop when the reader is already caught up).
    for (const button of this.buttonTargets) {
      const active = button.dataset.direction === "start" ? state.start : state.end

      button.dataset.active = active ? "true" : "false"
      button.toggleAttribute("inert", !active)

      if (active) button.removeAttribute("tabindex")
      else button.setAttribute("tabindex", "-1")
    }
  }

  // --- visibility (the lazy visibility store, as an explicit opt-in value) ---

  #scheduleVisibilitySync() {
    if (!this.trackVisibilityValue) return
    if (this.visibilityFrame !== null) return

    this.visibilityFrame = window.requestAnimationFrame(() => {
      this.visibilityFrame = null
      this.#commitVisibility()
    })
  }

  #commitVisibility() {
    const nextState = getMessageScrollerVisibilityState({
      content: this.#content(),
      scrollMargin: this.scrollMarginValue,
      scrollPreviousItemPeek: this.scrollPreviousItemPeekValue,
      spacer: this.#spacer(),
      viewport: this.#viewport(),
      visibleMessageIds: this.visibleMessageIds
    })

    if (!areVisibilityStatesEqual(this.visibilityState, nextState)) {
      this.visibilityState = nextState
      this.dispatch("visibility", {
        detail: {
          currentAnchorId: nextState.currentAnchorId,
          visibleMessageIds: [...nextState.visibleMessageIds]
        }
      })
    }
  }

  #observeVisibility() {
    if (!this.trackVisibilityValue) return

    if (typeof IntersectionObserver === "undefined") {
      // No observer: getMessageScrollerVisibilityState falls back to rects.
      this.#scheduleVisibilitySync()
      return
    }

    if (!this.visibilityObserver) {
      this.visibilityObserver = new IntersectionObserver(
        (entries) => {
          for (const entry of entries) {
            const messageId = entry.target.dataset.messageId

            if (!messageId) continue

            if (entry.isIntersecting) this.visibleMessageIds.add(messageId)
            else this.visibleMessageIds.delete(messageId)
          }

          this.#scheduleVisibilitySync()
        },
        {
          root: this.#viewport(),
          // Shrink the root's top edge to the reading line so a previous turn
          // peeking in the scrollMargin + peek band is not reported visible,
          // keeping visibleMessageIds consistent with currentAnchorId.
          rootMargin: `${-(this.scrollMarginValue + this.scrollPreviousItemPeekValue)}px 0px 0px 0px`,
          threshold: [0, 0.01, 0.5, 1]
        }
      )
    }

    const content = this.#content()

    if (content) this.#syncObservedRows(getMessageScrollerItems(content, this.#spacer()))

    this.#scheduleVisibilitySync()
  }

  // registerMessage's replacement: childList changes ARE registration.
  #syncObservedRows(items) {
    if (!this.visibilityObserver) return

    for (const element of [...this.observedRows]) {
      if (element.isConnected) continue

      this.visibilityObserver.unobserve(element)
      this.observedRows.delete(element)

      const messageId = element.dataset.messageId
      if (messageId) this.visibleMessageIds.delete(messageId)
    }

    for (const element of items) {
      if (!element.dataset.messageId || this.observedRows.has(element)) continue

      this.visibilityObserver.observe(element)
      this.observedRows.add(element)
    }

    this.#scheduleVisibilitySync()
  }

  // --- content / resize handlers ---

  #handleContentChange() {
    const content = this.#content()

    if (!content) return

    const items = getMessageScrollerItems(content, this.#spacer())
    const previousItemCount = this.itemCount
    const previousFirstItem = this.firstItem

    this.itemCount = items.length
    this.firstItem = items[0] ?? null

    // Every path re-captures the prepend anchor afterward, so each branch
    // just returns. Branch order is LOAD-BEARING, ported verbatim:
    // pending-jump, first-content, prepended, appended, updated.
    this.#reconcileScrollPosition(items, previousItemCount, previousFirstItem)
    this.#capturePrependAnchor()
    this.#syncObservedRows(items)
  }

  #reconcileScrollPosition(items, previousItemCount, previousFirstItem) {
    if (this.#flushPendingScrollToMessage()) return

    if (previousItemCount === 0) {
      if (this.#applyDefaultScrollPosition()) return

      if (items.length > 0 && this.autoScrollValue && this.#scrollToEnd({ behavior: "auto" })) {
        return
      }

      this.#commitScrollState()
      this.#scheduleVisibilitySync()
      return
    }

    const previousFirstItemIndex = previousFirstItem ? items.indexOf(previousFirstItem) : -1
    const didPrepend = this.preserveScrollOnPrependValue && previousFirstItemIndex > 0

    if (didPrepend) {
      // Prepended rows are not new appends. Restore the prior scroll position
      // (a no-op where native scroll anchoring already did it).
      this.#restorePrependedAnchor()
      return
    }

    if (items.length > previousItemCount) {
      const anchor = getNewScrollAnchor(items, previousItemCount)

      if (anchor) {
        // While following the live end, a batch of several anchored turns
        // arriving at once keeps following the end - not yanking back to
        // anchor the first turn of the batch. A single new anchor still
        // moves to the reading line as usual.
        if (
          this.autoScrollValue &&
          this.mode === "following-bottom" &&
          hasMultipleNewScrollAnchors(items, previousItemCount)
        ) {
          this.#scrollToEnd({ behavior: "auto" })
          return
        }

        this.#scrollToElement(anchor, { align: "start" }, { keepPreviousPeek: true })
        this.handledScrollAnchors.add(anchor)
        return
      }
    }

    if (items.length === previousItemCount) {
      // Same row count but an unhandled anchor appeared (attribute added or a
      // morph replaced the node): anchor it once.
      const anchor = getUnanchoredScrollAnchor(items, this.handledScrollAnchors)

      if (anchor) {
        this.#scrollToElement(anchor, { align: "start" }, { keepPreviousPeek: true })
        this.handledScrollAnchors.add(anchor)
        return
      }
    }

    // Appends with no new anchor (and content-only updates) fall through:
    // keep following the end if we still are, otherwise just recommit state.
    if (this.mode === "following-bottom" && this.autoScrollValue) {
      this.#scrollToEnd({ behavior: "auto" })
    } else {
      this.#commitScrollState()
      this.#scheduleVisibilitySync()
    }
  }

  #handleResize() {
    if (this.mode === "following-bottom" && this.autoScrollValue) {
      this.#scrollToEnd({ behavior: "auto" })
      return
    }

    // Hold the anchored turn in place as content below it resizes (a reply
    // streaming in) - otherwise the shrinking content lets the browser clamp
    // scrollTop and the turn drops.
    if (this.#reanchorToAnchoredMessage()) return

    this.#scheduleStateCommit()
    this.#scheduleVisibilitySync()
  }

  #applyDefaultScrollPosition() {
    if (!this.defaultScrollPositionValue || this.defaultScrollPositionApplied || this.itemCount === 0) {
      return false
    }

    let handled = false

    if (this.defaultScrollPositionValue === "last-anchor") {
      const content = this.#content()
      const viewport = this.#viewport()
      const anchor = content && viewport
        ? getLastScrollAnchor(getMessageScrollerItems(content, this.#spacer()))
        : null

      if (!content || !viewport || !anchor) {
        handled = this.#scrollToEnd({ behavior: "auto" })
      } else {
        const anchorTop = getElementTop(anchor, viewport)
        const contentBottom = getContentBottom({ content, spacer: this.#spacer(), viewport })
        // A short last turn already fits below the anchor, so opening at the
        // end shows the whole turn without a blank gap beneath it.
        const lastTurnFits = contentBottom - anchorTop <= viewport.clientHeight

        handled = lastTurnFits
          ? this.#scrollToEnd({ behavior: "auto" })
          : this.#scrollToElement(anchor, { align: "start" }, { keepPreviousPeek: true })
      }
    } else {
      handled = this.defaultScrollPositionValue === "end"
        ? this.#scrollToEnd({ behavior: "auto" })
        : this.#scrollToStart({ behavior: "auto" })
    }

    if (!handled) return false

    this.defaultScrollPositionApplied = true

    return true
  }

  // --- prepend preservation ---

  #capturePrependAnchor() {
    const content = this.#content()
    const viewport = this.#viewport()

    if (!content || !viewport) {
      this.prependRestore = null
      return
    }

    const anchor = getFirstVisibleMessageItem({ content, spacer: this.#spacer(), viewport })

    this.prependRestore = anchor
      ? { element: anchor, viewportTop: getElementViewportTop(anchor, viewport) }
      : null
  }

  #restorePrependedAnchor() {
    const anchor = this.prependRestore
    const viewport = this.#viewport()

    if (!anchor || !viewport || !anchor.element.isConnected) return false

    // Compare the anchor relative to the VIEWPORT, not the content: native
    // scroll anchoring leaves the viewport-relative position unchanged, so
    // this is a no-op where the browser already handled the prepend and only
    // corrects the scroll where it did not (e.g. Safari) - without trusting a
    // capability flag, which some engines report incorrectly.
    const nextViewportTop = getElementViewportTop(anchor.element, viewport)
    const delta = nextViewportTop - anchor.viewportTop

    if (Math.abs(delta) <= SCROLL_POSITION_EPSILON) return false

    viewport.scrollTop += delta
    anchor.viewportTop = getElementViewportTop(anchor.element, viewport)
    this.#scheduleStateCommit()
    this.#scheduleVisibilitySync()

    return true
  }

  // --- scroll commands (mechanics, split from the policy above as in source) ---

  #setAutoScrolling(autoscrolling) {
    if (this.autoscrollingTimeout !== null) {
      window.clearTimeout(this.autoscrollingTimeout)
      this.autoscrollingTimeout = null
    }

    if (this.autoscrolling !== autoscrolling) {
      this.autoscrolling = autoscrolling
      this.#commitScrollState()
    }

    if (autoscrolling) {
      this.autoscrollingTimeout = window.setTimeout(() => {
        this.autoscrollingTimeout = null
        this.autoscrolling = false
        this.#commitScrollState()
      }, AUTOSCROLLING_CLEAR_DELAY)
    }
  }

  // Tail spacer: fakes scroll room below a short anchored turn. Clamped >= 0,
  // ceil'd; visible it gets a negative marginTop compensating the content
  // flex gap so it adds no phantom row gap; hidden at 0.
  #setTailSpacerHeight(height) {
    const spacer = this.#spacer()

    if (!spacer) return

    const nextHeight = Math.max(0, Math.ceil(height))

    if (this.spacerHeight === nextHeight) return

    this.spacerHeight = nextHeight
    spacer.hidden = nextHeight === 0
    spacer.style.height = `${nextHeight}px`
    spacer.style.marginTop = nextHeight > 0 ? `${-this.spacerGap}px` : ""
  }

  // Instant scroll under prefers-reduced-motion (follow moves are already
  // behavior: auto in source - this only downgrades requested smooth jumps).
  #resolveBehavior(behavior) {
    if (behavior !== "smooth") return behavior

    if (
      typeof window.matchMedia === "function" &&
      window.matchMedia("(prefers-reduced-motion: reduce)").matches
    ) {
      return "auto"
    }

    return behavior
  }

  #scrollToPosition(scrollTop, { behavior = "auto", autoscrolling = false } = {}) {
    const viewport = this.#viewport()

    if (!viewport) return

    const nextScrollTop = Math.max(0, scrollTop)

    // Scrolls within epsilon snap without animating (zoom/HiDPI rounding).
    if (Math.abs(viewport.scrollTop - nextScrollTop) <= SCROLL_POSITION_EPSILON) {
      viewport.scrollTop = nextScrollTop
      this.#commitScrollState()
      return
    }

    if (autoscrolling) this.#setAutoScrolling(true)

    if (typeof viewport.scrollTo === "function") {
      viewport.scrollTo({ top: nextScrollTop, behavior: this.#resolveBehavior(behavior) })
    } else {
      viewport.scrollTop = nextScrollTop
    }

    this.#scheduleStateCommit()
  }

  #scrollToStart({ behavior = "auto" } = {}) {
    if (!this.#viewport()) return false

    this.#setTailSpacerHeight(0)
    this.streamingTurn = null
    this.#setMode("free-scrolling", { reason: "user-intent" })
    this.#scrollToPosition(0, { behavior })
    this.#scheduleVisibilitySync()

    return true
  }

  #scrollToEnd({ behavior = "auto" } = {}) {
    const viewport = this.#viewport()

    if (!viewport) return false

    this.#setTailSpacerHeight(0)
    this.streamingTurn = null
    this.#setMode(this.autoScrollValue ? "following-bottom" : "free-scrolling", {
      reason: "user-intent"
    })
    this.#scrollToPosition(getMaxScrollTop(viewport), { autoscrolling: true, behavior })
    this.#scheduleVisibilitySync()

    return true
  }

  #scrollToElement(element, { align = "start", behavior = "auto", scrollMargin = this.scrollMarginValue } = {}, { keepPreviousPeek = false } = {}) {
    const content = this.#content()
    const viewport = this.#viewport()

    if (!content || !viewport || !content.contains(element)) return false

    const scrollTop = getElementScrollTop({
      align,
      element,
      // keepPreviousPeek adds the peek to the start margin - the reading line.
      scrollMargin: keepPreviousPeek ? scrollMargin + this.scrollPreviousItemPeekValue : scrollMargin,
      spacer: this.#spacer(),
      viewport
    })

    const nextSpacerHeight = getTailSpacerHeight({
      content,
      scrollTop,
      spacer: this.#spacer(),
      viewport
    })

    this.#setTailSpacerHeight(nextSpacerHeight)
    // Seed the prepend anchor with the jump target so a prepend landing before
    // this scroll settles still preserves the jumped-to row; once settled,
    // syncAfterScroll re-captures it from the first visible row.
    this.prependRestore = {
      element,
      viewportTop: getElementViewportTop(element, viewport)
    }

    this.streamingTurn = keepPreviousPeek ? element : null
    this.#setMode(keepPreviousPeek ? "anchored-to-message" : "settling-jump")

    this.#scrollToPosition(scrollTop, { behavior })
    this.#scheduleVisibilitySync()

    return true
  }

  // Re-run the anchored placement (recompute spacer + scrollTop) so the turn
  // holds the reading line as content below it grows or shrinks.
  #reanchorToAnchoredMessage() {
    const element = this.streamingTurn

    if (!element || !element.isConnected || this.mode !== "anchored-to-message") {
      return false
    }

    return this.#scrollToElement(element, { align: "start" }, { keepPreviousPeek: true })
  }

  // The target row may not be mounted yet (async transcript / lazy frame).
  // A miss on an empty transcript queues the request, flushed on the next
  // content change. An explicit jump marks the mount default as applied so
  // defaultScrollPosition does not override it.
  #scrollToMessage(messageId, options) {
    const element = this.#findMessageElement(messageId)

    if (!element) {
      if (this.itemCount === 0) {
        this.pendingScrollToMessage = { messageId, options }
        this.defaultScrollPositionApplied = true

        return true
      }

      return false
    }

    this.defaultScrollPositionApplied = true

    if (this.#scrollToElement(element, options)) {
      this.pendingScrollToMessage = null
      return true
    }

    this.pendingScrollToMessage = { messageId, options }

    return true
  }

  #flushPendingScrollToMessage() {
    const pending = this.pendingScrollToMessage

    if (!pending) return false

    const element = this.#findMessageElement(pending.messageId)

    if (!element) return false

    if (!this.#scrollToElement(element, pending.options)) return false

    this.pendingScrollToMessage = null
    this.defaultScrollPositionApplied = true

    return true
  }

  // Rows register through the DOM, not a Map: look the id up in DOM order.
  #findMessageElement(messageId) {
    const content = this.#content()

    if (!content || !messageId) return null

    for (const item of getMessageScrollerItems(content, this.#spacer())) {
      if (item.dataset.messageId === messageId) return item
    }

    return null
  }
}
