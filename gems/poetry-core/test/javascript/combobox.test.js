import { beforeEach, describe, expect, it } from "vitest"
import { Application } from "@hotwired/stimulus"
import { registerPoetryControllers } from "@poetry/controllers"

// poetry--core--combobox JS-unit: the thin
// orchestrator - Select's shell (open/close, the native-first 5-step
// commit pipeline, autofill adoption) over Command's engine, composed via
// the poetry:command:select event ONLY. The three deliberate deltas vs
// Select are pinned (open focuses the INPUT, Tab closes without commit,
// a printable key on the closed trigger opens + seeds the filter), plus
// the composition boundary: no roving-focus token is ever appended and
// this controller does no filtering of its own.

const nextFrame = () => new Promise((resolve) => setTimeout(resolve, 0))
const flushMicrotasks = () => Promise.resolve().then(() => Promise.resolve())
const el = (id) => document.getElementById(id)

const press = (element, key, options = {}) => {
  const event = new KeyboardEvent("keydown", { key, bubbles: true, cancelable: true, ...options })
  element.dispatchEvent(event)
  return event
}

const click = (element) =>
  element.dispatchEvent(new MouseEvent("click", { bubbles: true, cancelable: true }))

const pressEscape = () =>
  window.dispatchEvent(new KeyboardEvent("keydown", { key: "Escape", bubbles: true }))

const FRAMEWORKS = [
  ["next.js", "Next.js"],
  ["sveltekit", "SvelteKit"],
  ["nuxt.js", "Nuxt.js"],
  ["remix", "Remix"],
  ["astro", "Astro"]
]

const markup = ({ value = "", open = false, modal = false, showClear = false } = {}) => {
  const selectedLabel = FRAMEWORKS.find(([v]) => v === value)?.[1]
  return `
    <button id="outside">outside</button>
    <div id="root" data-slot="combobox" data-component="combobox"
         data-controller="poetry--core--combobox"
         data-poetry--core--combobox-open-value="${open}"
         data-poetry--core--combobox-value-value="${value}"
         data-poetry--core--combobox-modal-value="${modal}">
      <select id="native" data-slot="combobox-native" aria-hidden="true" tabindex="-1" name="framework"
              data-action="change->poetry--core--combobox#nativeChanged">
        <option value=""></option>
        ${FRAMEWORKS.map(([v, label]) => `<option value="${v}" ${v === value ? "selected" : ""}>${label}</option>`).join("")}
      </select>
      <button type="button" id="trigger" data-slot="combobox-trigger" role="combobox"
              aria-controls="list" aria-expanded="false" aria-haspopup="listbox"
              ${value ? "" : "data-placeholder"}
              data-action="poetry--core--combobox#toggle keydown->poetry--core--combobox#triggerKeydown">
        <span id="display" data-slot="combobox-value" data-placeholder="Select framework…">${selectedLabel ?? "Select framework…"}</span>
      </button>
      ${showClear ? `
      <button type="button" id="clear" data-slot="combobox-clear" aria-label="Clear selection"
              ${value ? "" : "hidden"} data-action="poetry--core--combobox#clear"></button>` : ""}
      <div id="content" data-slot="combobox-content" tabindex="-1" data-closed ${open ? "" : "hidden"}>
        <div id="command" data-slot="command" data-controller="poetry--core--command">
          <div data-slot="command-input-wrapper">
            <input id="input" data-slot="command-input" type="text" role="combobox"
                   aria-expanded="true" aria-controls="list" aria-autocomplete="list"
                   aria-label="Filter options"
                   data-action="input->poetry--core--command#filterInput keydown->poetry--core--command#keydown">
          </div>
          <div id="list" data-slot="command-list" role="listbox" tabindex="-1" aria-label="Frameworks">
            <div id="empty" data-slot="command-empty" hidden>No results found.</div>
            ${FRAMEWORKS.map(([v, label]) => `
              <div id="item-${v}" data-slot="command-item" role="option"
                   data-poetry-collection-item data-value="${v}"
                   aria-selected="${v === value}" ${v === value ? "data-selected" : ""}
                   data-action="click->poetry--core--command#activate pointermove->poetry--core--command#pointerHighlight">
                <span data-slot="command-item-text">${label}</span>
                <span data-slot="combobox-item-indicator" aria-hidden="true"></span>
              </div>`).join("")}
          </div>
          <span id="status" data-slot="command-status" role="status" aria-live="polite"></span>
        </div>
      </div>
    </div>
    <button id="after">after</button>`
}

