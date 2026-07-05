import { Controller } from "@hotwired/stimulus"

// The Sidebar state machine (N9 W5): expand/collapse coordination for the
// app shell. The COLLAPSE itself is pure CSS - the peer sidebar carries
// data-state=expanded|collapsed and the dictionary's
// group-data-[state=collapsed] classes do all the width/transform work;
// this controller only flips that attribute (plus data-collapsible, which
// the source sets to the mode WHILE collapsed and "" while expanded),
// persists the choice to a cookie (so the SERVER can read it and render
// the right initial state - poetry's server-first angle), and binds the
// Cmd/Ctrl+B shortcut.
//
// Deferred with the mobile-Sheet mode (W5b): the isMobile branch that
// renders the sidebar inside a Sheet - a server-rendered render-twice /
// portal decision, not a controller concern.
export default class SidebarController extends Controller {
  static targets = ["sidebar"]
  static values = {
    open: { type: Boolean, default: true },
    // The collapse mode written to data-collapsible while collapsed
    // (offcanvas | icon); "none" means the shortcut/trigger are inert.
    collapsible: { type: String, default: "offcanvas" },
    cookieName: { type: String, default: "sidebar_state" },
    cookieMaxAge: { type: Number, default: 604800 }, // 7 days
    shortcut: { type: String, default: "b" }
  }

  #onKeydown = null

  connect() {
    // Reflect the server value to the DOM once. We do NOT drive reflection
    // off openValueChanged - Stimulus fires value callbacks asynchronously
    // (MutationObserver), so a click's DOM update would lag a frame; the
    // mutators below reflect synchronously instead.
    this.#reflect()

    this.#onKeydown = (event) => {
      if (event.key !== this.shortcutValue) return
      if (!(event.metaKey || event.ctrlKey)) return

      event.preventDefault()
      this.toggle()
    }
    window.addEventListener("keydown", this.#onKeydown)
  }

  disconnect() {
    if (this.#onKeydown) window.removeEventListener("keydown", this.#onKeydown)
    this.#onKeydown = null
  }

  // Action: click->poetry--core--sidebar#toggle (the trigger + the rail).
  toggle() {
    if (this.collapsibleValue === "none") return

    this.#set(!this.openValue)
  }

  open() {
    this.#set(true)
  }

  close() {
    this.#set(false)
  }

  // The single mutator: update the value, reflect synchronously, persist.
  // The cookie is written for genuine toggles only - the server already
  // knows the initial value (it read the cookie to render it), so connect
  // reflects without persisting.
  #set(open) {
    this.openValue = open
    this.#reflect()
    this.#persist()
  }

  #reflect() {
    const collapsed = !this.openValue

    for (const sidebar of this.sidebarTargets) {
      sidebar.setAttribute("data-state", collapsed ? "collapsed" : "expanded")
      sidebar.setAttribute("data-collapsible", collapsed ? this.collapsibleValue : "")
    }
    this.dispatch("toggle", { detail: { open: this.openValue } })
  }

  #persist() {
    if (typeof document === "undefined") return

    document.cookie =
      `${this.cookieNameValue}=${this.openValue}; path=/; max-age=${this.cookieMaxAgeValue}; samesite=lax`
  }
}
