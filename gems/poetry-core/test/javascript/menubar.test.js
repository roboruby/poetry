import { beforeEach, describe, expect, it } from "vitest"
import { Application } from "@hotwired/stimulus"
import { registerPoetryControllers } from "@poetry/controllers"

// poetry--core--menubar JS-unit: the cross-menu COORDINATOR only - toggle,
// gated hover-slide, edge-navigate, value bookkeeping - layered over real
// poetry--core--menu instances (one per menu, modal: false) and the real
// horizontal roving-focus on the bar. Everything inside an open menu is
// menu.test.js's business; real pointer geometry is the browser pass's.

const nextFrame = () => new Promise((resolve) => setTimeout(resolve, 0))

const el = (id) => document.getElementById(id)

const press = (element, key) =>
  element.dispatchEvent(new KeyboardEvent("keydown", { key, bubbles: true, cancelable: true }))

const click = (element) =>
  element.dispatchEvent(new MouseEvent("click", { bubbles: true, cancelable: true }))

const pointerdown = (element) =>
  element.dispatchEvent(new MouseEvent("pointerdown", { bubbles: true, cancelable: true }))

const pointerenter = (element) =>
  element.dispatchEvent(new MouseEvent("pointerenter", { bubbles: false, cancelable: true }))

const pressEscape = () =>
  window.dispatchEvent(new KeyboardEvent("keydown", { key: "Escape", bubbles: true }))

const record = (type, target) => {
  const seen = []
  target.addEventListener(type, (event) => seen.push(event.detail))
  return seen
}

const TRIGGER_ACTIONS = "pointerdown->poetry--core--menubar#toggle " +
  "pointerenter->poetry--core--menubar#hoverSlide " +
  "keydown->poetry--core--menubar#triggerKeydown"

const menuMarkup = ({ value, disabled = false, items }) => `
  <div class="contents" data-slot="menubar-menu" data-controller="poetry--core--menu"
       data-poetry--core--menu-modal-value="false">
    <button type="button" id="${value}-trigger" data-slot="menubar-trigger" role="menuitem"
            tabindex="-1" data-poetry-collection-item aria-haspopup="menu" aria-expanded="false"
            aria-controls="${value}-content" data-value="${value}"
            ${disabled ? "disabled data-disabled" : ""} data-action="${TRIGGER_ACTIONS}">
      ${value}
    </button>
    <div id="${value}-content" data-slot="menubar-content" role="menu" aria-orientation="vertical"
         aria-labelledby="${value}-trigger" tabindex="-1" data-closed hidden>
      ${items.map((item) => `
        <div id="${value}-${item.toLowerCase().replaceAll(" ", "-")}" data-slot="menubar-item"
             role="menuitem" tabindex="-1" data-poetry-collection-item>${item}</div>`).join("")}
    </div>
  </div>`

const barMarkup = ({ value = "", loop = false, dir = "ltr" } = {}) => `
  <div id="shell" dir="${dir}">
    <div id="bar" data-slot="menubar" data-component="menubar" role="menubar" aria-label="App menu"
         data-closed
         data-controller="poetry--core--menubar poetry--core--roving-focus"
         data-poetry--core--menubar-value-value="${value}"
         data-poetry--core--menubar-loop-value="${loop}"
         data-poetry--core--roving-focus-orientation-value="horizontal"
         data-poetry--core--roving-focus-manage-tabindex-value="true"
         data-poetry--core--roving-focus-loop-value="${loop}"
         data-action="keydown->poetry--core--roving-focus#keydown
                      poetry:menu:edge-navigate->poetry--core--menubar#slideAdjacent
                      poetry:menu:closed->poetry--core--menubar#onMenuClosed">
      ${menuMarkup({ value: "file", items: ["New Tab", "Open"] })}
      ${menuMarkup({ value: "edit", items: ["Undo", "Redo"] })}
      ${menuMarkup({ value: "help", disabled: true, items: ["About"] })}
      ${menuMarkup({ value: "view", items: ["Reload"] })}
    </div>
  </div>`

