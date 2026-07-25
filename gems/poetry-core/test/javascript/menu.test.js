import { beforeEach, describe, expect, it, vi } from "vitest"
import { Application } from "@hotwired/stimulus"
import { registerPoetryControllers } from "@poetry/controllers"

// poetry--core--menu JS-unit: the menus-family contract surface, jsdom-only
// (geometry-free). Real positioning, the animated presence exit, and the
// hover grace-diagonal are the browser-verification suite's job - what this
// file proves is the state machine: open reasons + initial focus, the
// typeahead buffer, the cancelable select, checkbox/radio state, the
// edge-navigate seam, submenu state-attribute coordination, and dismiss handling
// via the dismissable layer's event.

const nextFrame = () => new Promise((resolve) => setTimeout(resolve, 0))
const flushMicrotasks = () => Promise.resolve().then(() => Promise.resolve())

const el = (id) => document.getElementById(id)

const press = (element, key, options = {}) =>
  element.dispatchEvent(new KeyboardEvent("keydown", { key, bubbles: true, cancelable: true, ...options }))

const click = (element) =>
  element.dispatchEvent(new MouseEvent("click", { bubbles: true, cancelable: true }))

const pointerdown = (element) =>
  element.dispatchEvent(new MouseEvent("pointerdown", { bubbles: true }))

const pressEscape = () =>
  window.dispatchEvent(new KeyboardEvent("keydown", { key: "Escape", bubbles: true }))

const pointerover = (element, relatedTarget = null) =>
  element.dispatchEvent(new MouseEvent("pointerover", { bubbles: true, relatedTarget }))

const pointerout = (element, relatedTarget = null) =>
  element.dispatchEvent(new MouseEvent("pointerout", { bubbles: true, relatedTarget }))

const record = (type, target) => {
  const seen = []
  target.addEventListener(type, (event) => seen.push(event.detail))
  return seen
}

const menuMarkup = ({ open = false, modal = true, loop = false, closeOnSelect = true, dir = "ltr", link = false, submit = false } = {}) => `
  <div id="shell" dir="${dir}">
    <div id="root" data-slot="dropdown-menu" data-component="dropdown-menu"
         data-controller="poetry--core--menu"
         data-poetry--core--menu-open-value="${open}"
         data-poetry--core--menu-modal-value="${modal}"
         data-poetry--core--menu-loop-value="${loop}"
         data-poetry--core--menu-close-on-select-value="${closeOnSelect}">
      <button type="button" id="trigger" data-slot="dropdown-menu-trigger"
              aria-haspopup="menu" aria-controls="content" aria-expanded="false"
              data-action="poetry--core--menu#toggle keydown->poetry--core--menu#triggerKeydown">Open</button>
      <div id="content" data-slot="dropdown-menu-content" role="menu" aria-orientation="vertical"
           aria-labelledby="trigger" tabindex="-1" data-closed hidden>
        ${submit ? `<button id="item-submit" data-slot="dropdown-menu-item" role="menuitem" tabindex="-1"
             data-poetry-collection-item data-action="click->poetry--core--menu#activate">Sign out</button>` : ""}
        ${link ? `<a id="item-link" href="/go" data-slot="dropdown-menu-item" role="menuitem" tabindex="-1"
             data-poetry-collection-item data-action="click->poetry--core--menu#activate">Home</a>` : ""}
        <div id="item-profile" data-slot="dropdown-menu-item" role="menuitem" tabindex="-1"
             data-poetry-collection-item>Profile</div>
        <div id="item-archive" data-slot="dropdown-menu-item" role="menuitem" tabindex="-1"
             data-poetry-collection-item data-text-value="Zip">Archive</div>
        <div id="item-settings" data-slot="dropdown-menu-item" role="menuitem" tabindex="-1"
             data-poetry-collection-item>Settings</div>
        <div id="item-disabled" data-slot="dropdown-menu-item" role="menuitem" tabindex="-1"
             data-poetry-collection-item data-disabled aria-disabled="true">Quit</div>
        <div id="item-sync" data-slot="dropdown-menu-item" role="menuitem" tabindex="-1"
             data-poetry-collection-item data-variant="destructive" data-value="sync">Sync</div>
        <div id="checkbox-status" data-slot="dropdown-menu-checkbox-item" role="menuitemcheckbox" tabindex="-1"
             data-poetry-collection-item aria-checked="false" data-unchecked data-value="status-bar">Status Bar</div>
        <div id="radio-group" data-slot="dropdown-menu-radio-group" role="group" data-value="">
          <div id="radio-top" data-slot="dropdown-menu-radio-item" role="menuitemradio" tabindex="-1"
               data-poetry-collection-item data-value="top" aria-checked="false" data-unchecked
               data-close-on-select="false">Top</div>
          <div id="radio-bottom" data-slot="dropdown-menu-radio-item" role="menuitemradio" tabindex="-1"
               data-poetry-collection-item data-value="bottom" aria-checked="false" data-unchecked
               data-close-on-select="false">Bottom</div>
        </div>
        <div id="sub-a" data-slot="dropdown-menu-sub">
          <div id="sub-a-trigger" data-slot="dropdown-menu-sub-trigger" role="menuitem" tabindex="-1"
               data-poetry-collection-item aria-haspopup="menu" aria-expanded="false"
               aria-controls="sub-a-content">Share</div>
          <div id="sub-a-content" data-slot="dropdown-menu-sub-content" role="menu" aria-orientation="vertical"
               aria-labelledby="sub-a-trigger" tabindex="-1" data-closed hidden>
            <div id="sub-a-email" data-slot="dropdown-menu-item" role="menuitem" tabindex="-1"
                 data-poetry-collection-item>Email</div>
            <div id="sub-a-message" data-slot="dropdown-menu-item" role="menuitem" tabindex="-1"
                 data-poetry-collection-item>Message</div>
          </div>
        </div>
        <div id="sub-b" data-slot="dropdown-menu-sub">
          <div id="sub-b-trigger" data-slot="dropdown-menu-sub-trigger" role="menuitem" tabindex="-1"
               data-poetry-collection-item aria-haspopup="menu" aria-expanded="false"
               aria-controls="sub-b-content">Export</div>
          <div id="sub-b-content" data-slot="dropdown-menu-sub-content" role="menu" aria-orientation="vertical"
               aria-labelledby="sub-b-trigger" tabindex="-1" data-closed hidden>
            <div id="sub-b-pdf" data-slot="dropdown-menu-item" role="menuitem" tabindex="-1"
                 data-poetry-collection-item>PDF</div>
          </div>
        </div>
      </div>
    </div>
  </div>`

