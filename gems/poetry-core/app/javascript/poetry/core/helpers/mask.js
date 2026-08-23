// The mask engine, adapted from Mantine's use-mask hook (MIT, v9.4.1).
// Adapted from https://github.com/mantinedev/mantine - see THIRD_PARTY_NOTICES.md.
// Pure functions over a parsed slot list, zero DOM. A mask is a sequence of
// slots: token slots
// validate ONE character against a pattern, literal slots are fixed chrome
// ("/", "-", " ") the engine inserts and the user never types. Every value
// decision lives here so it stays exhaustively unit-testable; the caret
// math and events live in mask_controller.js.

export const DEFAULT_TOKENS = {
  "9": /[0-9]/,
  a: /[A-Za-z]/,
  A: /[A-Z]/,
  "*": /[A-Za-z0-9]/,
  "#": /[-+0-9]/
}

// String grammar: token chars from the (custom-over-default merged) token
// map, "\" escapes the next char to a literal, "?" is consumed and makes
// every LATER slot optional - the flag is STICKY, it never resets, so
// "(999) 999-9999? x9999" is complete without the extension. Array
// grammar: RegExp item = token slot, string item = literal.
export function parseMask(mask, tokens = {}) {
  if (Array.isArray(mask)) {
    return mask.map((item) =>
      item instanceof RegExp
        ? { type: "token", char: "_", pattern: item }
        : { type: "literal", char: item }
    )
  }

  const map = { ...DEFAULT_TOKENS, ...tokens }
  const slots = []
  let optional = false

  for (let i = 0; i < mask.length; i++) {
    const char = mask[i]

    if (char === "\\" && i + 1 < mask.length) {
      i++
      slots.push({ type: "literal", char: mask[i] })
      continue
    }

    if (char === "?") {
      optional = true
      continue
    }

    if (map[char]) slots.push({ type: "token", char, pattern: map[char], optional })
    else slots.push({ type: "literal", char })
  }

  return slots
}

// Raw chars -> masked string. Literals append EAGERLY (raw "12" under
// "99/99" is "12/" - the separator paints the moment it is reachable); a
// token slot consumes the next raw char when it matches, else silently
// DROPS it and retries the SAME slot with the following char; transform
// (poetry's upcase knob) runs before validation.
export function applyMaskToRaw(raw, slots, transform) {
  let result = ""
  let rawIndex = 0

  for (let slotIndex = 0; slotIndex < slots.length; slotIndex++) {
    const slot = slots[slotIndex]

    if (slot.type === "literal") {
      result += slot.char
      continue
    }

    if (rawIndex >= raw.length) break

    const char = transform ? transform(raw[rawIndex]) : raw[rawIndex]

    if (slot.pattern.test(char)) {
      result += char
      rawIndex++
    } else {
      rawIndex++ // silent drop
      slotIndex-- // retry the same slot
    }
  }

  return result
}

// Re-parse arbitrary display text (autofill, a server-rendered value, IME
// output): literals self-match or are inserted, token slots scan forward
// discarding non-matching chars, and the walk stops at the first slot the
// remaining text cannot fill.
export function processInput(text, slots) {
  let result = ""
  let index = 0

  for (let slotIndex = 0; slotIndex < slots.length && index <= text.length; slotIndex++) {
    const slot = slots[slotIndex]

    if (slot.type === "literal") {
      result += slot.char
      if (index < text.length && text[index] === slot.char) index++
      continue
    }

    if (index >= text.length) break

    while (index < text.length) {
      const char = text[index]

      index++

      if (slot.pattern.test(char)) {
        result += char
        break
      }
    }

    if (result.length <= slotIndex) break // the slot went unfilled
  }

  return result
}

// Chars at token positions - the value the form actually means.
export function extractRaw(masked, slots) {
  let raw = ""

  for (let i = 0; i < masked.length && i < slots.length; i++) {
    if (slots[i].type === "token") raw += masked[i]
  }

  return raw
}

// Pad the masked value with the mask skeleton. slotChar "_" by default; a
// multi-char slotChar indexes per position ("dd/mm/yyyy" under a date
// mask) falling back to "_" past its end; null/"" disables padding (the
// display stops at the first empty token slot).
export function buildDisplayValue(value, slots, slotChar = "_", showSlots = true) {
  if (!showSlots) return value

  let display = value

  for (let i = value.length; i < slots.length; i++) {
    const slot = slots[i]

    if (slot.type === "literal") {
      display += slot.char
      continue
    }

    const char = slotCharAt(slotChar, i)

    if (!char) break

    display += char
  }

  return display
}

function slotCharAt(slotChar, index) {
  if (slotChar === null || slotChar === undefined || slotChar === "") return ""

  return slotChar.length > 1 ? (slotChar[index] ?? "_") : slotChar
}

// Complete = every non-optional token position is filled and pattern-valid.
export function checkComplete(masked, slots) {
  return slots.every((slot, i) =>
    slot.type !== "token" || slot.optional || (i < masked.length && slot.pattern.test(masked[i]))
  )
}

// Regex source for the HTML pattern attribute: "full" wraps each token in
// a capture group, "full-inexact" doesn't; optional tokens get a trailing
// "?"; literals are regex-escaped.
export function generatePattern(slots, kind = "full") {
  return slots.map((slot) => {
    if (slot.type === "literal") return slot.char.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")

    const source = kind === "full-inexact" ? slot.pattern.source : `(${slot.pattern.source})`

    return slot.optional ? `${source}?` : source
  }).join("")
}

// Skip a literal run rightward from pos, bounded by the filled region -
// the caret never lands inside chrome or out in the skeleton.
export function findNextEditablePosition(pos, slots, filledLength) {
  while (pos < slots.length && pos < filledLength && slots[pos].type === "literal") pos++

  return pos
}

// First token position at or after `from` (slots.length when none).
export function nextTokenPosition(slots, from = 0) {
  for (let i = from; i < slots.length; i++) {
    if (slots[i].type === "token") return i
  }

  return slots.length
}

// Last token position at or before `from` (-1 when none).
export function prevTokenPosition(slots, from) {
  for (let i = from; i >= 0; i--) {
    if (slots[i].type === "token") return i
  }

  return -1
}
