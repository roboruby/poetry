import { Controller } from "@hotwired/stimulus"
import { teardown, scopeOf } from "@poetry/controllers/helpers/scope"
import { useDrag } from "@poetry/motion/behaviors/drag"
import { useAnimate } from "@poetry/motion/behaviors/animate"
import { prefersReducedMotion } from "@poetry/motion/policy"

/**
 * Swipe cards: a stack whose top card drags sideways. Past the threshold
 * it flies off that way, is hidden, and the stack dispatches
 * poetry--motion--swipe-cards:swipe with { direction, card, index } so the
 * host can record the choice; short of it, the card springs back. The
 * arrow keys on the focused stack and the swipeLeft and swipeRight actions
 * do the same without a pointer. When the last card goes, the stack is
 * marked data-empty and dispatches :empty. Reduced motion still drags and
 * dismisses, without the flight.
 */
export default class SwipeCardsController extends Controller {
  static targets = ["card"]

  static events = ["poetry--motion--swipe-cards:swipe", "poetry--motion--swipe-cards:empty"]

  static values = {
    // Pixels of drag that commit a swipe.
    threshold: { type: Number, default: 100 }
  }

  /**
   * Makes the top card swipeable and listens for the arrow keys.
   *
   * @returns {void}
   */
  connect() {
    this.#mark()
    for (const card of this.cardTargets) {
      useDrag(this, card, {
        axis: "x",
        onMove: ({ x }) => card.style.setProperty("--swipe-rotate", `${x / 20}deg`),
        onEnd: ({ x }) => {
          if (Math.abs(x) < this.thresholdValue) {
            card.style.removeProperty("--swipe-rotate")
            return false
          }
          this.#dismiss(card, x > 0 ? "right" : "left", x)
          return true
        }
      })
    }
    scopeOf(this).listen(this.element, "keydown", (event) => {
      if (event.key === "ArrowLeft") this.swipeLeft()
      else if (event.key === "ArrowRight") this.swipeRight()
      else return
      event.preventDefault()
    })
  }

  /**
   * Stops listening; the cards keep what was swiped.
   *
   * @returns {void}
   */
  disconnect() {
    teardown(this)
  }

  /**
   * Swipes the top card to the left.
   *
   * @returns {void}
   */
  swipeLeft() {
    const card = this.#top()
    if (card) this.#dismiss(card, "left", 0)
  }

  /**
   * Swipes the top card to the right.
   *
   * @returns {void}
   */
  swipeRight() {
    const card = this.#top()
    if (card) this.#dismiss(card, "right", 0)
  }

  // The card on top: the first one not yet dismissed.
  #top() {
    return this.cardTargets.find((card) => !card.hidden && !card.hasAttribute("data-dismissed"))
  }

  // Flies the card off, hides it, and tells the host.
  async #dismiss(card, direction, from) {
    if (card.hasAttribute("data-dismissed")) return
    card.setAttribute("data-dismissed", direction)
    const index = this.cardTargets.indexOf(card)
    this.dispatch("swipe", { detail: { direction, card, index } })
    if (!prefersReducedMotion()) {
      const away = direction === "right" ? 1 : -1
      await useAnimate(this, card, {
        translate: [`${from}px 0px`, `${away * 120}% 0px`], opacity: [1, 0]
      }, { duration: "normal" }).finished
    }
    card.hidden = true
    for (const name of ["--swipe-rotate", "--motion-drag-x", "--motion-drag-y", "translate"]) card.style.removeProperty(name)
    this.#mark()
    if (!this.#top()) {
      this.element.setAttribute("data-empty", "")
      this.dispatch("empty")
    }
  }

  // Marks the card on top, the one that takes the pointer.
  #mark() {
    const top = this.#top()
    for (const card of this.cardTargets) card.toggleAttribute("data-top", card === top)
  }
}
