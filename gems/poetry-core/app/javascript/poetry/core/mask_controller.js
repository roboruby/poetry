import { Controller } from "@hotwired/stimulus"
import {
  applyMaskToRaw,
  buildDisplayValue,
  checkComplete,
  extractRaw,
  findNextEditablePosition,
  generatePattern,
  nextTokenPosition,
  parseMask,
  prevTokenPosition,
  processInput
} from "@poetry/controllers/helpers/mask"

// The input-mask machine (use-mask 9.4.1 port) on a bare native
// <input> - this.element IS the input. Three layers:
//
// 1. THE PRIMARY PATH is keydown with preventDefault: a printable char
//    skips forward over literals from the caret and pattern-tests (a
//    failing char is a NO-OP, it never reaches the field), a selection is
//    replaced via a raw rebuild, and the caret lands past the next literal
//    run. Backspace scans BACKWARD over literals (the caret lands at the
//    deleted token), Delete scans FORWARD (the caret stays),
//    Cmd/Ctrl+Backspace kills to start, arrows hop literal runs. Because
//    preventDefault kills the native undo stack, a custom
//    {raw, selectionStart} history (max 100, deduped) backs
//    Cmd/Ctrl+Z / Shift+Cmd/Ctrl+Z / Ctrl+Y.
//
// 2. THE FALLBACK is the input-event diff (IME, mobile keyboards,
//    autofill, password managers - paths that never emit clean keydowns):
//    the longest common prefix+suffix against the previous display
//    isolates the inserted text and the removed span, the value is rebuilt
//    from raw pieces, re-masked, and the caret lands after the insertion.
//
// 3. THE DISPLAY: skeleton padding ("__/__") shows on focus
//    (showMaskOnFocus, default) or permanently (alwaysShowMask); blur
//    strips it back to the filled region - or clears the field entirely
//    when autoClear is set and the mask is incomplete. A COLLAPSED caret
//    is clamped into [first token, end of filled region] on focus (rAF),
//    mousedown (rAF) and mouseup; selections are never touched.
//
// Port caveat: unlike an upstream library, every programmatic value write dispatches a
// native bubbling `input` event (#painting guards the controller against
// its own echo) so Rails/Turbo listeners stay live. The raw value mirrors
// to data-raw after every change; `pattern` is set on connect from
// generatePattern("full-inexact") unless the input already carries one.
const MAX_UNDO_HISTORY = 100

export default class MaskController extends Controller {
  // The events this controller dispatches (manifest surface;
  // events_declaration.test.js enforces the list stays honest).
  static events = ["poetry:mask:change", "poetry:mask:complete"]

  static values = {
    mask: String,
    slotChar: { type: String, default: "_" },
    alwaysShowMask: Boolean,
    showMaskOnFocus: { type: Boolean, default: true },
    autoClear: Boolean,
    upcase: Boolean
  }

  #slots = []
  #processed = "" // the masked value, no skeleton padding
  #display = "" // what the input currently shows (may include skeleton)
  #raw = ""
  #wasComplete = false
  #focused = false
  #painting = false // set while dispatching our own native input echo
  #undoStack = []
  #redoStack = []

