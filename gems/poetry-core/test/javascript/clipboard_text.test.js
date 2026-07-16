import { afterEach, beforeEach, describe, expect, it, vi } from "vitest"
import { Application } from "@hotwired/stimulus"
import { registerPoetryControllers } from "@poetry/controllers"

// ClipboardText (the kumo contract): copy writes the input's value
// (or the textValue override), stamps data-copied for a beat, announces,
// and dispatches copied; the execCommand fallback restores the user's own
// selection and focus.

const nextFrame = () => new Promise((resolve) => setTimeout(resolve, 0))

const IDENTIFIER = "poetry--core--clipboard-text"

const el = (id) => document.getElementById(id)

const markup = ({ value = "npm install poetry", text = "" } = {}) => `
  <div id="root" data-controller="${IDENTIFIER}"
       data-${IDENTIFIER}-text-value="${text}"
       data-${IDENTIFIER}-message-value="Copied to clipboard">
    <input id="input" type="text" readonly value="${value}" data-${IDENTIFIER}-target="input">
    <button id="copy" data-action="click->${IDENTIFIER}#copy">Copy</button>
  </div>
  <p id="prose">select me</p>`

describe("poetry--core--clipboard-text", () => {
  let application
  let written

  beforeEach(async () => {
    document.body.innerHTML = `<div id="host"></div>`
    written = []
    Object.defineProperty(navigator, "clipboard", {
      configurable: true,
      value: { writeText: vi.fn(async (text) => written.push(text)) }
    })
    application = Application.start()
    registerPoetryControllers(application)
    await nextFrame()
    return async () => {
      el("host")?.replaceChildren()
      await nextFrame()
      application.stop()
    }
  })

  afterEach(() => {
    // Safety restore: a timed-out test never reaches its own useRealTimers,
    // and a leaked fake clock starves every later hook's setTimeout.
    vi.useRealTimers()
    delete navigator.clipboard
  })

  async function mount(options = {}) {
    el("host").innerHTML = markup(options)
    await nextFrame()
  }

  async function copy() {
    el("copy").click()
    await nextFrame()
  }

  it("copies the input value, stamps data-copied, and dispatches copied", async () => {
    await mount()
    const events = []
    el("root").addEventListener("poetry:clipboard-text:copied", (event) => events.push(event.detail.text))

    await copy()

    expect(written).toEqual(["npm install poetry"])
    expect(el("root").hasAttribute("data-copied")).toBe(true)
    expect(events).toEqual(["npm install poetry"])
  })

  it("copies a source target's textContent (the CodeBlock path)", async () => {
    el("host").innerHTML = `
      <div id="root" data-controller="poetry--core--clipboard-text"
           data-poetry--core--clipboard-text-message-value="">
        <code id="code" data-poetry--core--clipboard-text-target="source">gem "poetry-ui"</code>
        <button id="copy" data-action="click->poetry--core--clipboard-text#copy">Copy</button>
      </div>`
    await nextFrame()

    await copy()

    expect(written).toEqual([`gem "poetry-ui"`])
    expect(el("root").hasAttribute("data-copied")).toBe(true)
  })

  it("prefers the textValue override to the displayed value", async () => {
    await mount({ value: "poetry-core@0.1…", text: "poetry-core@0.1.0-full-digest" })

    await copy()

    expect(written).toEqual(["poetry-core@0.1.0-full-digest"])
  })

  it("clears data-copied after the copied beat", async () => {
    await mount()
    // Bounded advancement, never runAllTimersAsync: the announce singleton
    // keeps self-scheduling timers alive, so "all timers" never exhausts.
    vi.useFakeTimers()
    el("copy").click()
    await vi.advanceTimersByTimeAsync(50)

    expect(el("root").hasAttribute("data-copied")).toBe(true)

    await vi.advanceTimersByTimeAsync(1600)

    expect(el("root").hasAttribute("data-copied")).toBe(false)
    vi.useRealTimers()
  })

  it("announces through the live-region singleton", async () => {
    await mount()

    await copy()

    const region = document.querySelector("[aria-live=polite]")
    expect(region).not.toBeNull()
    await new Promise((resolve) => setTimeout(resolve, 150))
    expect(region.textContent).toContain("Copied to clipboard")
  })

  it("falls back to execCommand and restores the user's selection", async () => {
    await mount()
    navigator.clipboard.writeText = vi.fn(async () => {
      throw new Error("denied")
    })
    document.execCommand = vi.fn(() => true)

    const prose = el("prose").firstChild
    const range = document.createRange()
    range.setStart(prose, 0)
    range.setEnd(prose, 6)
    const selection = document.getSelection()
    selection.removeAllRanges()
    selection.addRange(range)

    await copy()

    expect(document.execCommand).toHaveBeenCalledWith("copy")
    expect(el("root").hasAttribute("data-copied")).toBe(true)
    expect(document.getSelection().toString()).toBe("select")
  })

  it("does not stamp data-copied when both clipboard paths fail", async () => {
    await mount()
    navigator.clipboard.writeText = vi.fn(async () => {
      throw new Error("denied")
    })
    document.execCommand = vi.fn(() => false)

    await copy()

    expect(el("root").hasAttribute("data-copied")).toBe(false)
  })
})
