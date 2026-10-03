import { Controller } from "@hotwired/stimulus"
import { useBeforeCache } from "@poetry/controllers/behaviors/before_cache"
import { useListen } from "@poetry/controllers/behaviors/listen"
import { useMobile } from "@poetry/controllers/behaviors/mobile"
import { useScrollLock } from "@poetry/controllers/behaviors/scroll_lock"
import { matchesHotkey } from "@poetry/controllers/helpers/hotkey"
import { enterPresence, exitPresence } from "@poetry/controllers/helpers/presence"
import { teardown } from "@poetry/controllers/helpers/scope"
import { setState } from "@poetry/controllers/helpers/state"

const EVENT_PREFIX = "poetry:sidebar"

/**
 * The Sidebar state machine (desktop plus the mobile mode): expand/collapse
 * coordination for the app shell. The COLLAPSE itself is pure CSS - the
 * peer sidebar carries data-state=expanded|collapsed and the dictionary's
 * group-data-[state=collapsed] classes do all the width/transform work;
 * this controller only flips that attribute (plus data-collapsible, which
 * the source sets to the mode WHILE collapsed and "" while expanded),
 * persists the choice to a cookie (so the SERVER can read it and render
 * the right initial state - poetry's server-first angle), and binds the
 * Cmd/Ctrl+B shortcut.
 *
 * MOBILE (DOM-move): below md the trigger routes to a separate
 * never-persisted openMobile state (only desktop
 * toggles write the cookie). Opening ADOPTS the server-rendered nav
 * children from the desktop inner into the mobile <dialog> (one render,
 * no duplicate ids - the render-twice rejection) and shows it through the
 * sheet presence path; closing holds through the slide-out, then moves
 * the children back. Crossing to desktop while open restores INSTANTLY.
 * The component-facing event namespace (the poetry:<component> rule).
 */
export default class SidebarController extends Controller {
  // The events this controller dispatches (manifest surface;
  // events_declaration.test.js enforces the list stays honest).
  static events = ["poetry:sidebar:mobile-toggle", "poetry:sidebar:toggle"]

  static targets = ["sidebar", "inner", "mobileDialog", "mobileInner"]
  static values = {
    // Whether the sidebar is expanded.
    open: { type: Boolean, default: true },
    // The collapse mode written to data-collapsible while collapsed
    // (offcanvas | icon); "none" means the shortcut/trigger are inert.
    collapsible: { type: String, default: "offcanvas" },
    // The cookie that remembers the open state across requests.
    cookieName: { type: String, default: "sidebar_state" },
    // How long the cookie lives, in seconds.
    cookieMaxAge: { type: Number, default: 604800 }, // 7 days
    shortcut: { type: String, default: "b" }
  }

  #isMobile = false
  #mobileOpen = false
  #closingMobile = false
  #scrollLock = null

