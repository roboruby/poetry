import { beforeEach, describe, expect, it } from "vitest"
import { Application } from "@hotwired/stimulus"
import { registerPoetryControllers } from "@poetry/controllers"

// poetry--core--command JS-unit (Command): the
// activedescendant palette engine. The filter pass is HIDE-ONLY (childNodes
// order asserted before/after - DOM order is the ranking authority), the
// highlight is the data-highlighted + aria-activedescendant twin-write with
// real focus pinned to the input, activation is a cancelable event and
// nothing more (engine purity - Combobox's build dependency), and the three
// cmdk deltas are pinned: Home/End move the CARET, Space types, and
// aria-selected is NEVER written by this controller.

const nextFrame = () => new Promise((resolve) => setTimeout(resolve, 0))
const wait = (ms) => new Promise((resolve) => setTimeout(resolve, ms))
const el = (id) => document.getElementById(id)

const press = (element, key, options = {}) => {
  const event = new KeyboardEvent("keydown", { key, bubbles: true, cancelable: true, ...options })
  element.dispatchEvent(event)
  return event
}

const type = (query) => {
  el("input").value = query
  el("input").dispatchEvent(new Event("input", { bubbles: true }))
}

const pointermove = (element) =>
  element.dispatchEvent(new Event("pointermove", { bubbles: true }))

// The cmdk-demo item set: two groups + a separator; Calendar carries
// keywords, Calculator can be disabled per test.
const GROUPS = [
  ["suggestions", "Suggestions", [
    ["calendar", "Calendar", { keywords: "schedule dates" }],
    ["search-emoji", "Search Emoji", {}],
    ["calculator", "Calculator", {}]
  ]],
  ["settings", "Settings", [
    ["profile", "Profile", {}],
    ["billing", "Billing", {}],
    ["settings", "Settings", {}]
  ]]
]

const itemHtml = ([value, label, options], { disabledValues, highlightedValue }) => `
  <div id="item-${value}" data-slot="command-item" role="option"
       data-poetry-collection-item data-value="${value}"
       ${options.keywords ? `data-keywords="${options.keywords}"` : ""}
       ${options.filterValue ? `data-filter-value="${options.filterValue}"` : ""}
       ${options.alwaysRender ? "data-always-render" : ""}
       ${disabledValues.includes(value) ? 'data-disabled aria-disabled="true"' : ""}
       ${highlightedValue === value ? "data-highlighted" : ""}
       data-action="click->poetry--core--command#activate pointermove->poetry--core--command#pointerHighlight">
    <span data-slot="command-item-text">${label}</span>
  </div>`

const markup = ({ filter = true, loop = false, disabledValues = [], highlightedValue = null, extraItems = "" } = {}) => `
  <div id="root" data-slot="command" data-component="command"
       data-controller="poetry--core--command"
       data-poetry--core--command-filter-value="${filter}"
       data-poetry--core--command-loop-value="${loop}">
    <div data-slot="command-input-wrapper">
      <input id="input" data-slot="command-input" type="text" role="combobox"
             aria-expanded="true" aria-controls="list" aria-autocomplete="list"
             autocomplete="off" autocorrect="off" spellcheck="false"
             data-action="input->poetry--core--command#filterInput keydown->poetry--core--command#keydown">
    </div>
    <div id="list" data-slot="command-list" role="listbox" tabindex="-1" aria-label="Commands">
      <div id="empty" data-slot="command-empty" hidden>No results found.</div>
      ${GROUPS.map(([slug, heading, items]) => `
        <div id="group-${slug}" data-slot="command-group" role="group" aria-labelledby="heading-${slug}">
          <div id="heading-${slug}" data-slot="command-group-heading">${heading}</div>
          ${items.map((item) => itemHtml(item, { disabledValues, highlightedValue })).join("")}
        </div>`).join(`
        <div id="separator" data-slot="command-separator" role="separator"></div>`)}
      ${extraItems}
    </div>
    <span id="status" data-slot="command-status" role="status" aria-live="polite"
          data-zero="0 results" data-one="1 result" data-other="%{count} results"></span>
  </div>`

const ALL_VALUES = GROUPS.flatMap(([, , items]) => items.map(([value]) => value))
const visibleValues = () =>
  ALL_VALUES.filter((value) => !el(`item-${value}`).closest("[hidden]"))
const highlightedId = () => document.querySelector("[data-highlighted]")?.id ?? null
const activedescendant = () => el("input").getAttribute("aria-activedescendant")

async function mount(options = {}) {
  document.body.innerHTML = markup(options)
  const application = Application.start()
  registerPoetryControllers(application)
  await nextFrame()
  return application
}

