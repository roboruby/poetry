import { beforeEach, describe, expect, it } from "vitest"
import { Application } from "@hotwired/stimulus"
import { registerPoetryControllers } from "@poetry/controllers"

// poetry--core--popover JS-unit: the thin owner over the token-activated
// layer stack - toggle flips the state attributes + aria-expanded on both trigger and
// content; open appends focus-scope + dismissable with trapped/scrim values
// = modal; close removes them after presence; dismiss -> close with reason
// escape|outside; #suppressRestore on outside+non-modal; reconcile-on-connect
// for server-rendered open. Positioning (popper) is markup-owned and not
// exercised here; real focus-trap behavior is the browser pass's job.

const nextFrame = () => new Promise((resolve) => setTimeout(resolve, 0))

const el = (id) => document.getElementById(id)

const TRAPPED = "data-poetry--core--focus-scope-trapped-value"
const SCRIM = "data-poetry--core--dismissable-disable-outside-pointer-events-value"

const controllersOf = (id) => (el(id).getAttribute("data-controller") ?? "").split(/\s+/).filter(Boolean)

const pressEscape = () =>
  window.dispatchEvent(new KeyboardEvent("keydown", { key: "Escape", bubbles: true }))

const record = (type, target) => {
  const seen = []
  target.addEventListener(type, (event) => seen.push(event.detail))
  return seen
}

const markup = ({ open = false, modal = false } = {}) => `
  <div id="root" data-slot="popover" data-component="popover"
       data-controller="poetry--core--popover"
       data-poetry--core--popover-open-value="${open}"
       data-poetry--core--popover-modal-value="${modal}">
    <button id="trigger" type="button" data-slot="popover-trigger"
            aria-haspopup="dialog" aria-controls="content"
            aria-expanded="${open}" ${open ? "data-popup-open" : ""}
            data-action="poetry--core--popover#toggle">Open popover</button>
    <div id="content" data-slot="popover-content" role="dialog" tabindex="-1"
         ${open ? "data-open" : "data-closed"} ${open ? "" : "hidden"}>
      <input id="field" type="text">
      <button id="inner" type="button">Confirm</button>
    </div>
  </div>`

