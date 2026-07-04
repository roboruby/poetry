import { Controller } from "@hotwired/stimulus"
import { collectionItems } from "@poetry/controllers/helpers/collection"
import { enterPresence, exitPresence } from "@poetry/controllers/helpers/presence"
import { setState, stateOf } from "@poetry/controllers/helpers/state"

// The Combobox ORCHESTRATOR (Combobox): Select's shell
// x Command's engine, composed VIA THE EVENT CONTRACT ONLY - this thin
// controller owns open/close + the commit pipeline + autofill adoption and
// listens for the embedded engine's poetry:command:select; it contains NO
// filter/highlight/scoring code (Command owns those) and Command gained no
// combobox code (engine purity, fenced both directions by the conformance
// greps). Zero code is shared with SelectController - the PATTERNS are
// (the layer mechanism, the native-first 5-step pipeline, the adoption
// path), re-instantiated here because a facade extraction was explicitly
// declined (the Select contract's open question, answered by this build).
//
// THE THREE DELIBERATE DELTAS vs Select, each pinned by tests so neither
// sibling's rules leak:
// - open focuses the COMMAND INPUT for every reason (a combobox session is
//   a TYPING session - APG editable combobox); the selected option gets the
//   HIGHLIGHT (activedescendant, via the Command controller) + scroll, not
//   DOM focus;
// - Tab while open CLOSES WITHOUT COMMIT and lets focus proceed (Popover
//   semantics, modal:false default; modal:true restores the trap) - Select
//   is Tab-inert;
// - a printable key on the CLOSED trigger OPENS and SEEDS the filter
//   (typing filters, never blind-commits) - Select's closed-trigger
//   typeahead-commit does NOT port.
//
// TWO MEANINGS, TWO ATTRIBUTES, ONE LIST: data-highlighted +
// aria-activedescendant = position (Command's, never aria-selected);
// aria-selected + data-selected + the indicator = the COMMITTED value
// (Select's twin-write, written only here, in the pipeline).
//
// THE SYNC INVARIANT (Select's, inherited): native_select.value, the value
// Value, the twin-write, and the display never diverge - every write path
// funnels through #apply, NATIVE FIRST (serialization truth is never
// behind the facade), with real bubbling change/input on the native so
// Turbo auto-submit and form listeners work unmodified.
const TRIGGER_SELECTOR = '[data-slot="combobox-trigger"]'
const NATIVE_SELECTOR = '[data-slot="combobox-native"]'
const VALUE_SELECTOR = '[data-slot="combobox-value"]'
const CONTENT_SELECTOR = '[data-slot="combobox-content"]'
const COMMAND_SELECTOR = '[data-slot="command"]'
const INPUT_SELECTOR = '[data-slot="command-input"]'
const ITEM_SELECTOR = '[data-slot="command-item"]'
const ITEM_TEXT_SELECTOR = '[data-slot="command-item-text"]'

const EVENT_PREFIX = "poetry:combobox"
const COMMAND_IDENTIFIER = "poetry--core--command"

// NO roving-focus (the popup is Command's activedescendant session - the
// family's first popup without it).
const CONTENT_LAYER_CONTROLLERS = ["poetry--core--focus-scope", "poetry--core--dismissable"]

export default class ComboboxController extends Controller {
  static values = {
    open: { type: Boolean, default: false },
    value: { type: String, default: "" },
    // DEFAULT FALSE - Popover semantics (Tab-out closes, no scrim); true
    // restores the focus-scope trap for dialog-critical pickers.
    modal: { type: Boolean, default: false }
  }

  #connected = false
  #wired = []
  #suppressRestore = false
  #cancelExit = null
  #applied = ""
  #placeholder = ""

