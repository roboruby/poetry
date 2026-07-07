import { Controller } from "@hotwired/stimulus"
import { COLLECTION_ITEM_SELECTOR, collectionItems } from "@poetry/controllers/helpers/collection"
import { directionOf } from "@poetry/controllers/helpers/direction"

// The roving-tabindex engine (Tier 2, P1): the group is ONE Tab stop -
// exactly one item holds tabindex=0, the rest -1, and arrow keys move focus
// among the collection items in DOM order. Orientation gates which arrows
// are live (horizontal flips Left/Right under RTL via the direction
// helper); Home/End jump to the edges; loop wraps. Backs Tabs, Toolbar,
// RadioGroup, Menus, ToggleGroup, and the Select/Command list.
//
// Dynamic items: NAVIGATION recomputes the collection on every keydown (the
// DOM is the registry - always fresh, zero bookkeeping), but that alone is
// not correct: an item appended between keystrokes would sit at its natural
// tabindex and grow the group a SECOND Tab stop before any arrow is
// pressed. The MutationObserver exists for that one job - re-stamping the
// roving tabindex the moment items enter or leave.
export default class RovingFocusController extends Controller {
  // The events this controller dispatches (manifest surface;
  // events_declaration.test.js enforces the list stays honest).
  static events = ["poetry--core--roving-focus:entry"]

  static values = {
    orientation: { type: String, default: "vertical" }, // horizontal | vertical | both
    loop: { type: Boolean, default: true },
    // false = focus-nav-only mode (the APG accordion contract): every
    // trigger stays tabbable and arrows are convenience navigation, not a
    // roving tab stop. The controller then NEVER writes tabindex - not on
    // connect, not on mutation, not on focus moves.
    manageTabindex: { type: Boolean, default: true }
  }

  #observer = null

  connect() {
    this.#syncItems()

    this.#observer = new MutationObserver(() => this.#syncItems())
    this.#observer.observe(this.element, { childList: true, subtree: true })
  }

  disconnect() {
    this.#observer?.disconnect()
    this.#observer = null
  }

  // Action: keydown->poetry--core--roving-focus#keydown on the group root.
  keydown(event) {
    if (event.defaultPrevented) return // a nested group (an open menu level) already moved focus

    const items = this.#items()

    if (items.length === 0) return

    const nextIndex = this.#nextIndex(event.key, this.#indexFor(event.target, items), items.length)

    if (nextIndex === null) return

    event.preventDefault() // a handled arrow must not also scroll the page
    this.#focusItem(items[nextIndex], items)
  }

  // The group's OWN items only: a hidden subtree (a closed submenu level) is
  // not navigable, data-disabled items are filtered at query time (the menu
  // contract), and an item claimed by a DESCENDANT roving group (an open
  // submenu's content) roves there, not here - nested groups self-scope
  // without any registration bookkeeping (the DOM is the registry).
  #items() {
    return collectionItems(this.element).filter((item) => this.#owns(item))
  }

  #owns(item) {
    if (item.closest("[hidden]")) return false
    if (item.hasAttribute("data-disabled")) return false

    const scope = item.parentElement?.closest(`[data-controller~="${this.identifier}"]`)

    return !scope || scope === this.element
  }

  #indexFor(target, items) {
    const item = target instanceof Element ? target.closest(COLLECTION_ITEM_SELECTOR) : null
    const index = items.indexOf(item)

    if (index !== -1) return index

    // Keydown from the group itself (entry): start from the current tab stop.
    return Math.max(this.#currentIndex(items), 0)
  }

  #currentIndex(items) {
    return items.findIndex((item) => item.getAttribute("tabindex") === "0")
  }

  #nextIndex(key, index, count) {
    if (key === "Home") return 0
    if (key === "End") return count - 1

    const delta = this.#arrowDelta(key)

    if (delta === null) return null

    const next = index + delta

    if (this.loopValue) return (next + count) % count

    return Math.min(Math.max(next, 0), count - 1) // no loop: the edges clamp
  }

  // Orientation gates the axis; the cross-axis arrows fall through untouched
  // (a vertical menu must not swallow Left/Right). "both" activates all four
  // arrows (the APG radio contract - Radix RadioGroup passes orientation
  // undefined so RovingFocusGroup lives on both axes): Down/Right advance,
  // Up/Left retreat, with ONLY the horizontal pair RTL-flipped. RTL is read
  // per keystroke from the closest [dir] ancestor, so a dir flip needs no
  // reconnect.
  #arrowDelta(key) {
    const axis = this.orientationValue

    if (axis !== "vertical" && (key === "ArrowRight" || key === "ArrowLeft")) {
      const rtl = directionOf(this.element) === "rtl"

      if (key === "ArrowRight") return rtl ? -1 : 1

      return rtl ? 1 : -1
    }

    if (axis !== "horizontal") {
      if (key === "ArrowDown") return 1
      if (key === "ArrowUp") return -1
    }

    return null
  }

  // Cancelable entry: a consumer preventDefault()s to keep focus where it is
  // (Radix's onEntryFocus). The tab stop only moves when focus actually does.
  #focusItem(item, items = this.#items()) {
    const entry = this.dispatch("entry", { detail: { item }, cancelable: true })

    if (entry.defaultPrevented) return

    this.#writeTabStops(items, item)
    item.focus()
  }

  // One 0, rest -1. The current stop survives re-syncs; if it was removed
  // (or never existed - fresh connect), the first item takes it.
  #syncItems() {
    const items = this.#items()

    this.element.dataset.orientation = this.orientationValue

    const currentIndex = this.#currentIndex(items)
    this.#writeTabStops(items, items[Math.max(currentIndex, 0)])
  }

  #writeTabStops(items, current) {
    for (const item of items) {
      if (this.manageTabindexValue) item.setAttribute("tabindex", item === current ? "0" : "-1")

      item.dataset.orientation = this.orientationValue
    }
  }
}
