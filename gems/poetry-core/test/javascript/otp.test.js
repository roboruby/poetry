import { beforeEach, describe, expect, it } from "vitest"
import { Application } from "@hotwired/stimulus"
import { registerPoetryControllers } from "@poetry/controllers"

// poetry--core--otp JS-unit: the projection invariant (input.value ==
// painted cells, always), pattern filtering + paste splitting + truncation,
// the caret projection (data-active follows selectionStart, clamped at the
// last cell; the fake caret only on the active EMPTY cell), blur clearing,
// change per accepted mutation, and complete firing once per rise to full
// length (re-armed below it).

const nextFrame = () => new Promise((resolve) => setTimeout(resolve, 0))
const el = (id) => document.getElementById(id)

const markup = ({ length = 6, groups = null, pattern = "\\d", value = "", disabled = false } = {}) => {
  const clusters = groups ?? [length]
  let index = 0
  const chars = value.split("")
  const cells = clusters.map((size, g) => `
    <div data-slot="input-otp-group" class="flex items-center" aria-hidden="true">
      ${Array.from({ length: size }, () => `
        <div id="slot-${index}" data-slot="input-otp-slot" data-poetry--core--otp-target="slot"
             data-active="false">${chars[index++] ?? ""}<div data-slot="input-otp-caret" hidden><div></div></div></div>`).join("")}
    </div>
    ${g < clusters.length - 1 ? '<div data-slot="input-otp-separator" role="separator" aria-hidden="true"></div>' : ""}`)

  return `
    <form id="form">
      <div id="container" data-slot="input-otp-container" data-component="input-otp"
           data-controller="poetry--core--otp"
           data-poetry--core--otp-length-value="${length}"
           data-poetry--core--otp-pattern-value="${pattern}"
           data-action="click->poetry--core--otp#focusInput">
        <input id="otp" data-slot="input-otp" data-poetry--core--otp-target="input"
               type="text" name="code" value="${value}" maxlength="${length}"
               autocomplete="one-time-code" ${disabled ? "disabled" : ""}
               data-action="input->poetry--core--otp#sync focus->poetry--core--otp#sync blur->poetry--core--otp#sync paste->poetry--core--otp#paste">
        ${cells.join("")}
      </div>
    </form>`
}

async function mount(options = {}) {
  document.body.innerHTML = markup(options)
  const application = Application.start()
  registerPoetryControllers(application)
  await nextFrame()
  return application
}

// Types/pastes by writing the native input's value + caret, then firing the
// input event - what the platform does after an accepted edit.
const write = (value, caret = value.length) => {
  const input = el("otp")
  input.value = value
  input.setSelectionRange(caret, caret)
  input.dispatchEvent(new Event("input", { bubbles: true }))
}

const focus = () => {
  el("otp").focus()
  el("otp").dispatchEvent(new Event("focus", { bubbles: false }))
}

const painted = () =>
  Array.from(document.querySelectorAll("[data-slot=input-otp-slot]"))
    .map((slot) => (slot.firstChild?.nodeType === Node.TEXT_NODE ? slot.firstChild.data : ""))
    .join("")

const actives = () =>
  Array.from(document.querySelectorAll("[data-slot=input-otp-slot]")).map((slot) => slot.dataset.active)

const caretVisible = (index) => !el(`slot-${index}`).querySelector("[data-slot=input-otp-caret]").hidden

