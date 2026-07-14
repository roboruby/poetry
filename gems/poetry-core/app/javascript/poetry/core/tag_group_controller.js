import { Controller } from "@hotwired/stimulus"

// The TagGroup removal engine (the react-aria tag contract):
// navigation itself rides the roving-focus controller (the toolbar
// precedent) - this controller owns what tags add on top:
//
// - Delete/Backspace on a focused tag removes it (row-origin keys only;
//   keys from a tag's inner remove button must not drive the grid).
// - The remove button removes exactly its own tag.
// - Focus recovery after removal is the react-aria walk: FORWARD through
//   the pre-removal order to the first surviving enabled tag, then
//   backward; when the last tag goes, the CONTAINER takes focus, flips
//   role grid->group, and becomes the tab stop.
// - The container is a live region ONLY while focus is within (polite,
//   additions) - SRs hear tags added while working in the group without
//   spam from elsewhere.
//
// Removal is CANCELABLE (poetry:tag-group:remove): a Turbo-driven host
// preventDefault()s and re-renders; otherwise this controller removes the
// row (and the hidden input riding it - form mode serializes name[] per
// tag).
const EVENT_PREFIX = "poetry:tag-group"

export default class TagGroupController extends Controller {
  // The events this controller dispatches (manifest surface;
  // events_declaration.test.js enforces the list stays honest).
  static events = ["poetry:tag-group:remove"]

  #onFocusin = () => this.element.setAttribute("aria-live", "polite")
  #onFocusout = (event) => {
    if (this.element.contains(event.relatedTarget)) return

    this.element.setAttribute("aria-live", "off")
  }

  connect() {
    this.element.addEventListener("focusin", this.#onFocusin)
    this.element.addEventListener("focusout", this.#onFocusout)
    this.#reflectEmpty()
  }

  disconnect() {
    this.element.removeEventListener("focusin", this.#onFocusin)
    this.element.removeEventListener("focusout", this.#onFocusout)
  }

  // keydown, wired as a data-action on the container.
  keydown(event) {
    if (event.key !== "Delete" && event.key !== "Backspace") return

    const row = event.target.closest("[data-slot='tag-group-tag']")

    // Row-origin only: the remove button's own keys stay its own.
    if (!row || event.target !== row) return
    if (row.hasAttribute("data-disabled")) return

    event.preventDefault()
    this.#remove(row)
  }

  // click on a tag's remove button (data-action on the button).
  remove(event) {
    event.preventDefault()
    const row = event.target.closest("[data-slot='tag-group-tag']")

    if (!row || row.hasAttribute("data-disabled")) return

    this.#remove(row)
  }

  #remove(row) {
    const removal = this.dispatch("remove", {
      prefix: EVENT_PREFIX,
      detail: { value: row.getAttribute("data-value"), id: row.id },
      cancelable: true
    })

    if (removal.defaultPrevented) return // the host re-renders instead

    const target = this.#recoveryTarget(row)

    row.remove()
    this.#reflectEmpty()

    if (target) {
      target.setAttribute("tabindex", "0")
      target.focus()
    } else if (this.element.contains(document.activeElement) ||
               document.activeElement === document.body) {
      this.element.focus()
    }
  }

  // The react-aria walk, in pre-removal DOM order: forward to the first
  // surviving enabled tag, then backward.
  #recoveryTarget(row) {
    const rows = this.#rows()
    const index = rows.indexOf(row)
    const enabled = (candidate) => candidate !== row && !candidate.hasAttribute("data-disabled")

    return rows.slice(index + 1).find(enabled) ??
      rows.slice(0, index).reverse().find(enabled) ??
      null
  }

  #reflectEmpty() {
    const empty = this.#rows().length === 0

    this.element.toggleAttribute("data-empty", empty)
    this.element.setAttribute("role", empty ? "group" : "grid")

    if (empty) this.element.setAttribute("tabindex", "0")
    else this.element.removeAttribute("tabindex")
  }

  #rows() {
    return Array.from(this.element.querySelectorAll("[data-slot='tag-group-tag']"))
  }
}
