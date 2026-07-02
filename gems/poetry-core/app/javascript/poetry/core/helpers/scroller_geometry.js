// Scroll geometry for the message-scroller (ported 1:1 from shadcn's
// message-scroller geometry.ts): pure functions of {viewport, content,
// spacer, rects} - no Stimulus, no state. This is the jsdom-testable half;
// the controller owns the policy that decides when to call these. The
// constants encode fixed upstream bugs - change them only against source.

// Two fractional scrollTop values within this range are treated as equal, to
// absorb zoom and HiDPI rounding drift.
export const SCROLL_POSITION_EPSILON = 0.5

// Initial scrollable snapshot before measurement.
export const EMPTY_MESSAGE_SCROLLER_SCROLLABLE = Object.freeze({
  start: false,
  end: false
})

// Initial visibility snapshot: nothing tracked, no current anchor.
export const EMPTY_MESSAGE_SCROLLER_VISIBILITY_STATE = Object.freeze({
  currentAnchorId: null,
  visibleMessageIds: Object.freeze([])
})

export function getMessageScrollerScrollable({ content, scrollEdgeThreshold, spacer, viewport }) {
  if (!viewport || !content) return EMPTY_MESSAGE_SCROLLER_SCROLLABLE

  const contentBottom = getContentBottom({ content, spacer, viewport })

  return {
    start: viewport.scrollTop > scrollEdgeThreshold,
    end: contentBottom - viewport.scrollTop - viewport.clientHeight > scrollEdgeThreshold
  }
}

export function getMessageScrollerVisibilityState({
  content,
  scrollMargin,
  scrollPreviousItemPeek,
  spacer,
  viewport,
  visibleMessageIds
}) {
  if (!content || !viewport) return EMPTY_MESSAGE_SCROLLER_VISIBILITY_STATE

  const viewportRect = viewport.getBoundingClientRect()
  // The reading line sits scrollPreviousItemPeek below scrollMargin: anchored
  // turns land there with the previous turn peeking above. A row only peeking
  // in that band has not been read down to yet, so it counts as neither
  // visible nor current.
  const lineTop = viewportRect.top + scrollMargin + scrollPreviousItemPeek
  const trackByLayout = typeof IntersectionObserver === "undefined"

  const visible = []
  let currentAnchorId = null

  // Walk rows in document order so visible ids come out top-to-bottom.
  for (const item of getMessageScrollerItems(content, spacer)) {
    const messageId = item.dataset.messageId
    if (!messageId) continue

    const isAnchor = item.dataset.scrollAnchor === "true"
    // Anchors need a rect to place the current line; non-anchors lean on the
    // observer set (or a rect in the no-observer fallback).
    const rect = isAnchor || trackByLayout ? item.getBoundingClientRect() : null

    const isVisible = trackByLayout && rect
      ? rect.bottom > lineTop && rect.top < viewportRect.bottom
      : visibleMessageIds.has(messageId)

    if (isVisible) visible.push(messageId)

    // Current is the last anchor to have reached the reading line: the turn
    // you scrolled to (placed at the line) wins over newer turns lower down,
    // the previous turn peeking above the line has been passed, and it stays
    // current even after its header scrolls above the viewport.
    if (isAnchor && rect && rect.top <= lineTop + SCROLL_POSITION_EPSILON) {
      currentAnchorId = messageId
    }
  }

  if (visible.length === 0 && currentAnchorId === null) {
    return EMPTY_MESSAGE_SCROLLER_VISIBILITY_STATE
  }

  return { currentAnchorId, visibleMessageIds: visible }
}

// The collection is DOM order: rows are content's element children minus the
// tail spacer (the Radix collection primitive collapsed to a filter).
export function getMessageScrollerItems(content, spacer) {
  return Array.from(content.children).filter(
    (child) => child instanceof HTMLElement && child !== spacer
  )
}

export function getNewScrollAnchor(items, previousItemCount) {
  for (let index = previousItemCount; index < items.length; index++) {
    const item = items[index]
    if (item?.dataset.scrollAnchor === "true") return item
  }
  return null
}

export function getUnanchoredScrollAnchor(items, handledAnchors) {
  for (const item of items) {
    if (item.dataset.scrollAnchor === "true" && !handledAnchors.has(item)) return item
  }
  return null
}

export function hasMultipleNewScrollAnchors(items, previousItemCount) {
  let count = 0

  for (let index = previousItemCount; index < items.length; index++) {
    const item = items[index]
    if (item?.dataset.scrollAnchor !== "true") continue

    count += 1
    if (count > 1) return true
  }

  return false
}

