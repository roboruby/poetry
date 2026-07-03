import { Controller } from "@hotwired/stimulus"
import { collectionItems } from "@poetry/controllers/helpers/collection"
import { enterPresence, exitPresence } from "@poetry/controllers/helpers/presence"
import { setState, stateOf } from "@poetry/controllers/helpers/state"
import { createTypeahead, typeaheadLabel } from "@poetry/controllers/helpers/typeahead"

// The Select listbox controller - the APG select-only combobox on the menus
// MACHINERY (popper markup-owned + focus-scope/dismissable/roving-focus
// activated as layers + the shared typeahead helper) but deliberately NOT a
// mode of poetry--core--menu: everything menu-specific (submenus,
// close_on_select, checkbox/radio aria-checked, edge-navigate, Tab-closes,
// pointer-open-no-focus) is wrong for a listbox, and everything here is
// dead weight for menus.
//
// THE SYNC INVARIANT (the component): native_select.value, the value Value,
// aria-selected/data-state on options, and the display text never diverge -
// every write path (commit, closed-trigger typeahead, autofill adoption,
// programmatic setValue) funnels through #apply, which writes the NATIVE
// SELECT FIRST (serialization truth is never behind the facade), dispatches
// real bubbling change/input on it (Turbo auto-submit and friends work
// unmodified), flips aria-selected + data-state TOGETHER on every option,
// syncs the value display from the option's item-text (data-text-value
// override), toggles trigger[data-placeholder], then fires
// poetry:select:change.
//
// The three Radix-parity deltas vs the menu family, all deliberate:
// - Tab while open is INERT (a value picker resolves by commit or Esc);
// - open focuses the SELECTED option for EVERY reason, pointer included;
// - typeahead on the CLOSED trigger COMMITS the match without opening
//   (native <select> parity), while open typeahead only moves focus.
const TRIGGER_SELECTOR = '[data-slot="select-trigger"]'
const ITEM_SELECTOR = '[data-slot="select-item"]'
const ITEM_TEXT_SELECTOR = '[data-slot="select-item-text"]'
const NATIVE_SELECTOR = '[data-slot="select-native"]'
const VALUE_SELECTOR = '[data-slot="select-value"]'
const VIEWPORT_SELECTOR = '[data-slot="select-viewport"]'
const SCROLL_UP_SELECTOR = '[data-slot="select-scroll-up-button"]'
const SCROLL_DOWN_SELECTOR = '[data-slot="select-scroll-down-button"]'

const EVENT_PREFIX = "poetry:select"

const ROVING = "poetry--core--roving-focus"
const ROVING_ACTION = `keydown->${ROVING}#keydown`
const CONTENT_LAYER_CONTROLLERS = ["poetry--core--focus-scope", "poetry--core--dismissable", ROVING]

const SCROLL_HOLD_STEP = 4 // px per frame while hovering a scroll button

export default class SelectController extends Controller {
  static values = {
    open: { type: Boolean, default: false },
    value: { type: String, default: "" },
    modal: { type: Boolean, default: true },
    loop: { type: Boolean, default: false },
    typeaheadTimeout: { type: Number, default: 1000 }
  }

  #connected = false
  #wired = []
  #claimed = new WeakSet()
  #suppressRestore = false
  #cancelExit = null
  #typeahead = createTypeahead()
  #applied = ""
  #placeholder = ""
  #scrollFrame = null

