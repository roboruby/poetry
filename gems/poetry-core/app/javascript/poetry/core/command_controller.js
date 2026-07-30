import { Controller } from "@hotwired/stimulus"
import { collectionItems } from "@poetry/controllers/helpers/collection"
import { scoreItem } from "@poetry/controllers/helpers/filter_rank"

// The Command palette engine (Command) - the suite's
// first ACTIVEDESCENDANT component (the APG editable-combobox pattern, the
// deliberate delta vs the menus/Select family's roving focus): real DOM
// focus stays pinned to the input for the whole session; the highlighted
// option carries data-highlighted + its server-stable id in the input's
// aria-activedescendant (the twin-write, activedescendant-flavored).
// Options never get tabindex; roving-focus is NOT attached; aria-selected
// is NEVER written here (reserved for committed values - Combobox's
// twin-write; a bare palette has no committed value).
//
// THE FILTER is the deterministic helpers/filter_rank spec (prefix 4 >
// word-boundary 3 > substring 2 > keyword 1 > hidden 0, diacritic-folded)
// and it is HIDE-ONLY: score-0 items get hidden + data-hidden, matches get
// both removed, and children are NEVER reordered - DOM order is the
// ranking authority within a band; the score's only job is seating the
// auto-highlight. filter:false is the server-driven mode (cmdk
// shouldFilter parity): steps 1-2 (hiding) are skipped entirely and only
// highlight/activation/announcement run over whatever the server rendered
// - the Turbo-frame async seam Combobox's recipe plugs into.
//
// ACTIVATION IS AN EVENT, NOT AN ACTION: Enter/click dispatches cancelable
// poetry:command:select and this controller does nothing further - no
// navigation, no close, no value write. The listener (host data-action,
// Combobox's commit pipeline) owns the consequences - the engine-purity
// Combobox's composition depends on (no popper/commit/native-select code
// lives here, fenced by the conformance greps).
//
// The DOM is the store, filtering included: query in the input, visibility
// as hidden + data-hidden, highlight as data-highlighted +
// aria-activedescendant, group visibility derived - a Turbo Stream can
// append items mid-session and the next keystroke ranks them.
const INPUT_SELECTOR = '[data-slot="command-input"]'
const LIST_SELECTOR = '[data-slot="command-list"]'
const ITEM_SELECTOR = '[data-slot="command-item"]'
const ITEM_TEXT_SELECTOR = '[data-slot="command-item-text"]'
const GROUP_SELECTOR = '[data-slot="command-group"]'
const SEPARATOR_SELECTOR = '[data-slot="command-separator"]'
const EMPTY_SELECTOR = '[data-slot="command-empty"]'
const STATUS_SELECTOR = '[data-slot="command-status"]'

const EVENT_PREFIX = "poetry:command"

// The status live region is ALWAYS debounced (keystroke bursts announce
// once) - activedescendant says WHERE you are, the count says HOW MANY
// remain (the cmdk a11y gap this component closes).
const STATUS_DEBOUNCE = 100

export default class CommandController extends Controller {
  // The events this controller dispatches (manifest surface;
  // events_declaration.test.js enforces the list stays honest).
  static events = ["poetry:command:filter", "poetry:command:highlight", "poetry:command:select"]

  static values = {
    // false = SERVER-DRIVEN mode (cmdk shouldFilter=false): never hide -
    // the host re-renders the list (Turbo frame) and Command only runs
    // highlight/activation/announcement over what is rendered.
    filter: { type: Boolean, default: true },
    // Arrow-key wrap over visible enabled items (cmdk parity: false).
    loop: { type: Boolean, default: false },
    // Filter-pass debounce in ms (0 = synchronous - client filtering is
    // cheap string work; the status announcement is debounced separately).
    debounce: { type: Number, default: 0 }
  }

  #connected = false
  #passTimer = null
  #statusTimer = null
  #delegatedList = null

