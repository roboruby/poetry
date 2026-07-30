import { beforeEach, describe, expect, it } from "vitest"
import { Application } from "@hotwired/stimulus"
import { registerPoetryControllers } from "@poetry/controllers"

// poetry--core--select JS-unit (geometry-free; popper is markup-owned and
// exercised in its own suite): the listbox state machine - open focuses the
// SELECTED option for every reason, the 5-step commit pipeline in order
// (native select FIRST + real change/input), the cancelable select event,
// the three menu-family deltas (Tab inert, closed-trigger typeahead
// commits, Left/Right no-ops), autofill adoption via nativeChanged, Esc
// no-commit, scroll-button visibility, and reconcile-on-connect.

const nextFrame = () => new Promise((resolve) => setTimeout(resolve, 0))
const flushMicrotasks = () => Promise.resolve().then(() => Promise.resolve())
const el = (id) => document.getElementById(id)

const press = (element, key, options = {}) =>
  element.dispatchEvent(new KeyboardEvent("keydown", { key, bubbles: true, cancelable: true, ...options }))

const click = (element) =>
  element.dispatchEvent(new MouseEvent("click", { bubbles: true, cancelable: true }))

const pressEscape = () =>
  window.dispatchEvent(new KeyboardEvent("keydown", { key: "Escape", bubbles: true }))

const pointerover = (element, relatedTarget = null) =>
  element.dispatchEvent(new MouseEvent("pointerover", { bubbles: true, relatedTarget }))

const pointerout = (element, relatedTarget = null) =>
  element.dispatchEvent(new MouseEvent("pointerout", { bubbles: true, relatedTarget }))

const FRUITS = [
  ["apple", "Apple"],
  ["banana", "Banana"],
  ["blueberry", "Blueberry"],
  ["cherry", "Cherry"]
]

const markup = ({ value = "", open = false, disabledValues = [], loop = false } = {}) => {
  const selectedLabel = FRUITS.find(([v]) => v === value)?.[1]
  return `
    <button id="outside">outside</button>
    <div id="root" data-slot="select" data-component="select"
         data-controller="poetry--core--select"
         data-poetry--core--select-open-value="${open}"
         data-poetry--core--select-value-value="${value}"
         data-poetry--core--select-loop-value="${loop}">
      <select id="native" data-slot="select-native" aria-hidden="true" tabindex="-1" name="fruit"
              data-action="change->poetry--core--select#nativeChanged">
        <option value=""></option>
        ${FRUITS.map(([v, label]) => `<option value="${v}" ${v === value ? "selected" : ""}>${label}</option>`).join("")}
      </select>
      <button type="button" id="trigger" data-slot="select-trigger" role="combobox"
              aria-controls="content" aria-expanded="false" aria-autocomplete="none"
              ${value ? "" : "data-placeholder"}
              data-action="poetry--core--select#toggle keydown->poetry--core--select#triggerKeydown">
        <span id="display" data-slot="select-value" data-placeholder="Pick a fruit">${selectedLabel ?? "Pick a fruit"}</span>
      </button>
      <div id="content" data-slot="select-content" role="listbox" tabindex="-1"
           data-closed ${open ? "" : "hidden"}>
        <div id="scroll-up" data-slot="select-scroll-up-button" aria-hidden="true" hidden
             data-action="pointerenter->poetry--core--select#scrollHoldStart pointerleave->poetry--core--select#scrollHoldStop"></div>
        <div id="viewport" data-slot="select-viewport">
          ${FRUITS.map(([v, label]) => `
            <div id="item-${v}" data-slot="select-item" role="option" tabindex="-1"
                 data-poetry-collection-item data-value="${v}"
                 aria-selected="${v === value}" ${v === value ? "data-selected" : ""}
                 ${disabledValues.includes(v) ? "data-disabled aria-disabled=\"true\"" : ""}
                 data-action="click->poetry--core--select#commit">
              <span data-slot="select-item-indicator" aria-hidden="true"></span>
              <span data-slot="select-item-text">${label}</span>
            </div>`).join("")}
        </div>
        <div id="scroll-down" data-slot="select-scroll-down-button" aria-hidden="true" hidden></div>
      </div>
    </div>`
}

