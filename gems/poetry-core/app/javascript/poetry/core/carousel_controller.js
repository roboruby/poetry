import { Controller } from "@hotwired/stimulus"

// The Carousel engine, decided NATIVE: no carousel library - the platform's
// scroll-snap owns the physics (touch, momentum, snapping, overscroll),
// and this controller adds only what CSS can't: prev/next paging, button
// state, and arrow keys. Navigation scrolls the VIEWPORT by a bounding-
// rect delta (RTL- and transform-safe: never scrollLeft sign
// conventions) - not scrollIntoView, whose alignment bubbles to
// scrollable ancestors and whose "nearest" no-ops when several slides
// fit the viewport at once (the vertical stack). Deferred with the
// library-grade machinery: loop (it clones slides), autoplay, and a plugin API.
const SLIDE_SELECTOR = '[data-slot="carousel-item"]'

// The component-facing event namespace (the poetry:<component> rule).
const EVENT_PREFIX = "poetry:carousel"

export default class CarouselController extends Controller {
  // The events this controller dispatches (manifest surface;
  // events_declaration.test.js enforces the list stays honest).
  static events = ["poetry:carousel:select"]

  static targets = ["viewport", "previous", "next"]
  static values = {
    orientation: { type: String, default: "horizontal" }
  }

  #raf = null

  /** Syncs button state to the initial scroll position. */
  connect() {
    this.#sync()
  }

  /** Cancels any pending sync frame. */
  disconnect() {
    if (this.#raf !== null) cancelAnimationFrame(this.#raf)
  }

  /**
   * The viewport's scroll action - button state follows the SCROLL
   * (finger, wheel, keyboard PageDown), not just our own paging.
   * rAF-coalesced: scroll fires in bursts.
   */
  scrolled() {
    if (this.#raf !== null) return

    this.#raf = requestAnimationFrame(() => {
      this.#raf = null
      this.#sync()
    })
  }

  /** The previous button's click action: pages one slide back. */
  previous() {
    this.#scrollTo(this.#index() - 1)
  }

  /** The next button's click action: pages one slide forward. */
  next() {
    this.#scrollTo(this.#index() + 1)
  }

  /**
   * The region root's keydown action (the upstream wrapper contract):
   * arrows page the carousel, orientation-aware.
   *
   * @param {KeyboardEvent} event
   */
  keydown(event) {
    const [prevKey, nextKey] =
      this.orientationValue === "vertical" ? ["ArrowUp", "ArrowDown"] : ["ArrowLeft", "ArrowRight"]

    if (event.key === prevKey) {
      event.preventDefault()
      this.previous()
    } else if (event.key === nextKey) {
      event.preventDefault()
      this.next()
    }
  }

  /**
   * The programmatic surface: scrolls to a slide by index (clamped).
   *
   * @param {number | string} index - stringified numbers accepted
   */
  scrollTo(index) {
    this.#scrollTo(Number(index))
  }

  #scrollTo(index) {
    const slides = this.#slides()
    const target = slides[Math.max(0, Math.min(slides.length - 1, index))]
    if (!target) return

    // Rect delta start-aligns the target inside the viewport alone.
    // Subtracting scroll-margin lands on the slide's SNAP position (the
    // items carry negative scroll-margin to cancel their gutter from the
    // snap area), so the smooth scroll and the CSS snap agree.
    const vertical = this.orientationValue === "vertical"
    const rect = target.getBoundingClientRect()
    const viewport = this.viewportTarget.getBoundingClientRect()
    const style = getComputedStyle(target)
    const delta = vertical
      ? rect.top - (parseFloat(style.scrollMarginTop) || 0) - viewport.top
      : rect.left - (parseFloat(style.scrollMarginLeft) || 0) - viewport.left

    this.viewportTarget.scrollBy?.({
      behavior: "smooth",
      left: vertical ? 0 : delta,
      top: vertical ? delta : 0
    })
    // Button state also syncs from the scroll events the smooth scroll
    // emits; this immediate pass covers environments without them.
    this.#sync(index)
  }

  // The slide nearest the viewport's start edge - bounding rects, so RTL
  // and transforms cost nothing.
  #index() {
    const viewport = this.viewportTarget.getBoundingClientRect()
    let nearest = 0
    let nearestDistance = Infinity

    this.#slides().forEach((slide, index) => {
      const rect = slide.getBoundingClientRect()
      const distance = this.orientationValue === "vertical"
        ? Math.abs(rect.top - viewport.top)
        : Math.abs(rect.left - viewport.left)

      if (distance < nearestDistance) {
        nearest = index
        nearestDistance = distance
      }
    })

    return nearest
  }

  #sync(index = this.#index()) {
    const last = this.#slides().length - 1

    if (this.hasPreviousTarget) this.previousTarget.disabled = index <= 0
    if (this.hasNextTarget) this.nextTarget.disabled = index >= last || this.#atEnd()

    this.dispatch("select", { prefix: EVENT_PREFIX, detail: { index } })
  }

  // Embla trims snap points the scroller cannot reach (containScroll);
  // native scroll keeps them, so next must ALSO disable at max scroll -
  // otherwise trailing slides that cannot start-align (multi-visible
  // layouts) leave a live button that does nothing. Math.abs keeps the
  // check RTL-safe (scrollLeft runs negative there).
  #atEnd() {
    const viewport = this.viewportTarget
    const vertical = this.orientationValue === "vertical"
    const max = vertical
      ? viewport.scrollHeight - viewport.clientHeight
      : viewport.scrollWidth - viewport.clientWidth

    return max > 0 && Math.abs(vertical ? viewport.scrollTop : viewport.scrollLeft) >= max - 1
  }

  #slides() {
    return [...this.viewportTarget.querySelectorAll(SLIDE_SELECTOR)]
  }
}