describe("poetry--core--popover", () => {
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
    el("host").innerHTML = markup(options)
    await nextFrame()
  }

  describe("toggle", () => {
    it("opens: data-popup-open/data-open + aria-expanded flip on trigger and content, content unhides, poetry:popover:open fires", async () => {
      await mount()
      const opens = record("poetry:popover:open", el("root"))

      el("trigger").click()
      await nextFrame()

      expect(el("trigger").hasAttribute("data-popup-open")).toBe(true)
      expect(el("trigger").getAttribute("aria-expanded")).toBe("true")
      expect(el("content").hasAttribute("data-open")).toBe(true)
      expect(el("content").hidden).toBe(false)
      expect(opens.length).toBe(1)
    })

    it("closes: reverses the attributes, hides after presence, and reports reason trigger-press", async () => {
      await mount()
      const closes = record("poetry:popover:closed", el("root"))

      el("trigger").click()
      await nextFrame()
      el("trigger").click()
      await nextFrame()

      expect(el("trigger").hasAttribute("data-popup-open")).toBe(false)
      expect(el("trigger").getAttribute("aria-expanded")).toBe("false")
      expect(el("content").hasAttribute("data-closed")).toBe(true)
      expect(el("content").hidden).toBe(true)
      expect(closes).toEqual([{ reason: "trigger-press" }])
    })

    it("a REAL trigger press on an open popover closes once and never re-opens (pointerdown, then click)", async () => {
      await mount()
      const closes = record("poetry:popover:closed", el("root"))
      const opens = record("poetry:popover:open", el("root"))

      el("trigger").click()
      await nextFrame()

      expect(opens.length).toBe(1)

      // A real press reaches the dismissable layer as pointerdown FIRST (the
      // trigger sits outside the content element), then the button's click
      // fires. Without the trigger veto that sequence closes on pointerdown
      // and re-opens on click - the popover appears to never close. iOS
      // light-dismiss double-fires arrive through this same seam.
      el("trigger").dispatchEvent(new MouseEvent("pointerdown", { bubbles: true }))
      el("trigger").click()
      await nextFrame()

      expect(el("content").hidden).toBe(true)
      expect(el("trigger").getAttribute("aria-expanded")).toBe("false")
      expect(closes).toEqual([{ reason: "trigger-press" }])
      expect(opens.length).toBe(1) // no phantom re-open
    })
  })

  describe("the token-activated layer stack", () => {
    it("open appends focus-scope + dismissable with trapped/scrim = modal (false default); close removes them", async () => {
      await mount()

      el("trigger").click()
      await nextFrame()

      expect(controllersOf("content")).toContain("poetry--core--focus-scope")
      expect(controllersOf("content")).toContain("poetry--core--dismissable")
      expect(el("content").getAttribute(TRAPPED)).toBe("false")
      expect(el("content").getAttribute(SCRIM)).toBe("false")

      el("trigger").click()
      await nextFrame()

      expect(controllersOf("content")).toEqual([])
    })

    it("modal: true forwards trapped + the pointer-events scrim", async () => {
      await mount({ modal: true })

      el("trigger").click()
      await nextFrame()

      expect(el("content").getAttribute(TRAPPED)).toBe("true")
      expect(el("content").getAttribute(SCRIM)).toBe("true")
    })

    it("a closed popover on the page never steals focus at load (no static layers)", async () => {
      await mount()

      expect(controllersOf("content")).toEqual([])
      expect(document.activeElement).toBe(document.body)
    })
  })

  describe("initial focus and focus return (the dialog pattern)", () => {
    it("focus moves to the first tabbable on open (focus-scope's mount default, not vetoed)", async () => {
      await mount()

      el("trigger").click()
      await nextFrame()

      expect(document.activeElement).toBe(el("field"))
    })

    it("Esc closes with reason escape-key and focus returns to the trigger", async () => {
      await mount()
      const closes = record("poetry:popover:closed", el("root"))

      el("trigger").focus()
      el("trigger").click()
      await nextFrame()
      pressEscape()
      await nextFrame()

      expect(closes).toEqual([{ reason: "escape-key" }])
      expect(el("content").hidden).toBe(true)
      expect(document.activeElement).toBe(el("trigger"))
    })

    it("outside press on a NON-modal popover closes with reason outside-press and does NOT yank focus back", async () => {
      await mount()
      const closes = record("poetry:popover:closed", el("root"))

      el("trigger").focus()
      el("trigger").click()
      await nextFrame()

      el("outside").dispatchEvent(new MouseEvent("pointerdown", { bubbles: true }))
      await nextFrame()

      expect(closes).toEqual([{ reason: "outside-press" }])
      expect(document.activeElement).not.toBe(el("trigger"))
    })

    it("outside press on a MODAL popover restores focus to the trigger", async () => {
      await mount({ modal: true })

      el("trigger").focus()
      el("trigger").click()
      await nextFrame()

      el("outside").dispatchEvent(new MouseEvent("pointerdown", { bubbles: true }))
      await nextFrame()

      expect(el("content").hidden).toBe(true)
      expect(document.activeElement).toBe(el("trigger"))
    })
  })

  describe("controllable state", () => {
    it("flipping the open value opens and closes the same machine (reason none)", async () => {
      await mount()
      const closes = record("poetry:popover:closed", el("root"))

      el("root").setAttribute("data-poetry--core--popover-open-value", "true")
      await nextFrame()

      expect(el("content").hasAttribute("data-open")).toBe(true)

      el("root").setAttribute("data-poetry--core--popover-open-value", "false")
      await nextFrame()

      expect(el("content").hasAttribute("data-closed")).toBe(true)
      expect(closes).toEqual([{ reason: "none" }])
    })

    it("reconcile-on-connect: server-rendered open: true activates the layer stack (Turbo Stream safe)", async () => {
      await mount({ open: true })

      expect(el("content").hidden).toBe(false)
      expect(controllersOf("content")).toContain("poetry--core--focus-scope")
      expect(controllersOf("content")).toContain("poetry--core--dismissable")
      expect(el("content").getAttribute(TRAPPED)).toBe("false")
    })
  })

  describe("portal-on-open", () => {
    it("open portals the content to body + flips popper to absolute; close restores both and focus returns", async () => {
      await mount()

      el("trigger").focus()
      el("trigger").click()
      await nextFrame()

      expect(el("content").hasAttribute("data-open")).toBe(true)
      expect(el("content").parentNode).toBe(document.body)
      expect(el("root").getAttribute("data-poetry--core--popper-strategy-value")).toBe("absolute")
      // focus-scope's mount default still lands INSIDE the portaled content
      expect(document.activeElement).toBe(el("field"))

      pressEscape()
      await nextFrame()

      expect(el("content").hasAttribute("data-closed")).toBe(true)
      expect(el("content").parentNode).toBe(el("root"))
      expect(el("root").getAttribute("data-poetry--core--popper-strategy-value")).toBe("fixed")
      expect(document.activeElement).toBe(el("trigger"), "focus restores by element ref, indifferent to the move")
    })

    it("a server-pinned open popover portals one frame after connect (the popper cache order)", async () => {
      await mount({ open: true })

      // (the deferral itself is a rAF - too fast to assert against
      // jsdom's 16ms rAF timer without flaking; the OUTCOME is the pin)
      await new Promise((resolve) => setTimeout(resolve, 40))

      expect(el("content").parentNode).toBe(document.body)
      expect(el("root").getAttribute("data-poetry--core--popper-strategy-value")).toBe("absolute")
    })

    it("disconnecting an open popover never strands content at body (drop-never-strand)", async () => {
      await mount()

      el("trigger").click()
      await nextFrame()
      expect(el("content").parentNode).toBe(document.body)

      el("host").replaceChildren()
      await nextFrame()

      expect(document.getElementById("content")).toBe(null)
    })
  })
})
