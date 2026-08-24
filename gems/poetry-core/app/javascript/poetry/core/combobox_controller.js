import { Controller } from "@hotwired/stimulus"
import { collectionItems } from "@poetry/controllers/helpers/collection"
import { isImeKeydown } from "@poetry/controllers/helpers/escape"
import { isPortaled, portalContent, resolvePortalContainer, restoreContent } from "@poetry/controllers/helpers/portal"
import { enterPresence, exitPresence } from "@poetry/controllers/helpers/presence"
import { setState, stateOf } from "@poetry/controllers/helpers/state"
import { tabbableWithin } from "@poetry/controllers/helpers/tabbable"

// The Combobox ORCHESTRATOR: Select's shell
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
//
// MULTIPLE (Base UI's multiple + input-inside layout): the value is a
// LIST (the value Value carries a JSON array over the same String seam),
// the native is a <select multiple> posting name[], and the trigger is
// replaced by the chips FIELD - one chip per committed value IN VALUE
// ORDER with the filter input inline after them (data-slot=command-input,
// so the engine contract holds; the engine itself rides the ROOT).
// Selection TOGGLES and the popup STAYS OPEN; chips take REAL DOM focus
// (:focus-visible styles it - never data-highlighted) and focusing a chip
// closes the popup; Backspace on the empty input removes the last chip;
// Escape on the CLOSED popup clears the query and wipes the selection.
// The input NEVER mirrors selection text; single-mode paths are
// behavior-identical.
const TRIGGER_SELECTOR = '[data-slot="combobox-trigger"]'
const NATIVE_SELECTOR = '[data-slot="combobox-native"]'
const VALUE_SELECTOR = '[data-slot="combobox-value"]'
const CONTENT_SELECTOR = '[data-slot="combobox-content"]'
const CLEAR_SELECTOR = '[data-slot="combobox-clear"]'
const CHIPS_SELECTOR = '[data-slot="combobox-chips"]'
const CHIP_SELECTOR = '[data-slot="combobox-chip"]'
const CHIP_REMOVE_SELECTOR = '[data-slot="combobox-chip-remove"]'
const COMMAND_SELECTOR = '[data-slot="command"]'
const INPUT_SELECTOR = '[data-slot="command-input"]'
const ITEM_SELECTOR = '[data-slot="command-item"]'
const ITEM_TEXT_SELECTOR = '[data-slot="command-item-text"]'

const EVENT_PREFIX = "poetry:combobox"
const COMMAND_IDENTIFIER = "poetry--core--command"

// NO roving-focus (the popup is Command's activedescendant session - the
// family's first popup without it).
const CONTENT_LAYER_CONTROLLERS = ["poetry--core--focus-scope", "poetry--core--dismissable"]
const POPPER_STRATEGY = "data-poetry--core--popper-strategy-value"

export default class ComboboxController extends Controller {
  // The events this controller dispatches (manifest surface;
  // events_declaration.test.js enforces the list stays honest).
  static events = [
    "poetry:combobox:change", "poetry:combobox:closed", "poetry:combobox:open",
    "poetry:combobox:select"
  ]

  static values = {
    open: { type: Boolean, default: false },
    // Single: the committed value. multiple: a JSON array over the same
    // String seam (parsed by #listValues, serialized by #applyValues).
    value: { type: String, default: "" },
    // DEFAULT FALSE - Popover semantics (Tab-out closes, no scrim); true
    // restores the focus-scope trap for dialog-critical pickers.
    modal: { type: Boolean, default: false },
    // Base UI multiple: the value is a LIST, the trigger is the chips
    // field, selection toggles, the popup stays open on select.
    multiple: { type: Boolean, default: false }
  }

  #connected = false
  #wired = []
  #suppressRestore = false
  #cancelExit = null
  #applied = ""
  #placeholder = ""
  #dismissedEvent = null

