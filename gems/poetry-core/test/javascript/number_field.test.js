import { afterEach, beforeEach, describe, expect, it, vi } from "vitest"
import { Application } from "@hotwired/stimulus"
import { registerPoetryControllers } from "@poetry/controllers"

const nextFrame = () => new Promise((resolve) => setTimeout(resolve, 0))

function mount({ value = "", min, max, step, snap, format, wheel } = {}) {
  const values = [
    min !== undefined && `data-poetry--core--number-field-min-value="${min}"`,
    max !== undefined && `data-poetry--core--number-field-max-value="${max}"`,
    step !== undefined && `data-poetry--core--number-field-step-value="${step}"`,
    snap ? 'data-poetry--core--number-field-snap-value="true"' : null,
    wheel ? 'data-poetry--core--number-field-wheel-value="true"' : null,
    format && `data-poetry--core--number-field-format-value='${JSON.stringify(format)}'`
  ].filter(Boolean).join(" ")

  document.body.innerHTML = `
    <div id="root" data-controller="poetry--core--number-field" ${values}
         data-poetry--core--number-field-locale-value="en-US">
      <button id="dec" data-poetry--core--number-field-target="decrement"
              data-action="pointerdown->poetry--core--number-field#press click->poetry--core--number-field#tap pointerleave->poetry--core--number-field#leave">-</button>
      <input id="input" type="text" data-poetry--core--number-field-target="input"
             data-action="keydown->poetry--core--number-field#keydown input->poetry--core--number-field#input focus->poetry--core--number-field#focus blur->poetry--core--number-field#blur">
      <button id="inc" data-poetry--core--number-field-target="increment"
              data-action="pointerdown->poetry--core--number-field#press click->poetry--core--number-field#tap pointerleave->poetry--core--number-field#leave">+</button>
      <input id="hidden" type="number" hidden value="${value}"
             data-poetry--core--number-field-target="hidden"
             data-action="change->poetry--core--number-field#hiddenChanged">
    </div>`
}

const el = (id) => document.getElementById(id)
const type = (text) => {
  el("input").value = text
  el("input").dispatchEvent(new Event("input", { bubbles: true }))
}
const key = (props) => el("input").dispatchEvent(
  new KeyboardEvent("keydown", { bubbles: true, cancelable: true, ...props })
)

