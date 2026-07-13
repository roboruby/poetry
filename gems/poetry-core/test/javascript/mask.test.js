import { afterEach, beforeEach, describe, expect, it } from "vitest"
import { Application } from "@hotwired/stimulus"
import MaskController from "@poetry/controllers/mask_controller"
import {
  applyMaskToRaw,
  buildDisplayValue,
  checkComplete,
  extractRaw,
  findNextEditablePosition,
  generatePattern,
  parseMask,
  processInput
} from "@poetry/controllers/helpers/mask"

// poetry--core--mask JS-unit: the pure engine (grammar, eager literals,
// silent drop, skeleton, completeness, pattern generation) plus the
// controller's two editing paths - keydown (primary, preventDefault +
// custom undo) and the input-event diff fallback (IME/autofill) - paste
// splicing, focus/blur skeleton lifecycle, caret clamping, the native
// input echo on programmatic writes, and the complete transition.

const nextFrame = () => new Promise((resolve) => setTimeout(resolve, 0))
const frame = () => new Promise((resolve) => requestAnimationFrame(() => resolve()))

describe("mask engine", () => {
  const date = parseMask("99/99")

  describe("parseMask", () => {
    it("maps default tokens and literals", () => {
      expect(date.map((slot) => slot.type)).toEqual(["token", "token", "literal", "token", "token"])
      expect(date[0].pattern.test("7")).toBe(true)
      expect(date[0].pattern.test("x")).toBe(false)
      expect(date[2].char).toBe("/")

      const kinds = parseMask("9aA*#")

      expect(kinds.every((slot) => slot.type === "token")).toBe(true)
      expect(kinds[1].pattern.test("q")).toBe(true)
      expect(kinds[2].pattern.test("q")).toBe(false)
      expect(kinds[2].pattern.test("Q")).toBe(true)
      expect(kinds[3].pattern.test("q")).toBe(true)
      expect(kinds[4].pattern.test("+")).toBe(true)
    })

    it("merges custom tokens over the defaults", () => {
      const slots = parseMask("9h", { h: /[0-5]/ })

      expect(slots[0].pattern.test("9")).toBe(true) // default survives
      expect(slots[1].pattern.test("5")).toBe(true)
      expect(slots[1].pattern.test("6")).toBe(false)
    })

    it("backslash escapes the next char to a literal", () => {
      const slots = parseMask("\\99")

      expect(slots[0]).toMatchObject({ type: "literal", char: "9" })
      expect(slots[1].type).toBe("token")
    })

    it("? is consumed and makes every LATER slot optional - sticky, never resets", () => {
      const slots = parseMask("(999) 999-9999? x9999")

      expect(slots.some((slot) => slot.char === "?")).toBe(false)
      expect(slots[1].optional).toBe(false)
      expect(slots.filter((slot) => slot.type === "token").slice(-4).every((slot) => slot.optional)).toBe(true)
    })

    it("array form: RegExp = token, string = literal", () => {
      const slots = parseMask([/\d/, "-", /[a-z]/])

      expect(slots.map((slot) => slot.type)).toEqual(["token", "literal", "token"])
      expect(slots[1].char).toBe("-")
    })
  })

  describe("applyMaskToRaw", () => {
    it("appends literals EAGERLY", () => {
      expect(applyMaskToRaw("12", date)).toBe("12/")
      expect(applyMaskToRaw("1234", date)).toBe("12/34")
    })

    it("silently drops non-matching raw chars and retries the same slot", () => {
      expect(applyMaskToRaw("1a2b34", date)).toBe("12/34")
      expect(applyMaskToRaw("abc", date)).toBe("")
    })

    it("runs transform before validation", () => {
      expect(applyMaskToRaw("ab", parseMask("AA"), (char) => char.toUpperCase())).toBe("AB")
      expect(applyMaskToRaw("ab", parseMask("AA"))).toBe("")
    })
  })

  describe("processInput", () => {
    it("re-parses display text: literals self-match, junk is discarded", () => {
      expect(processInput("12/34", date)).toBe("12/34")
      expect(processInput("1234", date)).toBe("12/34")
      expect(processInput("1x2/3", date)).toBe("12/3")
    })

    it("stops at the first unfillable slot", () => {
      expect(processInput("12/ab", date)).toBe("12/")
    })
  })

  it("extractRaw returns the chars at token positions", () => {
    expect(extractRaw("12/34", date)).toBe("1234")
    expect(extractRaw("12/", date)).toBe("12")
  })

  describe("buildDisplayValue", () => {
    it("pads with the mask skeleton", () => {
      expect(buildDisplayValue("12", date, "_", true)).toBe("12/__")
      expect(buildDisplayValue("", date, "_", true)).toBe("__/__")
      expect(buildDisplayValue("12", date, "_", false)).toBe("12")
    })

    it("multi-char slotChar indexes per position with _ past its end", () => {
      expect(buildDisplayValue("", date, "dd mm", true)).toBe("dd/mm")
      expect(buildDisplayValue("", date, "dd", true)).toBe("dd/__")
    })

    it("null or empty slotChar disables padding (literals still eager)", () => {
      expect(buildDisplayValue("12", date, null, true)).toBe("12/")
      expect(buildDisplayValue("12", date, "", true)).toBe("12/")
    })
  })

  it("checkComplete requires every non-optional token; optionals may stay empty", () => {
    expect(checkComplete("12/34", date)).toBe(true)
    expect(checkComplete("12/3", date)).toBe(false)

    const phone = parseMask("(999) 999-9999? x9999")

    expect(checkComplete("(123) 456-7890", phone)).toBe(true)
    expect(checkComplete("(123) 456-7890 x1234", phone)).toBe(true)
    expect(checkComplete("(123) 456-78", phone)).toBe(false)
  })

  it("generatePattern: full wraps tokens in capture groups, full-inexact doesn't, literals escape", () => {
    expect(generatePattern(date, "full")).toBe("([0-9])([0-9])/([0-9])([0-9])")
    expect(generatePattern(date, "full-inexact")).toBe("[0-9][0-9]/[0-9][0-9]")
    expect(generatePattern(parseMask("9+9"), "full-inexact")).toBe("[0-9]\\+[0-9]")
    expect(generatePattern(parseMask("99?9"), "full-inexact")).toBe("[0-9][0-9][0-9]?")
    expect(generatePattern(parseMask("99?9"), "full")).toBe("([0-9])([0-9])([0-9])?")
  })

  it("findNextEditablePosition skips literal runs, bounded by the filled region", () => {
    const gap = parseMask("99--99")

    expect(findNextEditablePosition(2, gap, 6)).toBe(4)
    expect(findNextEditablePosition(2, gap, 2)).toBe(2) // never past the fill
    expect(findNextEditablePosition(0, gap, 6)).toBe(0)
  })
})

