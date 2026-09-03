import { beforeEach, describe, expect, it } from "vitest"
import { Application } from "@hotwired/stimulus"
import { registerPoetryControllers } from "@poetry/controllers"

// The segmented date/time editor (the segment model):
// segments build from formatToParts in locale order, digits accumulate
// with maxValue auto-advance, arrows fill-then-step, the native input
// stays THE form value (ISO), and blur constrains February 31st. What
// jsdom cannot see (real caret behavior, IME composition, VoiceOver's
// spinbutton focus) belongs to the browser pass.

const nextFrame = () => new Promise((resolve) => setTimeout(resolve, 0))

const IDENTIFIER = "poetry--core--date-field"

const el = (id) => document.getElementById(id)

const fieldMarkup = ({ type = "date", value = "", extra = "", locale = "en-US" } = {}) => `
  <div id="field" data-controller="${IDENTIFIER}"
       data-${IDENTIFIER}-locale-value="${locale}"
       data-${IDENTIFIER}-placeholder-value="${{ date: "2026-07-13", time: "12:00" }[type] ?? "2026-07-13T12:00"}"
       data-${IDENTIFIER}-labels-value='{"empty":"Empty","year":"year","month":"month","day":"day","hour":"hour","minute":"minute","second":"second","dayPeriod":"AM/PM"}'
       data-${IDENTIFIER}-placeholders-value='{"year":"yyyy","month":"mm","day":"dd","hour":"--","minute":"--","second":"--"}'
       ${extra}>
    <span id="group" role="presentation" data-${IDENTIFIER}-target="group"
          data-action="click->${IDENTIFIER}#focusGap focusout->${IDENTIFIER}#settle"></span>
    <input id="native" type="${type}" name="when" value="${value}"
           data-${IDENTIFIER}-target="input">
  </div>`

const segments = () => Array.from(document.querySelectorAll('[data-slot="date-field-segment"]'))
const segment = (type) => document.querySelector(`[data-slot="date-field-segment"][data-type="${type}"]`)

const press = (element, key, options = {}) =>
  element.dispatchEvent(new KeyboardEvent("keydown", { key, bubbles: true, cancelable: true, ...options }))

const type = (element, text) => {
  for (const char of text) {
    element.dispatchEvent(new InputEvent("beforeinput", {
      inputType: "insertText", data: char, bubbles: true, cancelable: true
    }))
  }
}

