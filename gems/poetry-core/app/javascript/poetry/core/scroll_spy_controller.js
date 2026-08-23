import { Controller } from "@hotwired/stimulus"

// Scroll-spy: marks the
// nav link whose section is currently active while the page scrolls - the
// docs-TOC pattern. Put the controller on the nav; every link target's
// href="#id" names its section:
//
//   <nav data-controller="poetry--core--scroll-spy">
//     <a href="#usage" data-poetry--core--scroll-spy-target="link">Usage</a>
//
// The active section is the LAST one whose top sits above the offset line
// (a closest-heading reduce); its link gains data-active and a
// poetry--core--scroll-spy:changed event carries the id. rAF-coalesced
// passive scroll + resize listeners; call refresh() after content changes.
export default class extends Controller {
  static targets = ["link"]
  static values = {
    // Viewport y (px) a section must cross to count as active.
    offset: { type: Number, default: 96 }
  }

  static events = ["poetry--core--scroll-spy:changed"]

  #onScroll = null
  #frame = null
  #sections = []
  #activeId = null

  connect() {
    this.refresh()
    this.#onScroll = () => {
      if (this.#frame !== null) return

      this.#frame = requestAnimationFrame(() => {
        this.#frame = null
        this.#update()
      })
    }
    window.addEventListener("scroll", this.#onScroll, { passive: true })
    window.addEventListener("resize", this.#onScroll, { passive: true })
  }

  disconnect() {
    window.removeEventListener("scroll", this.#onScroll)
    window.removeEventListener("resize", this.#onScroll)
    if (this.#frame !== null) cancelAnimationFrame(this.#frame)
    this.#frame = null
  }

  // Re-resolve sections from the links' hashes (content changed, Turbo
  // morph, tab switch) and recompute immediately.
  refresh() {
    this.#sections = this.linkTargets
      .map((link) => {
        const hash = link.getAttribute("href") || ""
        const id = hash.startsWith("#") ? hash.slice(1) : null
        return id ? { link, section: document.getElementById(id) } : null
      })
      .filter((entry) => entry && entry.section)
    this.#update()
  }

  #update() {
    let active = null
    for (const entry of this.#sections) {
      if (entry.section.getBoundingClientRect().top <= this.offsetValue) active = entry
    }

    const id = active ? active.section.id : null
    if (id === this.#activeId) return

    this.#activeId = id
    this.linkTargets.forEach((link) => link.removeAttribute("data-active"))
    if (active) active.link.setAttribute("data-active", "")
    this.dispatch("changed", { detail: { id } })
  }
}