  /**
   * Heals a restored zombie snapshot, reflects the server value once (the
   * body comment explains why not openValueChanged), starts the
   * breakpoint watcher, subscribes the before-cache close, and binds the
   * shortcut.
   */
  connect() {
    this.#scrollLock = useScrollLock(this)
    this.#healRestoredSnapshot()
    // Reflect the server value to the DOM once. We do NOT drive reflection
    // off openValueChanged - Stimulus fires value callbacks asynchronously
    // (MutationObserver), so a click's DOM update would lag a frame; the
    // mutators below reflect synchronously instead.
    this.#reflect()

    useMobile(this, (mobile) => this.#mobileChanged(mobile))

    // Close before Turbo snapshots (instantly - the page is being torn
    // down anyway): an open mobile sheet serialized into the cache
    // restores as a de-modalized zombie holding the nav children hostage
    // over a frozen scroll lock.
    useBeforeCache(this, () => {
      if (!this.#mobileOpen) return
      this.#closingMobile = false
      this.mobileDialogTarget.removeAttribute("data-ending-style")
      setState(this.mobileDialogTarget, "closed")
      this.#restoreMobile()
    })

    useListen(this, window, "keydown", (event) => {
      // The full descriptor grammar (the dialog idiom): a bare metaKey||
      // ctrlKey check also fires on stray-modifier chords (Cmd+Shift+B).
      if (event.defaultPrevented || !matchesHotkey(event, `meta+${this.shortcutValue}`)) return

      event.preventDefault()
      this.toggle()
    })
  }

  /**
   * Tears the scope down: the shortcut, the breakpoint watcher, the
   * before-cache subscription and the scroll lock, balanced.
   */
  disconnect() {
    teardown(this)
  }

  /**
   * The trigger's (and rail's) click action - also the shortcut's
   * landing. On mobile the SAME trigger routes to the sheet; on desktop
   * it flips the collapse (inert when collapsible is "none").
   */
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

  /**
   * The mobile dialog's cancel action (and the close affordances): closes
   * through the sheet exit, then moves the nav children home.
   *
   * @param {Event} [event] - the native cancel event, when Esc drove it
   */
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

  /**
   * The mobile dialog's click action - the dialog's coordinate
   * discrimination (a backdrop click targets the <dialog> itself AND
   * lands outside its bounding rect).
   *
   * @param {MouseEvent} event
   */
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
    this.#lock()
    this.#mobileOpen = true
    this.dispatch("mobile-toggle", { prefix: EVENT_PREFIX, detail: { open: true } })
  }

  // Close the native dialog and move the nav children HOME.
  #restoreMobile() {
    this.mobileDialogTarget.close()
    while (this.mobileInnerTarget.firstChild) this.innerTarget.appendChild(this.mobileInnerTarget.firstChild)
    this.#unlock()
    this.#mobileOpen = false
    this.dispatch("mobile-toggle", { prefix: EVENT_PREFIX, detail: { open: false } })
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

  /** Programmatically expands the desktop sidebar (persisted). */
  open() {
    this.#set(true)
  }

  /** Programmatically collapses the desktop sidebar (persisted). */
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
    this.dispatch("toggle", { prefix: EVENT_PREFIX, detail: { open: this.openValue } })
  }

  #persist() {
    if (typeof document === "undefined") return

    document.cookie =
      `${this.cookieNameValue}=${this.openValue}; path=/; max-age=${this.cookieMaxAgeValue}; samesite=lax`
  }

  // A mobile sheet restored from a PRE-FIX cached snapshot: the open
  // attribute survived serialization (the nav children with it), and the
  // body's inline lock styles came back with no refcount behind them.
  // Normalize to closed, move the children home, and clear the orphaned
  // lock styles directly (the refcounted helper is at zero on a fresh
  // page and must not be decremented).
  #healRestoredSnapshot() {
    if (!this.hasMobileDialogTarget || !this.mobileDialogTarget.open) return
    // A genuinely modal dialog only reconnects mid-flight when its subtree
    // is MOVED while open - leave those alone (the dialog heal's rule).
    let modal = false
    try {
      modal = this.mobileDialogTarget.matches(":modal")
    } catch {
      modal = false
    }
    if (modal) return

    this.mobileDialogTarget.close()
    setState(this.mobileDialogTarget, "closed")
    if (this.hasMobileInnerTarget && this.hasInnerTarget) {
      while (this.mobileInnerTarget.firstChild) this.innerTarget.appendChild(this.mobileInnerTarget.firstChild)
    }
    document.body.style.overflow = ""
    document.body.style.paddingRight = ""
  }

  // Shared refcounted lock with scrollbar-gutter compensation (the dialog
  // idiom) - the per-instance behavior keeps double-unlocks (before-cache
  // close, then disconnect) balanced.
  #lock() {
    this.#scrollLock?.lock()
  }

  #unlock() {
    this.#scrollLock?.unlock()
  }
}