describe("poetry--core--menu", () => {
  let application

  beforeEach(async () => {
    vi.useRealTimers()
    document.body.innerHTML = `<button id="outside">outside</button><div id="host"></div>`
    application = Application.start()
    registerPoetryControllers(application)
    await nextFrame()
    // application.stop() does NOT disconnect live controllers (see
    // dialog.test.js) - remove the tree and await the disconnect so the
    // dismissable/focus-scope class-level stacks cannot leak across tests.
    return async () => {
      vi.useRealTimers()
      el("host")?.replaceChildren()
      await nextFrame()
      application.stop()
    }
  })

  async function mount(options = {}) {
    el("host").innerHTML = menuMarkup(options)
    await nextFrame()
  }

  async function openWithPointer() {
    el("trigger").focus()
    click(el("trigger"))
    await nextFrame()
  }

  async function openWithKey(key) {
    el("trigger").focus()
    press(el("trigger"), key)
    await nextFrame()
  }

  describe("open / close reasons + focus targeting", () => {
    it("pointer open: data-open/data-popup-open + aria-expanded flip, data-open-reason=trigger-press, focus lands on the content (not an item)", async () => {
      await mount()
      const opens = record("poetry:menu:open", el("root"))

      await openWithPointer()

      expect(el("content").hasAttribute("data-open")).toBe(true)
      expect(el("content").hidden).toBe(false)
      expect(el("content").getAttribute("data-open-reason")).toBe("trigger-press")
      expect(el("trigger").hasAttribute("data-popup-open")).toBe(true)
      expect(el("trigger").getAttribute("aria-expanded")).toBe("true")
      expect(document.activeElement).toBe(el("content"))
      expect(opens).toEqual([{ reason: "trigger-press" }])
    })

    it("ArrowDown opens with reason list-navigation + seed first and focuses the FIRST enabled item", async () => {
      await mount()

      await openWithKey("ArrowDown")

      expect(el("content").getAttribute("data-open-reason")).toBe("list-navigation")
      expect(el("content").getAttribute("data-open-seed")).toBe("first")
      expect(document.activeElement).toBe(el("item-profile"))
    })

    it("ArrowUp opens with reason list-navigation + seed last and focuses the LAST enabled item", async () => {
      await mount()

      await openWithKey("ArrowUp")

      expect(el("content").getAttribute("data-open-reason")).toBe("list-navigation")
      expect(el("content").getAttribute("data-open-seed")).toBe("last")
      expect(document.activeElement).toBe(el("sub-b-trigger"))
    })

    it("toggle on an open menu closes it (reason: trigger-press) and restores focus to the trigger", async () => {
      await mount()
      const closes = record("poetry:menu:closed", el("root"))

      await openWithPointer()
      click(el("trigger"))
      await nextFrame()

      expect(el("content").hasAttribute("data-closed")).toBe(true)
      expect(el("content").hidden).toBe(true)
      expect(el("content").hasAttribute("data-open-reason")).toBe(false)
      expect(el("trigger").getAttribute("aria-expanded")).toBe("false")
      expect(closes).toEqual([{ reason: "trigger-press" }])
      expect(document.activeElement).toBe(el("trigger"))
    })

    it("a REAL trigger press on an open menu closes once and never re-opens (pointerdown, then click)", async () => {
      await mount()
      const closes = record("poetry:menu:closed", el("root"))
      const opens = record("poetry:menu:open", el("root"))

      await openWithPointer()

      expect(opens.length).toBe(1)

      // A real press reaches the dismissable layer as pointerdown FIRST (the
      // trigger sits outside the content) - without the trigger veto that
      // closes on pointerdown and the trailing click re-opens.
      el("trigger").dispatchEvent(new MouseEvent("pointerdown", { bubbles: true }))
      click(el("trigger"))
      await nextFrame()

      expect(el("content").hidden).toBe(true)
      expect(el("trigger").getAttribute("aria-expanded")).toBe("false")
      expect(closes).toEqual([{ reason: "trigger-press" }])
      expect(opens.length).toBe(1) // no phantom re-open
    })

    it("Tab while open closes the menu", async () => {
      await mount()
      await openWithKey("ArrowDown")

      press(el("item-profile"), "Tab")
      await nextFrame()

      expect(el("content").hasAttribute("data-closed")).toBe(true)
      expect(el("content").hidden).toBe(true)
      expect(el("content").hasAttribute("data-open-seed")).toBe(false)
    })

    it("the open value is controllable: flipping the attribute drives the machine (server-owned state)", async () => {
      await mount()

      el("root").setAttribute("data-poetry--core--menu-open-value", "true")
      await nextFrame()
      expect(el("content").hasAttribute("data-open")).toBe(true)

      el("root").setAttribute("data-poetry--core--menu-open-value", "false")
      await nextFrame()
      expect(el("content").hasAttribute("data-closed")).toBe(true)
      expect(el("content").hidden).toBe(true)
    })
  })

  describe("typeahead", () => {
    it("matches forward from the focused item, cycles on a repeated letter, and resets after the timeout", async () => {
      await mount()
      await openWithKey("ArrowDown")
      expect(document.activeElement).toBe(el("item-profile"))

      vi.useFakeTimers()

      press(el("item-profile"), "s")
      expect(document.activeElement).toBe(el("item-settings"))

      press(el("item-settings"), "s") // repeat cycles to the next s-match
      expect(document.activeElement).toBe(el("item-sync"))

      press(el("item-sync"), "s")
      expect(document.activeElement).toBe(el("checkbox-status"))

      press(el("checkbox-status"), "s") // wraps (Share) - disabled Quit skipped throughout
      expect(document.activeElement).toBe(el("sub-a-trigger"))

      await vi.advanceTimersByTimeAsync(1001) // the 1s buffer window expires

      press(el("sub-a-trigger"), "t") // a fresh single-letter search
      expect(document.activeElement).toBe(el("radio-top"))
    })

    it("a growing buffer narrows instead of cycling, and stays put while the current item still matches", async () => {
      await mount()
      await openWithKey("ArrowDown")

      vi.useFakeTimers()

      press(el("item-profile"), "s")
      expect(document.activeElement).toBe(el("item-settings"))

      press(el("item-settings"), "h") // buffer "sh" -> Share (Settings no longer matches)
      expect(document.activeElement).toBe(el("sub-a-trigger"))

      press(el("sub-a-trigger"), "a") // buffer "sha" - Share still matches: no move
      expect(document.activeElement).toBe(el("sub-a-trigger"))
    })

    it("text_value overrides the rendered label", async () => {
      await mount()
      await openWithKey("ArrowDown")

      press(el("item-profile"), "z") // Archive carries data-text-value="Zip"
      expect(document.activeElement).toBe(el("item-archive"))

      press(el("item-archive"), "a") // and its own label no longer matches ("a" finds nothing)
      expect(document.activeElement).toBe(el("item-archive"))
    })

    it("is scoped to the deepest open level", async () => {
      await mount()
      await openWithKey("ArrowDown")

      el("sub-a-trigger").focus()
      press(el("sub-a-trigger"), "ArrowRight")
      expect(document.activeElement).toBe(el("sub-a-email"))

      press(el("sub-a-email"), "m") // Message, inside the sub
      expect(document.activeElement).toBe(el("sub-a-message"))

      press(el("sub-a-message"), "p") // Profile/PDF live on OTHER levels: no move
      expect(document.activeElement).toBe(el("sub-a-message"))
    })
  })

  describe("select + activation", () => {
    it("click activation dispatches cancelable poetry:menu:select and closes (reason: item-press) with focus back on the trigger", async () => {
      await mount()
      const selects = record("poetry:menu:select", el("root"))
      const closes = record("poetry:menu:closed", el("root"))

      await openWithPointer()
      click(el("item-sync"))
      await nextFrame()

      expect(selects.length).toBe(1)
      expect(selects[0].item).toBe(el("item-sync"))
      expect(selects[0].value).toBe("sync")
      expect(selects[0].variant).toBe("destructive")
      expect(selects[0].kind).toBe("item")
      expect(el("content").hasAttribute("data-closed")).toBe(true)
      expect(closes).toEqual([{ reason: "item-press" }])
      expect(document.activeElement).toBe(el("trigger"))
    })

    it("Enter on a link item follows the anchor (a synthetic click), not a JS-only activate", async () => {
      await mount({ link: true })
      await openWithKey("ArrowDown") // opens + focuses the FIRST item - the link
      expect(document.activeElement).toBe(el("item-link"))

      const clicks = []
      el("item-link").addEventListener("click", (event) => {
        event.preventDefault() // stop jsdom attempting the navigation itself
        clicks.push(event)
      })

      press(el("item-link"), "Enter")
      await nextFrame()

      // The keyboard path routed through item.click() so the anchor navigates
      // (Turbo-intercepted in a real app); non-link items never dispatch a click.
      expect(clicks.length).toBe(1)
    })

    it("Enter on a submit (button) item acts through the button (a synthetic click)", async () => {
      await mount({ submit: true })
      await openWithKey("ArrowDown") // opens + focuses the FIRST item - the submit button
      expect(document.activeElement).toBe(el("item-submit"))

      const clicks = []
      el("item-submit").addEventListener("click", (event) => {
        event.preventDefault() // a real button would submit its form here
        clicks.push(event)
      })

      press(el("item-submit"), "Enter")
      await nextFrame()

      expect(clicks.length).toBe(1)
    })

    it("Enter activates the focused item", async () => {
      await mount()
      const selects = record("poetry:menu:select", el("root"))

      await openWithKey("ArrowDown")
      press(el("item-profile"), "Enter")
      await nextFrame()

      expect(selects.length).toBe(1)
      expect(selects[0].item).toBe(el("item-profile"))
      expect(el("content").hasAttribute("data-closed")).toBe(true)
    })

    it("preventDefault on select vetoes the close (Radix onSelect parity)", async () => {
      await mount()
      el("host").addEventListener("poetry:menu:select", (event) => event.preventDefault())

      await openWithPointer()
      click(el("item-profile"))
      await nextFrame()

      expect(el("content").hasAttribute("data-open")).toBe(true)
    })

    it("closeOnSelect: false at the menu level keeps the menu open after select", async () => {
      await mount({ closeOnSelect: false })

      await openWithPointer()
      click(el("item-profile"))
      await nextFrame()

      expect(el("content").hasAttribute("data-open")).toBe(true)
    })

    it("select from inside a sub closes the WHOLE chain", async () => {
      await mount()
      await openWithKey("ArrowDown")

      el("sub-a-trigger").focus()
      press(el("sub-a-trigger"), "ArrowRight")
      press(el("sub-a-email"), "Enter")
      await nextFrame()

      expect(el("sub-a-content").hasAttribute("data-closed")).toBe(true)
      expect(el("sub-a-trigger").hasAttribute("data-popup-open")).toBe(false)
      expect(el("content").hasAttribute("data-closed")).toBe(true)
    })
  })

  describe("checkbox / radio state", () => {
    it("checkbox activation flips aria-checked + data-checked TOGETHER and fires poetry:menu:change before select", async () => {
      await mount({ closeOnSelect: false })
      const order = []
      el("root").addEventListener("poetry:menu:change", () => order.push("change"))
      el("root").addEventListener("poetry:menu:select", () => order.push("select"))
      const changes = record("poetry:menu:change", el("root"))

      await openWithPointer()
      click(el("checkbox-status"))

      expect(el("checkbox-status").getAttribute("aria-checked")).toBe("true")
      expect(el("checkbox-status").hasAttribute("data-checked")).toBe(true)
      expect(changes).toEqual([{ kind: "checkbox", value: "status-bar", checked: true, group_value: null }])
      expect(order).toEqual(["change", "select"])

      click(el("checkbox-status")) // toggles back off
      expect(el("checkbox-status").getAttribute("aria-checked")).toBe("false")
      expect(el("checkbox-status").hasAttribute("data-unchecked")).toBe(true)
      expect(changes.at(-1)).toEqual({ kind: "checkbox", value: "status-bar", checked: false, group_value: null })
    })

    it("a canceled select still keeps committed checkbox state (state commits BEFORE the event)", async () => {
      await mount()
      el("host").addEventListener("poetry:menu:select", (event) => event.preventDefault())

      await openWithPointer()
      click(el("checkbox-status"))

      expect(el("checkbox-status").getAttribute("aria-checked")).toBe("true")
      expect(el("content").hasAttribute("data-open")).toBe(true)
    })

    it("radio activation checks one item, unchecks its siblings, writes the group value, and (close_on_select: false) keeps the menu open", async () => {
      await mount()
      const changes = record("poetry:menu:change", el("root"))

      await openWithPointer()
      click(el("radio-top"))

      expect(el("radio-top").getAttribute("aria-checked")).toBe("true")
      expect(el("radio-top").hasAttribute("data-checked")).toBe(true)
      expect(el("radio-group").getAttribute("data-value")).toBe("top")
      expect(el("content").hasAttribute("data-open")).toBe(true)

      click(el("radio-bottom"))

      expect(el("radio-bottom").getAttribute("aria-checked")).toBe("true")
      expect(el("radio-top").getAttribute("aria-checked")).toBe("false")
      expect(el("radio-top").hasAttribute("data-unchecked")).toBe(true)
      expect(el("radio-group").getAttribute("data-value")).toBe("bottom")
      expect(changes).toEqual([
        { kind: "radio", value: "top", checked: true, group_value: "top" },
        { kind: "radio", value: "bottom", checked: true, group_value: "bottom" }
      ])
    })
  })

  describe("edge-navigate (the Menubar seam)", () => {
    it("ArrowRight on a plain ROOT item fires poetry:menu:edge-navigate {direction: right} and changes nothing standalone", async () => {
      await mount()
      const edges = record("poetry:menu:edge-navigate", el("root"))

      await openWithKey("ArrowDown")
      press(el("item-profile"), "ArrowRight")

      expect(edges).toEqual([{ direction: "right" }])
      expect(el("content").hasAttribute("data-open")).toBe(true)
      expect(document.activeElement).toBe(el("item-profile"))
    })

    it("ArrowLeft at ROOT level fires {direction: left}; canceling it consumes the keydown", async () => {
      await mount()
      const edges = record("poetry:menu:edge-navigate", el("root"))
      el("root").addEventListener("poetry:menu:edge-navigate", (event) => event.preventDefault())

      await openWithKey("ArrowDown")
      const notConsumed = press(el("item-profile"), "ArrowLeft")

      expect(edges).toEqual([{ direction: "left" }])
      expect(notConsumed).toBe(false) // the coordinator canceled -> keydown preventDefault'ed
    })

    it("never fires from inside a sub, and not from a sub-trigger (ArrowRight there opens the sub)", async () => {
      await mount()
      const edges = record("poetry:menu:edge-navigate", el("root"))

      await openWithKey("ArrowDown")
      el("sub-a-trigger").focus()
      press(el("sub-a-trigger"), "ArrowRight") // opens the sub - no edge event

      press(el("sub-a-email"), "ArrowRight") // plain item INSIDE the sub - no edge event
      press(el("sub-a-email"), "ArrowLeft") // closes the sub - no edge event

      expect(edges).toEqual([])
    })
  })

  describe("disabled items", () => {
    it("list-navigation seed first skips a disabled leading item", async () => {
      await mount()
      el("item-profile").setAttribute("data-disabled", "")
      el("item-profile").setAttribute("aria-disabled", "true")

      await openWithKey("ArrowDown")

      expect(document.activeElement).toBe(el("item-archive"))
    })

    it("click on a disabled item neither selects nor closes", async () => {
      await mount()
      const selects = record("poetry:menu:select", el("root"))

      await openWithPointer()
      click(el("item-disabled"))
      await nextFrame()

      expect(selects).toEqual([])
      expect(el("content").hasAttribute("data-open")).toBe(true)
    })

    it("typeahead skips disabled items", async () => {
      await mount()
      await openWithKey("ArrowDown")

      press(el("item-profile"), "q") // "Quit" is the only q-item and it is disabled
      expect(document.activeElement).toBe(el("item-profile"))
    })
  })

  describe("submenus", () => {
    it("ArrowRight on a sub-trigger opens the sub (data-popup-open/data-open + aria-expanded on both halves) and focuses its first item", async () => {
      await mount()
      await openWithKey("ArrowDown")

      el("sub-a-trigger").focus()
      press(el("sub-a-trigger"), "ArrowRight")

      expect(el("sub-a-trigger").hasAttribute("data-popup-open")).toBe(true)
      expect(el("sub-a-trigger").getAttribute("aria-expanded")).toBe("true")
      expect(el("sub-a-content").hasAttribute("data-open")).toBe(true)
      expect(el("sub-a-content").hidden).toBe(false)
      expect(document.activeElement).toBe(el("sub-a-email"))
    })

    it("ArrowLeft inside a sub closes it and returns focus to its sub-trigger", async () => {
      await mount()
      await openWithKey("ArrowDown")
      el("sub-a-trigger").focus()
      press(el("sub-a-trigger"), "ArrowRight")

      press(el("sub-a-email"), "ArrowLeft")

      expect(el("sub-a-content").hasAttribute("data-closed")).toBe(true)
      expect(el("sub-a-content").hidden).toBe(true)
      expect(el("sub-a-trigger").hasAttribute("data-popup-open")).toBe(false)
      expect(el("sub-a-trigger").getAttribute("aria-expanded")).toBe("false")
      expect(document.activeElement).toBe(el("sub-a-trigger"))
    })

    it("RTL swaps the open/close arrows", async () => {
      await mount({ dir: "rtl" })
      await openWithKey("ArrowDown")

      el("sub-a-trigger").focus()
      press(el("sub-a-trigger"), "ArrowLeft") // rtl: Left opens
      expect(el("sub-a-content").hasAttribute("data-open")).toBe(true)

      press(el("sub-a-email"), "ArrowRight") // rtl: Right closes
      expect(el("sub-a-content").hasAttribute("data-closed")).toBe(true)
      expect(document.activeElement).toBe(el("sub-a-trigger"))
    })

    it("opening a sub closes its open sibling (at most ONE open sub per level)", async () => {
      await mount()
      await openWithKey("ArrowDown")

      el("sub-a-trigger").focus()
      press(el("sub-a-trigger"), "ArrowRight")
      expect(el("sub-a-content").hasAttribute("data-open")).toBe(true)

      el("sub-b-trigger").focus()
      press(el("sub-b-trigger"), "ArrowRight")

      expect(el("sub-b-content").hasAttribute("data-open")).toBe(true)
      expect(el("sub-a-content").hasAttribute("data-closed")).toBe(true)
      expect(el("sub-a-trigger").hasAttribute("data-popup-open")).toBe(false)
    })

    it("hover opens after the 100ms intent delay WITHOUT moving focus; leaving closes after 300ms", async () => {
      await mount()
      await openWithPointer()
      const focusedBefore = document.activeElement

      vi.useFakeTimers()

      pointerover(el("sub-a-trigger"), el("item-profile"))
      expect(el("sub-a-content").hasAttribute("data-closed")).toBe(true) // not yet - intent delay

      await vi.advanceTimersByTimeAsync(100)
      expect(el("sub-a-content").hasAttribute("data-open")).toBe(true)
      expect(document.activeElement).toBe(focusedBefore)

      pointerout(el("sub-a-trigger"), el("item-profile"))
      pointerover(el("item-profile"), el("sub-a-trigger"))
      await vi.advanceTimersByTimeAsync(299)
      expect(el("sub-a-content").hasAttribute("data-open")).toBe(true) // still within the close window

      await vi.advanceTimersByTimeAsync(1)
      expect(el("sub-a-content").hasAttribute("data-closed")).toBe(true)
    })

    it("entering the sub-content within the close window keeps the sub open (the grace path)", async () => {
      await mount()
      await openWithPointer()

      vi.useFakeTimers()

      pointerover(el("sub-a-trigger"), el("item-profile"))
      await vi.advanceTimersByTimeAsync(100)
      expect(el("sub-a-content").hasAttribute("data-open")).toBe(true)

      pointerout(el("sub-a-trigger"), document.body) // diagonal travel: briefly off both halves
      pointerover(el("sub-a-email")) // lands in the sub-content before the delay elapses
      await vi.advanceTimersByTimeAsync(500)

      expect(el("sub-a-content").hasAttribute("data-open")).toBe(true)
    })
  })

  describe("dismiss handling (via the dismissable layer)", () => {
    it("Escape closes the menu (reason: escape-key) and focus returns to the trigger", async () => {
      await mount()
      const closes = record("poetry:menu:closed", el("root"))

      await openWithPointer()
      pressEscape()
      await nextFrame()

      expect(el("content").hasAttribute("data-closed")).toBe(true)
      expect(el("content").hidden).toBe(true)
      expect(closes).toEqual([{ reason: "escape-key" }])
      expect(document.activeElement).toBe(el("trigger"))
    })

    it("Escape closes the DEEPEST level only: sub first (focus to ITS sub-trigger), then the root", async () => {
      await mount()
      await openWithKey("ArrowDown")
      el("sub-a-trigger").focus()
      press(el("sub-a-trigger"), "ArrowRight")
      await nextFrame() // the sub's dismissable layer connects

      pressEscape()
      await nextFrame()

      expect(el("sub-a-content").hasAttribute("data-closed")).toBe(true)
      expect(document.activeElement).toBe(el("sub-a-trigger"))
      expect(el("content").hasAttribute("data-open")).toBe(true)

      pressEscape()
      await nextFrame()

      expect(el("content").hasAttribute("data-closed")).toBe(true)
      expect(document.activeElement).toBe(el("trigger"))
    })

    it("an outside press closes the whole chain (reason: outside-press); modal restores focus to the trigger", async () => {
      await mount()
      const closes = record("poetry:menu:closed", el("root"))

      await openWithKey("ArrowDown")
      el("sub-a-trigger").focus()
      press(el("sub-a-trigger"), "ArrowRight")
      await nextFrame()

      pointerdown(el("outside"))
      await nextFrame()

      expect(el("sub-a-content").hasAttribute("data-closed")).toBe(true)
      expect(el("content").hasAttribute("data-closed")).toBe(true)
      expect(closes).toEqual([{ reason: "outside-press" }])
      expect(document.activeElement).toBe(el("trigger"))
    })

    it("modal: false skips the focus restore on outside interaction (focus follows the click)", async () => {
      await mount({ modal: false })

      await openWithPointer()
      pointerdown(el("outside"))
      await nextFrame()
      await flushMicrotasks()

      expect(el("content").hasAttribute("data-closed")).toBe(true)
      expect(document.activeElement).not.toBe(el("trigger"))
    })

    it("modal forwards to the layer stack: trapped focus-scope + the body pointer-events scrim while open", async () => {
      await mount()
      await openWithPointer()

      expect(el("content").getAttribute("data-poetry--core--focus-scope-trapped-value")).toBe("true")
      expect(document.body.style.pointerEvents).toBe("none")
      expect(el("content").style.pointerEvents).toBe("auto")

      click(el("trigger"))
      await nextFrame()

      expect(document.body.style.pointerEvents).toBe("")
    })
  })
})