describe("poetry--core--otp", () => {
  let application

  beforeEach(async () => {
    application = await mount()
    return async () => {
      document.body.replaceChildren()
      await nextFrame()
      application.stop()
    }
  })

  it("typing fills cells left-to-right and the active cell advances with the native caret", () => {
    focus()

    write("1")
    expect(painted()).toBe("1")
    expect(el("otp").value).toBe("1")
    expect(actives()).toEqual(["false", "true", "false", "false", "false", "false"])

    write("12")
    expect(painted()).toBe("12")
    expect(actives()[2]).toBe("true")
  })

  it("backspace retreats the active cell (a projection of selectionStart)", () => {
    focus()
    write("123")
    expect(actives()[3]).toBe("true")

    write("12") // native backspace result: shorter value, caret at 2
    expect(painted()).toBe("12")
    expect(actives()[2]).toBe("true")
  })

  it("paste splits: filtering strips the junk and distributes from cell 0", () => {
    focus()
    write("123-456") // pasted with a separator

    expect(el("otp").value).toBe("123456")
    expect(painted()).toBe("123456")
  })

  it("a paste longer than length truncates", () => {
    focus()
    write("12345678")

    expect(el("otp").value).toBe("123456")
    expect(painted()).toBe("123456")
  })

  // The REAL paste path: maxlength truncates the raw clipboard text BEFORE
  // the input event ("123-456" loses its 6 to the dash), so the controller
  // intercepts the paste event and filters FIRST (2026-07-03 browser pass;
  // jsdom doesn't enforce maxlength, so write() alone can't cover this).
  describe("the paste event", () => {
    const paste = (text) => {
      const event = new Event("paste", { bubbles: true, cancelable: true })
      event.clipboardData = { getData: () => text }
      el("otp").dispatchEvent(event)
      return event
    }

    it("filters the clipboard text before insertion - the full code survives its separators", () => {
      focus()
      const event = paste("123-456")

      expect(event.defaultPrevented).toBe(true)
      expect(el("otp").value).toBe("123456")
      expect(painted()).toBe("123456")
    })

    it("splices at the selection and truncates to length", () => {
      focus()
      write("12")
      paste("999 999 999")

      expect(el("otp").value).toBe("129999")
      expect(painted()).toBe("129999")
    })

    it("a paste over a full selection replaces the value", () => {
      focus()
      write("111111")
      el("otp").setSelectionRange(0, 6)
      paste("22-33 44")

      expect(el("otp").value).toBe("223344")
    })

    it("an all-junk paste is a no-op mutation (no change event)", () => {
      focus()
      write("12")
      const events = []
      el("container").addEventListener("poetry:otp:change", (event) => events.push(event.detail.value))
      paste("---")

      expect(el("otp").value).toBe("12")
      expect(events).toEqual([])
    })
  })

  it("pattern-rejected characters never paint", () => {
    focus()
    write("1a2b")

    expect(el("otp").value).toBe("12")
    expect(painted()).toBe("12")
  })

  it("alphanumeric pattern accepts letters", async () => {
    application.stop()
    application = await mount({ pattern: "[a-zA-Z0-9]" })

    focus()
    write("A1B2")

    expect(painted()).toBe("A1B2")
  })

  it("the caret cell clamps to the LAST slot when complete; the fake caret shows only on the active EMPTY cell", () => {
    focus()
    write("")
    expect(actives()[0]).toBe("true")
    expect(caretVisible(0)).toBe(true) // empty active cell blinks

    write("123456")
    expect(actives()).toEqual(["false", "false", "false", "false", "false", "true"]) // clamped to length-1
    expect(caretVisible(5)).toBe(false) // filled active cell: ring only
  })

  it("arrow-key caret moves re-project via selectionchange", async () => {
    focus()
    write("123")

    el("otp").setSelectionRange(1, 1) // ArrowLeft x2, natively
    document.dispatchEvent(new Event("selectionchange"))

    expect(actives()).toEqual(["false", "true", "false", "false", "false", "false"])
  })

  it("blur clears the active cell and the caret", () => {
    focus()
    write("1")
    expect(actives().includes("true")).toBe(true)

    el("otp").blur()
    el("otp").dispatchEvent(new Event("blur", { bubbles: false }))

    expect(actives()).toEqual(["false", "false", "false", "false", "false", "false"])
    expect(caretVisible(1)).toBe(false)
  })

  it("change fires per accepted mutation with {value, complete}", () => {
    const seen = []
    el("container").addEventListener("poetry:otp:change", (event) => seen.push(event.detail))

    focus()
    write("1")
    write("12")
    write("12") // no mutation - filtered value unchanged

    expect(seen).toEqual([
      { value: "1", complete: false },
      { value: "12", complete: false }
    ])
  })

  it("complete fires once at full length and re-arms when edited below", () => {
    const completes = []
    el("container").addEventListener("poetry:otp:complete", (event) => completes.push(event.detail))

    focus()
    write("123456")
    expect(completes).toEqual([{ value: "123456" }])

    el("otp").setSelectionRange(6, 6)
    document.dispatchEvent(new Event("selectionchange")) // caret churn: no re-fire
    expect(completes.length).toBe(1)

    write("12345") // edited below length: re-armed
    write("123450")
    expect(completes.length).toBe(2)
  })

  it("focusInput focuses the real control from a container click (gaps/separators)", () => {
    el("container").dispatchEvent(new MouseEvent("click", { bubbles: true }))

    expect(document.activeElement).toBe(el("otp"))
  })

  it("focusInput no-ops when disabled", async () => {
    application.stop()
    application = await mount({ disabled: true })

    el("container").dispatchEvent(new MouseEvent("click", { bubbles: true }))

    expect(document.activeElement).not.toBe(el("otp"))
  })

  it("server-rendered value paints on connect (grouped cells flatten in order)", async () => {
    application.stop()
    application = await mount({ groups: [3, 3], value: "987" })

    expect(painted()).toBe("987")
    expect(el("otp").value).toBe("987")
  })

  it("the projection invariant holds after a programmatic autofill-style write", () => {
    focus()
    el("otp").value = "555555"
    el("otp").dispatchEvent(new Event("input", { bubbles: true }))

    expect(painted()).toBe("555555")
    expect(el("otp").value).toBe(painted())
  })
})
