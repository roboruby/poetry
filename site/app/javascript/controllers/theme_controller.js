import { Controller } from "@hotwired/stimulus"

// Dark mode is a class on <html> (the poetry token contract). The layout's
// inline head script applies the stored choice pre-paint; this only
// toggles and persists.
export default class extends Controller {
  toggle() {
    const dark = document.documentElement.classList.toggle("dark")
    try {
      localStorage.setItem("poetry-docs-theme", dark ? "dark" : "light")
    } catch {
      // private mode - the toggle still works for the session
    }
  }
}
