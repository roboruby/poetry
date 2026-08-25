import { Controller } from "@hotwired/stimulus"

// Remembers explicit sidebar disclosure choices in a cookie so the
// server re-renders every Turbo visit with the user's own open set;
// sections the user never touched keep following the current page's
// section. The remember action rides the collapsible trigger AFTER the
// state controller's toggle (declaration order), so aria-expanded
// already reflects the new state when it reads it.
export default class extends Controller {
  remember(event) {
    const trigger = event.currentTarget
    const state = this.#read()
    state[event.params.section] = trigger.getAttribute("aria-expanded") === "true"
    document.cookie = "docs_sidebar=" + encodeURIComponent(JSON.stringify(state)) +
      "; path=/; max-age=31536000; samesite=lax"
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
}
