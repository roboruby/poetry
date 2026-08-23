import { Controller } from "@hotwired/stimulus"

// Page-level scroll reveal for the landing page. Stamps data-revealed
// when the element enters the viewport; landing-brand.css carries the
// transition and the prefers-reduced-motion escape.
export default class extends Controller {
  connect() {
    if (matchMedia("(prefers-reduced-motion: reduce)").matches) {
      this.element.setAttribute("data-revealed", "")
      return
    }
    this.observer = new IntersectionObserver(
      (entries) => {
        for (const entry of entries) {
          if (!entry.isIntersecting) continue
          entry.target.setAttribute("data-revealed", "")
          this.observer.unobserve(entry.target)
        }
      },
      { threshold: 0.15 }
    )
    this.observer.observe(this.element)
  }

  disconnect() {
    this.observer?.disconnect()
  }
}