describe("poetry--core--number-field", () => {
  let application

  beforeEach(async () => {
    application = Application.start()
    registerPoetryControllers(application)
  })

  afterEach(() => {
    application.stop()
    vi.useRealTimers()
  })

  it("formats the server value on connect and syncs the two-input pair", async () => {
    mount({ value: "1234.5", format: { style: "currency", currency: "USD" } })
    await nextFrame()

    expect(el("input").value).toBe("$1,234.50")
    expect(el("hidden").value).toBe("1234.5")
    expect(el("root").hasAttribute("data-filled")).toBe(true)
  })

  it("arrows step with Shift large / Alt small and commit each press", async () => {
    mount({ value: "10" })
    await nextFrame()

    const commits = []
    el("root").addEventListener("poetry:number-field:commit", (e) => commits.push(e.detail.value))

    key({ key: "ArrowUp" })
    expect(el("hidden").value).toBe("11")
    key({ key: "ArrowUp", shiftKey: true })
    expect(el("hidden").value).toBe("21")
    key({ key: "ArrowDown", altKey: true })
    expect(el("hidden").value).toBe("20.9")
    expect(commits).toEqual([11, 21, 20.9])
  })

  it("steps from empty by seeding 0 clamped into range", async () => {
    mount({ min: -100, max: -5 })
    await nextFrame()

    key({ key: "ArrowUp" })

    expect(el("hidden").value).toBe("-5")
  })

  it("float noise is cleaned: 0.1 + 0.2 steps to 0.3", async () => {
    mount({ value: "0.2", step: 0.1 })
    await nextFrame()

    key({ key: "ArrowUp" })

    expect(el("hidden").value).toBe("0.3")
  })

  it("Home/End jump to the defined bounds only", async () => {
    mount({ value: "50", min: 5, max: 95 })
    await nextFrame()

    key({ key: "End" })
    expect(el("hidden").value).toBe("95")
    key({ key: "Home" })
    expect(el("hidden").value).toBe("5")
  })

  it("typing goes live only when parseable and never rewrites the display", async () => {
    mount()
    await nextFrame()

    const changes = []
    el("root").addEventListener("poetry:number-field:change", (e) => changes.push(e.detail.value))

    type("-")
    expect(changes).toEqual([])
    type("-4")
    expect(changes).toEqual([-4])
    expect(el("input").value).toBe("-4")
    expect(el("hidden").value).toBe("-4")
  })

  it("blur clamps, normalizes the display, and commits; unparseable text is left alone", async () => {
    mount({ min: 0, max: 10 })
    await nextFrame()

    type("42")
    el("input").dispatchEvent(new Event("blur"))
    expect(el("input").value).toBe("10")
    expect(el("hidden").value).toBe("10")

    type("10abc") // gate bypassed via direct set - the input event path
    el("input").value = "abc"
    el("input").dispatchEvent(new Event("blur"))

    expect(el("input").value).toBe("abc")
    expect(el("hidden").value).toBe("10")
  })

  it("blur on an emptied field clears to null", async () => {
    mount({ value: "7" })
    await nextFrame()

    type("")
    el("input").dispatchEvent(new Event("blur"))

    expect(el("hidden").value).toBe("")
    expect(el("root").hasAttribute("data-filled")).toBe(false)
  })

  it("press-and-hold repeats after 400ms every 60ms, stops at the bound, commits once", async () => {
    vi.useFakeTimers()
    mount({ value: "0", max: 5 })
    await vi.advanceTimersByTimeAsync(0)

    const commits = []
    el("root").addEventListener("poetry:number-field:commit", () => commits.push(el("hidden").value))

    el("inc").dispatchEvent(new MouseEvent("pointerdown", { bubbles: true, button: 0 }))
    expect(el("hidden").value).toBe("1")

    await vi.advanceTimersByTimeAsync(400 + 60 * 3)
    expect(el("hidden").value).toBe("4")

    await vi.advanceTimersByTimeAsync(60 * 10) // reaches 5, then boundary stops the repeat
    expect(el("hidden").value).toBe("5")
    expect(el("inc").disabled).toBe(true)

    window.dispatchEvent(new MouseEvent("pointerup", { bubbles: true }))
    expect(commits).toEqual(["5"])
  })

  it("a quick tap (click without prior pointerdown tick) steps exactly once", async () => {
    mount({ value: "1" })
    await nextFrame()

    el("inc").dispatchEvent(new MouseEvent("pointerdown", { bubbles: true, button: 0 }))
    el("inc").dispatchEvent(new MouseEvent("click", { bubbles: true }))
    expect(el("hidden").value).toBe("2")

    el("inc").dispatchEvent(new MouseEvent("click", { bubbles: true }))
    expect(el("hidden").value).toBe("3")
  })

  it("snap mode floors/ceils to step multiples directionally", async () => {
    mount({ value: "7", step: 5, snap: true, min: 0 })
    await nextFrame()

    key({ key: "ArrowUp" })
    expect(el("hidden").value).toBe("10")
    key({ key: "ArrowDown" })
    expect(el("hidden").value).toBe("5")
  })

  it("keydown gates characters: letters blocked, format symbols and one minus allowed", async () => {
    mount({ min: -10 })
    await nextFrame()

    expect(key({ key: "x" })).toBe(false) // preventDefault -> dispatch returns false
    expect(key({ key: "7" })).toBe(true)
    expect(key({ key: "-" })).toBe(true)
    el("input").value = "-7"
    expect(key({ key: "-" })).toBe(false) // second minus blocked

    mount({ min: 0 })
    await nextFrame()

    expect(key({ key: "-" })).toBe(false) // min >= 0 blocks minus entirely
  })

  it("percent format parses display text back to the fraction", async () => {
    mount({ value: "0.25", format: { style: "percent" } })
    await nextFrame()

    expect(el("input").value).toBe("25%")
    type("40%")
    expect(el("hidden").value).toBe("0.4")
  })

  it("locale group separators parse: en-US thousands", async () => {
    mount({ format: { useGrouping: true } })
    await nextFrame()

    type("1,234,567.5")

    expect(el("hidden").value).toBe("1234567.5")
  })

  it("wheel steps only when opted in and focused; ctrl+wheel passes through", async () => {
    mount({ value: "5", wheel: true })
    await nextFrame()

    el("input").dispatchEvent(new WheelEvent("wheel", { deltaY: -1, cancelable: true }))
    expect(el("hidden").value).toBe("5") // not focused

    el("input").focus()
    el("input").dispatchEvent(new WheelEvent("wheel", { deltaY: -1, cancelable: true }))
    expect(el("hidden").value).toBe("6")
    el("input").dispatchEvent(new WheelEvent("wheel", { deltaY: 1, ctrlKey: true, cancelable: true }))
    expect(el("hidden").value).toBe("6")
  })

  it("autofill on the hidden input is adopted and clamped", async () => {
    mount({ min: 0, max: 50 })
    await nextFrame()

    el("hidden").value = "120"
    el("hidden").dispatchEvent(new Event("change", { bubbles: true }))

    expect(el("input").value).toBe("50")
    expect(el("hidden").value).toBe("50")
  })
})