describe("poetry--core--mask", () => {
  let application

  beforeEach(async () => {
    application = Application.start()
    application.register("poetry--core--mask", MaskController)
    await nextFrame()
  })

  afterEach(() => {
    application.stop()
    document.body.replaceChildren()
  })

  const el = () => document.getElementById("field")

  async function mount({ mask = "99/99", attrs = "", value = "" } = {}) {
    document.body.innerHTML = `
      <input id="field" type="text" ${value ? `value="${value}"` : ""}
             data-controller="poetry--core--mask"
             data-poetry--core--mask-mask-value="${mask}" ${attrs}>`
    await nextFrame()
    return el()
  }

  const focus = async () => {
    el().focus()
    await frame() // the caret clamp lands on the next animation frame
  }

  const press = (key, props = {}) => {
    const event = new KeyboardEvent("keydown", { key, bubbles: true, cancelable: true, ...props })

    el().dispatchEvent(event)
    return event
  }

  const type = (text) => [...text].forEach((char) => press(char))

  const caret = (start, end = start) => el().setSelectionRange(start, end)

  const paste = (text) => {
    const event = new Event("paste", { bubbles: true, cancelable: true })

    event.clipboardData = { getData: () => text }
    el().dispatchEvent(event)
    return event
  }

  it("typing fills through literals (keydown path) and mirrors data-raw", async () => {
    await mount()
    await focus()

    type("1234")

    expect(el().value).toBe("12/34")
    expect(el().getAttribute("data-raw")).toBe("1234")
    expect(el().selectionStart).toBe(5)
  })

  it("a pattern-failing char is a prevented no-op", async () => {
    await mount()
    await focus()

    type("1")
    const rejected = press("x")

    expect(rejected.defaultPrevented).toBe(true)
    expect(el().value).toBe("1_/__")
    expect(el().getAttribute("data-raw")).toBe("1")
  })

  it("typing past a full mask is swallowed", async () => {
    await mount()
    await focus()

    type("12345")

    expect(el().value).toBe("12/34")
  })

  it("backspace scans BACKWARD over literals; the caret lands at the deleted token", async () => {
    await mount()
    await focus()
    type("1234")

    caret(3) // right after the "/"
    press("Backspace")

    expect(el().value).toBe("13/4_")
    expect(el().selectionStart).toBe(1)
  })

  it("delete scans FORWARD over literals; the caret stays", async () => {
    await mount()
    await focus()
    type("1234")

    caret(2) // right before the "/"
    press("Delete")

    expect(el().value).toBe("12/4_")
    expect(el().selectionStart).toBe(2)
  })

  it("cmd/ctrl+backspace kills to start", async () => {
    await mount()
    await focus()
    type("1234")

    caret(4)
    press("Backspace", { metaKey: true })

    expect(el().value).toBe("4_/__")
    expect(el().getAttribute("data-raw")).toBe("4")
    expect(el().selectionStart).toBe(0)
  })

  it("typing over a selection replaces it via raw rebuild", async () => {
    await mount()
    await focus()
    type("1234")

    caret(0, 4) // "12/3" selected
    press("9")

    expect(el().value).toBe("94/__")
    expect(el().getAttribute("data-raw")).toBe("94")
    expect(el().selectionStart).toBe(1)
  })

  it("arrow keys hop literal runs (right skips forward, left lands after the previous token)", async () => {
    await mount()
    await focus()
    type("1234")

    caret(1)
    const right = press("ArrowRight")

    expect(right.defaultPrevented).toBe(true)
    expect(el().selectionStart).toBe(3)

    const left = press("ArrowLeft")

    expect(left.defaultPrevented).toBe(true)
    expect(el().selectionStart).toBe(2)

    // A plain one-step move stays native.
    expect(press("ArrowLeft").defaultPrevented).toBe(false)
  })

  it("undo/redo restore {raw, caret} - the custom stack preventDefault made necessary", async () => {
    await mount()
    await focus()

    type("12")
    press("Backspace")
    expect(el().getAttribute("data-raw")).toBe("1")

    press("z", { metaKey: true })
    expect(el().value).toBe("12/__")
    expect(el().getAttribute("data-raw")).toBe("12")
    expect(el().selectionStart).toBe(3)

    press("z", { metaKey: true, shiftKey: true }) // redo
    expect(el().getAttribute("data-raw")).toBe("1")

    press("z", { ctrlKey: true }) // undo (ctrl flavor)
    press("y", { ctrlKey: true }) // redo (ctrl+y flavor)
    expect(el().getAttribute("data-raw")).toBe("1")
  })

  it("a new edit clears the redo stack", async () => {
    await mount()
    await focus()

    type("12")
    press("z", { metaKey: true })
    expect(el().getAttribute("data-raw")).toBe("1")

    type("3")
    press("z", { metaKey: true, shiftKey: true }) // redo has nothing

    expect(el().getAttribute("data-raw")).toBe("13")
  })

  it("paste splices raw at the selection, silently dropping invalid chars", async () => {
    await mount()
    await focus()

    const event = paste("1a2b34")

    expect(event.defaultPrevented).toBe(true)
    expect(el().value).toBe("12/34")
    expect(el().getAttribute("data-raw")).toBe("1234")
  })

  it("paste over a selection replaces it and lands the caret after the masked insertion", async () => {
    await mount()
    await focus()
    type("1234")

    caret(3, 4) // "3" selected
    paste("9")

    expect(el().value).toBe("12/94")
    expect(el().selectionStart).toBe(4)
  })

  it("the input-event diff fallback re-masks autofill-style writes", async () => {
    await mount()

    el().value = "1234"
    el().dispatchEvent(new Event("input", { bubbles: true }))

    expect(el().value).toBe("12/34")
    expect(el().getAttribute("data-raw")).toBe("1234")
  })

  it("the diff fallback handles a mid-value deletion (IME-style)", async () => {
    await mount()
    el().value = "1234"
    el().dispatchEvent(new Event("input", { bubbles: true }))

    el().value = "12/4" // "3" removed by an editing path with no keydown
    el().dispatchEvent(new Event("input", { bubbles: true }))

    expect(el().value).toBe("12/4")
    expect(el().getAttribute("data-raw")).toBe("124")
  })

  it("focus shows the skeleton and blur on an empty field clears it", async () => {
    await mount()

    await focus()
    expect(el().value).toBe("__/__")

    el().blur()
    expect(el().value).toBe("")
  })

  it("blur strips the padding but keeps the filled region (incomplete, no alwaysShowMask)", async () => {
    await mount()
    await focus()
    type("12")
    expect(el().value).toBe("12/__")

    el().blur()

    expect(el().value).toBe("12/")
    expect(el().getAttribute("data-raw")).toBe("12")
  })

  it("autoClear wipes an incomplete value on blur", async () => {
    await mount({ attrs: 'data-poetry--core--mask-auto-clear-value="true"' })
    const changes = []

    el().addEventListener("poetry:mask:change", (event) => changes.push(event.detail.raw))
    await focus()
    type("12")

    el().blur()

    expect(el().value).toBe("")
    expect(el().getAttribute("data-raw")).toBe("")
    expect(changes[changes.length - 1]).toBe("")
  })

  it("alwaysShowMask paints the skeleton on connect and keeps it after blur", async () => {
    await mount({ attrs: 'data-poetry--core--mask-always-show-mask-value="true"' })

    expect(el().value).toBe("__/__")

    await focus()
    type("12")
    el().blur()

    expect(el().value).toBe("12/__")
  })

  it("showMaskOnFocus false: no skeleton until there is content", async () => {
    await mount({ attrs: 'data-poetry--core--mask-show-mask-on-focus-value="false"' })

    await focus()
    expect(el().value).toBe("")

    type("1")
    expect(el().value).toBe("1_/__")
  })

  it("a custom slotChar drives the skeleton", async () => {
    await mount({ attrs: 'data-poetry--core--mask-slot-char-value="•"' })

    await focus()

    expect(el().value).toBe("••/••")
  })

  it("processes a server-rendered value on connect WITHOUT dispatching events", async () => {
    document.body.innerHTML = `
      <input id="field" type="text" value="1234"
             data-controller="poetry--core--mask"
             data-poetry--core--mask-mask-value="99/99">`
    const seen = []

    el().addEventListener("poetry:mask:change", () => seen.push("change"))
    el().addEventListener("poetry:mask:complete", () => seen.push("complete"))
    el().addEventListener("input", () => seen.push("input"))
    await nextFrame()

    expect(el().value).toBe("12/34")
    expect(el().getAttribute("data-raw")).toBe("1234")
    expect(seen).toEqual([])
  })

  it("every programmatic write dispatches a native bubbling input event", async () => {
    await mount()
    const inputs = []

    document.body.addEventListener("input", () => inputs.push(el().value))

    await focus() // skeleton paint is a programmatic write too
    expect(inputs).toEqual(["__/__"])

    press("1")
    expect(inputs).toEqual(["__/__", "1_/__"])
    expect(el().getAttribute("data-raw")).toBe("1") // own echo not re-processed
  })

  it("change fires per user-driven mutation with {raw, masked, complete}", async () => {
    await mount()
    const seen = []

    el().addEventListener("poetry:mask:change", (event) => seen.push(event.detail))
    await focus()
    type("1")

    expect(seen).toEqual([{ raw: "1", masked: "1_/__", complete: false }])
  })

  it("complete fires once on the transition into complete and re-arms below it", async () => {
    await mount()
    const completes = []

    el().addEventListener("poetry:mask:complete", (event) => completes.push(event.detail))
    await focus()

    type("1234")
    expect(completes).toEqual([{ raw: "1234", masked: "12/34", complete: true }])

    type("5") // full mask: swallowed, no re-fire
    expect(completes.length).toBe(1)

    press("Backspace") // below complete: re-armed
    type("4")
    expect(completes.length).toBe(2)
  })

  it("sets the pattern attribute from full-inexact unless one exists", async () => {
    await mount()
    expect(el().getAttribute("pattern")).toBe("[0-9][0-9]/[0-9][0-9]")

    await mount({ attrs: 'pattern="[0-9]*"' })
    expect(el().getAttribute("pattern")).toBe("[0-9]*")
  })

  it("upcase transforms before validation", async () => {
    await mount({ mask: "AAA", attrs: 'data-poetry--core--mask-upcase-value="true"' })
    await focus()

    type("abc")

    expect(el().value).toBe("ABC")
    expect(el().getAttribute("data-raw")).toBe("ABC")
  })

  it("mouseup clamps a collapsed caret into the filled region; selections stay", async () => {
    await mount()
    await focus()
    type("12") // processed "12/", display "12/__"

    caret(5) // out in the skeleton
    el().dispatchEvent(new MouseEvent("mouseup", { bubbles: true }))
    expect(el().selectionStart).toBe(3)

    caret(1, 4)
    el().dispatchEvent(new MouseEvent("mouseup", { bubbles: true }))
    expect(el().selectionStart).toBe(1)
    expect(el().selectionEnd).toBe(4)
  })

  it("mousedown clamps on the next frame", async () => {
    await mount()
    await focus()
    type("12")

    el().dispatchEvent(new MouseEvent("mousedown", { bubbles: true }))
    caret(5) // the click's caret placement, after mousedown
    await frame()

    expect(el().selectionStart).toBe(3)
  })
})
