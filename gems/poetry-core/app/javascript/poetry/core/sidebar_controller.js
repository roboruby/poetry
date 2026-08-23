import { Controller } from "@hotwired/stimulus"
import { watchMobile } from "@poetry/controllers/helpers/breakpoint"
import { enterPresence, exitPresence } from "@poetry/controllers/helpers/presence"
import { setState } from "@poetry/controllers/helpers/state"

// The Sidebar state machine (desktop plus the mobile mode): expand/collapse
// coordination for the app shell. The COLLAPSE itself is pure CSS - the
// peer sidebar carries data-state=expanded|collapsed and the dictionary's
// group-data-[state=collapsed] classes do all the width/transform work;
// this controller only flips that attribute (plus data-collapsible, which
// the source sets to the mode WHILE collapsed and "" while expanded),
// persists the choice to a cookie (so the SERVER can read it and render
// the right initial state - poetry's server-first angle), and binds the
// Cmd/Ctrl+B shortcut.
//
// MOBILE (DOM-move): below md the trigger routes to a separate
// never-persisted openMobile state (upstream parity - only desktop
// toggles write the cookie). Opening ADOPTS the server-rendered nav
// children from the desktop inner into the mobile <dialog> (one render,
// no duplicate ids - the render-twice rejection) and shows it through the
// sheet presence path; closing holds through the slide-out, then moves
// the children back. Crossing to desktop while open restores INSTANTLY.
export default class SidebarController extends Controller {
  // The events this controller dispatches (manifest surface;
  // events_declaration.test.js enforces the list stays honest).
  static events = ["poetry--core--sidebar:mobile-toggle", "poetry--core--sidebar:toggle"]

  static targets = ["sidebar", "inner", "mobileDialog", "mobileInner"]
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
  #unwatchMobile = null
  #isMobile = false
  #mobileOpen = false
  #closingMobile = false
  #previousOverflow

  connect() {
    // Reflect the server value to the DOM once. We do NOT drive reflection
    // off openValueChanged - Stimulus fires value callbacks asynchronously
    // (MutationObserver), so a click's DOM update would lag a frame; the
    // mutators below reflect synchronously instead.
    this.#reflect()

    this.#unwatchMobile = watchMobile((mobile) => this.#mobileChanged(mobile))

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
    this.#unwatchMobile?.()
    this.#unwatchMobile = null
  }

  // Action: click->poetry--core--sidebar#toggle (the trigger + the rail).
  // On mobile the SAME trigger (and Cmd/Ctrl+B) routes to the sheet.
  toggle() {
    if (this.#isMobile && this.hasMobileDialogTarget) {
      if (this.#mobileOpen) this.closeMobile()
      else this.#openMobile()
      return
    }
    if (this.collapsibleValue === "none") return

    this.#set(!this.openValue)
  }

  // -- the mobile sheet -------------------------------------------------

  // Action: cancel->poetry--core--sidebar#closeMobile on the mobile dialog.
  closeMobile(event) {
    if (event?.type === "cancel") event.preventDefault() // route Esc through the animated path
    if (!this.#mobileOpen || this.#closingMobile) return

    this.#closingMobile = true
    exitPresence(this.mobileDialogTarget, {
      onRemove: () => {
        this.#closingMobile = false
        this.#restoreMobile()
      }
    })
  }

  // Action: click->poetry--core--sidebar#mobileBackdropClose - the
  // dialog's coordinate discrimination (a backdrop click targets the
  // <dialog> itself AND lands outside its bounding rect).
  mobileBackdropClose(event) {
    if (event.target !== this.mobileDialogTarget) return

    const rect = this.mobileDialogTarget.getBoundingClientRect()
    const inside = rect.top <= event.clientY && event.clientY <= rect.bottom &&
      rect.left <= event.clientX && event.clientX <= rect.right
    if (!inside) this.closeMobile()
  }

  // DOM-move: adopt the server-rendered nav into the mobile
  // dialog - one render, no duplicate ids.
  #openMobile() {
    if (this.#mobileOpen || !this.hasMobileInnerTarget) return

    while (this.innerTarget.firstChild) this.mobileInnerTarget.appendChild(this.innerTarget.firstChild)
    this.mobileDialogTarget.showModal()
    enterPresence(this.mobileDialogTarget)
    this.#previousOverflow = document.body.style.overflow
    document.body.style.overflow = "hidden"
    this.#mobileOpen = true
    this.dispatch("mobile-toggle", { detail: { open: true } })
  }

  // Close the native dialog and move the nav children HOME.
  #restoreMobile() {
    this.mobileDialogTarget.close()
    while (this.mobileInnerTarget.firstChild) this.innerTarget.appendChild(this.mobileInnerTarget.firstChild)
    if (this.#previousOverflow !== undefined) {
      document.body.style.overflow = this.#previousOverflow
      this.#previousOverflow = undefined
    }
    this.#mobileOpen = false
    this.dispatch("mobile-toggle", { detail: { open: false } })
  }

  // Crossing to desktop while the sheet is open restores INSTANTLY (no
  // exit animation - the layout is changing wholesale anyway).
  #mobileChanged(mobile) {
    this.#isMobile = mobile
    if (!mobile && this.#mobileOpen && !this.#closingMobile) {
      this.mobileDialogTarget.removeAttribute("data-ending-style")
      setState(this.mobileDialogTarget, "closed")
      this.#restoreMobile()
    }
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
