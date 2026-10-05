import { Controller } from "@hotwired/stimulus"

// Remembers explicit sidebar disclosure choices in a cookie so the
// server re-renders every Turbo visit with the user's own open set;
// sections the user never touched keep following the current page's
// section. Two writers share the cookie: the section triggers in the
// docs shell (remember) and the docs links on the landing page (open).
export default class extends Controller {
  // Which link leads into which sidebar section (href => section title),
  // server-rendered on the landing nav containers from their link list.
  static values = { links: Object }

  // Rides the collapsible trigger AFTER the state controller's toggle
  // (declaration order), so aria-expanded already reflects the new
  // state when it reads it.
  remember(event) {
    const trigger = event.currentTarget
    this.#write({ ...this.#read(), [event.params.section]: trigger.getAttribute("aria-expanded") === "true" })
  }

  // A landing link into a section records that section as open before
  // the browser follows it, so the section is open on arrival even for
  // a visitor who once collapsed it. Links outside the map (Docs, the
  // external ones) pass through untouched.
  open(event) {
    const link = event.target.closest("a[href]")
    const section = link && this.linksValue[link.getAttribute("href")]
    if (section) this.#write({ ...this.#read(), [section]: true })
  }

  #read() {
    const raw = document.cookie.split("; ").find((c) => c.startsWith("docs_sidebar="))
    try {
      const value = JSON.parse(decodeURIComponent(raw.split("=").slice(1).join("=")))
      return value && typeof value === "object" ? value : {}
    } catch {
      return {}
    }
  }

  #write(state) {
    document.cookie = "docs_sidebar=" + encodeURIComponent(JSON.stringify(state)) +
      "; path=/; max-age=31536000; samesite=lax"
  }
}