  connect() {
    if (this.element.tagName !== "INPUT") {
      console.warn("poetry--core--mask: must be attached to an <input>")
      return
    }

    this.#slots = parseMask(this.maskValue)

    if (!this.element.hasAttribute("pattern")) {
      this.element.setAttribute("pattern", generatePattern(this.#slots, "full-inexact"))
    }

    this.#listen("addEventListener")
    this.#initialize()
  }

  disconnect() {
    this.#listen("removeEventListener")
  }

  #listen(method) {
    for (const [type, handler] of [
      ["input", this.#onInput],
      ["focus", this.#onFocus],
      ["blur", this.#onBlur],
      ["mousedown", this.#onMousedown],
      ["mouseup", this.#onMouseup],
      ["keydown", this.#onKeydown],
      ["paste", this.#onPaste]
    ]) this.element[method](type, handler)
  }

  // Mount: a server-rendered value is processed through the mask SILENTLY -
  // no poetry events, no native input echo (nothing changed semantically).
  #initialize() {
    const value = this.element.value

    if (value) {
      const processed = processInput(value, this.#slots)

      this.#processed = processed
      this.#raw = extractRaw(processed, this.#slots)
      this.#display = buildDisplayValue(processed, this.#slots, this.slotCharValue, this.#showSlots(processed))
      this.#wasComplete = checkComplete(processed, this.#slots)
      this.element.value = this.#display
    } else if (this.alwaysShowMaskValue) {
      this.#display = buildDisplayValue("", this.#slots, this.slotCharValue, true)
      this.element.value = this.#display
    }

    this.element.setAttribute("data-raw", this.#raw)
  }

  // --- the keydown path (primary: full editing control) ---

  #onKeydown = (event) => {
    const input = this.element
    const start = input.selectionStart ?? 0
    const end = input.selectionEnd ?? 0
    const processed = this.#processed
    const slots = this.#slots
    const modifier = event.metaKey || (event.ctrlKey && !event.altKey)
    const key = (event.key ?? "").toLowerCase()

    if (modifier && key === "z" && !event.shiftKey) {
      event.preventDefault()
      this.#restore(this.#undoStack, this.#redoStack)
      return
    }

    if (modifier && ((key === "z" && event.shiftKey) || (key === "y" && !event.shiftKey))) {
      event.preventDefault()
      this.#restore(this.#redoStack, this.#undoStack)
      return
    }

    if (event.key === "Backspace") {
      event.preventDefault()

      if (modifier) {
        // Cmd/Ctrl+Backspace: kill to start, keep the tail.
        const from = Math.min(start, processed.length)
        const afterRaw = extractRaw(processed.slice(from), slots.slice(from))

        this.#pushUndo()
        this.#updateValue(this.#mask(afterRaw), 0)
        return
      }

      if (start !== end) {
        this.#deleteSelection(start, end)
        return
      }

      if (start === 0) return

      // Scan BACKWARD over literals; the caret lands at the deleted token.
      let pos = start - 1

      while (pos >= 0 && slots[pos]?.type === "literal") pos--

      if (pos < 0) return

      const beforeRaw = extractRaw(processed.slice(0, pos), slots.slice(0, pos))
      const afterRaw = extractRaw(processed.slice(pos + 1), slots.slice(pos + 1))

      this.#pushUndo()
      this.#updateValue(this.#mask(beforeRaw + afterRaw), pos)
      return
    }

    if (event.key === "Delete") {
      event.preventDefault()

      if (start !== end) {
        this.#deleteSelection(start, end)
        return
      }

      // Scan FORWARD over literals; the caret stays put.
      let pos = start

      while (pos < slots.length && slots[pos]?.type === "literal") pos++

      if (pos >= processed.length) return

      const beforeRaw = extractRaw(processed.slice(0, start), slots.slice(0, start))
      const afterRaw = extractRaw(processed.slice(pos + 1), slots.slice(pos + 1))

      this.#pushUndo()
      this.#updateValue(this.#mask(beforeRaw + afterRaw), start)
      return
    }

    if (event.key === "ArrowRight" && !event.shiftKey) {
      const next = findNextEditablePosition(start + 1, slots, input.value.length)

      if (next !== start + 1) {
        event.preventDefault()
        input.setSelectionRange(next, next)
      }
      return
    }

    if (event.key === "ArrowLeft" && !event.shiftKey) {
      if (start === 0) return

      const previous = prevTokenPosition(slots, start - 1)

      if (previous >= 0 && previous !== start - 1) {
        event.preventDefault()
        input.setSelectionRange(previous + 1, previous + 1)
      }
      return
    }

    if ((event.key ?? "").length === 1 && !event.ctrlKey && !event.metaKey && !event.altKey) {
      event.preventDefault() // a failing char is a no-op, never the field's problem

      let pos = Math.min(start, processed.length)

      while (pos < slots.length && slots[pos]?.type === "literal") pos++

      if (pos >= slots.length) return

      const transform = this.#transform()
      const char = transform ? transform(event.key) : event.key

      if (!slots[pos].pattern.test(char)) return

      const beforeRaw = extractRaw(processed.slice(0, pos), slots.slice(0, pos))
      const afterFrom = start < end ? Math.min(end, processed.length) : pos
      const afterRaw = extractRaw(processed.slice(afterFrom), slots.slice(afterFrom))
      const masked = this.#mask(beforeRaw + char + afterRaw)

      this.#pushUndo()
      this.#updateValue(masked, findNextEditablePosition(pos + 1, slots, masked.length))
    }
  }

  // Selection deletion (Backspace and Delete share it): keep the raw
  // before the selection, keep the raw after it, re-mask, caret at start.
  #deleteSelection(start, end) {
    const processed = this.#processed
    const to = Math.min(end, processed.length)
    const beforeRaw = extractRaw(processed.slice(0, start), this.#slots.slice(0, start))
    const afterRaw = extractRaw(processed.slice(to), this.#slots.slice(to))

    this.#pushUndo()
    this.#updateValue(this.#mask(beforeRaw + afterRaw), start)
  }

  // --- the input-event diff fallback (IME / mobile / autofill) ---

  #onInput = () => {
    if (this.#painting) return // our own native echo

    const prev = this.#display
    const curr = this.element.value

    let prefix = 0
    const maxPrefix = Math.min(prev.length, curr.length)

    while (prefix < maxPrefix && prev[prefix] === curr[prefix]) prefix++

    let suffix = 0
    const maxSuffix = Math.min(prev.length - prefix, curr.length - prefix)

    while (suffix < maxSuffix && prev[prev.length - 1 - suffix] === curr[curr.length - 1 - suffix]) suffix++

    const inserted = curr.slice(prefix, curr.length - suffix)
    const removedEnd = prev.length - suffix
    const beforeRaw = extractRaw(prev.slice(0, prefix), this.#slots.slice(0, prefix))
    const afterRaw = extractRaw(prev.slice(removedEnd), this.#slots.slice(removedEnd))
    const masked = this.#mask(beforeRaw + inserted + afterRaw)

    if (masked !== prev) this.#pushUndo()

    this.#updateValue(masked, this.#mask(beforeRaw + inserted).length)
  }

  // --- paste: raw insertion at the clamped selection ---

  #onPaste = (event) => {
    event.preventDefault()

    const text = event.clipboardData?.getData("text") ?? ""
    const input = this.element
    const processed = this.#processed
    const start = Math.min(input.selectionStart ?? 0, processed.length)
    const end = Math.min(input.selectionEnd ?? 0, processed.length)
    const beforeRaw = extractRaw(processed.slice(0, start), this.#slots.slice(0, start))
    const afterRaw = extractRaw(processed.slice(end), this.#slots.slice(end))

    this.#pushUndo()
    this.#updateValue(this.#mask(beforeRaw + text + afterRaw))

    // The caret lands after the MASKED insertion (invalid chars dropped).
    const caret = Math.min(this.#mask(beforeRaw + text).length, this.#slots.length)

    if (document.activeElement === input) input.setSelectionRange(caret, caret)
  }

  // --- focus / blur: skeleton lifecycle ---

  #onFocus = () => {
    this.#focused = true

    if (this.showMaskOnFocusValue || this.alwaysShowMaskValue) {
      this.#display = buildDisplayValue(this.#processed, this.#slots, this.slotCharValue, true)
      this.#paint(this.#display)
    }

    // rAF: the browser places the caret AFTER focus fires.
    requestAnimationFrame(() => {
      if (document.activeElement === this.element) this.#clampCaret({ floor: true })
    })
  }

  #onBlur = () => {
    this.#focused = false

    const slots = this.#slots
    const skeleton = buildDisplayValue(this.#processed, slots, this.slotCharValue, true)
    // An externally mutated value (no input event fired) still re-parses.
    const processed = this.element.value === skeleton
      ? this.#processed
      : processInput(this.element.value, slots)
    const complete = checkComplete(processed, slots)

    if (this.autoClearValue && !complete && processed.length > 0) {
      this.#clear()

      if (this.alwaysShowMaskValue) {
        this.#display = buildDisplayValue("", slots, this.slotCharValue, true)
        this.#paint(this.#display)
      }
      return
    }

    if (!this.alwaysShowMaskValue && !complete) {
      if (extractRaw(processed, slots).length === 0) {
        this.#clear()
        return
      }

      // Strip the skeleton padding; the filled region stays.
      this.#processed = processed
      this.#raw = extractRaw(processed, slots)
      this.#display = processed
      this.element.setAttribute("data-raw", this.#raw)
      this.#paint(processed)
    }
  }

  // --- caret clamping (focus rAF / mousedown rAF / mouseup) ---

  #onMouseup = () => {
    if (document.activeElement === this.element) this.#clampCaret({ floor: true })
  }

  #onMousedown = () => {
    // rAF: the click's caret placement hasn't happened yet at mousedown.
    requestAnimationFrame(() => {
      if (document.activeElement === this.element) this.#clampCaret({ floor: false })
    })
  }

  // Clamp a COLLAPSED caret into [first token, end of the filled region];
  // selections are never touched (floor: the mousedown variant only caps).
  #clampCaret({ floor }) {
    const input = this.element
    const start = input.selectionStart ?? 0

    if (start !== (input.selectionEnd ?? 0)) return

    const first = nextTokenPosition(this.#slots)
    const limit = this.#processed.length > 0
      ? findNextEditablePosition(this.#processed.length, this.#slots, this.#processed.length)
      : first

    if (start > limit || (floor && start < first)) input.setSelectionRange(limit, limit)
  }

  // --- the undo/redo history (preventDefault kills the native stack) ---

  #pushUndo() {
    const state = { raw: this.#raw, selectionStart: this.element.selectionStart ?? this.#raw.length }
    const top = this.#undoStack[this.#undoStack.length - 1]

    if (top && top.raw === state.raw && top.selectionStart === state.selectionStart) return

    this.#undoStack.push(state)

    if (this.#undoStack.length > MAX_UNDO_HISTORY) this.#undoStack.shift()

    this.#redoStack = []
  }

  #restore(from, to) {
    const state = from.pop()

    if (!state) return

    to.push({ raw: this.#raw, selectionStart: this.element.selectionStart ?? 0 })
    this.#updateValue(this.#mask(state.raw), state.selectionStart)
  }

  // --- the single value sink ---

  // Canonicalize -> re-derive raw + display -> write the DOM -> fire the
  // events. change fires per user-driven mutation; complete fires ONCE per
  // rise into complete (editing below re-arms it).
  #updateValue(masked, caret) {
    const processed = processInput(masked, this.#slots)
    const raw = extractRaw(processed, this.#slots)
    const display = buildDisplayValue(processed, this.#slots, this.slotCharValue, this.#showSlots(processed))

    this.#processed = processed
    this.#raw = raw
    this.#display = display
    this.element.setAttribute("data-raw", raw)
    this.#paint(display, caret === undefined ? undefined : Math.min(caret, processed.length))

    const complete = checkComplete(processed, this.#slots)
    const detail = { raw, masked: display, complete }

    this.dispatch("change", { prefix: "poetry:mask", detail })

    if (complete && !this.#wasComplete) {
      this.dispatch("complete", { prefix: "poetry:mask", detail })
    }

    this.#wasComplete = complete
  }

  // autoClear / empty blur: everything resets and listeners hear about it.
  #clear() {
    this.#processed = ""
    this.#display = ""
    this.#raw = ""
    this.#wasComplete = false
    this.element.setAttribute("data-raw", "")
    this.#paint("")
    this.dispatch("change", { prefix: "poetry:mask", detail: { raw: "", masked: "", complete: false } })
  }

  // Every programmatic value write echoes a native bubbling input event
  // (the recorded an upstream library port caveat - Rails/Turbo listeners must stay
  // live); #painting keeps #onInput from re-processing the echo.
  #paint(display, caret) {
    const changed = this.element.value !== display

    if (changed) this.element.value = display

    if (caret !== undefined && document.activeElement === this.element) {
      this.element.setSelectionRange(caret, caret)
    }

    if (!changed) return

    this.#painting = true
    this.element.dispatchEvent(new Event("input", { bubbles: true }))
    this.#painting = false
  }

  #showSlots(processed) {
    return (this.alwaysShowMaskValue || this.#focused) &&
      (this.showMaskOnFocusValue || processed.length > 0)
  }

  #mask(raw) {
    return applyMaskToRaw(raw, this.#slots, this.#transform())
  }

  // the upstream library's transform generalizes to any fn; poetry keeps ONE
  // declarative knob - uppercase before validation.
  #transform() {
    return this.upcaseValue ? (char) => char.toUpperCase() : undefined
  }
}