  connect() {
    // Reconcile-on-connect (Turbo morph/stream safe): a non-empty input
    // re-derives visibility + highlight silently (no events for state the
    // server already declared); an empty input just seats the highlight
    // (a server-rendered data-highlighted item wins, else first enabled).
    if ((this.#input()?.value ?? "") !== "") {
      this.#pass({ silent: true })
    } else {
      this.#seat({ silent: true })
    }

    // Portal delegation (docs/portal-on-open.md): Stimulus scopes
    // data-actions to the controller's subtree, so the per-item
    // activate/pointerHighlight actions go DEAD when the popup portals
    // out of it (Combobox multiple mounts this engine on the ROOT while
    // the listbox moves to body). The listeners ride the LIST node - they
    // travel with the portal; in-scope items remain the actions' job
    // (#delegatedItem guards the double-fire).
    const list = this.#list()

    if (list) {
      list.addEventListener("click", this.#onListClick)
      list.addEventListener("pointermove", this.#onListPointermove)
      this.#delegatedList = list
    }

    this.#connected = true
  }

  disconnect() {
    this.#connected = false

    if (this.#passTimer !== null) window.clearTimeout(this.#passTimer)
    if (this.#statusTimer !== null) window.clearTimeout(this.#statusTimer)

    this.#passTimer = null
    this.#statusTimer = null

    if (this.#delegatedList) {
      this.#delegatedList.removeEventListener("click", this.#onListClick)
      this.#delegatedList.removeEventListener("pointermove", this.#onListPointermove)
      this.#delegatedList = null
    }
  }

  #onListClick = (event) => {
    const item = this.#delegatedItem(event)

    if (item && !this.#isDisabled(item)) this.#activate(item)
  }

  #onListPointermove = (event) => {
    const item = this.#delegatedItem(event)

    if (item && !this.#isDisabled(item) && !this.#isHidden(item)) this.#highlight(item, { scroll: false })
  }

  #delegatedItem(event) {
    if (!(event.target instanceof Element)) return null
    // In-scope items are the Stimulus actions' job - delegation exists
    // only for items the portal moved OUT of this controller's subtree.
    if (this.element.contains(event.target)) return null

    return event.target.closest(ITEM_SELECTOR)
  }

  // --- the filter pass (input action) ---

  filterInput() {
    if (this.debounceValue <= 0) {
      this.#pass()
      return
    }

    if (this.#passTimer !== null) window.clearTimeout(this.#passTimer)

    this.#passTimer = window.setTimeout(() => {
      this.#passTimer = null
      this.#pass()
    }, this.debounceValue)
  }

  // --- the activedescendant keyboard map (input action) ---
  //
  // Home/End/ArrowLeft/ArrowRight fall through to the input (CARET
  // movement - APG-correct for an editable field; cmdk's Home/End
  // list-hijack is deliberately not ported; Meta/Ctrl+Arrows cover the
  // list jump). Space TYPES a space, never activates (a text field - the
  // family delta vs Select/menus). Esc/Tab are NOT handled - the hosting
  // layer owns them (Dialog dismiss / Combobox close / natural tab-out).
  keydown(event) {
    switch (event.key) {
      case "ArrowDown":
      case "ArrowUp": {
        event.preventDefault() // the caret never moves on vertical arrows

        const items = this.#navigableItems()

        if (items.length === 0) return

        const down = event.key === "ArrowDown"

        if (event.metaKey || event.ctrlKey) {
          // Meta/Ctrl+ArrowDown/Up jump last / first (cmdk parity).
          this.#highlight(items[down ? items.length - 1 : 0])
          return
        }

        const index = items.indexOf(this.#highlighted())
        let next

        if (index === -1) {
          next = down ? 0 : items.length - 1
        } else {
          next = index + (down ? 1 : -1)

          if (this.loopValue) next = (next + items.length) % items.length
          else next = Math.min(items.length - 1, Math.max(0, next))
        }

        this.#highlight(items[next])
        return
      }
      case "Enter": {
        event.preventDefault() // never submit a form through the palette input

        const item = this.#highlighted()

        if (item && !this.#isDisabled(item) && !this.#isHidden(item)) this.#activate(item)

        return
      }
      default:
        // Everything else - printable keys, Space, Backspace, Home/End,
        // Left/Right, Esc, Tab - belongs to the input or the host.
    }
  }

  // --- activation (item click action) ---

  activate(event) {
    const origin = event.currentTarget instanceof Element ? event.currentTarget : event.target
    const item = origin instanceof Element ? origin.closest(ITEM_SELECTOR) : null

    if (!item || this.#isDisabled(item)) return

    this.#activate(item)
  }

  // --- pointer highlight (item pointermove action) ---

  // Pointer parity with cmdk: hovering highlights (no scroll chasing);
  // pointerleave does NOT clear - the keyboard position survives mouse
  // exit (cmdk-exact).
  pointerHighlight(event) {
    const origin = event.currentTarget instanceof Element ? event.currentTarget : event.target
    const item = origin instanceof Element ? origin.closest(ITEM_SELECTOR) : null

    if (!item || this.#isDisabled(item) || this.#isHidden(item)) return

    this.#highlight(item, { scroll: false })
  }

  // --- the composition surface (engine-generic; Combobox calls these) ---

  // Move the highlight to a given option (visible + enabled required).
  highlightItem(item, { scroll = true } = {}) {
    if (!item || this.#isDisabled(item) || this.#isHidden(item)) return

    this.#highlight(item, { scroll })
  }

  // Clear the query and silently re-derive visibility + highlight (the
  // clean-reopen reset an overlay host runs on close).
  reset() {
    const input = this.#input()

    if (!input) return

    input.value = ""
    this.#pass({ silent: true })
  }

  // --- the pass ---

  // Synchronous, on every input event (and silently on connect/reset):
  // 1. score every collection item; client mode hides score-0 (unless
  //    data-always-render) via hidden + data-hidden - NEVER reorders.
  // 2. groups hide when ALL their items hide; separators hide whenever
  //    the query is non-empty (cmdk parity). Skipped in filter:false.
  // 3. re-seat the highlight: highest score among visible ∩ enabled,
  //    first-in-DOM tiebreak; zero visible clears both twin-writes and
  //    unhides the empty part.
  // 4. dispatch poetry:command:filter {query, visible}; debounce the
  //    status live-region count.
  #pass({ silent = false } = {}) {
    const input = this.#input()
    const list = this.#list()

    if (!input || !list) return

    const query = input.value ?? ""
    const items = this.#items(list)
    const scores = new Map()

    for (const item of items) {
      const score = scoreItem(item, query)

      scores.set(item, score)

      if (this.filterValue) {
        const hide = score === 0 && !item.hasAttribute("data-always-render")

        item.toggleAttribute("hidden", hide)
        item.toggleAttribute("data-hidden", hide)
      }
    }

    if (this.filterValue) {
      for (const group of list.querySelectorAll(GROUP_SELECTOR)) {
        const members = this.#items(group)
        const hide = !group.hasAttribute("data-always-render") &&
          members.every((item) => item.hasAttribute("data-hidden"))

        group.toggleAttribute("hidden", hide)
      }

      for (const separator of list.querySelectorAll(SEPARATOR_SELECTOR)) {
        separator.toggleAttribute("hidden", query !== "")
      }
    }

    const visibleItems = items.filter((item) => !this.#isHidden(item))
    const visible = visibleItems.length
    // List-scoped first: in Combobox's multiple mode this engine rides the
    // ROOT while portal-on-open moves the popup (list + empty + status) to
    // body - element scoping goes blind there; the list resolves by the
    // input's aria-controls id, and the parts around it hang off it.
    const empty = list.querySelector(EMPTY_SELECTOR) ?? this.element.querySelector(EMPTY_SELECTOR)

    if (empty) empty.hidden = visible !== 0

    // Re-seat: highest score among visible ∩ enabled, first-in-DOM
    // tiebreak (strictly-greater replacement preserves DOM order as the
    // within-band authority).
    let best = null
    let bestScore = -1

    for (const item of visibleItems) {
      if (this.#isDisabled(item)) continue

      const score = scores.get(item) ?? 0

      if (score > bestScore) {
        best = item
        bestScore = score
      }
    }

    if (best) this.#highlight(best, { silent })
    else this.#clearHighlight()

    if (silent) return

    this.dispatch("filter", { prefix: EVENT_PREFIX, detail: { query, visible } })
    this.#announce(visible)
  }

  // Initial seat (empty query): a server-rendered data-highlighted item
  // wins (the value: option), else the first visible enabled item; the
  // activedescendant twin is written either way.
  #seat({ silent = false } = {}) {
    const seeded = this.#highlighted()

    if (seeded && !this.#isDisabled(seeded) && !this.#isHidden(seeded)) {
      this.#highlight(seeded, { silent, force: true })
      return
    }

    const first = this.#navigableItems()[0]

    if (first) this.#highlight(first, { silent })
    else this.#clearHighlight()
  }

  // --- highlight (the twin-write: data-highlighted + activedescendant) ---

  #highlight(item, { silent = false, scroll = true, force = false } = {}) {
    const previous = this.#highlighted()

    if (previous === item && !force) return

    previous?.removeAttribute("data-highlighted")
    item.setAttribute("data-highlighted", "")
    this.#input()?.setAttribute("aria-activedescendant", item.id)
    if (scroll) item.scrollIntoView?.({ block: "nearest" })

    if (silent || previous === item) return

    this.dispatch("highlight", {
      prefix: EVENT_PREFIX,
      target: item,
      detail: { item, value: item.dataset.value ?? "" }
    })
  }

  #clearHighlight() {
    this.#highlighted()?.removeAttribute("data-highlighted")
    this.#input()?.removeAttribute("aria-activedescendant")
  }

  // --- activation ---

  // Cancelable select; NOT canceled -> Command does NOTHING FURTHER (no
  // navigation, no close, no value write) - a palette engine, not an actor.
  #activate(item) {
    this.dispatch("select", {
      prefix: EVENT_PREFIX,
      target: item,
      cancelable: true,
      detail: { item, value: item.dataset.value ?? "", label: this.#labelOf(item) }
    })
  }

  #labelOf(item) {
    return (item.querySelector(ITEM_TEXT_SELECTOR)?.textContent ?? item.textContent ?? "").trim()
  }

  // --- the status live region ---

  // Debounced result counts into the component-rendered polite region;
  // the localized templates ride data attributes on the region (data-zero
  // / data-one / data-other with a %{count} placeholder) so the engine
  // stays i18n-free.
  #announce(visible) {
    // Element scope first (the bare palette), then beside the resolved
    // list - Combobox multiple portals the popup (status included) out of
    // this engine's root subtree (docs/portal-on-open.md).
    const status = this.element.querySelector(STATUS_SELECTOR) ??
      this.#list()?.parentElement?.querySelector(STATUS_SELECTOR)

    if (!status) return

    if (this.#statusTimer !== null) window.clearTimeout(this.#statusTimer)

    this.#statusTimer = window.setTimeout(() => {
      this.#statusTimer = null

      const template = (visible === 0 && status.dataset.zero) ||
        (visible === 1 && status.dataset.one) ||
        status.dataset.other || "%{count} results"

      status.textContent = template.replace("%{count}", String(visible))
    }, STATUS_DEBOUNCE)
  }

  // --- structural resolution (data-slots, portal/stream-safe) ---

  #input() {
    return this.element.querySelector(INPUT_SELECTOR)
  }

  #list() {
    const id = this.#input()?.getAttribute("aria-controls")

    return (id && document.getElementById(id)) || this.element.querySelector(LIST_SELECTOR)
  }

  #items(root = this.#list()) {
    return root ? collectionItems(root, ITEM_SELECTOR) : []
  }

  #navigableItems() {
    return this.#items().filter((item) => !this.#isHidden(item) && !this.#isDisabled(item))
  }

  #highlighted() {
    return this.#list()?.querySelector("[data-highlighted]") ?? null
  }

  #isDisabled(item) {
    return item.hasAttribute("data-disabled") || item.getAttribute("aria-disabled") === "true"
  }

  // An item is hidden when itself or any ancestor (its group, a
  // server-hidden frame) carries the hidden attribute.
  #isHidden(item) {
    return item.closest("[hidden]") !== null
  }
}
