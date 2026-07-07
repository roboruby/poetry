import { Controller } from "@hotwired/stimulus"

// The Carousel engine (N9 W4), decided NATIVE: no embla - the platform's
// scroll-snap owns the physics (touch, momentum, snapping, overscroll),
// and this controller adds only what CSS can't: prev/next paging, button
// state, and arrow keys. Navigation is scrollIntoView on the TARGET slide
// (RTL- and transform-safe: geometry via bounding rects, never
// scrollLeft sign conventions). Deferred with embla's machinery: loop
// (it clones slides), autoplay, and the plugin API.
const SLIDE_SELECTOR = '[data-slot="carousel-item"]'

export default class CarouselController extends Controller {
  // The events this controller dispatches (manifest surface;
  // events_declaration.test.js enforces the list stays honest).
  static events = ["poetry--core--carousel:select"]

  static targets = ["viewport", "previous", "next"]
  static values = {
    orientation: { type: String, default: "horizontal" }
  }

  #raf = null

  connect() {
    this.#sync()
  }

  disconnect() {
    if (this.#raf !== null) cancelAnimationFrame(this.#raf)
  }

  // Action: scroll->poetry--core--carousel#scrolled on the viewport -
  // button state follows the SCROLL (finger, wheel, keyboard PageDown),
  // not just our own paging. rAF-coalesced: scroll fires in bursts.
  scrolled() {
    if (this.#raf !== null) return

    this.#raf = requestAnimationFrame(() => {
      this.#raf = null
      this.#sync()
    })
  }

  previous() {
    this.#scrollTo(this.#index() - 1)
  }

  next() {
    this.#scrollTo(this.#index() + 1)
  }

  // Action: keydown->poetry--core--carousel#keydown on the region root
  // (the shadcn wrapper contract: arrows page the carousel).
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

  // The programmatic surface.
  scrollTo(index) {
    this.#scrollTo(Number(index))
  }

  #scrollTo(index) {
    const slides = this.#slides()
    const target = slides[Math.max(0, Math.min(slides.length - 1, index))]

    target?.scrollIntoView?.({
      behavior: "smooth", block: "nearest",
      inline: this.orientationValue === "vertical" ? "nearest" : "start"
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
    if (this.hasNextTarget) this.nextTarget.disabled = index >= last

    this.dispatch("select", { detail: { index } })
  }

  #slides() {
    return [...this.viewportTarget.querySelectorAll(SLIDE_SELECTOR)]
  }
}
