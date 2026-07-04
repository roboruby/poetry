import { beforeEach, describe, expect, it, vi } from "vitest"
import { Application } from "@hotwired/stimulus"
import { registerPoetryControllers } from "@poetry/controllers"

// poetry--core--context-menu JS-unit: the ContextMenu DELTA layer only -
// point capture, the long-press timer, the native-menu passthrough, and the
// popper anchor-point attribute writes. The menu machinery it drives is
// poetry--core--menu on the same root (its own suite: menu.test.js); real
// positioning at the captured point is the browser pass's job.

const nextFrame = () => new Promise((resolve) => setTimeout(resolve, 0))

const el = (id) => document.getElementById(id)

const ANCHOR = "data-poetry--core--popper-anchor-point-value"

const contextmenu = (element, { x = 0, y = 0 } = {}) =>
  element.dispatchEvent(new MouseEvent("contextmenu", {
    bubbles: true, cancelable: true, clientX: x, clientY: y
  }))

const pointer = (element, type, { pointerType = "touch", x = 0, y = 0 } = {}) => {
  const event = new MouseEvent(type, { bubbles: true, cancelable: true, clientX: x, clientY: y })

  Object.defineProperty(event, "pointerType", { value: pointerType })
  element.dispatchEvent(event)
  return event
}

const record = (type, target) => {
  const seen = []
  target.addEventListener(type, (event) => seen.push(event.detail))
  return seen
}

const markup = ({ disabled = false, delay = 700 } = {}) => `
  <div id="root" data-slot="context-menu" data-component="context_menu"
       data-controller="poetry--core--context-menu poetry--core--menu"
       data-poetry--core--context-menu-disabled-value="${disabled}"
       data-poetry--core--context-menu-long-press-delay-value="${delay}"
       data-poetry--core--menu-modal-value="true">
    <span id="trigger" data-slot="context-menu-trigger"
          aria-controls="content" style="-webkit-touch-callout: none"
          data-action="contextmenu->poetry--core--context-menu#open
                       pointerdown->poetry--core--context-menu#pressStart
                       pointermove->poetry--core--context-menu#pressCancel
                       pointerup->poetry--core--context-menu#pressCancel
                       pointercancel->poetry--core--context-menu#pressCancel">
      Right-click surface
    </span>
    <div id="content" data-slot="context-menu-content" role="menu" aria-orientation="vertical"
         aria-label="Context menu" tabindex="-1" data-closed hidden>
      <div id="item-rename" data-slot="context-menu-item" role="menuitem" tabindex="-1"
           data-poetry-collection-item>Rename</div>
      <div id="item-delete" data-slot="context-menu-item" role="menuitem" tabindex="-1"
           data-poetry-collection-item data-variant="destructive">Delete</div>
    </div>
  </div>`