  connect() {
    const content = this.#content()

    if (content) this.#wireContent(content)

    const chips = this.#chips()

    // The chips FIELD is a second wired keyboard surface in multiple
    // (Tab-out closes from the inline input exactly like from the popup).
    if (chips) this.#listen(chips, "keydown", this.#onKeydown)

    const display = this.#display()

    this.#placeholder = display?.dataset.placeholder ??
      (this.#trigger()?.hasAttribute("data-placeholder") ? (display?.textContent ?? "").trim() : "")

    // Reconcile-on-connect (Turbo Stream re-render safe): the native select
    // is the serialization truth (Select-exact). multiple reads the value
    // Value's JSON array, falling back to the native's selectedOptions.
    const serverValue = this.multipleValue
      ? this.#reconciledValues()
      : (this.valueValue !== "" ? this.valueValue : (this.#native()?.value ?? ""))

    this.#applied = serverValue
    this.#apply(serverValue, { silent: true, force: true })

    this.#connected = true

    if (this.#isOpen()) {
      if (content) {
        this.#activateLayers(content)
        this.#portalPinned(content)
      }
      this.openValue = true
    } else if (this.openValue) {
      this.#show("trigger-press")
    }
  }

  // The reconcile path portals ONE FRAME LATE: connect order within a boot
  // is unordered, and portaling before the sibling popper's connect would
  // rob it of its content target before it could cache the node.
  #portalPinned(content) {
    window.requestAnimationFrame(() => {
      if (!this.#connected || !this.#isOpen()) return

      portalContent(content, { container: resolvePortalContainer(this.element) })
      this.element.setAttribute(POPPER_STRATEGY, "absolute")
    })
  }

  disconnect() {
    this.#connected = false

    // Never leave content stranded at the container (drop-never-strand).
    const content = this.#content()

    if (content) restoreContent(content)

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
    if (!this.#connected) return

    if (this.multipleValue) {
      const values = this.#listValues(value)

      if (this.#sameValues(values, this.#applied)) return

      this.#apply(values)
      return
    }

    if (value === this.#applied) return

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

  // --- the chips field (multiple) ---

  // Mousedown anywhere in the chips FRAME focuses the input and opens the
  // popup (Base UI: the whole frame is the field) - except a chip-remove
  // press, which is a removal, never a chips-area press.
  chipsPointerdown(event) {
    const input = this.#input()

    if (!input || input.disabled) return
    if (event.target instanceof Element && event.target.closest(CHIP_REMOVE_SELECTOR)) return

    // Keep the press from landing focus on the frame/chip; a press on the
    // input itself keeps native caret placement.
    if (event.target !== input) event.preventDefault()

    input.focus()

    if (!this.#isOpen()) this.#show("trigger-press")
  }

  // The inline input's OWN keyboard map (multiple; the engine's map rides
  // the same keydown): Backspace on an empty input removes the LAST chip
  // (focus stays here), ArrowLeft at caret 0 walks into the chips,
  // ArrowDown/Up reopen the popup, Enter with no highlight closes, and
  // Escape on the CLOSED popup clears the query AND wipes the selection
  // to [] (Base UI-exact; readOnly blocks every mutation).
  inputKeydown(event) {
    if (!this.multipleValue) return

    const input = event.target

    switch (event.key) {
      case "Backspace": {
        if (input.value !== "" || input.readOnly) return
        if (this.#applied.length === 0) return

        this.#apply(this.#applied.slice(0, -1))
        return
      }
      case "ArrowLeft": {
        if (input.selectionStart !== 0 || input.selectionEnd !== 0) return

        const chips = this.#chipElements()

        if (chips.length > 0) {
          event.preventDefault()
          this.#focusChip(chips[chips.length - 1])
        }
        return
      }
      case "ArrowDown":
      case "ArrowUp":
        if (!this.#isOpen()) this.#show("list-navigation")
        return
      case "Enter":
        if (this.#isOpen() && !this.#highlightedOption()) this.#hide("none")
        return
      case "Escape": {
        // The press that just dismissed the popup must not ALSO wipe - and
        // neither may an IME composition-cancel Escape (the user is dropping
        // a composition, not asking to clear the field).
        if (event === this.#dismissedEvent || this.#isOpen() || input.readOnly) return
        if (isImeKeydown(event)) return

        this.#command()?.reset()
        if (this.#applied.length > 0) this.#apply([])
        return
      }
      default:
        // Everything else belongs to the input or the engine's map.
    }
  }

  // A focused chip's keyboard map (Base UI): Left/Right walk the chips
  // (off either end -> back to the input), Backspace/Delete remove (next
  // highlight: same index, step back at the tail, the input once
  // emptied), Enter/Space are no-ops returning to the input, ArrowDown/Up
  // reopen the popup, a printable char resumes the typing session.
  chipKeydown(event) {
    const origin = event.currentTarget instanceof Element ? event.currentTarget : event.target
    const chip = origin instanceof Element ? origin.closest(CHIP_SELECTOR) : null

    if (!chip) return

    const chips = this.#chipElements()
    const index = chips.indexOf(chip)

    switch (event.key) {
      case "ArrowLeft":
      case "ArrowRight": {
        event.preventDefault()

        const next = index + (event.key === "ArrowRight" ? 1 : -1)

        if (next >= 0 && next < chips.length) this.#focusChip(chips[next])
        else this.#input()?.focus()
        return
      }
      case "Backspace":
      case "Delete":
        event.preventDefault()

        if (this.#input()?.readOnly) return

        this.#removeAt(index)
        return
      case "Enter":
      case " ":
        event.preventDefault()
        this.#input()?.focus()
        return
      case "ArrowDown":
      case "ArrowUp":
        event.preventDefault()
        this.#input()?.focus()
        if (!this.#isOpen()) this.#show("list-navigation")
        return
      default:
        // A printable char refocuses the input (the key lands there).
        if (event.key.length === 1 && !event.ctrlKey && !event.altKey && !event.metaKey) {
          this.#input()?.focus()
        }
    }
  }

  // ChipRemove press (its click action): remove the chip's value; focus
  // returns to the input WITHOUT opening (not a chips-area press).
  removeChip(event) {
    if (this.#input()?.readOnly) return

    const origin = event.currentTarget instanceof Element ? event.currentTarget : event.target
    const chip = origin instanceof Element ? origin.closest(CHIP_SELECTOR) : null
    const index = chip ? this.#chipElements().indexOf(chip) : -1

    if (index === -1) return

    const values = [...this.#applied]

    values.splice(index, 1)
    this.#apply(values)
    this.#input()?.focus()
  }

  // --- the show_clear X (its click action) ---

  // The trigger-side deselection surface (Base UI Combobox.Clear): commit
  // the blank value through the pipeline, then hand focus to the trigger -
  // the X hides itself once the value empties, and a focused hidden
  // button would drop focus to body. Single mode only (the component
  // raises on multiple; the guard here is belt and braces).
  clear() {
    if (this.multipleValue) return

    if (this.#applied !== "") this.#apply("")
    this.#trigger()?.focus()
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
    if (this.multipleValue) {
      const values = this.#listValues(value)

      if (this.#sameValues(values, this.#applied)) return

      this.#apply(values)
      return
    }

    if (value === this.#applied) return

    this.#apply(String(value ?? ""))
  }

  // --- autofill adoption (Select's path verbatim) ---

  nativeChanged() {
    if (this.multipleValue) {
      const values = this.#nativeValues()

      // MEMBERSHIP comparison, not order: a <select multiple> only knows
      // DOM order, so the pipeline's own bubbling change (value order
      // preserved) must never round-trip into a reorder.
      if (this.#sameMembers(values, this.#applied)) return

      this.#apply(values, { fromNative: true })
      return
    }

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

    const expander = this.#expander()

    // Portal-on-open: move BEFORE the
    // enter presence (reparenting mid-animation restarts it), re-anchor
    // absolute - static under compositor scroll, transform-immune. In
    // multiple mode only the popup (listbox) moves; the chips field with
    // its inline input stays home as the popper anchor.
    portalContent(content, { container: resolvePortalContainer(this.element) })
    this.element.setAttribute(POPPER_STRATEGY, "absolute")

    content.hidden = false
    content.setAttribute("data-open-reason", reason)
    if (seed) content.setAttribute("data-open-seed", seed)
    else content.removeAttribute("data-open-seed")
    expander?.setAttribute("aria-expanded", "true")
    if (expander) setState(expander, "popup-open")
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

    const expander = this.#expander()

    expander?.setAttribute("aria-expanded", "false")
    if (expander) setState(expander, "popup-closed")
    content.removeAttribute("data-open-reason")
    content.removeAttribute("data-open-seed")
    this.openValue = false

    this.#cancelExit = exitPresence(content, {
      onRemove: () => {
        this.#cancelExit = null
        content.hidden = true
        // Home AFTER the exit finished and hidden landed (D4); focus
        // return is focus-scope's ref-based job, indifferent to the move.
        restoreContent(content)
        this.element.setAttribute(POPPER_STRATEGY, "fixed")
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
  // multiple INVERTS both rules (Base UI): selection TOGGLES membership
  // (appended at the array END) and the popup STAYS OPEN; a typed query
  // clears immediately so the full list is restored for the next pick.
  #onCommandSelect = (event) => {
    const { item, value = "", label = "" } = event.detail ?? {}

    const select = this.dispatch("select", {
      prefix: EVENT_PREFIX,
      target: item instanceof Element ? item : this.element,
      cancelable: true,
      detail: { item, value, label }
    })

    if (select.defaultPrevented) return

    if (this.multipleValue) {
      const input = this.#input()

      if (input?.readOnly) return

      const values = [...this.#applied]
      const index = values.indexOf(value)

      if (index === -1) values.push(value)
      else values.splice(index, 1)

      this.#apply(values)

      if (input && input.value !== "") {
        this.#command()?.reset()
        if (item instanceof Element) this.#command()?.highlightItem(item)
      }

      input?.focus()
      return
    }

    if (value !== this.#applied) this.#apply(value)

    this.#hide("item-press")
  }

  // THE single sync path, NATIVE FIRST (Select's 5 steps re-instantiated):
  // 1. native_select.value + real bubbling change/input; 2. aria-selected
  // + data-selected twin-flipped on every option; 3+4. display synced from
  // the option's item-text (data-text-value override) + the trigger's
  // data-placeholder; 5. poetry:combobox:change. multiple routes to the
  // set-shaped twin below.
  #apply(value, { silent = false, fromNative = false, force = false } = {}) {
    if (this.multipleValue) {
      this.#applyValues(this.#listValues(value), { silent, fromNative, force })
      return
    }

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
    // The show_clear X follows the VALUE (not the matched item - the async
    // recipe can commit values whose item is not rendered); the chevron
    // swap derives from this one flip in CSS.
    this.#clearButton()?.toggleAttribute("hidden", value === "")

    if (!silent) {
      this.dispatch("change", { prefix: EVENT_PREFIX, detail: { value, label, previous } })
    }
  }

  #labelOf(item) {
    return (item.dataset.textValue ??
      item.querySelector(ITEM_TEXT_SELECTOR)?.textContent ??
      item.textContent ?? "").trim()
  }

  // The multiple twin of #apply, set-shaped (the same 5 steps over a value
  // LIST): 1. the native <select multiple>'s selectedOptions + real
  // bubbling change/input; 2. aria-selected + data-selected twin-flipped
  // by ARRAY INCLUSION; 3+4. chips rebuilt IN VALUE ORDER + the frame's
  // data-placeholder / role=toolbar flips (the input NEVER mirrors
  // selection text); 5. poetry:combobox:change with array-shaped detail.
  #applyValues(values, { silent = false, fromNative = false, force = false } = {}) {
    if (!force && this.#sameValues(values, this.#applied)) return

    const previous = this.#applied

    this.#applied = values
    this.valueValue = JSON.stringify(values)

    const native = this.#native()

    if (native && !fromNative) {
      for (const option of this.#nativeOptions()) option.selected = values.includes(option.value)

      if (!silent) {
        native.dispatchEvent(new Event("input", { bubbles: true }))
        native.dispatchEvent(new Event("change", { bubbles: true }))
      }
    }

    for (const item of this.#items()) {
      const match = values.includes(item.dataset.value ?? "")

      item.setAttribute("aria-selected", String(match))
      setState(item, match ? "selected" : "unselected")
    }

    this.#renderChips(values)

    if (!silent) {
      this.dispatch("change", {
        prefix: EVENT_PREFIX,
        detail: { value: values, label: values.map((value) => this.#labelForValue(value)), previous }
      })
    }
  }

  // Chips are SERVER markup: the frame's <template> skeleton (byte-what
  // the server renders for a committed value) is cloned per value rather
  // than composing DOM of this controller's own.
  #renderChips(values) {
    const chips = this.#chips()

    if (!chips) return

    for (const chip of this.#chipElements()) chip.remove()

    const template = chips.querySelector("template")
    const input = chips.querySelector(INPUT_SELECTOR)
    const removeTemplate = chips.dataset.removeLabel ?? "Remove %{label}"

    if (template?.content?.firstElementChild) {
      for (const value of values) {
        const chip = template.content.firstElementChild.cloneNode(true)
        const label = this.#labelForValue(value)

        chip.setAttribute("data-value", value)
        chip.setAttribute("aria-label", label)
        chip.querySelector(CHIP_REMOVE_SELECTOR)
          ?.setAttribute("aria-label", removeTemplate.replace("%{label}", label))
        chip.insertBefore(document.createTextNode(label), chip.firstChild)
        chips.insertBefore(chip, input)
      }
    }

    // role=toolbar rides the frame ONLY while it holds chips (Base UI);
    // an empty selection wears the data-placeholder styling hook instead.
    if (values.length > 0) chips.setAttribute("role", "toolbar")
    else chips.removeAttribute("role")
    chips.toggleAttribute("data-placeholder", values.length === 0)
  }

  // Chip keyboard removal: next highlight lands on the SAME index, steps
  // back at the tail, and returns to the input once the list empties.
  #removeAt(index) {
    const values = [...this.#applied]

    if (index < 0 || index >= values.length) return

    values.splice(index, 1)
    this.#apply(values)

    const chips = this.#chipElements()

    if (chips.length === 0) this.#input()?.focus()
    else this.#focusChip(chips[Math.min(index, chips.length - 1)])
  }

  // Real DOM focus IS the chip highlight (:focus-visible/:focus-within
  // style it; chips never wear data-highlighted) - and focusing a chip
  // CLOSES the popup (the typing session is suspended). disabled blocks
  // chip focus entirely.
  #focusChip(chip) {
    if (!chip || chip.hasAttribute("data-disabled")) return

    if (this.#isOpen()) this.#hide("chip-focus", { restoreFocus: false })

    chip.focus()
  }

  #labelForValue(value) {
    const item = this.#items().find((candidate) => (candidate.dataset.value ?? "") === value)

    if (item) return this.#labelOf(item)

    const option = this.#nativeOptions().find((candidate) => candidate.value === value)

    return (option?.textContent ?? value).trim()
  }

  // --- content wiring (programmatic: portal-safe) ---

  #wireContent(content) {
    this.#listen(content, "keydown", this.#onKeydown)
    this.#listen(content, "poetry:command:select", this.#onCommandSelect)
    this.#listen(content, "poetry--core--dismissable:interact-outside", this.#onInteractOutside)
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
  //
  // The Tab seam: a Tab originating INSIDE the portaled
  // popup would proceed from body's end, not from the combobox - close
  // (unchanged) and place focus where the un-portaled DOM would have
  // landed it: the trigger on Shift+Tab, the next tabbable after it on
  // Tab (the reference combobox rule). Multiple mode's typing surface is the
  // chips input at HOME, so its Tab-out proceeds naturally, untouched.
  #onKeydown = (event) => {
    if (event.key !== "Tab" || this.modalValue || !this.#isOpen()) return

    const content = this.#content()
    const fromPortaled = Boolean(content) && isPortaled(content) &&
      event.target instanceof Element && content.contains(event.target)

    this.#hide("focus-out", { restoreFocus: false })

    if (!fromPortaled) return

    const anchor = this.#trigger()

    if (!anchor) return

    event.preventDefault()

    if (event.shiftKey) {
      anchor.focus()
      return
    }

    const tabbables = tabbableWithin(document.body)
    const next = tabbables
      .slice(tabbables.indexOf(anchor) + 1)
      .find((element) => !content.contains(element))

    ;(next ?? anchor).focus()
  }

  // A press on the combobox's OWN trigger is the toggle's job (the popover
  // trigger-press rule: without the veto, pointerdown closes and the
  // trailing click re-opens). In multiple, a press in the chips FIELD is
  // an anchor press too - vetoing the layer keeps the popup open while
  // chips mutate under the pointer.
  #onInteractOutside = (event) => {
    if (event.target !== this.#content()) return

    const origin = event.detail?.originalEvent?.target

    if (!(origin instanceof Element)) return
    if (this.#trigger()?.contains(origin)) return event.preventDefault()
    if (this.multipleValue && this.#chips()?.contains(origin)) event.preventDefault()
  }

  // Esc / outside press arrive as the dismissable layer's dismiss event.
  // Neither EVER commits - the value is untouched (family rule).
  #onDismiss = (event) => {
    if (event.target !== this.#content()) return

    const escaped = event.detail?.originalEvent?.type === "keydown"

    // Remembered so the SAME keypress cannot double as the closed-popup
    // Escape wipe in the multiple input map.
    this.#dismissedEvent = event.detail?.originalEvent ?? null
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
  // Multiple has no trigger - the chips frame's inline input carries the
  // same aria-controls (and sits HOME, so this read survives the portal).
  #listbox() {
    const id = this.#trigger()?.getAttribute("aria-controls") ??
      this.#chips()?.querySelector(INPUT_SELECTOR)?.getAttribute("aria-controls")

    return id ? document.getElementById(id) : null
  }

  #content() {
    return this.#listbox()?.closest(CONTENT_SELECTOR) ??
      this.element.querySelector(CONTENT_SELECTOR)
  }

  #command() {
    // multiple mounts the engine on the ROOT (the input sits outside the
    // popup); single keeps it on the popup's command part.
    const root = this.#content()?.querySelector(COMMAND_SELECTOR) ??
      (this.multipleValue ? this.element : null)

    return root
      ? this.application.getControllerForElementAndIdentifier(root, COMMAND_IDENTIFIER)
      : null
  }

  #input() {
    // multiple: the ONE input lives inline in the chips frame (Base UI's
    // input-inside layout); single keeps it in the popup.
    return this.#content()?.querySelector(INPUT_SELECTOR) ??
      this.#chips()?.querySelector(INPUT_SELECTOR) ?? null
  }

  #native() {
    return this.element.querySelector(NATIVE_SELECTOR)
  }

  #display() {
    return this.element.querySelector(VALUE_SELECTOR)
  }

  // The open-state carrier: the trigger button (single) or the inline
  // input (multiple - Base UI stamps aria-expanded/data-popup-open there).
  #expander() {
    return this.#trigger() ?? (this.multipleValue ? this.#input() : null)
  }

  #chips() {
    return this.element.querySelector(CHIPS_SELECTOR)
  }

  #clearButton() {
    return this.element.querySelector(CLEAR_SELECTOR)
  }

  // Live chips only - the <template> skeleton's content is inert and
  // never matches a querySelectorAll over the frame.
  #chipElements() {
    const chips = this.#chips()

    return chips ? Array.from(chips.querySelectorAll(CHIP_SELECTOR)) : []
  }

  #highlightedOption() {
    return (this.#listbox() ?? this.#content())?.querySelector("[data-highlighted]") ?? null
  }

  #reconciledValues() {
    const declared = this.#listValues(this.valueValue)

    return declared.length > 0 ? declared : this.#nativeValues()
  }

  // selectedOptions derived by hand (options + the selected property):
  // identical semantics, and it holds in every DOM this runs against.
  #nativeValues() {
    return this.#nativeOptions()
      .filter((option) => option.selected)
      .map((option) => option.value)
      .filter((value) => value !== "")
  }

  #nativeOptions() {
    return Array.from(this.#native()?.querySelectorAll("option") ?? [])
  }

  // The value Value stays a String seam in both modes; multiple carries a
  // JSON array through it (a bare scalar adopts as a one-element list).
  #listValues(raw) {
    if (Array.isArray(raw)) return raw.map(String)
    if (typeof raw !== "string" || raw === "") return []

    try {
      const parsed = JSON.parse(raw)

      return Array.isArray(parsed) ? parsed.map(String) : [String(parsed)]
    } catch {
      return [raw]
    }
  }

  // Order-sensitive on purpose: chips render IN VALUE ORDER, so a reorder
  // IS a change.
  #sameValues(values, applied) {
    return Array.isArray(applied) && values.length === applied.length &&
      values.every((value, index) => value === applied[index])
  }

  // Order-blind twin for the native adoption seam only.
  #sameMembers(values, applied) {
    return Array.isArray(applied) && values.length === applied.length &&
      values.every((value) => applied.includes(value))
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