const controller = (application) =>
  application.getControllerForElementAndIdentifier(el("root"), "poetry--core--combobox")

const ariaSelected = () => FRAMEWORKS.map(([v]) => el(`item-${v}`).getAttribute("aria-selected"))
const dataSelected = () => FRAMEWORKS.map(([v]) => el(`item-${v}`).hasAttribute("data-selected"))

async function mount(options = {}) {
  document.body.innerHTML = markup(options)
  const application = Application.start()
  registerPoetryControllers(application)
  await nextFrame()
  return application
}

async function open() {
  el("trigger").focus()
  click(el("trigger"))
  await flushMicrotasks()
  await nextFrame()
}

describe("poetry--core--combobox", () => {
  let application

  beforeEach(async () => {
    application = await mount({ value: "sveltekit" })
    return async () => {
      document.body.replaceChildren()
      await nextFrame()
      application.stop()
    }
  })

  describe("open (the typing-session deltas vs Select)", () => {
    it("pointer open focuses the INPUT (never an option) and highlights the selected option", async () => {
      await open()

      expect(el("trigger").getAttribute("aria-expanded")).toBe("true")
      expect(el("content").hasAttribute("data-open")).toBe(true)
      expect(el("content").hidden).toBe(false)
      expect(document.activeElement).toBe(el("input"))
      expect(el("item-sveltekit").hasAttribute("data-highlighted")).toBe(true)
      expect(el("input").getAttribute("aria-activedescendant")).toBe("item-sveltekit")
    })

    it("every keyboard open reason also focuses the input (no option focus, ever)", async () => {
      for (const key of ["Enter", " ", "ArrowDown", "ArrowUp"]) {
        expect(press(el("trigger"), key).defaultPrevented).toBe(true)
        await flushMicrotasks()
        await nextFrame()

        expect(document.activeElement).toBe(el("input"))
        expect(el("item-sveltekit").hasAttribute("data-highlighted")).toBe(true)

        pressEscape()
        await nextFrame()
      }
    })

    it("a printable key on the closed trigger OPENS and SEEDS the filter (never blind-commits)", async () => {
      el("trigger").focus()
      press(el("trigger"), "n")
      await flushMicrotasks()
      await nextFrame()

      expect(el("content").hasAttribute("data-open")).toBe(true)
      expect(el("content").getAttribute("data-open-reason")).toBe("keyboard")
      expect(el("content").getAttribute("data-open-seed")).toBe("n")
      expect(document.activeElement).toBe(el("input"))
      expect(el("input").value).toBe("n")
      // The seeded char ran the engine's filter pass: Next.js + Nuxt.js only.
      expect(el("item-sveltekit").hasAttribute("hidden")).toBe(true)
      expect(el("item-next.js").hasAttribute("hidden")).toBe(false)
      // And NOTHING committed (Select's closed-trigger typeahead-commit does not port).
      expect(el("native").value).toBe("sveltekit")
    })

    it("dispatches poetry:combobox:open with the reason", async () => {
      let reason = null
      el("root").addEventListener("poetry:combobox:open", (event) => { reason = event.detail.reason })

      await open()

      expect(reason).toBe("trigger-press")
    })

    it("appends focus-scope + dismissable but NEVER roving-focus (the activedescendant popup)", async () => {
      await open()

      const tokens = (el("content").getAttribute("data-controller") ?? "").split(/\s+/)

      expect(tokens).toContain("poetry--core--focus-scope")
      expect(tokens).toContain("poetry--core--dismissable")
      expect(tokens).not.toContain("poetry--core--roving-focus")
    })

    it("a REAL trigger press on an open combobox closes once and never re-opens (pointerdown, then click)", async () => {
      await open()

      // A real press reaches the dismissable layer as pointerdown FIRST (the
      // trigger sits outside the content) - without the trigger veto that
      // closes on pointerdown and the trailing click re-opens.
      el("trigger").dispatchEvent(new MouseEvent("pointerdown", { bubbles: true }))
      click(el("trigger"))
      await nextFrame()

      expect(el("content").hidden).toBe(true)
      expect(el("trigger").getAttribute("aria-expanded")).toBe("false")
    })
  })

  describe("the commit pipeline (native first, Select's 5 steps)", () => {
    it("Enter on a highlighted option commits: native first with real events, twin-write, display, close, focus return", async () => {
      await open()

      const sequence = []
      el("native").addEventListener("change", () => sequence.push(["native-change", el("native").value]))
      el("root").addEventListener("poetry:combobox:change", (event) => sequence.push(["change", event.detail]))

      press(el("input"), "ArrowDown") // sveltekit -> nuxt.js
      press(el("input"), "Enter")
      await nextFrame()

      expect(el("native").value).toBe("nuxt.js")
      expect(sequence[0]).toEqual(["native-change", "nuxt.js"]) // native BEFORE the poetry event
      expect(sequence[1][1]).toEqual({ value: "nuxt.js", label: "Nuxt.js", previous: "sveltekit" })
      expect(ariaSelected()).toEqual(["false", "false", "true", "false", "false"])
      expect(dataSelected()).toEqual([false, false, true, false, false])
      expect(el("display").textContent).toBe("Nuxt.js")
      expect(el("trigger").hasAttribute("data-placeholder")).toBe(false)
      expect(el("content").hidden).toBe(true)
      expect(document.activeElement).toBe(el("trigger"))
    })

    it("click-commit routes through the SAME event seam (Command's select is the only trigger)", async () => {
      await open()

      click(el("item-remix"))
      await nextFrame()

      expect(el("native").value).toBe("remix")
      expect(el("display").textContent).toBe("Remix")
      expect(el("content").hidden).toBe(true)
    })

    it("poetry:combobox:select is cancelable BEFORE the value commits - veto keeps the popup open", async () => {
      await open()

      el("root").addEventListener("poetry:combobox:select", (event) => event.preventDefault(), { once: true })

      click(el("item-remix"))
      await nextFrame()

      expect(el("native").value).toBe("sveltekit")
      expect(el("content").hidden).toBe(false)
      expect(ariaSelected()).toEqual(["false", "true", "false", "false", "false"])
    })

    it("re-committing the selected value is IDEMPOTENT: closes, no change events (no re-click-to-clear toggle)", async () => {
      await open()

      let changes = 0
      el("root").addEventListener("poetry:combobox:change", () => { changes += 1 })
      el("native").addEventListener("change", () => { changes += 1 })

      click(el("item-sveltekit"))
      await nextFrame()

      expect(el("content").hidden).toBe(true)
      expect(el("native").value).toBe("sveltekit")
      expect(changes).toBe(0)
    })
  })

  describe("the show_clear X (Base UI Combobox.Clear)", () => {
    beforeEach(async () => {
      application.stop()
      application = await mount({ value: "sveltekit", showClear: true })
    })

    it("clicking the X commits the blank value through the pipeline and hands focus to the trigger", async () => {
      const sequence = []
      el("native").addEventListener("change", () => sequence.push(["native-change", el("native").value]))
      el("root").addEventListener("poetry:combobox:change", (event) => sequence.push(["change", event.detail]))

      expect(el("clear").hidden).toBe(false)

      click(el("clear"))
      await nextFrame()

      expect(el("native").value).toBe("")
      expect(sequence[0]).toEqual(["native-change", ""]) // native BEFORE the poetry event
      expect(sequence[1][1]).toEqual({ value: "", label: null, previous: "sveltekit" })
      expect(ariaSelected()).toEqual(["false", "false", "false", "false", "false"])
      expect(dataSelected()).toEqual([false, false, false, false, false])
      expect(el("display").textContent).toBe("Select framework…")
      expect(el("trigger").hasAttribute("data-placeholder")).toBe(true)
      expect(el("clear").hidden).toBe(true) // the X hides itself once the value empties
      expect(document.activeElement).toBe(el("trigger"))
    })

    it("the X follows the value: shown again by the next commit", async () => {
      click(el("clear"))
      await nextFrame()
      expect(el("clear").hidden).toBe(true)

      await open()
      click(el("item-remix"))
      await nextFrame()

      expect(el("native").value).toBe("remix")
      expect(el("clear").hidden).toBe(false)
    })

    it("clearing an already-empty value is a no-op (no change events)", async () => {
      application.stop()
      application = await mount({ showClear: true })

      let changes = 0
      el("root").addEventListener("poetry:combobox:change", () => { changes += 1 })
      el("native").addEventListener("change", () => { changes += 1 })

      expect(el("clear").hidden).toBe(true)

      click(el("clear"))
      await nextFrame()

      expect(changes).toBe(0)
      expect(document.activeElement).toBe(el("trigger"))
    })
  })

  describe("close without commit", () => {
    it("Esc closes, leaves the value untouched, resets the query, and returns focus to the trigger", async () => {
      await open()

      el("input").value = "re"
      el("input").dispatchEvent(new Event("input", { bubbles: true }))

      pressEscape()
      await nextFrame()

      expect(el("content").hidden).toBe(true)
      expect(el("native").value).toBe("sveltekit")
      expect(el("input").value).toBe("") // clean reopen (the fresh-mount behavior, made explicit)
      expect(el("item-next.js").hasAttribute("hidden")).toBe(false) // visibility re-derived
      expect(document.activeElement).toBe(el("trigger"))
    })

    it("Tab closes WITHOUT commit and lands focus AFTER the trigger (the portaled-Tab seam - the popup lives at body)", async () => {
      await open()

      const event = press(el("input"), "Tab")
      await nextFrame()

      // The portaled popup cannot let focus proceed naturally (it would
      // land at body's end) - the close re-routes it to where the
      // un-portaled DOM would have: the next tabbable after the trigger.
      expect(event.defaultPrevented).toBe(true)
      expect(document.activeElement).toBe(el("after"))
      expect(el("content").hidden).toBe(true)
      expect(el("native").value).toBe("sveltekit")
      expect(el("trigger").getAttribute("aria-expanded")).toBe("false")
    })

    it("Shift+Tab closes WITHOUT commit and lands focus ON the trigger (the portaled-Tab seam)", async () => {
      await open()

      const event = press(el("input"), "Tab", { shiftKey: true })
      await nextFrame()

      expect(event.defaultPrevented).toBe(true)
      expect(document.activeElement).toBe(el("trigger"))
      expect(el("content").hidden).toBe(true)
    })

    it("modal: true leaves Tab to the focus-scope trap (the popup stays open)", async () => {
      application.stop()
      application = await mount({ value: "sveltekit", modal: true })
      await open()

      press(el("input"), "Tab")
      await nextFrame()

      expect(el("content").hidden).toBe(false)
      expect(el("trigger").getAttribute("aria-expanded")).toBe("true")
    })

    it("outside press dismisses without commit", async () => {
      await open()

      el("outside").dispatchEvent(new MouseEvent("pointerdown", { bubbles: true }))
      click(el("outside"))
      await nextFrame()

      expect(el("content").hidden).toBe(true)
      expect(el("native").value).toBe("sveltekit")
    })

    it("dispatches poetry:combobox:closed with the reason", async () => {
      await open()

      let reason = null
      el("root").addEventListener("poetry:combobox:closed", (event) => { reason = event.detail.reason })

      pressEscape()
      await nextFrame()

      expect(reason).toBe("escape-key")
    })
  })

  describe("value plumbing (the sync invariant)", () => {
    it("reconciles on connect: the server-selected value seeds display + twin-write silently", () => {
      expect(el("display").textContent).toBe("SvelteKit")
      expect(ariaSelected()).toEqual(["false", "true", "false", "false", "false"])
      expect(el("trigger").hasAttribute("data-placeholder")).toBe(false)
    })

    it("no value: placeholder shows and data-placeholder rides the trigger; open seats the first enabled", async () => {
      application.stop()
      application = await mount()

      expect(el("display").textContent).toBe("Select framework…")
      expect(el("trigger").hasAttribute("data-placeholder")).toBe(true)

      await open()

      expect(el("item-next.js").hasAttribute("data-highlighted")).toBe(true)
    })

    it("autofill (native change) adopts into the UI without re-dispatching native events", async () => {
      let nativeEvents = 0
      el("native").addEventListener("input", () => { nativeEvents += 1 })

      el("native").value = "astro"
      el("native").dispatchEvent(new Event("change", { bubbles: true }))

      expect(el("display").textContent).toBe("Astro")
      expect(ariaSelected()).toEqual(["false", "false", "false", "false", "true"])
      expect(nativeEvents).toBe(0) // fromNative: no write-back loop
    })

    it("setValue / the value Value funnel through the pipeline", async () => {
      controller(application).setValue("remix")

      expect(el("native").value).toBe("remix")
      expect(el("display").textContent).toBe("Remix")
      expect(dataSelected()).toEqual([false, false, false, true, false])
    })
  })

  describe("the composition boundary", () => {
    it("arrows/typing inside the popup are entirely Command's; this controller only hears the select event", async () => {
      await open()

      // The engine filters; the shell must not have hidden anything itself
      // before typing, and the twin-write must not move with the highlight.
      press(el("input"), "ArrowDown")
      press(el("input"), "ArrowUp")

      expect(ariaSelected()).toEqual(["false", "true", "false", "false", "false"]) // committed value unmoved
      expect(el("native").value).toBe("sveltekit")
    })
  })

  describe("portal-on-open", () => {
    it("open portals the content to body + flips popper to absolute; a commit restores both", async () => {
      await open()

      expect(el("content").parentNode).toBe(document.body)
      expect(el("root").getAttribute("data-poetry--core--popper-strategy-value")).toBe("absolute")
      expect(document.activeElement).toBe(el("input"), "the typing session starts inside the portaled popup")

      click(el("item-remix"))
      await nextFrame()

      expect(el("native").value).toBe("remix")
      expect(el("content").hidden).toBe(true)
      expect(el("content").parentNode).toBe(el("root"))
      expect(el("root").getAttribute("data-poetry--core--popper-strategy-value")).toBe("fixed")
    })

    it("a server-pinned open combobox portals one frame after connect (the popper cache order)", async () => {
      application.stop()
      application = await mount({ value: "sveltekit", open: true })

      // (the deferral itself is a rAF - too fast to assert against
      // jsdom's 16ms rAF timer without flaking; the OUTCOME is the pin)
      await new Promise((resolve) => setTimeout(resolve, 40))

      expect(el("content").parentNode).toBe(document.body)
      expect(el("root").getAttribute("data-poetry--core--popper-strategy-value")).toBe("absolute")
    })

    it("disconnecting an open combobox never strands content at body (drop-never-strand)", async () => {
      await open()
      expect(el("content").parentNode).toBe(document.body)

      el("root").remove()
      await nextFrame()

      expect(document.getElementById("content")).toBe(null)
    })

    it("reopening after a close never flashes the empty part (the close-time reset under a hidden popup)", async () => {
      await open()
      expect(el("empty").hidden).toBe(true)

      pressEscape()
      await nextFrame()

      expect(el("empty").hidden).toBe(true, "the close-time query reset must not unhide it")

      await open()

      expect(el("empty").hidden).toBe(true)
      expect(el("item-next.js").hidden).toBe(false)
    })
  })
})

