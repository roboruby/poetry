import { Controller } from "@hotwired/stimulus"

const STYLES = ["default", "vega", "nova", "mira", "rhea", "maia", "luma", "lyra", "sera"]
const KEY = "poetry-docs-style"

// The docs style axis (N12 W5): keeps exactly one style-<name> class on
// <html> so the scoped fragments from style-registry.css apply. Orthogonal
// to the dark axis (theme_controller). The layout's pre-paint script
// applies the stored choice before first paint; this controller switches
// it live and keeps the header select in sync across Turbo visits.
export default class extends Controller {
  connect() {
    const select = this.element.querySelector("select")
    if (select) select.value = this.current()
  }

  apply(event) {
    const name = event.target.value
    if (!STYLES.includes(name)) return
    const root = document.documentElement.classList
    STYLES.forEach((style) => root.remove(`style-${style}`))
    root.add(`style-${name}`)
    try {
      localStorage.setItem(KEY, name)
    } catch {}
  }

  current() {
    return STYLES.find((style) => document.documentElement.classList.contains(`style-${style}`)) || "default"
  }
}