describe("poetry--core--command", () => {
  let application

  beforeEach(async () => {
    application = await mount()
    return async () => {
      document.body.replaceChildren()
      await nextFrame()
      application.stop()
    }
  })

  describe("connect", () => {
    it("seats the initial highlight on the first enabled item and twin-writes activedescendant", () => {
      expect(highlightedId()).toBe("item-calendar")
      expect(activedescendant()).toBe("item-calendar")
    })

    it("respects a server-rendered data-highlighted seed (the value: option)", async () => {
      application.stop()
      application = await mount({ highlightedValue: "profile" })

      expect(highlightedId()).toBe("item-profile")
      expect(activedescendant()).toBe("item-profile")
    })

    it("skips a disabled first item when seating", async () => {
      application.stop()
      application = await mount({ disabledValues: ["calendar"] })

      expect(highlightedId()).toBe("item-search-emoji")
    })

    it("reconciles a non-empty input silently (morph/stream re-render)", async () => {
      application.stop()
      document.body.innerHTML = markup()
      el("input").value = "cal"
      application = Application.start()
      registerPoetryControllers(application)
      await nextFrame()

      expect(visibleValues()).toEqual(["calendar", "calculator"])
      expect(highlightedId()).toBe("item-calendar")
      expect(el("status").textContent).toBe("") // silent: no announcement for server-declared state
    })
  })

  describe("the filter pass", () => {
    it("hides score-0 items (hidden + data-hidden) and keeps matches, hide-only", () => {
      type("cal")

      expect(visibleValues()).toEqual(["calendar", "calculator"])

      const hiddenItem = el("item-profile")
      expect(hiddenItem.hasAttribute("hidden")).toBe(true)
      expect(hiddenItem.hasAttribute("data-hidden")).toBe(true)

      type("")

      expect(visibleValues()).toEqual(ALL_VALUES)
      expect(hiddenItem.hasAttribute("hidden")).toBe(false)
      expect(hiddenItem.hasAttribute("data-hidden")).toBe(false)
    })

    it("NEVER reorders the DOM (order asserted before/after a pass)", () => {
      const order = () => Array.from(el("list").querySelectorAll("[data-slot=command-item]")).map((item) => item.id)
      const before = order()

      type("s") // mixed bands: keyword (calendar) + prefix (search-emoji, settings)

      expect(order()).toEqual(before)

      type("")

      expect(order()).toEqual(before)
    })

    it("hides a group when ALL its items hide; separators hide whenever the query is non-empty", () => {
      type("cal")

      expect(el("group-suggestions").hasAttribute("hidden")).toBe(false)
      expect(el("group-settings").hasAttribute("hidden")).toBe(true)
      expect(el("separator").hasAttribute("hidden")).toBe(true)

      type("")

      expect(el("group-settings").hasAttribute("hidden")).toBe(false)
      expect(el("separator").hasAttribute("hidden")).toBe(false)
    })

    it("re-seats the highlight on the top score band, DOM order breaking ties", () => {
      // "s": calendar matches by KEYWORD (1, first in DOM), search-emoji and
      // settings by PREFIX (4) - the band outranks DOM position...
      type("s")

      expect(visibleValues()).toEqual(["calendar", "search-emoji", "settings"])
      expect(highlightedId()).toBe("item-search-emoji")

      // ...and DOM order breaks the tie within the prefix band.
      type("cal") // calendar + calculator both prefix (4)

      expect(highlightedId()).toBe("item-calendar")
    })

    it("matches by keywords and by data-filter-value", async () => {
      type("sched") // calendar's keyword

      expect(visibleValues()).toEqual(["calendar"])

      application.stop()
      application = await mount({
        extraItems: `<div id="item-rich" data-slot="command-item" role="option"
                          data-poetry-collection-item data-value="rich" data-filter-value="Zebra">
                       <span data-slot="command-item-text">🦓</span>
                     </div>`
      })
      type("zeb")

      expect(el("item-rich").hasAttribute("hidden")).toBe(false)
      expect(el("item-calendar").hasAttribute("hidden")).toBe(true)
    })

    it("zero match: everything hides, the empty part shows, both highlight writes clear", () => {
      type("zzz")

      expect(visibleValues()).toEqual([])
      expect(el("empty").hidden).toBe(false)
      expect(highlightedId()).toBeNull()
      expect(activedescendant()).toBeNull()

      type("cal")

      expect(el("empty").hidden).toBe(true)
      expect(highlightedId()).toBe("item-calendar")
    })

    it("data-always-render items survive a non-matching query", async () => {
      application.stop()
      application = await mount({
        extraItems: `<div id="item-pinned" data-slot="command-item" role="option"
                          data-poetry-collection-item data-value="pinned" data-always-render>
                       <span data-slot="command-item-text">Recent</span>
                     </div>`
      })
      type("zzz")

      expect(el("item-pinned").hasAttribute("hidden")).toBe(false)
      expect(el("item-pinned").hasAttribute("data-hidden")).toBe(false)
      expect(el("empty").hidden).toBe(true) // still one visible item
    })

    it("dispatches poetry:command:filter {query, visible} after each pass", () => {
      const events = []
      el("root").addEventListener("poetry:command:filter", (event) => events.push(event.detail))

      type("cal")
      type("zzz")

      expect(events).toEqual([{ query: "cal", visible: 2 }, { query: "zzz", visible: 0 }])
    })

    it("stream-appended items join the next pass (the DOM is the store)", () => {
      el("group-suggestions").insertAdjacentHTML("beforeend", `
        <div id="item-late" data-slot="command-item" role="option"
             data-poetry-collection-item data-value="late">
          <span data-slot="command-item-text">Later Addition</span>
        </div>`)

      type("late")

      expect(el("item-late").hasAttribute("hidden")).toBe(false)
      expect(el("item-calendar").hasAttribute("hidden")).toBe(true)
      expect(highlightedId()).toBe("item-late")
    })

    it("filter:false skips hiding entirely but still re-seats highlight + announces", async () => {
      application.stop()
      application = await mount({ filter: false })

      const events = []
      el("root").addEventListener("poetry:command:filter", (event) => events.push(event.detail))

      type("bil")

      expect(visibleValues()).toEqual(ALL_VALUES) // the server owns visibility
      expect(highlightedId()).toBe("item-billing") // top score still seats
      expect(events).toEqual([{ query: "bil", visible: 6 }])
    })
  })

  describe("the status live region", () => {
    it("announces the debounced result count once per keystroke burst", async () => {
      type("c")
      type("ca")
      type("cal")

      expect(el("status").textContent).toBe("") // debounced - nothing yet

      await wait(150)

      expect(el("status").textContent).toBe("2 results")
    })

    it("uses the zero / one templates", async () => {
      type("zzz")
      await wait(150)
      expect(el("status").textContent).toBe("0 results")

      type("sched")
      await wait(150)
      expect(el("status").textContent).toBe("1 result")
    })
  })

  describe("the activedescendant keyboard map", () => {
    it("ArrowDown / ArrowUp move the highlight over visible enabled items; focus never leaves the input", () => {
      el("input").focus()

      press(el("input"), "ArrowDown")
      expect(highlightedId()).toBe("item-search-emoji")
      expect(activedescendant()).toBe("item-search-emoji")

      press(el("input"), "ArrowUp")
      expect(highlightedId()).toBe("item-calendar")
      expect(document.activeElement).toBe(el("input"))
    })

    it("arrows prevent default (the caret never moves vertically)", () => {
      expect(press(el("input"), "ArrowDown").defaultPrevented).toBe(true)
      expect(press(el("input"), "ArrowUp").defaultPrevented).toBe(true)
    })

    it("loop:false stops at the ends; loop:true wraps", async () => {
      press(el("input"), "ArrowUp") // already first
      expect(highlightedId()).toBe("item-calendar")

      application.stop()
      application = await mount({ loop: true })

      press(el("input"), "ArrowUp")
      expect(highlightedId()).toBe("item-settings") // wrapped to last
      press(el("input"), "ArrowDown")
      expect(highlightedId()).toBe("item-calendar") // and back
    })

    it("Meta/Ctrl+Arrows jump to the last / first visible enabled item (cmdk parity)", () => {
      press(el("input"), "ArrowDown", { metaKey: true })
      expect(highlightedId()).toBe("item-settings")

      press(el("input"), "ArrowUp", { ctrlKey: true })
      expect(highlightedId()).toBe("item-calendar")
    })

    it("arrows walk visible ∩ enabled only (hidden and disabled skipped)", async () => {
      application.stop()
      application = await mount({ disabledValues: ["search-emoji"] })

      type("c") // visible: calendar (prefix), calculator (prefix), search-emoji... hidden? "search emoji" has no c... yes hidden

      expect(highlightedId()).toBe("item-calendar")
      press(el("input"), "ArrowDown")
      expect(highlightedId()).toBe("item-calculator") // search-emoji hidden AND disabled - skipped
    })

    it("hidden item ids never land in aria-activedescendant", () => {
      type("cal")
      press(el("input"), "ArrowDown", { metaKey: true })

      expect(activedescendant()).toBe("item-calculator")
      expect(el(activedescendant()).closest("[hidden]")).toBeNull()
    })

    it("Home / End / ArrowLeft / ArrowRight fall through to the input (caret, not list - the cmdk delta)", () => {
      type("cal")
      const seatBefore = highlightedId()

      for (const key of ["Home", "End", "ArrowLeft", "ArrowRight"]) {
        expect(press(el("input"), key).defaultPrevented).toBe(false)
      }

      expect(highlightedId()).toBe(seatBefore)
    })

    it("Space types a space - never activates (the family delta vs Select/menus)", () => {
      let selected = false
      el("root").addEventListener("poetry:command:select", () => { selected = true })

      expect(press(el("input"), " ").defaultPrevented).toBe(false)
      expect(selected).toBe(false)
    })

    it("Esc and Tab are NOT handled (the hosting layer owns them)", () => {
      expect(press(el("input"), "Escape").defaultPrevented).toBe(false)
      expect(press(el("input"), "Tab").defaultPrevented).toBe(false)
    })
  })

  describe("activation (an event, not an action)", () => {
    it("Enter dispatches cancelable poetry:command:select for the highlighted item and prevents default", () => {
      let detail = null
      let cancelable = false
      el("root").addEventListener("poetry:command:select", (event) => {
        detail = event.detail
        cancelable = event.cancelable
      })

      const event = press(el("input"), "Enter")

      expect(event.defaultPrevented).toBe(true)
      expect(cancelable).toBe(true)
      expect(detail.value).toBe("calendar")
      expect(detail.label).toBe("Calendar")
      expect(detail.item).toBe(el("item-calendar"))
    })

    it("click on an item activates it; the controller performs NO default action beyond the event", () => {
      let value = null
      el("root").addEventListener("poetry:command:select", (event) => { value = event.detail.value })

      el("item-billing").dispatchEvent(new MouseEvent("click", { bubbles: true, cancelable: true }))

      expect(value).toBe("billing")
      // Engine purity: nothing hidden, nothing selected, input untouched.
      expect(visibleValues()).toEqual(ALL_VALUES)
      expect(el("input").value).toBe("")
    })

    it("disabled items are activation no-ops", async () => {
      application.stop()
      application = await mount({ disabledValues: ["calendar"] })

      let selected = false
      el("root").addEventListener("poetry:command:select", () => { selected = true })

      el("item-calendar").dispatchEvent(new MouseEvent("click", { bubbles: true, cancelable: true }))

      expect(selected).toBe(false)
    })

    it("Enter with zero matches is a no-op", () => {
      type("zzz")

      let selected = false
      el("root").addEventListener("poetry:command:select", () => { selected = true })

      press(el("input"), "Enter")

      expect(selected).toBe(false)
    })
  })

  describe("pointer highlight", () => {
    it("pointermove highlights (twin-write); leaving the list does NOT clear (cmdk-exact)", () => {
      pointermove(el("item-billing"))

      expect(highlightedId()).toBe("item-billing")
      expect(activedescendant()).toBe("item-billing")

      el("list").dispatchEvent(new Event("pointerleave", { bubbles: true }))

      expect(highlightedId()).toBe("item-billing")
    })

    it("dispatches poetry:command:highlight when the activedescendant moves", () => {
      const values = []
      el("root").addEventListener("poetry:command:highlight", (event) => values.push(event.detail.value))

      pointermove(el("item-profile"))
      press(el("input"), "ArrowDown")

      expect(values).toEqual(["profile", "billing"])
    })

    it("disabled items never take pointer highlight", async () => {
      application.stop()
      application = await mount({ disabledValues: ["billing"] })

      pointermove(el("item-billing"))

      expect(highlightedId()).toBe("item-calendar") // the connect seat, unmoved
    })
  })

  describe("engine purity (the Combobox build dependency)", () => {
    it("never writes aria-selected or tabindex on options through a full session", () => {
      type("cal")
      press(el("input"), "ArrowDown")
      press(el("input"), "Enter")
      type("")

      for (const value of ALL_VALUES) {
        expect(el(`item-${value}`).hasAttribute("aria-selected")).toBe(false)
        expect(el(`item-${value}`).hasAttribute("tabindex")).toBe(false)
      }
    })
  })

  describe("the composition surface", () => {
    it("highlightItem seats a given option; reset clears the query and silently re-derives", async () => {
      const command = application.getControllerForElementAndIdentifier(el("root"), "poetry--core--command")

      command.highlightItem(el("item-settings"))
      expect(highlightedId()).toBe("item-settings")

      type("cal")
      expect(visibleValues()).toEqual(["calendar", "calculator"])

      command.reset()
      await wait(150)

      expect(el("input").value).toBe("")
      expect(visibleValues()).toEqual(ALL_VALUES)
      expect(highlightedId()).toBe("item-calendar")
    })

    it("a reset under a HIDDEN popup never unhides the empty part (the reopen 'No results' flash)", async () => {
      const command = application.getControllerForElementAndIdentifier(el("root"), "poetry--core--command")

      type("cal")
      expect(el("empty").hidden).toBe(true)

      // The host's close path hides the whole popup FIRST, then resets the
      // query - items above the list must not count as filtered out.
      el("root").hidden = true
      command.reset()
      await wait(150)

      expect(el("empty").hidden).toBe(true)
      expect(el("input").value).toBe("")

      el("root").hidden = false
    })
  })
})