  connect() {
    const content = this.#content()

    if (content) this.#wireContent(content)

    const display = this.#display()

    this.#placeholder = display?.dataset.placeholder ??
      (this.#trigger()?.hasAttribute("data-placeholder") ? (display?.textContent ?? "").trim() : "")

    // Reconcile-on-connect (Turbo Stream re-render safe): the native select
    // is the serialization truth (Select-exact).
    const serverValue = this.valueValue !== "" ? this.valueValue : (this.#native()?.value ?? "")

    this.#applied = serverValue
    this.#apply(serverValue, { silent: true, force: true })

    this.#connected = true

    if (this.#isOpen()) {
      if (content) this.#activateLayers(content)
      this.openValue = true
    } else if (this.openValue) {
      this.#show("trigger-press")
    }
  }

  disconnect() {
    this.#connected = false

    for (const [target, type, listener] of this.#wired) target.removeEventListener(type, listener)

    this.#wired = []
    this.#cancelExit?.()
    this.#cancelExit = null
  }

  // --- controllable state ---

  openValueChanged(value) {
    if (!this.#connected) return

    if (value && !this.#isOpen()) this.#show("trigger-press")
    else if (!value && this.#isOpen()) this.#hide("none")
  }

  valueValueChanged(value) {
    if (!this.#connected || value === this.#applied) return

    this.#apply(value)
  }

  // --- trigger actions ---

  toggle() {
    if (this.#isOpen()) this.#hide("trigger-press")
    else this.#show("trigger-press")
  }

  // Enter / Space / ArrowDown / ArrowUp open (reason: list-navigation). A
  // PRINTABLE key opens AND seeds the filter input with the char (reason:
  // keyboard + the char as data-open-seed, a poetry extension - the char is
  // never lost, the filter pass runs immediately).
  // There is deliberately NO closed-trigger typeahead-commit here.
  triggerKeydown(event) {
    if (this.#isOpen()) return

    if (event.key === "Enter" || event.key === " " || event.key === "ArrowDown" || event.key === "ArrowUp") {
      event.preventDefault()
      this.#show("list-navigation")
      return
    }

    if (event.key.length === 1 && !event.ctrlKey && !event.altKey && !event.metaKey) {
      event.preventDefault()
      this.#show("keyboard", { seed: event.key })
    }
  }

  // --- programmatic API ---

  open(reason = "trigger-press", { seed = "" } = {}) {
    if (reason instanceof Event) this.#show("trigger-press")
    else this.#show(reason, { seed })
  }

  close(reason = "none") {
    this.#hide(reason instanceof Event ? "none" : reason)
  }

  setValue(value) {
    if (value === this.#applied) return

    this.#apply(String(value ?? ""))
  }

  // --- autofill adoption (Select's path verbatim) ---

  nativeChanged() {
    const value = this.#native()?.value ?? ""

    if (value === this.#applied) return

    this.#apply(value, { fromNative: true })
  }

  // --- open / close ---

  #show(reason, { seed = "" } = {}) {
    const content = this.#content()

    if (!content || this.#isOpen()) return

    this.#cancelExit?.()
    this.#cancelExit = null
    this.#suppressRestore = false

    const trigger = this.#trigger()

    content.hidden = false
    content.setAttribute("data-open-reason", reason)
    if (seed) content.setAttribute("data-open-seed", seed)
    else content.removeAttribute("data-open-seed")
    trigger?.setAttribute("aria-expanded", "true")
    if (trigger) setState(trigger, "popup-open")
    enterPresence(content)
    this.#activateLayers(content)
    this.openValue = true

    // Layer controllers connect on the attribute-mutation microtask; focus
    // rides one behind so focus-scope has snapshotted the trigger.
    queueMicrotask(() => {
      if (!this.#isOpen()) return

      const input = this.#input()

      // FOCUS GOES TO THE INPUT for every reason (the typing-session call);
      // the selected option is communicated by highlight, not focus.
      input?.focus()

      if (seed && input) {
        input.value = seed
        // The engine's own action runs the pass (and re-seats highlight).
        input.dispatchEvent(new Event("input", { bubbles: true }))
      } else {
        // Seed the highlight on the COMMITTED option via the Command
        // controller (activedescendant + scrollIntoView) - first enabled
        // when no value (the engine cannot seat while the popup was
        // hidden, so the shell seeds every open).
        const items = this.#items()
        const target = items.find((item) => item.getAttribute("aria-selected") === "true") ??
          items.find((item) => !item.hasAttribute("data-disabled") && !item.closest("[hidden]"))

        if (target) this.#command()?.highlightItem(target)
      }

      this.dispatch("open", { prefix: EVENT_PREFIX, detail: seed ? { reason, seed } : { reason } })
    })
  }

  #hide(reason, { restoreFocus = true } = {}) {
    const content = this.#content()

    if (!content || !this.#isOpen()) return

    this.#suppressRestore = !restoreFocus || (reason === "outside-press" && !this.modalValue)

    const trigger = this.#trigger()

    trigger?.setAttribute("aria-expanded", "false")
    if (trigger) setState(trigger, "popup-closed")
    content.removeAttribute("data-open-reason")
    content.removeAttribute("data-open-seed")
    this.openValue = false

    this.#cancelExit = exitPresence(content, {
      onRemove: () => {
        this.#cancelExit = null
        content.hidden = true
        this.#removeControllers(content, CONTENT_LAYER_CONTROLLERS)
        // Reset the query so reopen starts clean (the React demo got this
        // from remounting; persistent DOM does it deliberately).
        this.#command()?.reset()
        this.dispatch("closed", { prefix: EVENT_PREFIX, detail: { reason } })
      }
    })
  }

  // --- the commit pipeline ---

  // Command's select event is the ONLY commit trigger (no click handling
  // here - the composition boundary). Cancelable BEFORE the value commits;
  // vetoing keeps the popup open. Committing the already-selected value is
  // IDEMPOTENT: close, value unchanged, no change events (deselection is a
  // form affordance - include_blank - not a hidden toggle gesture).
  #onCommandSelect = (event) => {
    const { item, value = "", label = "" } = event.detail ?? {}

    const select = this.dispatch("select", {
      prefix: EVENT_PREFIX,
      target: item instanceof Element ? item : this.element,
      cancelable: true,
      detail: { item, value, label }
    })

    if (select.defaultPrevented) return

    if (value !== this.#applied) this.#apply(value)

    this.#hide("item-press")
  }

  // THE single sync path, NATIVE FIRST (Select's 5 steps re-instantiated):
  // 1. native_select.value + real bubbling change/input; 2. aria-selected
  // + data-selected twin-flipped on every option; 3+4. display synced from
  // the option's item-text (data-text-value override) + the trigger's
  // data-placeholder; 5. poetry:combobox:change.
  #apply(value, { silent = false, fromNative = false, force = false } = {}) {
    if (!force && value === this.#applied) return

    const previous = this.#applied

    this.#applied = value
    this.valueValue = value

    const native = this.#native()

    if (native && !fromNative) {
      native.value = value

      if (!silent) {
        native.dispatchEvent(new Event("input", { bubbles: true }))
        native.dispatchEvent(new Event("change", { bubbles: true }))
      }
    }

    let selected = null

    for (const item of this.#items()) {
      const match = value !== "" && (item.dataset.value ?? "") === value

      item.setAttribute("aria-selected", String(match))
      setState(item, match ? "selected" : "unselected")

      if (match) selected = item
    }

    const display = this.#display()
    const label = selected ? this.#labelOf(selected) : null

    if (display) display.textContent = label ?? this.#placeholder

    this.#trigger()?.toggleAttribute("data-placeholder", !selected)

    if (!silent) {
      this.dispatch("change", { prefix: EVENT_PREFIX, detail: { value, label, previous } })
    }
  }

  #labelOf(item) {
    return (item.dataset.textValue ??
      item.querySelector(ITEM_TEXT_SELECTOR)?.textContent ??
      item.textContent ?? "").trim()
  }

  // --- content wiring (programmatic: portal-safe) ---

  #wireContent(content) {
    this.#listen(content, "keydown", this.#onKeydown)
    this.#listen(content, "poetry:command:select", this.#onCommandSelect)
    this.#listen(content, "poetry--core--dismissable:dismiss", this.#onDismiss)
    this.#listen(content, "poetry--core--focus-scope:mount-auto-focus", this.#onMountAutoFocus)
    this.#listen(content, "poetry--core--focus-scope:unmount-auto-focus", this.#onUnmountAutoFocus)
  }

  #listen(target, type, listener) {
    target.addEventListener(type, listener)
    this.#wired.push([target, type, listener])
  }

  // Tab while open CLOSES WITHOUT COMMIT and lets focus proceed (Popover
  // semantics - THE delta vs Select's Tab-inert). modal:true leaves Tab to
  // the focus-scope trap instead. Everything else inside the popup is
  // Command's activedescendant map - no second keyboard map lives here.
  #onKeydown = (event) => {
    if (event.key !== "Tab" || this.modalValue || !this.#isOpen()) return

    this.#hide("focus-out", { restoreFocus: false })
  }

  // Esc / outside press arrive as the dismissable layer's dismiss event.
  // Neither EVER commits - the value is untouched (family rule).
  #onDismiss = (event) => {
    if (event.target !== this.#content()) return

    const escaped = event.detail?.originalEvent?.type === "keydown"

    this.#hide(escaped ? "escape-key" : "outside-press")
  }

  // The combobox owns initial focus (the command input), not focus-scope.
  #onMountAutoFocus = (event) => {
    if (event.target === this.#content()) event.preventDefault()
  }

  #onUnmountAutoFocus = (event) => {
    if (event.target === this.#content() && this.#suppressRestore) event.preventDefault()
  }

  // --- the layer stack (Select's proven mechanism, MINUS roving-focus) ---

  #activateLayers(content) {
    content.setAttribute("data-poetry--core--focus-scope-trapped-value", String(this.modalValue))
    // Non-modal Tab must DEPART (closing the popup - the Select delta);
    // focus-scope's edge-loop default would swallow it. modal:true keeps
    // the trap+loop pair.
    content.setAttribute("data-poetry--core--focus-scope-loop-value", String(this.modalValue))
    content.setAttribute(
      "data-poetry--core--dismissable-disable-outside-pointer-events-value", String(this.modalValue)
    )

    this.#addControllers(content, CONTENT_LAYER_CONTROLLERS)
  }

  #addControllers(element, identifiers) {
    const tokens = (element.getAttribute("data-controller") ?? "").split(/\s+/).filter(Boolean)

    for (const identifier of identifiers) {
      if (!tokens.includes(identifier)) tokens.push(identifier)
    }

    element.setAttribute("data-controller", tokens.join(" "))
  }

  #removeControllers(element, identifiers) {
    const tokens = (element.getAttribute("data-controller") ?? "")
      .split(/\s+/)
      .filter((token) => token && !identifiers.includes(token))

    element.setAttribute("data-controller", tokens.join(" "))
  }

  // --- structural resolution (ids are the seams; portal/stream-safe) ---

  #trigger() {
    return this.element.querySelector(TRIGGER_SELECTOR)
  }

  // The trigger's aria-controls points at the LISTBOX (the a11y-true
  // relationship); the popup container is its closest content wrapper.
  #listbox() {
    const id = this.#trigger()?.getAttribute("aria-controls")

    return id ? document.getElementById(id) : null
  }

  #content() {
    return this.#listbox()?.closest(CONTENT_SELECTOR) ??
      this.element.querySelector(CONTENT_SELECTOR)
  }

  #command() {
    const root = this.#content()?.querySelector(COMMAND_SELECTOR)

    return root
      ? this.application.getControllerForElementAndIdentifier(root, COMMAND_IDENTIFIER)
      : null
  }

  #input() {
    return this.#content()?.querySelector(INPUT_SELECTOR) ?? null
  }

  #native() {
    return this.element.querySelector(NATIVE_SELECTOR)
  }

  #display() {
    return this.element.querySelector(VALUE_SELECTOR)
  }

  #isOpen() {
    const content = this.#content()

    return Boolean(content) && stateOf(content) === "open"
  }

  #items() {
    const listbox = this.#listbox() ?? this.#content()

    return listbox ? collectionItems(listbox, ITEM_SELECTOR) : []
  }
}