describe("poetry--core--context-menu", () => {
  let application

  beforeEach(async () => {
    vi.useRealTimers()
    document.body.innerHTML = `<div id="host"></div>`
    application = Application.start()
    registerPoetryControllers(application)
    await nextFrame()
    return async () => {
      vi.useRealTimers()
      el("host")?.replaceChildren()
      await nextFrame()
      application.stop()
    }
  })

  async function mount(options = {}) {
    el("host").innerHTML = markup(options)
    await nextFrame()
  }

  describe("the contextmenu path", () => {
    it("preventDefaults, writes the anchor point, opens at the pointer, and announces {x, y, input: pointer}", async () => {
      await mount()
      const opens = record("poetry:context-menu:open", el("root"))
      const consumed = !contextmenu(el("trigger"), { x: 512, y: 384 })
      await nextFrame()

      expect(consumed).toBe(true) // preventDefault: the custom menu replaces the native one
      expect(el("root").getAttribute(ANCHOR)).toBe("512,384")
      expect(el("content").hasAttribute("data-open")).toBe(true)
      expect(el("content").hidden).toBe(false)
      expect(el("content").getAttribute("data-open-reason")).toBe("pointer")
      expect(el("trigger").hasAttribute("data-popup-open")).toBe(true)
      expect(opens).toEqual([{ x: 512, y: 384, input: "pointer" }])
    })

    it("never introduces ARIA onto the surface: no aria-expanded/aria-haspopup/role appear at runtime", async () => {
      await mount()
      contextmenu(el("trigger"), { x: 10, y: 20 })
      await nextFrame()

      expect(el("trigger").hasAttribute("aria-expanded")).toBe(false)
      expect(el("trigger").hasAttribute("aria-haspopup")).toBe(false)
      expect(el("trigger").hasAttribute("role")).toBe(false)
    })

    it("disabled stands the handlers down: no preventDefault (native menu passthrough), nothing opens", async () => {
      await mount({ disabled: true })
      const consumed = !contextmenu(el("trigger"), { x: 100, y: 100 })
      await nextFrame()

      expect(consumed).toBe(false)
      expect(el("content").hasAttribute("data-closed")).toBe(true)
      expect(el("root").hasAttribute(ANCHOR)).toBe(false)
    })

    it("a keyboard-synthesized contextmenu (0,0 - Shift+F10) clears the anchor so popper falls back to the trigger rect, and focuses the first item", async () => {
      await mount()
      const opens = record("poetry:context-menu:open", el("root"))

      contextmenu(el("trigger"), { x: 0, y: 0 })
      await nextFrame()

      expect(el("root").getAttribute(ANCHOR)).toBe("")
      expect(el("content").hasAttribute("data-open")).toBe(true)
      expect(el("content").getAttribute("data-open-reason")).toBe("keyboard-first")
      expect(document.activeElement).toBe(el("item-rename"))
      expect(opens).toEqual([{ x: null, y: null, input: "keyboard" }])
    })

    it("re-invoking while open re-captures the point (re-anchor) and keeps the menu open", async () => {
      await mount()

      contextmenu(el("trigger"), { x: 100, y: 100 })
      await nextFrame()
      contextmenu(el("trigger"), { x: 300, y: 200 })
      await nextFrame()

      expect(el("root").getAttribute(ANCHOR)).toBe("300,200")
      expect(el("content").hasAttribute("data-open")).toBe(true)
    })
  })

  describe("the long-press path (touch/pen only)", () => {
    it("pointerdown opens at the press point after the 700ms default, with data-pressing feedback during the window", async () => {
      await mount()
      const opens = record("poetry:context-menu:open", el("root"))

      vi.useFakeTimers()
      pointer(el("trigger"), "pointerdown", { x: 40, y: 60 })

      expect(el("trigger").hasAttribute("data-pressing")).toBe(true)

      await vi.advanceTimersByTimeAsync(699)
      expect(el("content").hasAttribute("data-closed")).toBe(true)

      await vi.advanceTimersByTimeAsync(1)
      expect(el("content").hasAttribute("data-open")).toBe(true)
      expect(el("trigger").hasAttribute("data-pressing")).toBe(false)
      expect(el("root").getAttribute(ANCHOR)).toBe("40,60")
      expect(opens).toEqual([{ x: 40, y: 60, input: "long-press" }])
    })

    it("longPressDelay is a Value (Radix hardcodes 700)", async () => {
      await mount({ delay: 300 })

      vi.useFakeTimers()
      pointer(el("trigger"), "pointerdown", { x: 1, y: 2 })
      await vi.advanceTimersByTimeAsync(300)

      expect(el("content").hasAttribute("data-open")).toBe(true)
    })

    it("ANY pointermove cancels (no slop radius); pointerup and pointercancel cancel too", async () => {
      await mount()

      for (const type of ["pointermove", "pointerup", "pointercancel"]) {
        vi.useFakeTimers()
        pointer(el("trigger"), "pointerdown", { x: 5, y: 5 })
        pointer(el("trigger"), type, { x: 6, y: 5 })

        expect(el("trigger").hasAttribute("data-pressing")).toBe(false)

        await vi.advanceTimersByTimeAsync(1000)
        expect(el("content").hasAttribute("data-closed")).toBe(true)
        vi.useRealTimers()
      }
    })

    it("a second pointerdown restarts the timer (multi-touch guard) - one open, from the second press point", async () => {
      await mount()
      const opens = record("poetry:context-menu:open", el("root"))

      vi.useFakeTimers()
      pointer(el("trigger"), "pointerdown", { x: 10, y: 10 })
      await vi.advanceTimersByTimeAsync(400)
      pointer(el("trigger"), "pointerdown", { x: 90, y: 90 })
      await vi.advanceTimersByTimeAsync(699)

      expect(el("content").hasAttribute("data-closed")).toBe(true) // the first press's schedule is gone

      await vi.advanceTimersByTimeAsync(1)
      expect(el("content").hasAttribute("data-open")).toBe(true)
      expect(el("root").getAttribute(ANCHOR)).toBe("90,90")
      expect(opens.length).toBe(1)
    })

    it("mouse pointerdown NEVER starts the timer (pointerType guard)", async () => {
      await mount()

      vi.useFakeTimers()
      pointer(el("trigger"), "pointerdown", { pointerType: "mouse", x: 10, y: 10 })

      expect(el("trigger").hasAttribute("data-pressing")).toBe(false)

      await vi.advanceTimersByTimeAsync(1500)
      expect(el("content").hasAttribute("data-closed")).toBe(true)
    })

    it("a touch press on the surface while open closes first (press-again-to-dismiss)", async () => {
      await mount()

      contextmenu(el("trigger"), { x: 100, y: 100 })
      await nextFrame()
      expect(el("content").hasAttribute("data-open")).toBe(true)

      pointer(el("trigger"), "pointerdown", { x: 100, y: 100 })
      await nextFrame()

      expect(el("content").hasAttribute("data-closed")).toBe(true)
    })

    it("the contextmenu handler clears a running long-press timer (Android synthesizes contextmenu from long-press - no double open)", async () => {
      await mount()
      const opens = record("poetry:context-menu:open", el("root"))

      vi.useFakeTimers()
      pointer(el("trigger"), "pointerdown", { x: 10, y: 10 })
      await vi.advanceTimersByTimeAsync(400)
      contextmenu(el("trigger"), { x: 10, y: 10 })
      await vi.advanceTimersByTimeAsync(1000)

      expect(opens.length).toBe(1)
      expect(el("content").hasAttribute("data-open")).toBe(true)
    })

    it("flipping disabled on cancels a pending press", async () => {
      await mount()

      vi.useFakeTimers()
      pointer(el("trigger"), "pointerdown", { x: 10, y: 10 })
      el("root").setAttribute("data-poetry--core--context-menu-disabled-value", "true")
      await vi.advanceTimersByTimeAsync(1000)

      expect(el("content").hasAttribute("data-closed")).toBe(true)
      expect(el("trigger").hasAttribute("data-pressing")).toBe(false)
    })
  })
})