// The MULTIPLE mode (Base UI's multiple + input-inside layout): the chips
// FIELD replaces the trigger - the filter input lives inline after the
// chips (still data-slot=command-input; the engine rides the ROOT), the
// native is a <select multiple> posting name[], selection TOGGLES with the
// popup STAYING OPEN, and chips take real DOM focus with their own
// keyboard map. The markup mirrors the component's multiple render.
const labelOf = (value) => FRAMEWORKS.find(([v]) => v === value)?.[1] ?? value

const chipMarkup = (value) => `
  <div data-slot="combobox-chip" tabindex="-1" data-value="${value}" aria-label="${labelOf(value)}"
       data-action="keydown->poetry--core--combobox#chipKeydown">${labelOf(value)}<button type="button"
      tabindex="-1" data-slot="combobox-chip-remove" aria-label="Remove ${labelOf(value)}"
      data-action="click->poetry--core--combobox#removeChip"></button></div>`

const multipleMarkup = ({ values = [], open = false } = {}) => `
  <button id="outside">outside</button>
  <div id="root" data-slot="combobox" data-component="combobox"
       data-controller="poetry--core--combobox poetry--core--command"
       data-poetry--core--combobox-open-value="${open}"
       data-poetry--core--combobox-multiple-value="true"
       data-poetry--core--combobox-value-value='${JSON.stringify(values)}'>
    <select id="native" multiple data-slot="combobox-native" aria-hidden="true" tabindex="-1"
            name="frameworks[]" data-action="change->poetry--core--combobox#nativeChanged">
      ${FRAMEWORKS.map(([v, label]) => `<option value="${v}" ${values.includes(v) ? "selected" : ""}>${label}</option>`).join("")}
    </select>
    <div id="chips" data-slot="combobox-chips" ${values.length > 0 ? 'role="toolbar"' : "data-placeholder"}
         data-remove-label="Remove %{label}"
         data-action="mousedown->poetry--core--combobox#chipsPointerdown">
      ${values.map((value) => chipMarkup(value)).join("")}
      <input id="input" data-slot="command-input" type="text" role="combobox"
             aria-expanded="false" aria-controls="list" aria-autocomplete="list"
             aria-label="Frameworks" placeholder="Select frameworks…"
             data-action="input->poetry--core--command#filterInput keydown->poetry--core--command#keydown keydown->poetry--core--combobox#inputKeydown">
      <template><div data-slot="combobox-chip" tabindex="-1"
           data-action="keydown->poetry--core--combobox#chipKeydown"><button type="button"
          tabindex="-1" data-slot="combobox-chip-remove"
          data-action="click->poetry--core--combobox#removeChip"></button></div></template>
    </div>
    <div id="content" data-slot="combobox-content" tabindex="-1" data-closed ${open ? "" : "hidden"}>
      <div id="list" data-slot="command-list" role="listbox" tabindex="-1" aria-label="Frameworks"
           aria-multiselectable="true">
        <div id="empty" data-slot="command-empty" hidden>No results found.</div>
        ${FRAMEWORKS.map(([v, label]) => `
          <div id="item-${v}" data-slot="command-item" role="option"
               data-poetry-collection-item data-value="${v}"
               aria-selected="${values.includes(v)}" ${values.includes(v) ? "data-selected" : ""}
               data-action="click->poetry--core--command#activate pointermove->poetry--core--command#pointerHighlight">
            <span data-slot="command-item-text">${label}</span>
            <span data-slot="combobox-item-indicator" aria-hidden="true"></span>
          </div>`).join("")}
      </div>
      <span id="status" data-slot="command-status" role="status" aria-live="polite"></span>
    </div>
  </div>`

