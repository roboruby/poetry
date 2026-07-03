import { beforeEach, describe, expect, it } from "vitest"
import { Application } from "@hotwired/stimulus"
import { registerPoetryControllers } from "@poetry/controllers"

// poetry--core--combobox JS-unit (Combobox): the thin
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

const markup = ({ value = "", open = false, modal = false } = {}) => {
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
              data-state="closed" ${value ? "" : "data-placeholder"}
              data-action="poetry--core--combobox#toggle keydown->poetry--core--combobox#triggerKeydown">
        <span id="display" data-slot="combobox-value" data-placeholder="Select framework…">${selectedLabel ?? "Select framework…"}</span>
      </button>
      <div id="content" data-slot="combobox-content" tabindex="-1" data-state="closed" ${open ? "" : "hidden"}>
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
                   aria-selected="${v === value}" data-state="${v === value ? "checked" : "unchecked"}"
                   data-action="click->poetry--core--command#activate pointermove->poetry--core--command#pointerHighlight">
                <span data-slot="command-item-text">${label}</span>
                <span data-slot="combobox-item-indicator" aria-hidden="true"></span>
              </div>`).join("")}
          </div>
          <span id="status" data-slot="command-status" role="status" aria-live="polite"></span>
        </div>
      </div>
    </div>`
}

const controller = (application) =>
  application.getControllerForElementAndIdentifier(el("root"), "poetry--core--combobox")

const ariaSelected = () => FRAMEWORKS.map(([v]) => el(`item-${v}`).getAttribute("aria-selected"))
const dataStates = () => FRAMEWORKS.map(([v]) => el(`item-${v}`).dataset.state)

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
      expect(el("content").dataset.state).toBe("open")
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

      expect(el("content").dataset.state).toBe("open")
      expect(el("content").getAttribute("data-open-reason")).toBe("typed")
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

      expect(reason).toBe("pointer")
    })

    it("appends focus-scope + dismissable but NEVER roving-focus (the activedescendant popup)", async () => {
      await open()

      const tokens = (el("content").getAttribute("data-controller") ?? "").split(/\s+/)

      expect(tokens).toContain("poetry--core--focus-scope")
      expect(tokens).toContain("poetry--core--dismissable")
      expect(tokens).not.toContain("poetry--core--roving-focus")
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
      expect(dataStates()).toEqual(["unchecked", "unchecked", "checked", "unchecked", "unchecked"])
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

  describe("close without commit", () => {
    it("Esc closes, leaves the value untouched, resets the query, and returns focus to the trigger", async () => {
      await open()

      el("input").value = "re"
      el("input").dispatchEvent(new Event("input", { bubbles: true }))

      pressEscape()
      await nextFrame()

      expect(el("content").hidden).toBe(true)
      expect(el("native").value).toBe("sveltekit")
      expect(el("input").value).toBe("") // clean reopen (the React-remount behavior, made explicit)
      expect(el("item-next.js").hasAttribute("hidden")).toBe(false) // visibility re-derived
      expect(document.activeElement).toBe(el("trigger"))
    })

    it("Tab closes WITHOUT commit and lets focus proceed (Popover semantics - the Select delta)", async () => {
      await open()

      const event = press(el("input"), "Tab")
      await nextFrame()

      expect(event.defaultPrevented).toBe(false) // focus proceeds naturally
      expect(el("content").hidden).toBe(true)
      expect(el("native").value).toBe("sveltekit")
      expect(el("trigger").getAttribute("aria-expanded")).toBe("false")
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

      expect(reason).toBe("escape")
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
      expect(dataStates()).toEqual(["unchecked", "unchecked", "unchecked", "checked", "unchecked"])
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
})