  connect() {
    const content = this.#content()

    if (content) this.#wireContent(content)

    // The placeholder: the value display's data-placeholder attribute when
    // given (survives a valued server render), else the empty-value display
    // text - captured so a later clear can restore it.
    const display = this.#display()

    this.#placeholder = display?.dataset.placeholder ??
      (this.#trigger()?.hasAttribute("data-placeholder") ? (display?.textContent ?? "").trim() : "")

    // Reconcile-on-connect (Turbo Stream re-render safe): the native select
    // is the serialization truth - adopt its value when the Value was not
    // given, else normalize the DOM to the Value. Both paths are silent
    // (no events for state the server already declared).
    const serverValue = this.valueValue !== "" ? this.valueValue : (this.#native()?.value ?? "")

    this.#applied = serverValue
    this.#apply(serverValue, { silent: true, force: true })

    this.#connected = true

    if (this.#isOpen()) {
      if (content) this.#activateLayers(content)
      this.openValue = true
    } else if (this.openValue) {
      this.#show("pointer")
    }
  }

  disconnect() {
    this.#connected = false

    for (const [target, type, listener] of this.#wired) target.removeEventListener(type, listener)

    this.#wired = []
    this.#typeahead.reset()
    this.scrollHoldStop()
    this.#cancelExit?.()
    this.#cancelExit = null
  }

  // --- controllable state ---

  openValueChanged(value) {
    if (!this.#connected) return

    if (value && !this.#isOpen()) this.#show("pointer")
    else if (!value && this.#isOpen()) this.#hide("programmatic")
  }

  valueValueChanged(value) {
    if (!this.#connected || value === this.#applied) return

    this.#apply(value)
  }

  // --- trigger actions ---

  toggle() {
    if (this.#isOpen()) this.#hide("trigger")
    else this.#show("pointer")
  }

  // Enter / Space / ArrowDown / ArrowUp open and focus the SELECTED option
  // (Radix: closed arrows never step the value). A printable key on the
  // CLOSED trigger commits the typeahead match WITHOUT opening (native
  // <select> parity - the full commit pipeline minus open/close).
  triggerKeydown(event) {
    if (this.#isOpen()) return

    if (event.key === "Enter" || event.key === " " || event.key === "ArrowDown" || event.key === "ArrowUp") {
      event.preventDefault()
      this.#show(this.#applied === "" ? "keyboard-first" : "keyboard-selected")
      return
    }

    if (event.key.length === 1 && !event.ctrlKey && !event.altKey && !event.metaKey) {
      event.preventDefault()

      const match = this.#search(event.key)

      if (match) this.#commitItem(match, { close: false })
    }
  }

  // --- programmatic API ---

  open(reason = "pointer") {
    this.#show(reason instanceof Event ? "pointer" : reason)
  }

  close(reason = "programmatic") {
    this.#hide(reason instanceof Event ? "programmatic" : reason)
  }

  setValue(value) {
    if (value === this.#applied) return

    this.#apply(String(value ?? ""))
  }

  // --- option activation ---

  // Public action for markup-declared data-action; the delegated content
  // click claims first, so both paths never double-commit.
  commit(event) {
    if (this.#claim(event)) return

    const origin = event.currentTarget instanceof Element ? event.currentTarget : event.target
    const item = origin instanceof Element ? origin.closest(ITEM_SELECTOR) : null

    if (!item || this.#isDisabled(item)) return

    this.#commitItem(item)
  }

  // --- content keydown (commit keys, typeahead, the Tab-inert delta) ---

  keydown(event) {
    if (this.#claim(event)) return
    if (!this.#isOpen()) return

    const target = event.target instanceof Element ? event.target : null
    const item = target?.closest(ITEM_SELECTOR) ?? null

    switch (event.key) {
      case "Tab":
        // THE delta vs the menu family: Tab is INERT while open - a value
        // picker resolves by commit or Esc (Radix Select-exact).
        event.preventDefault()
        event.stopImmediatePropagation()
        return
      case "Enter":
      case " ":
        if (event.key === " " && this.#typeahead.pending()) break // space extends a live search

        event.preventDefault()

        if (item && !this.#isDisabled(item)) this.#commitItem(item)

        return
      case "ArrowRight":
      case "ArrowLeft":
        return // flat listbox: no submenu meaning, no edge seam - no-ops
      default:
        break
    }

    if (event.key.length === 1 && !event.ctrlKey && !event.altKey && !event.metaKey) {
      event.preventDefault()

      // Open typeahead moves focus (highlight) ONLY - selection does not
      // follow focus; commit stays explicit.
      this.#search(event.key, item)?.focus()
    }
  }

  // --- autofill adoption ---

  // Browser autofill (or any programmatic write) fires change on the hidden
  // native select: the UI adopts it. fromNative skips re-writing the native
  // (and re-dispatching its events - no loop).
  nativeChanged() {
    const value = this.#native()?.value ?? ""

    if (value === this.#applied) return

    this.#apply(value, { fromNative: true })
  }

  // --- scroll buttons ---

  syncScrollButtons() {
    const content = this.#content()
    const viewport = content?.querySelector(VIEWPORT_SELECTOR)

    if (!content || !viewport) return

    const up = content.querySelector(SCROLL_UP_SELECTOR)
    const down = content.querySelector(SCROLL_DOWN_SELECTOR)

    if (up) up.hidden = viewport.scrollTop <= 0
    if (down) down.hidden = viewport.scrollTop + viewport.clientHeight >= viewport.scrollHeight
  }

  scrollHoldStart(event) {
    const origin = event.currentTarget instanceof Element ? event.currentTarget : null
    const direction = origin?.matches(SCROLL_UP_SELECTOR) ? -1 : 1
    const viewport = this.#content()?.querySelector(VIEWPORT_SELECTOR)

    if (!viewport) return

    this.scrollHoldStop()

    const step = () => {
      viewport.scrollTop += direction * SCROLL_HOLD_STEP
      this.syncScrollButtons()
      this.#scrollFrame = window.requestAnimationFrame(step)
    }

    this.#scrollFrame = window.requestAnimationFrame(step)
  }

  scrollHoldStop() {
    if (this.#scrollFrame === null) return

    window.cancelAnimationFrame(this.#scrollFrame)
    this.#scrollFrame = null
  }

  // --- open / close ---

  #show(reason) {
    const content = this.#content()

    if (!content || this.#isOpen()) return

    this.#cancelExit?.()
    this.#cancelExit = null
    this.#suppressRestore = false

    const trigger = this.#trigger()

    content.hidden = false
    content.setAttribute("data-open-reason", reason)
    trigger?.setAttribute("aria-expanded", "true")
    if (trigger) setState(trigger, "open")
    enterPresence(content)
    this.#activateLayers(content)
    this.openValue = true

    // The layer controllers connect on the attribute-mutation microtask;
    // initial focus rides one microtask behind so focus-scope has already
    // snapshotted the trigger (its focus-return target).
    queueMicrotask(() => {
      if (!this.#isOpen()) return

      this.#focusSelected(content)
      this.syncScrollButtons()
      this.dispatch("open", { prefix: EVENT_PREFIX, detail: { reason } })
    })
  }

  #hide(reason, { restoreFocus = true } = {}) {
    const content = this.#content()

    if (!content || !this.#isOpen()) return

    this.#typeahead.reset()
    this.scrollHoldStop()
    this.#suppressRestore = !restoreFocus || (reason === "outside" && !this.modalValue)

    const trigger = this.#trigger()

    trigger?.setAttribute("aria-expanded", "false")
    if (trigger) setState(trigger, "closed")
    content.removeAttribute("data-open-reason")
    this.openValue = false

    this.#cancelExit = exitPresence(content, {
      onRemove: () => {
        this.#cancelExit = null
        content.hidden = true
        this.#removeControllers(content, CONTENT_LAYER_CONTROLLERS)
        this.dispatch("closed", { prefix: EVENT_PREFIX, detail: { reason } })
      }
    })
  }

  // Initial focus: the SELECTED option for EVERY reason, pointer included
  // (Radix Select parity - the listbox exists to show you where you are);
  // first enabled option when the value is empty.
  #focusSelected(content) {
    const items = this.#enabledItems(content)
    const target = items.find((item) => item.getAttribute("aria-selected") === "true") ?? items[0]

    if (!target) {
      content.focus()
      return
    }

    target.focus()
    target.scrollIntoView?.({ block: "nearest" })
  }

  // --- the commit pipeline ---

  #commitItem(item, { close = true } = {}) {
    const value = item.dataset.value ?? ""

    // Cancelable BEFORE the value commits: preventDefault vetoes the commit
    // and keeps the listbox open (the family select-event shape).
    const select = this.dispatch("select", {
      prefix: EVENT_PREFIX,
      target: item,
      cancelable: true,
      detail: { item, value, label: this.#labelOf(item) }
    })

    if (select.defaultPrevented) return

    if (value !== this.#applied) this.#apply(value)
    if (close) this.#hide("commit")
  }

  // THE single sync path, native-first. silent skips events (reconcile);
  // fromNative skips step 1's write-back (the value came FROM the native).
  #apply(value, { silent = false, fromNative = false, force = false } = {}) {
    if (!force && value === this.#applied) return

    const previous = this.#applied

    this.#applied = value
    this.valueValue = value // the attribute mirror; the changed callback no-ops on #applied

    // 1. The native select FIRST - serialization truth is never behind the
    //    display - with real bubbling change/input (Turbo/analytics fire).
    const native = this.#native()

    if (native && !fromNative) {
      native.value = value

      if (!silent) {
        native.dispatchEvent(new Event("input", { bubbles: true }))
        native.dispatchEvent(new Event("change", { bubbles: true }))
      }
    }

    // 2. aria-selected + data-state flipped TOGETHER on every option.
    let selected = null

    for (const item of this.#items()) {
      const match = value !== "" && (item.dataset.value ?? "") === value

      item.setAttribute("aria-selected", String(match))
      setState(item, match ? "checked" : "unchecked")

      if (match) selected = item
    }

    // 3 + 4. The value display syncs from the option's item-text (or its
    //    data-text-value); an empty value restores the placeholder + the
    //    trigger's data-placeholder dimming.
    const display = this.#display()
    const label = selected ? this.#labelOf(selected) : null

    if (display) display.textContent = label ?? this.#placeholder

    this.#trigger()?.toggleAttribute("data-placeholder", !selected)

    // 5. The poetry change event.
    if (!silent) {
      this.dispatch("change", { prefix: EVENT_PREFIX, detail: { value, label, previous } })
    }
  }

  // --- typeahead (the shared helper; anchor = focused option when open,
  //     the selected option when closed) ---

  #search(key, activeItem = null) {
    const content = this.#content()

    if (!content) return null

    const items = this.#enabledItems(content)
    const active = activeItem ??
      (this.#isOpen()
        ? (document.activeElement instanceof Element ? document.activeElement.closest(ITEM_SELECTOR) : null)
        : items.find((item) => item.getAttribute("aria-selected") === "true") ?? null)

    return this.#typeahead.search(key, items, { active, timeout: this.typeaheadTimeoutValue })
  }

  #labelOf(item) {
    return (item.dataset.textValue ??
      item.querySelector(ITEM_TEXT_SELECTOR)?.textContent ??
      typeaheadLabel(item)).trim()
  }

  // --- content wiring (programmatic: portal-safe) ---

  #wireContent(content) {
    this.#listen(content, "keydown", (event) => this.keydown(event))
    this.#listen(content, "click", this.#onClick)
    this.#listen(content, "scroll", () => this.syncScrollButtons())
    this.#listen(content, "poetry--core--dismissable:dismiss", this.#onDismiss)
    this.#listen(content, "poetry--core--focus-scope:mount-auto-focus", this.#onMountAutoFocus)
    this.#listen(content, "poetry--core--focus-scope:unmount-auto-focus", this.#onUnmountAutoFocus)
  }

  #listen(target, type, listener) {
    target.addEventListener(type, listener)
    this.#wired.push([target, type, listener])
  }

  #onClick = (event) => {
    if (this.#claim(event)) return

    const item = event.target instanceof Element ? event.target.closest(ITEM_SELECTOR) : null

    if (!item || this.#isDisabled(item)) return

    this.#commitItem(item)
  }

  // Esc / outside press arrive as the dismissable layer's dismiss event.
  // Esc NEVER commits - the value is untouched.
  #onDismiss = (event) => {
    if (event.target !== this.#content()) return

    const escaped = event.detail?.originalEvent?.type === "keydown"

    this.#hide(escaped ? "escape" : "outside")
  }

  // The select owns initial focus (the selected option), not focus-scope.
  #onMountAutoFocus = (event) => {
    if (event.target === this.#content()) event.preventDefault()
  }

  #onUnmountAutoFocus = (event) => {
    if (event.target === this.#content() && this.#suppressRestore) event.preventDefault()
  }

  // --- the layer stack (the menu controller's proven mechanism) ---

  #activateLayers(content) {
    content.setAttribute("data-poetry--core--focus-scope-trapped-value", String(this.modalValue))
    content.setAttribute(
      "data-poetry--core--dismissable-disable-outside-pointer-events-value", String(this.modalValue)
    )
    content.setAttribute(`data-${ROVING}-orientation-value`, "vertical")
    content.setAttribute(`data-${ROVING}-manage-tabindex-value`, "true")
    content.setAttribute(`data-${ROVING}-loop-value`, String(this.loopValue))

    const action = content.getAttribute("data-action") ?? ""

    if (!action.includes(ROVING_ACTION)) {
      content.setAttribute("data-action", `${action} ${ROVING_ACTION}`.trim())
    }

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

  // --- structural resolution (ids are the seams; portal-safe) ---

  #trigger() {
    return this.element.querySelector(TRIGGER_SELECTOR)
  }

  #content() {
    const id = this.#trigger()?.getAttribute("aria-controls")

    return id ? document.getElementById(id) : null
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
    const content = this.#content()

    return content ? collectionItems(content, ITEM_SELECTOR) : []
  }

  #enabledItems(content = this.#content()) {
    if (!content) return []

    return collectionItems(content, ITEM_SELECTOR).filter((item) => !this.#isDisabled(item))
  }

  #isDisabled(item) {
    return item.hasAttribute("data-disabled") || item.getAttribute("aria-disabled") === "true"
  }

  #claim(event) {
    if (this.#claimed.has(event)) return true

    this.#claimed.add(event)

    return false
  }
}