describe("poetry--core--menubar", () => {
  let application

  beforeEach(async () => {
    document.body.innerHTML = `<button id="outside">outside</button><div id="host"></div>`
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
    el("host").innerHTML = barMarkup(options)
    await nextFrame()
  }

  const state = (value) => [
    el(`${value}-trigger`).hasAttribute("data-popup-open") ? "open" : "closed",
    el(`${value}-trigger`).getAttribute("aria-expanded"),
    el(`${value}-content`).hasAttribute("data-open") ? "open"
      : el(`${value}-content`).hasAttribute("data-closed") ? "closed" : undefined,
    el(`${value}-content`).hidden
  ]

  const tabStops = () => ["file", "edit", "help", "view"]
    .map((value) => el(`${value}-trigger`).getAttribute("tabindex"))

  describe("toggle (pointer)", () => {
    it("pointerdown opens the menu without moving focus into it, sets value + bar state, announces the change", async () => {
      await mount()
      const changes = record("poetry:menubar:value-changed", el("bar"))

      el("file-trigger").focus()
      pointerdown(el("file-trigger"))
      await nextFrame()

      expect(state("file")).toEqual(["open", "true", "open", false])
      expect(el("file-content").getAttribute("data-open-reason")).toBe("trigger-press")
      expect(document.activeElement).toBe(el("file-trigger")) // pointer-open leaves focus on the trigger
      expect(el("bar").hasAttribute("data-open")).toBe(true)
      expect(el("bar").getAttribute("data-poetry--core--menubar-value-value")).toBe("file")
      expect(changes).toEqual([{ value: "file", previous: null, reason: "trigger-press" }])
    })

    it("pointerdown on the OPEN trigger closes (the interact-outside veto stops dismiss-then-reopen)", async () => {
      await mount()
      const changes = record("poetry:menubar:value-changed", el("bar"))

      pointerdown(el("file-trigger"))
      await nextFrame() // the open menu's dismissable layer connects
      pointerdown(el("file-trigger"))
      await nextFrame()

      expect(state("file")).toEqual(["closed", "false", "closed", true])
      expect(el("bar").hasAttribute("data-closed")).toBe(true)
      expect(changes.length).toBe(2)
      expect(changes.at(-1)).toEqual({ value: null, previous: "file", reason: "trigger-press" })
    })

    it("pointerdown on a SIBLING trigger swaps menus in one gesture (no close-reopen flicker events)", async () => {
      await mount()
      const changes = record("poetry:menubar:value-changed", el("bar"))

      pointerdown(el("file-trigger"))
      await nextFrame()
      pointerdown(el("edit-trigger"))
      await nextFrame()

      expect(state("file")).toEqual(["closed", "false", "closed", true])
      expect(state("edit")).toEqual(["open", "true", "open", false])
      expect(changes).toEqual([
        { value: "file", previous: null, reason: "trigger-press" },
        { value: "edit", previous: "file", reason: "trigger-press" }
      ])
    })

    it("a disabled trigger never opens", async () => {
      await mount()

      pointerdown(el("help-trigger"))
      await nextFrame()

      expect(state("help")).toEqual(["closed", "false", "closed", true])
    })
  })

  describe("hover-slide (gated hover)", () => {
    it("pointerenter is a NO-OP from cold - hover never opens", async () => {
      await mount()

      pointerenter(el("edit-trigger"))
      await nextFrame()

      expect(state("edit")).toEqual(["closed", "false", "closed", true])
    })

    it("once a menu is open, pointerenter on a sibling slides: old closes, new opens, focus moves to the new trigger", async () => {
      await mount()
      const changes = record("poetry:menubar:value-changed", el("bar"))

      pointerdown(el("file-trigger"))
      await nextFrame()
      pointerenter(el("edit-trigger"))
      await nextFrame()

      expect(state("file")).toEqual(["closed", "false", "closed", true])
      expect(state("edit")).toEqual(["open", "true", "open", false])
      expect(document.activeElement).toBe(el("edit-trigger"))
      expect(changes.at(-1)).toEqual({ value: "edit", previous: "file", reason: "trigger-hover" })
      expect(tabStops()).toEqual(["-1", "0", "-1", "-1"])
    })
  })

  describe("keyboard open", () => {
    it("ArrowDown opens with the FIRST item focused; ArrowUp with the LAST", async () => {
      await mount()

      el("file-trigger").focus()
      press(el("file-trigger"), "ArrowDown")
      await nextFrame()

      expect(el("file-content").getAttribute("data-open-reason")).toBe("list-navigation")
      expect(el("file-content").getAttribute("data-open-seed")).toBe("first")
      expect(document.activeElement).toBe(el("file-new-tab"))

      pressEscape()
      await nextFrame()

      press(el("file-trigger"), "ArrowUp")
      await nextFrame()

      expect(el("file-content").getAttribute("data-open-reason")).toBe("list-navigation")
      expect(el("file-content").getAttribute("data-open-seed")).toBe("last")
      expect(document.activeElement).toBe(el("file-open"))
    })
  })

  describe("edge-navigate (the cross-menu arrows)", () => {
    async function openFileWithKeyboard() {
      el("file-trigger").focus()
      press(el("file-trigger"), "ArrowDown")
      await nextFrame()
    }

    it("ArrowRight on a plain item closes this menu and opens the NEXT (disabled skipped) with its first item focused", async () => {
      await mount()
      const changes = record("poetry:menubar:value-changed", el("bar"))
      await openFileWithKeyboard()

      press(el("file-new-tab"), "ArrowRight")
      await nextFrame()

      expect(state("file")).toEqual(["closed", "false", "closed", true])
      expect(state("edit")).toEqual(["open", "true", "open", false])
      expect(document.activeElement).toBe(el("edit-undo"))
      expect(changes.at(-1)).toEqual({ value: "edit", previous: "file", reason: "list-navigation" })

      press(el("edit-undo"), "ArrowRight") // edit -> view SKIPS the disabled help
      await nextFrame()

      expect(state("view")).toEqual(["open", "true", "open", false])
      expect(document.activeElement).toBe(el("view-reload"))
      expect(tabStops()).toEqual(["-1", "-1", "-1", "0"])
    })

    it("ArrowLeft is symmetric (also first-item focus - APG menubar, both directions)", async () => {
      await mount()

      el("edit-trigger").focus()
      press(el("edit-trigger"), "ArrowDown")
      await nextFrame()

      press(el("edit-undo"), "ArrowLeft")
      await nextFrame()

      expect(state("edit")).toEqual(["closed", "false", "closed", true])
      expect(state("file")).toEqual(["open", "true", "open", false])
      expect(document.activeElement).toBe(el("file-new-tab"))
    })

    it("no loop (the default): the edge holds - consumed, menu stays open, bar focus does not drift", async () => {
      await mount()

      el("view-trigger").focus()
      press(el("view-trigger"), "ArrowDown")
      await nextFrame()

      press(el("view-reload"), "ArrowRight")
      await nextFrame()

      expect(state("view")).toEqual(["open", "true", "open", false])
      expect(document.activeElement).toBe(el("view-reload"))
    })

    it("loop: true wraps last -> first", async () => {
      await mount({ loop: true })

      el("view-trigger").focus()
      press(el("view-trigger"), "ArrowDown")
      await nextFrame()

      press(el("view-reload"), "ArrowRight")
      await nextFrame()

      expect(state("view")).toEqual(["closed", "false", "closed", true])
      expect(state("file")).toEqual(["open", "true", "open", false])
      expect(document.activeElement).toBe(el("file-new-tab"))
    })

    it("RTL flips the cross-menu arrows (physical direction, logical move)", async () => {
      await mount({ dir: "rtl" })

      el("edit-trigger").focus()
      press(el("edit-trigger"), "ArrowDown")
      await nextFrame()

      press(el("edit-undo"), "ArrowRight") // rtl: physically right = previous menu
      await nextFrame()

      expect(state("file")).toEqual(["open", "true", "open", false])
      expect(document.activeElement).toBe(el("file-new-tab"))
    })
  })

  describe("dismiss + select", () => {
    it("Escape closes the menu, returns focus to ITS trigger, nulls the value (reason: escape-key)", async () => {
      await mount()
      const changes = record("poetry:menubar:value-changed", el("bar"))

      el("file-trigger").focus()
      press(el("file-trigger"), "ArrowDown")
      await nextFrame()
      pressEscape()
      await nextFrame()

      expect(state("file")).toEqual(["closed", "false", "closed", true])
      expect(document.activeElement).toBe(el("file-trigger"))
      expect(el("bar").hasAttribute("data-closed")).toBe(true)
      expect(changes.at(-1)).toEqual({ value: null, previous: "file", reason: "escape-key" })
    })

    it("an outside press closes (reason: outside-press) WITHOUT restoring focus to the trigger (non-modal: focus follows the click)", async () => {
      await mount()
      const changes = record("poetry:menubar:value-changed", el("bar"))

      el("file-trigger").focus()
      press(el("file-trigger"), "ArrowDown") // focus lands INSIDE the menu
      await nextFrame()
      pointerdown(el("outside"))
      await nextFrame()

      expect(state("file")).toEqual(["closed", "false", "closed", true])
      expect(changes.at(-1)).toEqual({ value: null, previous: "file", reason: "outside-press" })
      // The focus-scope restore is VETOED (interacted-outside + non-modal);
      // where focus lands is the browser's business, never the trigger's.
      expect(document.activeElement).not.toBe(el("file-trigger"))
    })

    it("item select closes everything and returns focus to the owning trigger (reason: item-press)", async () => {
      await mount()
      const changes = record("poetry:menubar:value-changed", el("bar"))

      el("file-trigger").focus()
      press(el("file-trigger"), "ArrowDown")
      await nextFrame()
      click(el("file-new-tab"))
      await nextFrame()

      expect(state("file")).toEqual(["closed", "false", "closed", true])
      expect(document.activeElement).toBe(el("file-trigger"))
      expect(changes.at(-1)).toEqual({ value: null, previous: "file", reason: "item-press" })
    })
  })

  describe("controllable value", () => {
    it("a server-declared value opens its menu on connect (reconcile), and flipping the attribute drives the machine", async () => {
      await mount({ value: "edit" })

      expect(state("edit")).toEqual(["open", "true", "open", false])
      expect(el("bar").hasAttribute("data-open")).toBe(true)

      el("bar").setAttribute("data-poetry--core--menubar-value-value", "view")
      await nextFrame()

      expect(state("edit")).toEqual(["closed", "false", "closed", true])
      expect(state("view")).toEqual(["open", "true", "open", false])

      el("bar").setAttribute("data-poetry--core--menubar-value-value", "")
      await nextFrame()

      expect(state("view")).toEqual(["closed", "false", "closed", true])
      expect(el("bar").hasAttribute("data-closed")).toBe(true)
    })
  })
})