describe("poetry--core--date-field", () => {
  let application

  beforeEach(async () => {
    document.body.innerHTML = `<div id="host"></div>`
    application = Application.start()
    registerPoetryControllers(application)
    await nextFrame()
    return async () => {
      el("host")?.replaceChildren()
      await nextFrame()
      application.stop()
    }
  })

  async function mount(options = {}) {
    el("host").innerHTML = fieldMarkup(options)
    await nextFrame()
  }

  describe("build", () => {
    it("builds spinbutton segments in en-US order (month/day/year) with literals aria-hidden", async () => {
      await mount()

      expect(segments().map((s) => s.getAttribute("data-type"))).toEqual(["month", "day", "year"])
      expect(segments().every((s) => s.getAttribute("role") === "spinbutton")).toBe(true)
      expect(el("field").hasAttribute("data-enhanced")).toBe(true)

      const literal = document.querySelector('[data-slot="date-field-literal"]')

      expect(literal.getAttribute("aria-hidden")).toBe("true")
    })

    it("empty segments show their placeholder text, data-placeholder, and the Empty valuetext", async () => {
      await mount()

      expect(segment("year").textContent).toBe("yyyy")
      expect(segment("year").hasAttribute("data-placeholder")).toBe(true)
      expect(segment("year").getAttribute("aria-valuetext")).toBe("Empty")
      expect(segment("month").getAttribute("aria-valuemin")).toBe("1")
      expect(segment("month").getAttribute("aria-valuemax")).toBe("12")
    })

    it("a server value fills the segments (month enriched in valuetext)", async () => {
      await mount({ value: "2026-03-09" })

      expect(segment("year").textContent).toBe("2026")
      expect(segment("month").textContent).toBe("3")
      expect(segment("day").textContent).toBe("9")
      expect(segment("month").getAttribute("aria-valuetext")).toContain("March")
      expect(segment("month").hasAttribute("data-placeholder")).toBe(false)
    })

    it("a year-first locale reorders the segments AND keeps its digit style (en-CA pads to 2026-03-09)", async () => {
      await mount({ locale: "en-CA", value: "2026-03-09" })

      expect(segments().map((s) => s.getAttribute("data-type"))).toEqual(["year", "month", "day"])
      // The locale's own digit width, measured from the single-digit
      // probe: en-CA renders 2-digit month/day, en-US stays 1-digit.
      expect(segment("month").textContent).toBe("03")
      expect(segment("day").textContent).toBe("09")
      expect(segment("year").textContent).toBe("2026")
    })

    it("a time field builds hour/minute/dayPeriod under the en-US twelve-hour cycle", async () => {
      await mount({ type: "time", value: "13:05" })

      expect(segments().map((s) => s.getAttribute("data-type"))).toEqual(["hour", "minute", "dayPeriod"])
      expect(segment("hour").textContent).toBe("1")
      expect(segment("minute").textContent).toBe("05") // minutes pad
      expect(segment("dayPeriod").textContent).toBe("PM")
    })
  })

  describe("arrows (fill-then-step, wrap)", () => {
    it("the first ArrowUp on an empty segment lands on the placeholder value", async () => {
      await mount() // placeholder 2026-07-13

      press(segment("month"), "ArrowUp")
      expect(segment("month").textContent).toBe("7")

      press(segment("month"), "ArrowUp")
      expect(segment("month").textContent).toBe("8")
    })

    it("wraps at the limits and Home/End jump to them", async () => {
      await mount({ value: "2026-12-01" })

      press(segment("month"), "ArrowUp")
      expect(segment("month").textContent).toBe("1")

      press(segment("month"), "End")
      expect(segment("month").textContent).toBe("12")

      press(segment("month"), "Home")
      expect(segment("month").textContent).toBe("1")
    })

    it("PageUp steps by the page step, rounded to its multiple", async () => {
      await mount({ type: "time", value: "13:07" })

      press(segment("minute"), "PageUp")
      expect(segment("minute").textContent).toBe("15")
    })
  })

  describe("typing (digit accumulation)", () => {
    it("accumulating digits auto-advances when no further digit fits", async () => {
      await mount()

      segment("month").focus()
      type(segment("month"), "1")
      expect(segment("month").textContent).toBe("1") // 1 can extend to 10-12: no advance yet
      expect(document.activeElement).toBe(segment("month"))

      type(segment("month"), "2")
      expect(segment("month").textContent).toBe("12")
      expect(document.activeElement).toBe(segment("day")) // 12x can never fit
    })

    it("typing past the maximum restarts from the last key (3 then 5 is 5, never 35)", async () => {
      await mount()

      segment("month").focus()
      type(segment("month"), "3")
      expect(document.activeElement).toBe(segment("day")) // 3 auto-advanced (30 > 12)

      segment("month").focus()
      type(segment("month"), "5")
      expect(segment("month").textContent).toBe("5")
    })

    it("a completed date commits ISO to the native input and fires both change events", async () => {
      await mount()

      const changes = []

      el("native").addEventListener("change", () => changes.push("native"))
      el("field").addEventListener("poetry:date-field:change", (event) => changes.push(event.detail.value))

      segment("month").focus()
      type(segment("month"), "7")
      type(segment("day"), "13")
      type(segment("year"), "2026")

      expect(el("native").value).toBe("2026-07-13")
      expect(changes).toContain("native")
      expect(changes).toContain("2026-07-13")
    })

    it("Backspace chops a digit, then clears to placeholder", async () => {
      await mount({ value: "2026-07-13" })

      press(segment("year"), "Backspace")
      expect(segment("year").textContent).toBe("202")

      press(segment("year"), "Backspace")
      press(segment("year"), "Backspace")
      press(segment("year"), "Backspace")
      expect(segment("year").hasAttribute("data-placeholder")).toBe(true)
      expect(el("native").value).toBe("") // incomplete: the wire cleared
    })

    it("typing a/p sets the day period", async () => {
      await mount({ type: "time", value: "09:30" })

      expect(segment("dayPeriod").textContent).toBe("AM")

      press(segment("dayPeriod"), "p")
      expect(segment("dayPeriod").textContent).toBe("PM")
      expect(el("native").value).toBe("21:30")

      press(segment("dayPeriod"), "a")
      expect(el("native").value).toBe("09:30")
    })
  })

  describe("commit discipline", () => {
    it("February 31st is held off the wire mid-edit and constrained on blur", async () => {
      await mount({ value: "2020-01-31" })

      press(segment("month"), "ArrowUp") // 1 -> 2 while day is 31

      expect(el("native").value).toBe("2020-01-31") // invalid Feb 31: wire holds

      segment("month").dispatchEvent(new FocusEvent("focusout", { bubbles: true, relatedTarget: null }))

      expect(segment("day").textContent).toBe("29") // 2020 leap year clamp
      expect(el("native").value).toBe("2020-02-29")
    })

    it("readonly fields ignore every edit", async () => {
      await mount({ value: "2026-07-13", extra: "" })
      el("native").readOnly = true

      press(segment("month"), "ArrowUp")
      type(segment("month"), "3")

      expect(segment("month").textContent).toBe("7")
      expect(el("native").value).toBe("2026-07-13")
    })
  })

  describe("native validation routing", () => {
    it("the input's invalid event moves focus to the first empty segment", async () => {
      await mount()

      const event = new Event("invalid", { cancelable: true })

      el("native").dispatchEvent(event)

      expect(event.defaultPrevented).toBe(true)
      expect(document.activeElement).toBe(segment("month"))
    })
  })

  describe("labeling", () => {
    it("segments carry the field name with the label appended; only the first is described", async () => {
      document.body.insertAdjacentHTML("afterbegin", `<label for="native" id="lbl">Due date</label>`)
      await mount({ extra: "" })
      el("native").setAttribute("aria-describedby", "hint")
      // rebuild is not required for the describedby assertion: it was read
      // at build; re-mount with the attribute present instead.
      el("host").innerHTML = fieldMarkup({})
      el("host").querySelector("input").setAttribute("aria-describedby", "hint")
      await nextFrame()

      const labels = segments().map((s) => s.getAttribute("aria-label"))

      expect(labels[0]).toContain("month")
      expect(labels.every((label) => label.includes("Due date"))).toBe(true)
      expect(segments()[0].getAttribute("aria-describedby")).toBe("hint")
      expect(segments()[1].hasAttribute("aria-describedby")).toBe(false)
    })
  })

  describe("datetime-local (both runs in one row)", () => {
    it("builds the date segments then the time segments in locale order, from one ISO datetime", async () => {
      await mount({ type: "datetime-local", value: "2026-07-13T13:05" })

      expect(segments().map((s) => s.getAttribute("data-type")))
        .toEqual(["month", "day", "year", "hour", "minute", "dayPeriod"])
      expect(segment("year").textContent).toBe("2026")
      expect(segment("hour").textContent).toBe("1")
      expect(segment("minute").textContent).toBe("05")
      expect(segment("dayPeriod").textContent).toBe("PM")
    })

    it("writes the combined wire value only once both halves are complete", async () => {
      await mount({ type: "datetime-local" })

      type(segment("month"), "7")
      type(segment("day"), "13")
      type(segment("year"), "2026")
      expect(el("native").value).toBe("") // the time half is still empty

      type(segment("hour"), "1")
      type(segment("minute"), "05")
      press(segment("dayPeriod"), "ArrowUp")
      el("group").dispatchEvent(new FocusEvent("focusout", { bubbles: true, relatedTarget: document.body }))
      expect(el("native").value).toBe("2026-07-13T13:05")
    })

    it("carries seconds on the wire when the field declares them", async () => {
      await mount({ type: "datetime-local", value: "2026-07-13T09:30:15",
                    extra: `data-${IDENTIFIER}-seconds-value="true"` })

      expect(segments().map((s) => s.getAttribute("data-type")))
        .toEqual(["month", "day", "year", "hour", "minute", "second", "dayPeriod"])
      expect(segment("second").textContent).toBe("15")
    })

    it("holds the wire on February 31st exactly like a date field", async () => {
      await mount({ type: "datetime-local", value: "2026-02-10T08:00" })

      type(segment("day"), "31")
      el("group").dispatchEvent(new FocusEvent("focusout", { bubbles: true, relatedTarget: document.body }))
      expect(el("native").value).toBe("2026-02-28T08:00") // blur clamps the day into the month
    })
  })
})
