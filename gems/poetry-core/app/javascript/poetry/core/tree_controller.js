import { Controller } from "@hotwired/stimulus"
import { directionOf } from "@poetry/controllers/helpers/direction"
import { createTypeahead, typeaheadLabel } from "@poetry/controllers/helpers/typeahead"

// The Tree engine (the flat-treegrid contract): the
// server renders a FLAT list of role=row siblings - hierarchy lives
// entirely in aria-level/posinset/setsize (static per render) - so this
// controller owns only what HTML cannot: roving focus over VISIBLE rows,
// the four-branch ArrowLeft/Right expansion logic (including
// focus-to-parent), Enter-toggles-expandable (the no-action default),
// typeahead, and subtree show/hide that preserves nested collapsed state
// (a row is visible iff every ancestor is expanded).
//
// Expansion state IS the DOM (aria-expanded + hidden); the host persists
// it by listening for poetry:tree:toggle. Selection modes are deferred
// (the TagGroup reasoning).
const EVENT_PREFIX = "poetry:tree"

export default class TreeController extends Controller {
  // The events this controller dispatches (manifest surface;
  // events_declaration.test.js enforces the list stays honest).
  static events = ["poetry:tree:toggle"]

  #typeahead = createTypeahead()

  connect() {
    this.#applyVisibility()
    this.#settleTabstop()
  }

  // keydown, wired as a data-action on the treegrid container.
  keydown(event) {
    const row = event.target.closest("[data-slot='tree-item']")

    // Row-origin keys only (a control inside a row keeps its own keys).
    if (!row || event.target !== row) return
    if (event.isComposing) return

    const [expandKey, collapseKey] =
      directionOf(row) === "rtl" ? ["ArrowLeft", "ArrowRight"] : ["ArrowRight", "ArrowLeft"]

    switch (event.key) {
      case "ArrowDown": event.preventDefault(); this.#move(row, 1); break
      case "ArrowUp": event.preventDefault(); this.#move(row, -1); break
      case "Home": event.preventDefault(); this.#focusRow(this.#visibleRows()[0]); break
      case "End": event.preventDefault(); this.#focusRow(this.#visibleRows().at(-1)); break
      case expandKey: this.#expandKey(event, row); break
      case collapseKey: this.#collapseKey(event, row); break
      case "Enter": this.#enterKey(event, row); break
      case " ": if (this.#typeahead.pending()) { event.preventDefault(); this.#search(" ", row) } break
      default: this.#maybeTypeahead(event, row)
    }
  }

  // click on a row toggles when expandable (the default press
  // behavior with no action/link/selection); clicks on inner controls
  // (links, the chevron) stay their own.
  press(event) {
    const row = event.target.closest("[data-slot='tree-item']")

    if (!row || row.hasAttribute("data-disabled")) return
    if (event.target.closest("a, button, input, select, textarea")) return
    if (!this.#expandable(row)) return

    this.#toggle(row)
  }

  // click on a chevron (tabindex -1; its pointerdown is preventDefault'd
  // via the pressStart action so focus never leaves the row).
  toggle(event) {
    event.preventDefault()
    event.stopPropagation()
    const row = event.target.closest("[data-slot='tree-item']")

    if (!row || row.hasAttribute("data-disabled")) return

    this.#toggle(row)
    this.#focusRow(row)
  }

  // pointerdown on the chevron: never steal focus from the row.
  pressStart(event) {
    event.preventDefault()
  }

  // --- expansion ---

  #expandKey(event, row) {
    if (!this.#expandable(row)) return

    if (row.getAttribute("aria-expanded") === "false") {
      event.preventDefault()
      this.#toggle(row)
    }
    // Expanded parent / leaf: no-op v1 (focus-into-row-children deferred).
  }

  #collapseKey(event, row) {
    if (this.#expandable(row) && row.getAttribute("aria-expanded") === "true") {
      event.preventDefault()
      this.#toggle(row)
      return
    }

    // Leaf or collapsed: focus the PARENT row (the nearest preceding row
    // with a smaller level).
    const parent = this.#parentOf(row)

    if (parent) {
      event.preventDefault()
      this.#focusRow(parent)
    }
  }

  #enterKey(event, row) {
    if (row.hasAttribute("data-disabled") || !this.#expandable(row)) return

    event.preventDefault()
    this.#toggle(row)
  }

  #toggle(row) {
    const expanded = row.getAttribute("aria-expanded") !== "true"

    row.setAttribute("aria-expanded", String(expanded))
    row.toggleAttribute("data-expanded", expanded)

    // The chevron's name flips with the state (Expand/Collapse; the
    // strings arrive server-localized as data attributes).
    const chevron = row.querySelector("[data-slot='tree-item-toggle']")
    const label = chevron?.getAttribute(expanded ? "data-collapse-label" : "data-expand-label")

    if (chevron && label) chevron.setAttribute("aria-label", label)

    this.#applyVisibility()

    this.dispatch("toggle", {
      prefix: EVENT_PREFIX,
      detail: { id: row.id, value: row.getAttribute("data-value"), expanded }
    })
  }

  // A row is visible iff EVERY ancestor is expanded: walk the flat list
  // tracking the shallowest collapsed level - rows deeper than it hide.
  #applyVisibility() {
    let hideBelow = Infinity

    for (const row of this.#rows()) {
      const level = this.#levelOf(row)

      if (level > hideBelow) {
        row.hidden = true
        continue
      }

      row.hidden = false
      hideBelow = this.#expandable(row) && row.getAttribute("aria-expanded") !== "true"
        ? level
        : Infinity
    }

    this.#settleTabstop()
  }

  // --- roving focus over visible rows ---

  #move(row, direction) {
    const rows = this.#visibleRows()
    const next = rows[rows.indexOf(row) + direction]

    this.#focusRow(next)
  }

  #focusRow(row) {
    if (!row) return

    for (const candidate of this.#rows()) {
      candidate.setAttribute("tabindex", candidate === row ? "0" : "-1")
    }

    row.focus()
  }

  // Exactly one visible row keeps tabindex 0 (the focused one if it is
  // still visible, else the first visible row).
  #settleTabstop() {
    const rows = this.#visibleRows()

    if (rows.length === 0) return

    const current = rows.find((row) => row.getAttribute("tabindex") === "0") ?? rows[0]

    for (const row of this.#rows()) {
      row.setAttribute("tabindex", row === current ? "0" : "-1")
    }
  }

  #maybeTypeahead(event, row) {
    if (event.key.length !== 1 || event.metaKey || event.ctrlKey || event.altKey) return

    event.preventDefault()
    this.#search(event.key, row)
  }

  #search(key, row) {
    const rows = this.#visibleRows().filter((candidate) => !candidate.hasAttribute("data-disabled"))
    const match = this.#typeahead.search(key, rows, { active: row, labelOf: typeaheadLabel })

    if (match) this.#focusRow(match)
  }

  // --- the flat-row math ---

  #rows() {
    return Array.from(this.element.querySelectorAll("[data-slot='tree-item']"))
  }

  #visibleRows() {
    return this.#rows().filter((row) => !row.hidden)
  }

  #levelOf(row) {
    return Number(row.getAttribute("aria-level")) || 1
  }

  #expandable(row) {
    return row.hasAttribute("aria-expanded")
  }

  #parentOf(row) {
    const rows = this.#rows()
    const level = this.#levelOf(row)

    for (let index = rows.indexOf(row) - 1; index >= 0; index -= 1) {
      if (this.#levelOf(rows[index]) < level) return rows[index]
    }

    return null
  }
}