export function getLastScrollAnchor(items) {
  for (let index = items.length - 1; index >= 0; index--) {
    const item = items[index]
    if (item?.dataset.scrollAnchor === "true") return item
  }
  return null
}

export function getFirstVisibleMessageItem({ content, spacer, viewport }) {
  const viewportRect = viewport.getBoundingClientRect()

  for (const item of getMessageScrollerItems(content, spacer)) {
    if (!item.dataset.messageId) continue

    const rect = item.getBoundingClientRect()
    if (rect.bottom > viewportRect.top && rect.top < viewportRect.bottom) return item
  }

  return null
}

// Target scrollTop that aligns element to the viewport inset (content block
// padding respected) per align: start | center | end | nearest.
export function getElementScrollTop({ align, element, scrollMargin, spacer, viewport }) {
  const elementTop = getElementTop(element, viewport)
  const elementHeight = element.getBoundingClientRect().height
  const contentPadding = getContentBlockPadding(spacer)

  if (align === "center") {
    const insetHeight = Math.max(
      0,
      viewport.clientHeight - contentPadding.start - contentPadding.end
    )

    return elementTop - contentPadding.start - (insetHeight - elementHeight) / 2 - scrollMargin
  }

  if (align === "end") {
    return elementTop - viewport.clientHeight + elementHeight + contentPadding.end + scrollMargin
  }

  if (align === "nearest") {
    const elementBottom = elementTop + elementHeight
    const viewportTop = viewport.scrollTop + contentPadding.start
    const viewportBottom = viewport.scrollTop + viewport.clientHeight - contentPadding.end

    if (elementTop >= viewportTop && elementBottom <= viewportBottom) {
      return viewport.scrollTop
    }

    if (elementTop < viewportTop) {
      return elementTop - contentPadding.start - scrollMargin
    }

    return elementBottom - viewport.clientHeight + contentPadding.end + scrollMargin
  }

  return elementTop - contentPadding.start - scrollMargin
}

export function getElementTop(element, viewport) {
  const elementRect = element.getBoundingClientRect()
  const viewportRect = viewport.getBoundingClientRect()

  return elementRect.top - viewportRect.top + viewport.scrollTop
}

export function getElementViewportTop(element, viewport) {
  return element.getBoundingClientRect().top - viewport.getBoundingClientRect().top
}

// Scroll room the tail spacer must fake below the last row so the requested
// scrollTop is reachable. Caller clamps/ceils (see the controller).
export function getTailSpacerHeight({ content, scrollTop, spacer, viewport }) {
  const contentBottom = getContentBottom({ content, spacer, viewport })

  return scrollTop + viewport.clientHeight - contentBottom
}

// Lowest row bottom in content space plus block padding, EXCLUDING the tail
// spacer - the spacer must never make the jump button appear.
export function getContentBottom({ content, spacer, viewport }) {
  const items = getMessageScrollerItems(content, spacer)
  const padding = getBlockPadding(content)
  const viewportRect = viewport.getBoundingClientRect()
  const scrollTop = viewport.scrollTop
  let contentBottom = padding.start + padding.end

  for (const item of items) {
    const rect = item.getBoundingClientRect()

    contentBottom = Math.max(
      contentBottom,
      rect.bottom - viewportRect.top + scrollTop + padding.end
    )
  }

  return contentBottom
}

export function getMaxScrollTop(viewport) {
  return Math.max(0, viewport.scrollHeight - viewport.clientHeight)
}

function getBlockPadding(element) {
  const style = window.getComputedStyle(element)

  return {
    end: readCssPixel(style.paddingBlockEnd || style.paddingBottom),
    start: readCssPixel(style.paddingBlockStart || style.paddingTop)
  }
}

export function getContentBlockPadding(spacer) {
  const content = spacer?.parentElement
  if (!content) return { end: 0, start: 0 }

  return getBlockPadding(content)
}

export function getFlexGap(element) {
  if (!element) return 0

  const style = window.getComputedStyle(element)
  const gap = style.rowGap === "normal" ? style.gap : style.rowGap

  return readCssPixel(gap)
}

function readCssPixel(value) {
  if (!value) return 0

  const number = Number.parseFloat(value)

  return Number.isFinite(number) ? number : 0
}

export function areScrollStatesEqual(current, next) {
  return current.start === next.start && current.end === next.end
}

export function areVisibilityStatesEqual(current, next) {
  if (current.currentAnchorId !== next.currentAnchorId) return false
  if (current.visibleMessageIds.length !== next.visibleMessageIds.length) return false

  return current.visibleMessageIds.every(
    (messageId, index) => messageId === next.visibleMessageIds[index]
  )
}