const controller = (application) =>
  application.getControllerForElementAndIdentifier(el("root"), "poetry--core--select")

const ariaSelected = () => FRUITS.map(([v]) => el(`item-${v}`).getAttribute("aria-selected"))

async function mount(options = {}) {
  document.body.innerHTML = markup(options)
  const application = Application.start()
  registerPoetryControllers(application)
  await nextFrame()
  return application
}

async function open() {
  el("trigger").focus() // browsers focus on mousedown; jsdom clicks don't
  click(el("trigger"))
  await flushMicrotasks()
  await nextFrame()
}

describe("poetry--core--select", () => {
  let application

  beforeEach(async () => {
    application = await mount({ value: "banana" })
    return async () => {
      document.body.replaceChildren()
      await nextFrame()
      application.stop()
    }
  })

  describe("open / close", () => {
    it("pointer open focuses the SELECTED option (the menu-family delta) and flips the aria/state pair", async () => {
      await open()

      expect(el("trigger").getAttribute("aria-expanded")).toBe("true")
      expect(el("trigger").hasAttribute("data-popup-open")).toBe(true)
      expect(el("content").hasAttribute("data-open")).toBe(true)
      expect(el("content").hidden).toBe(false)
      expect(el("content").getAttribute("data-open-reason")).toBe("trigger-press")
      expect(el("content").hasAttribute("data-open-seed")).toBe(false)
      expect(document.activeElement).toBe(el("item-banana"))
    })

    it("a REAL trigger press on an open select closes once and never re-opens (pointerdown, then click)", async () => {
      await open()

      // A real press reaches the dismissable layer as pointerdown FIRST (the
      // trigger sits outside the content) - without the trigger veto that
      // closes on pointerdown and the trailing click re-opens.
      el("trigger").dispatchEvent(new MouseEvent("pointerdown", { bubbles: true }))
      click(el("trigger"))
      await flushMicrotasks()
      await nextFrame()

      expect(el("content").hidden).toBe(true)
      expect(el("trigger").getAttribute("aria-expanded")).toBe("false")
    })

    it("all four trigger open keys focus the selected option; with no value, the first enabled", async () => {
      for (const key of ["Enter", " ", "ArrowDown", "ArrowUp"]) {
        press(el("trigger"), key)
        await flushMicrotasks()
        await nextFrame()

        expect(document.activeElement).toBe(el("item-banana"))
        expect(el("content").getAttribute("data-open-reason")).toBe("list-navigation")
        expect(el("content").getAttribute("data-open-seed")).toBe("selected")

        controller(application).close()
        await nextFrame()
      }

      application.stop()
      application = await mount()
      press(el("trigger"), "ArrowDown")
      await flushMicrotasks()
      await nextFrame()

      expect(document.activeElement).toBe(el("item-apple"))
      expect(el("content").getAttribute("data-open-reason")).toBe("list-navigation")
      expect(el("content").getAttribute("data-open-seed")).toBe("first")
    })

    it("Esc closes WITHOUT committing and returns focus to the trigger", async () => {
      await open()
      press(el("item-banana"), "ArrowDown") // highlight cherry... (blueberry)
      pressEscape()
      await nextFrame()

      expect(el("content").hidden).toBe(true)
      expect(el("trigger").getAttribute("aria-expanded")).toBe("false")
      expect(el("native").value).toBe("banana") // value untouched
      expect(ariaSelected()).toEqual(["false", "true", "false", "false"])
      expect(document.activeElement).toBe(el("trigger"))
    })

    it("Tab is INERT while open (focus stays in the listbox)", async () => {
      await open()

      const handled = press(el("item-banana"), "Tab")

      expect(handled).toBe(false) // preventDefault'ed
      expect(el("content").hasAttribute("data-open")).toBe(true)
    })
  })

  describe("the commit pipeline", () => {
    it("click commits: native FIRST with real change/input, aria-selected + data-selected together, display sync, close + focus return", async () => {
      await open()

      const order = []
      el("root").addEventListener("change", (event) => {
        if (event.target === el("native")) {
          order.push(["native-change", el("native").value, el("display").textContent])
        }
      })
      el("root").addEventListener("poetry:select:change", (event) => order.push(["change", event.detail]))

      click(el("item-cherry"))
      await nextFrame()

      // the native change fired BEFORE the display was written (native-first)
      expect(order[0]).toEqual(["native-change", "cherry", "Banana"])
      expect(order[1]).toEqual(["change", { value: "cherry", label: "Cherry", previous: "banana" }])

      expect(el("native").value).toBe("cherry")
      expect(ariaSelected()).toEqual(["false", "false", "false", "true"])
      expect(el("item-cherry").hasAttribute("data-selected")).toBe(true)
      expect(el("item-banana").hasAttribute("data-selected")).toBe(false)
      expect(el("display").textContent).toBe("Cherry")
      expect(el("trigger").hasAttribute("data-placeholder")).toBe(false)

      expect(el("content").hidden).toBe(true) // single-select always closes on commit
      expect(document.activeElement).toBe(el("trigger"))
    })

    it("Enter and Space commit the focused option", async () => {
      await open()
      press(el("item-banana"), "ArrowDown") // roving: focus blueberry
      expect(document.activeElement).toBe(el("item-blueberry"))

      press(el("item-blueberry"), "Enter")
      await nextFrame()

      expect(el("native").value).toBe("blueberry")
      expect(el("display").textContent).toBe("Blueberry")
      expect(el("content").hidden).toBe(true)
    })

    it("arrows move highlight ONLY - the value does not follow focus", async () => {
      await open()
      press(el("item-banana"), "ArrowDown")
      press(el("item-blueberry"), "ArrowDown")

      expect(document.activeElement).toBe(el("item-cherry"))
      expect(el("native").value).toBe("banana")
      expect(ariaSelected()).toEqual(["false", "true", "false", "false"])
    })

    it("the select event is cancelable: preventDefault keeps the listbox open and the value unchanged", async () => {
      await open()
      el("content").addEventListener("poetry:select:select", (event) => event.preventDefault(), { once: true })

      click(el("item-cherry"))
      await nextFrame()

      expect(el("content").hasAttribute("data-open")).toBe(true)
      expect(el("native").value).toBe("banana")

      click(el("item-cherry")) // un-vetoed: commits
      await nextFrame()
      expect(el("native").value).toBe("cherry")
    })

    it("committing the already-selected value closes without a change event", async () => {
      await open()

      const seen = []
      el("root").addEventListener("poetry:select:change", (event) => seen.push(event.detail))

      click(el("item-banana"))
      await nextFrame()

      expect(seen).toEqual([])
      expect(el("content").hidden).toBe(true)
    })

    it("disabled options cannot be committed and are skipped by arrows", async () => {
      application.stop()
      application = await mount({ value: "banana", disabledValues: ["blueberry"] })
      await open()

      click(el("item-blueberry"))
      expect(el("native").value).toBe("banana")
      expect(el("content").hasAttribute("data-open")).toBe(true)

      press(el("item-banana"), "ArrowDown")
      expect(document.activeElement).toBe(el("item-cherry")) // blueberry filtered
    })
  })

  describe("hover highlight (focus follows the pointer)", () => {
    it("pointerover on an enabled option focuses it - the themes' focus: styling IS the hover highlight", async () => {
      await open()

      pointerover(el("item-cherry"))

      expect(document.activeElement).toBe(el("item-cherry"))
    })

    it("pointerover on a DISABLED option clears the highlight to the content instead", async () => {
      application.stop()
      application = await mount({ value: "banana", disabledValues: ["blueberry"] })
      await open()

      pointerover(el("item-blueberry"))

      expect(document.activeElement).toBe(el("content"))
    })

    it("leaving an option for blank space hands focus back to the content (highlight clears)", async () => {
      await open()

      pointerover(el("item-cherry"))
      pointerout(el("item-cherry"), el("viewport"))

      expect(document.activeElement).toBe(el("content"))
    })

    it("touch pointers never hover-highlight (tap semantics)", async () => {
      await open()
      const before = document.activeElement

      const touchOver = new MouseEvent("pointerover", { bubbles: true })
      Object.defineProperty(touchOver, "pointerType", { value: "touch" })
      el("item-cherry").dispatchEvent(touchOver)

      expect(document.activeElement).toBe(before)
    })
  })

  describe("typeahead", () => {
    it("OPEN typeahead moves focus only (never commits)", async () => {
      await open()

      press(el("item-banana"), "c")

      expect(document.activeElement).toBe(el("item-cherry"))
      expect(el("native").value).toBe("banana")
    })

    it("CLOSED-trigger typeahead COMMITS the match without opening (native select parity)", async () => {
      const natives = []
      el("root").addEventListener("change", (event) => {
        if (event.target === el("native")) natives.push(el("native").value)
      })

      press(el("trigger"), "c")

      expect(el("content").hidden).toBe(true) // never opened
      expect(el("native").value).toBe("cherry")
      expect(el("display").textContent).toBe("Cherry")
      expect(ariaSelected()).toEqual(["false", "false", "false", "true"])
      expect(natives).toEqual(["cherry"])
    })

    it("Left/Right are no-ops in the flat listbox (no menu map leak)", async () => {
      await open()

      press(el("item-banana"), "ArrowRight")
      press(el("item-banana"), "ArrowLeft")

      expect(document.activeElement).toBe(el("item-banana"))
      expect(el("native").value).toBe("banana")
      expect(el("content").hasAttribute("data-open")).toBe(true)
    })
  })

  describe("the sync invariant's other write paths", () => {
    it("nativeChanged (autofill) adopts the native value into the UI without re-dispatching native events", async () => {
      const natives = []
      el("root").addEventListener("change", (event) => {
        if (event.target === el("native")) natives.push(el("native").value)
      })
      const changes = []
      el("root").addEventListener("poetry:select:change", (event) => changes.push(event.detail))

      el("native").value = "apple"
      el("native").dispatchEvent(new Event("change", { bubbles: true })) // the autofill write

      expect(natives).toEqual(["apple"]) // only the autofill's own event - no loop
      expect(changes).toEqual([{ value: "apple", label: "Apple", previous: "banana" }])
      expect(el("display").textContent).toBe("Apple")
      expect(ariaSelected()).toEqual(["true", "false", "false", "false"])
    })

    it("setValue runs the pipeline; clearing restores the placeholder + data-placeholder", async () => {
      controller(application).setValue("apple")
      expect(el("display").textContent).toBe("Apple")

      controller(application).setValue("")
      expect(el("display").textContent).toBe("Pick a fruit")
      expect(el("trigger").hasAttribute("data-placeholder")).toBe(true)
      expect(el("native").value).toBe("")
      expect(ariaSelected()).toEqual(["false", "false", "false", "false"])
    })
  })

  describe("scroll buttons", () => {
    const stubViewport = ({ scrollTop, clientHeight = 100, scrollHeight = 300 }) => {
      Object.defineProperty(el("viewport"), "scrollTop", { value: scrollTop, writable: true, configurable: true })
      Object.defineProperty(el("viewport"), "clientHeight", { value: clientHeight, configurable: true })
      Object.defineProperty(el("viewport"), "scrollHeight", { value: scrollHeight, configurable: true })
    }

    it("visibility syncs per scroll extremes", async () => {
      stubViewport({ scrollTop: 0 })
      controller(application).syncScrollButtons()
      expect(el("scroll-up").hidden).toBe(true)
      expect(el("scroll-down").hidden).toBe(false)

      stubViewport({ scrollTop: 100 })
      controller(application).syncScrollButtons()
      expect(el("scroll-up").hidden).toBe(false)
      expect(el("scroll-down").hidden).toBe(false)

      stubViewport({ scrollTop: 200 })
      controller(application).syncScrollButtons()
      expect(el("scroll-up").hidden).toBe(false)
      expect(el("scroll-down").hidden).toBe(true)
    })
  })

  describe("reconcile-on-connect", () => {
    it("server-rendered value: the display, aria, and native agree at connect (no events)", async () => {
      application.stop()

      const changes = []
      document.body.innerHTML = markup({ value: "cherry" })
      document.body.addEventListener("poetry:select:change", (event) => changes.push(event.detail))

      application = Application.start()
      registerPoetryControllers(application)
      await nextFrame()

      expect(changes).toEqual([])
      expect(el("display").textContent).toBe("Cherry")
      expect(el("native").value).toBe("cherry")
      expect(ariaSelected()).toEqual(["false", "false", "false", "true"])
    })

    it("with no Value given, the native select's value is adopted (serialization truth)", async () => {
      application.stop()
      document.body.innerHTML = markup()
      el("native").value = "blueberry"

      application = Application.start()
      registerPoetryControllers(application)
      await nextFrame()

      expect(controller(application).valueValue).toBe("blueberry")
      expect(el("display").textContent).toBe("Blueberry")
      expect(ariaSelected()).toEqual(["false", "false", "true", "false"])
    })

    it("a server-rendered OPEN select activates its layer stack on connect", async () => {
      application.stop()
      application = await mount({ value: "banana", open: true })

      expect(el("content").getAttribute("data-controller")).toContain("poetry--core--roving-focus")
      expect(controller(application).openValue).toBe(true)

      // and it still closes cleanly
      pressEscape()
      await nextFrame()
      expect(el("content").hidden).toBe(true)
    })
  })

  describe("portal-on-open (docs/portal-on-open.md S3)", () => {
    it("open portals the content to body + flips popper to absolute; close restores both and focus returns", async () => {
      await open()

      expect(el("content").parentNode).toBe(document.body)
      expect(el("root").getAttribute("data-poetry--core--popper-strategy-value")).toBe("absolute")
      // the selected option holds REAL focus inside the portaled listbox
      expect(document.activeElement).toBe(el("item-banana"))

      pressEscape()
      await nextFrame()

      expect(el("content").hidden).toBe(true)
      expect(el("content").parentNode).toBe(el("root"))
      expect(el("root").getAttribute("data-poetry--core--popper-strategy-value")).toBe("fixed")
      expect(document.activeElement).toBe(el("trigger"))
    })

    it("an item press inside the PORTALED listbox still commits through the native-first pipeline", async () => {
      await open()
      expect(el("content").parentNode).toBe(document.body)

      click(el("item-cherry"))
      await nextFrame()

      expect(el("native").value).toBe("cherry")
      expect(el("content").hidden).toBe(true)
      expect(el("content").parentNode).toBe(el("root"))
    })

    it("a server-pinned open select portals one frame after connect (the popper cache order)", async () => {
      application.stop()
      application = await mount({ value: "banana", open: true })

      // (the deferral itself is a rAF - too fast to assert against
      // jsdom's 16ms rAF timer without flaking; the OUTCOME is the pin)
      await new Promise((resolve) => setTimeout(resolve, 40))

      expect(el("content").parentNode).toBe(document.body)
      expect(el("root").getAttribute("data-poetry--core--popper-strategy-value")).toBe("absolute")
    })

    it("disconnecting an open select never strands content at body (drop-never-strand)", async () => {
      await open()
      expect(el("content").parentNode).toBe(document.body)

      document.getElementById("root").remove()
      await nextFrame()

      expect(document.getElementById("content")).toBe(null)
    })
  })
})
