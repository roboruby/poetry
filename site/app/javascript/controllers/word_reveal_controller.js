import { Controller } from "@hotwired/stimulus"

// Tagline word reveal: each .wr-word span lights up as it crosses a
// trigger line near the lower third of the viewport, in reading order.
// landing-brand.css carries the color transition and the
// prefers-reduced-motion escape (words render lit, no animation).
export default class extends Controller {
  connect() {
    const words = this.element.querySelectorAll(".wr-word")
    if (matchMedia("(prefers-reduced-motion: reduce)").matches) {
      words.forEach((w) => w.setAttribute("data-on", ""))
      return
    }
    this.observer = new IntersectionObserver(
      (entries) => {
        for (const entry of entries) {
          if (!entry.isIntersecting) continue
          entry.target.setAttribute("data-on", "")
          this.observer.unobserve(entry.target)
        }
      },
      { rootMargin: "0px 0px -35% 0px", threshold: 1 }
    )
    words.forEach((w) => this.observer.observe(w))
  }

  disconnect() {
    this.observer?.disconnect()
  }
}