async function mountMultiple(options = {}) {
  document.body.innerHTML = multipleMarkup(options)
  const application = Application.start()
  registerPoetryControllers(application)
  await nextFrame()
  return application
}

const chipValues = () =>
  Array.from(el("chips").querySelectorAll('[data-slot="combobox-chip"]')).map((chip) => chip.dataset.value)

const nativeSelected = () =>
  Array.from(el("native").selectedOptions).map((option) => option.value)

async function openMultiple() {
  el("input").focus()
  el("chips").dispatchEvent(new MouseEvent("mousedown", { bubbles: true, cancelable: true }))
  await flushMicrotasks()
  await nextFrame()
}

describe("poetry--core--combobox (multiple)", () => {
  let application

  beforeEach(async () => {
    application = await mountMultiple({ values: ["sveltekit", "remix"] })
    return async () => {
      document.body.replaceChildren()
      await nextFrame()
      application.stop()
    }
  })

  describe("the chips field", () => {
    it("reconciles on connect: chips IN VALUE ORDER, toolbar role, twin-writes by array inclusion", () => {
      expect(chipValues()).toEqual(["sveltekit", "remix"])
      expect(el("chips").getAttribute("role")).toBe("toolbar")
      expect(el("chips").hasAttribute("data-placeholder")).toBe(false)
      expect(ariaSelected()).toEqual(["false", "true", "false", "true", "false"])
      expect(dataSelected()).toEqual([false, true, false, true, false])
      expect(nativeSelected()).toEqual(["sveltekit", "remix"])
      // Rebuilt chips keep the accessible names (chip = its value text).
      const chip = el("chips").querySelector('[data-slot="combobox-chip"]')
      expect(chip.getAttribute("aria-label")).toBe("SvelteKit")
      expect(chip.querySelector('[data-slot="combobox-chip-remove"]').getAttribute("aria-label"))
        .toBe("Remove SvelteKit")
    })

    it("empty selection wears data-placeholder and NO toolbar role", async () => {
      application.stop()
      application = await mountMultiple()

      expect(chipValues()).toEqual([])
      expect(el("chips").hasAttribute("role")).toBe(false)
      expect(el("chips").hasAttribute("data-placeholder")).toBe(true)
    })

    it("mousedown anywhere in the frame focuses the input and opens; the input carries the open flip", async () => {
      await openMultiple()

      expect(document.activeElement).toBe(el("input"))
      expect(el("content").hasAttribute("data-open")).toBe(true)
      expect(el("input").getAttribute("aria-expanded")).toBe("true")
      expect(el("input").hasAttribute("data-popup-open")).toBe(true)
      // The committed options seed the highlight (first selected).
      expect(el("item-sveltekit").hasAttribute("data-highlighted")).toBe(true)
    })

    it("a chip-remove press is NOT a chips-area press (removes without opening)", async () => {
      const remove = el("chips").querySelector('[data-value="sveltekit"] [data-slot="combobox-chip-remove"]')

      remove.dispatchEvent(new MouseEvent("mousedown", { bubbles: true, cancelable: true }))
      click(remove)
      await nextFrame()

      expect(chipValues()).toEqual(["remix"])
      expect(nativeSelected()).toEqual(["remix"])
      expect(el("content").hidden).toBe(true)
      expect(document.activeElement).toBe(el("input"))
    })
  })

  describe("the toggle commit (popup stays open)", () => {
    it("selecting an unselected option APPENDS at the array end and never closes", async () => {
      await openMultiple()

      const sequence = []
      el("native").addEventListener("change", () => sequence.push(["native-change", nativeSelected()]))
      el("root").addEventListener("poetry:combobox:change", (event) => sequence.push(["change", event.detail]))

      click(el("item-astro"))
      await nextFrame()

      expect(el("content").hidden).toBe(false) // STAYS OPEN
      expect(chipValues()).toEqual(["sveltekit", "remix", "astro"])
      expect(nativeSelected()).toEqual(["sveltekit", "remix", "astro"])
      expect(sequence[0]).toEqual(["native-change", ["sveltekit", "remix", "astro"]]) // native FIRST
      expect(sequence[1][1]).toEqual({
        value: ["sveltekit", "remix", "astro"],
        label: ["SvelteKit", "Remix", "Astro"],
        previous: ["sveltekit", "remix"]
      })
      expect(ariaSelected()).toEqual(["false", "true", "false", "true", "true"])
    })

    it("re-selecting a selected option TOGGLES it out (no idempotent close)", async () => {
      await openMultiple()

      click(el("item-sveltekit"))
      await nextFrame()

      expect(el("content").hidden).toBe(false)
      expect(chipValues()).toEqual(["remix"])
      expect(nativeSelected()).toEqual(["remix"])
      expect(dataSelected()).toEqual([false, false, false, true, false])
    })

    it("a typed query clears immediately on select and the full list is restored", async () => {
      await openMultiple()

      el("input").value = "as"
      el("input").dispatchEvent(new Event("input", { bubbles: true }))
      expect(el("item-sveltekit").hasAttribute("hidden")).toBe(true)

      click(el("item-astro"))
      await nextFrame()

      expect(el("input").value).toBe("")
      expect(el("item-sveltekit").hasAttribute("hidden")).toBe(false) // full list restored
      expect(el("content").hidden).toBe(false)
      expect(chipValues()).toEqual(["sveltekit", "remix", "astro"])
    })
  })

  describe("the input keyboard map", () => {
    it("Backspace on the EMPTY input removes the LAST chip; focus stays in the input", async () => {
      el("input").focus()
      press(el("input"), "Backspace")
      await nextFrame()

      expect(chipValues()).toEqual(["sveltekit"])
      expect(nativeSelected()).toEqual(["sveltekit"])
      expect(document.activeElement).toBe(el("input"))

      // A non-empty input keeps Backspace for TEXT editing.
      el("input").value = "x"
      press(el("input"), "Backspace")
      await nextFrame()

      expect(chipValues()).toEqual(["sveltekit"])
    })

    it("ArrowLeft at caret 0 focuses the LAST chip and closes the popup", async () => {
      await openMultiple()

      press(el("input"), "ArrowLeft")
      await nextFrame()

      const last = el("chips").querySelector('[data-value="remix"]')

      expect(document.activeElement).toBe(last)
      expect(el("content").hidden).toBe(true) // focusing a chip CLOSES the popup
      expect(nativeSelected()).toEqual(["sveltekit", "remix"]) // no commit
    })

    it("Escape while the popup is CLOSED clears the query and wipes the selection to []", async () => {
      el("input").focus()
      el("input").value = "re"
      press(el("input"), "Escape")
      await nextFrame()

      expect(el("input").value).toBe("")
      expect(chipValues()).toEqual([])
      expect(nativeSelected()).toEqual([])
      expect(el("chips").hasAttribute("data-placeholder")).toBe(true)
      expect(el("chips").hasAttribute("role")).toBe(false)
    })

    it("the Escape that closes the popup does NOT double as the wipe", async () => {
      await openMultiple()

      press(el("input"), "Escape")
      await nextFrame()

      expect(el("content").hidden).toBe(true)
      expect(chipValues()).toEqual(["sveltekit", "remix"]) // selection intact
    })
  })

  describe("the chip keyboard map", () => {
    const chip = (value) => el("chips").querySelector(`[data-value="${value}"]`)

    it("ArrowLeft/Right walk the chips; off either end returns to the input", async () => {
      await openMultiple()
      press(el("input"), "ArrowLeft")
      await nextFrame()

      press(chip("remix"), "ArrowLeft")
      expect(document.activeElement).toBe(chip("sveltekit"))

      press(chip("sveltekit"), "ArrowLeft") // off the START -> input
      expect(document.activeElement).toBe(el("input"))

      press(el("input"), "ArrowLeft")
      press(chip("remix"), "ArrowRight") // off the END -> input
      expect(document.activeElement).toBe(el("input"))
    })

    it("Backspace removes the chip: next highlight same index, step back at the tail, input when emptied", async () => {
      application.stop()
      application = await mountMultiple({ values: ["next.js", "sveltekit", "remix"] })

      press(el("input"), "ArrowLeft") // -> remix (the tail)
      press(chip("remix"), "Backspace")
      await nextFrame()

      expect(chipValues()).toEqual(["next.js", "sveltekit"])
      expect(document.activeElement).toBe(chip("sveltekit")) // tail steps BACK

      press(chip("sveltekit"), "ArrowLeft")
      press(chip("next.js"), "Delete")
      await nextFrame()

      expect(chipValues()).toEqual(["sveltekit"])
      expect(document.activeElement).toBe(chip("sveltekit")) // SAME index

      press(chip("sveltekit"), "Backspace")
      await nextFrame()

      expect(chipValues()).toEqual([])
      expect(document.activeElement).toBe(el("input")) // emptied -> input
    })

    it("Enter/Space are no-ops returning to the input; ArrowDown reopens the popup", async () => {
      press(el("input"), "ArrowLeft")

      const enter = press(chip("remix"), "Enter")

      expect(enter.defaultPrevented).toBe(true)
      expect(document.activeElement).toBe(el("input"))
      expect(chipValues()).toEqual(["sveltekit", "remix"])

      press(el("input"), "ArrowLeft")
      press(chip("remix"), "ArrowDown")
      await flushMicrotasks()
      await nextFrame()

      expect(el("content").hasAttribute("data-open")).toBe(true)
      expect(document.activeElement).toBe(el("input"))
    })

    it("a printable char on a chip refocuses the input (typing resumes)", async () => {
      press(el("input"), "ArrowLeft")
      expect(document.activeElement).toBe(chip("remix"))

      press(chip("remix"), "n")

      expect(document.activeElement).toBe(el("input"))
      expect(chipValues()).toEqual(["sveltekit", "remix"])
    })
  })

  describe("value plumbing", () => {
    it("autofill (native change) adopts selectedOptions without re-dispatching native events", () => {
      let nativeEvents = 0
      el("native").addEventListener("input", () => { nativeEvents += 1 })

      for (const option of el("native").options) option.selected = option.value === "astro"
      el("native").dispatchEvent(new Event("change", { bubbles: true }))

      expect(chipValues()).toEqual(["astro"])
      expect(ariaSelected()).toEqual(["false", "false", "false", "false", "true"])
      expect(nativeEvents).toBe(0) // fromNative: no write-back loop
    })

    it("setValue(array) funnels through the pipeline; the value Value carries JSON", () => {
      controller(application).setValue(["nuxt.js", "next.js"])

      expect(chipValues()).toEqual(["nuxt.js", "next.js"]) // VALUE order, not DOM order
      expect(nativeSelected()).toEqual(["next.js", "nuxt.js"]) // native keeps option order
      expect(el("root").getAttribute("data-poetry--core--combobox-value-value"))
        .toBe('["nuxt.js","next.js"]')
    })
  })

  describe("portal-on-open (the ROOT-mounted engine over a portaled popup)", () => {
    it("the popup portals while the chips field stays home; the engine still filters the portaled list", async () => {
      await openMultiple()

      expect(el("content").parentNode).toBe(document.body)
      expect(el("chips").closest("#root")).toBe(el("root"), "the anchor field never moves")

      el("input").value = "re"
      el("input").dispatchEvent(new Event("input", { bubbles: true }))
      await nextFrame()

      // the ROOT-mounted engine reaches the body-level list via the
      // input's aria-controls id - hiding, highlight, empty all live
      expect(el("item-remix").hasAttribute("hidden")).toBe(false)
      expect(el("item-next.js").hasAttribute("hidden")).toBe(true)
      expect(el("item-remix").hasAttribute("data-highlighted")).toBe(true)
    })

    it("clicking an item in the PORTALED list commits via delegation (Stimulus actions unscope at body)", async () => {
      await openMultiple()
      expect(el("content").parentNode).toBe(document.body)

      click(el("item-astro"))
      await nextFrame()

      expect(nativeSelected()).toContain("astro")
      expect(el("content").hidden).toBe(false, "multiple keeps the popup open on select")
    })

    it("Tab from the HOME-side chips input closes and proceeds naturally (no portaled-Tab re-route)", async () => {
      await openMultiple()

      const event = press(el("input"), "Tab")
      await nextFrame()

      expect(event.defaultPrevented).toBe(false)
      expect(el("content").hidden).toBe(true)
      expect(el("content").parentNode).toBe(el("root"))
    })
  })
})
