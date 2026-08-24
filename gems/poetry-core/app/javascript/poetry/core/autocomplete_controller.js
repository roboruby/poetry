import { Controller } from "@hotwired/stimulus"

// The Autocomplete (Base UI's Autocomplete, poetry-shaped): a REAL text
// input that IS the form value, suggesting from a server-rendered list
// that filters as you type. This is the input-is-the-value semantic -
// the sibling of Combobox, whose value is a SELECTED ITEM behind a
// native <select>. Selecting a suggestion writes the input and closes;
// the text always submits as ordinary params.
//
// Base UI behaviors kept (the v1.7 spec sheet): locale-aware filtering
// (toLocaleLowerCase), list scroll reset on every filter pass, and
// change-reason details on the commit event (item-press | enter-key).
// Positioning rides the shared popper controller (input = anchor).
const ITEM_SELECTOR = '[data-slot="autocomplete-item"]'
const EVENT_PREFIX = "poetry:autocomplete"

export default class AutocompleteController extends Controller {
  static events = ["poetry:autocomplete:commit", "poetry:autocomplete:open", "poetry:autocomplete:closed"]

  static targets = ["input", "content", "list", "empty"]

  static values = {
    open: { type: Boolean, default: false },
    // Open the popup on focus even before any typing (Base UI openOnInputClick).
    openOnFocus: { type: Boolean, default: true }
  }

  disconnect() {
    if (this.openValue) this.#close()
  }

  // --- input events --------------------------------------------------------

  input() {
    this.#filter()
    if (!this.openValue) this.#open()
  }

  focus() {
    if (this.openOnFocusValue && !this.openValue) {
      this.#filter()
      this.#open()
    }
  }

  blurred(event) {
    // Focus moving into the popup (a click on an item) must not close
    // before the click commits - the item's pointerdown commits first.
    if (event.relatedTarget instanceof Element && this.element.contains(event.relatedTarget)) return

    if (this.openValue) this.#close()
  }

  keydown(event) {
    if (event.isComposing || event.keyCode === 229) return

    switch (event.key) {
      case "ArrowDown":
      case "ArrowUp": {
        event.preventDefault()
        if (!this.openValue) return this.#open()

        this.#moveHighlight(event.key === "ArrowDown" ? 1 : -1)
        break
      }
      case "Enter": {
        const highlighted = this.#highlighted()
        if (!this.openValue || !highlighted) return

        event.preventDefault()
        this.#commit(highlighted, "enter-key")
        break
      }
      case "Escape": {
        if (!this.openValue) return

        event.preventDefault()
        event.stopPropagation() // consumed: this press closes; the next reaches the layer above
        this.#close()
        break
      }
      case "Tab": {
        if (this.openValue) this.#close()
        break
      }
    }
  }

  // Pointerdown (not click): commit BEFORE the input's blur closes the popup.
  itemPress(event) {
    const item = event.target.closest(ITEM_SELECTOR)
    if (!item || item.hasAttribute("data-disabled")) return

    event.preventDefault() // keep focus on the input
    this.#commit(item, "item-press")
  }

  itemEnter(event) {
    const item = event.target.closest(ITEM_SELECTOR)
    if (!item || item.hasAttribute("data-disabled")) return

    this.#setHighlight(item)
  }

  // --- internals -----------------------------------------------------------

  #items() {
    return [...this.listTarget.querySelectorAll(ITEM_SELECTOR)]
  }

  #visibleItems() {
    return this.#items().filter((item) => !item.hidden && !item.hasAttribute("data-disabled"))
  }

  #highlighted() {
    return this.#items().find((item) => item.hasAttribute("data-highlighted") && !item.hidden)
  }

  #filter() {
    const query = this.inputTarget.value.trim().toLocaleLowerCase()
    let any = false

    this.#items().forEach((item) => {
      const label = (item.dataset.label || item.textContent).trim().toLocaleLowerCase()
      const match = query === "" || label.includes(query)
      item.hidden = !match
      any ||= match
    })

    // Base UI resets the list scroll on every filter pass.
    this.listTarget.scrollTop = 0
    this.#syncEmpty(any)
    this.#clearHighlight()
  }

  #syncEmpty(any) {
    if (this.hasEmptyTarget) this.emptyTarget.hidden = any
    this.contentTarget.toggleAttribute("data-empty", !any)
  }

  #moveHighlight(direction) {
    const items = this.#visibleItems()
    if (items.length === 0) return

    const current = items.indexOf(this.#highlighted())
    const next = current === -1
      ? (direction > 0 ? 0 : items.length - 1)
      : (current + direction + items.length) % items.length
    this.#setHighlight(items[next])
  }

  #setHighlight(item) {
    this.#clearHighlight()
    item.setAttribute("data-highlighted", "")
    this.inputTarget.setAttribute("aria-activedescendant", item.id)
    item.scrollIntoView({ block: "nearest" })
  }

  #clearHighlight() {
    this.#items().forEach((item) => item.removeAttribute("data-highlighted"))
    this.inputTarget.removeAttribute("aria-activedescendant")
  }

  #commit(item, reason) {
    this.inputTarget.value = item.dataset.value ?? (item.dataset.label || item.textContent.trim())
    this.inputTarget.dispatchEvent(new Event("input", { bubbles: true }))
    this.inputTarget.dispatchEvent(new Event("change", { bubbles: true }))
    this.dispatch("commit", { prefix: EVENT_PREFIX, detail: { value: this.inputTarget.value, reason } })
    this.#close()
    this.inputTarget.focus()
  }

  #open() {
    this.openValue = true
    this.contentTarget.hidden = false
    this.contentTarget.setAttribute("data-open", "")
    this.contentTarget.removeAttribute("data-closed")
    this.inputTarget.setAttribute("aria-expanded", "true")
    this.dispatch("open", { prefix: EVENT_PREFIX })
  }

  #close() {
    this.openValue = false
    this.contentTarget.hidden = true
    this.contentTarget.removeAttribute("data-open")
    this.contentTarget.setAttribute("data-closed", "")
    this.inputTarget.setAttribute("aria-expanded", "false")
    this.#clearHighlight()
    this.dispatch("closed", { prefix: EVENT_PREFIX })
  }
}
