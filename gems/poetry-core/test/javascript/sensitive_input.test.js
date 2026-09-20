import { beforeEach, describe, expect, it } from "vitest"
import { Application } from "@hotwired/stimulus"
import { registerPoetryControllers } from "@poetry/controllers"

// The SensitiveInput machine (the kumo contract): masked-with-value
// makes the MASK OVERLAY the reveal button (a role on the group would trip
// axe nested-interactive around the inert input); reveal moves focus in;
// Escape/blur/eye re-mask (Escape and the eye hand focus back to the
// mask); typing into empty auto-reveals; addon clicks never reveal.

const nextFrame = () => new Promise((resolve) => setTimeout(resolve, 0))

const IDENTIFIER = "poetry--core--sensitive-input"

const el = (id) => document.getElementById(id)

const markup = ({ value = "s3cret-key", state = "masked", disabled = "" } = {}) => `
  <div id="root" data-controller="${IDENTIFIER}" data-state="${state}" ${disabled}
       data-${IDENTIFIER}-masked-label-value="API key, masked."
       data-${IDENTIFIER}-hidden-message-value="Value hidden"
       data-action="focusout->${IDENTIFIER}#blurred">
    <div id="group" data-action="click->${IDENTIFIER}#reveal">
      <span id="mask" data-${IDENTIFIER}-target="mask"
            data-action="keydown->${IDENTIFIER}#maskKeydown">••••••••</span>
      <input id="input" type="password" value="${value}"
             data-${IDENTIFIER}-target="input"
             data-action="input->${IDENTIFIER}#changed keydown->${IDENTIFIER}#inputKeydown">
      <div id="addon" data-slot="input-group-addon">
        <button id="eye" data-${IDENTIFIER}-target="toggle"
                data-action="click->${IDENTIFIER}#toggle">eye</button>
        <button id="copy">copy</button>
      </div>
    </div>
    <span id="hint" data-${IDENTIFIER}-target="hint">Click or press Enter to reveal.</span>
  </div>
  <button id="outside">outside</button>`

const click = (id, options = {}) => {
  el(id).dispatchEvent(new MouseEvent("click", { bubbles: true, clientX: 5, clientY: 5, detail: 1, ...options }))
}

describe("poetry--core--sensitive-input", () => {
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
    el("host").innerHTML = markup(options)
    await nextFrame()
  }

  it("reflects the masked contract onto the mask button and the input", async () => {
    await mount()

    expect(el("mask").getAttribute("role")).toBe("button")
    expect(el("mask").getAttribute("tabindex")).toBe("0")
    expect(el("mask").getAttribute("aria-label")).toBe("API key, masked.")
    expect(el("mask").getAttribute("aria-describedby")).toBe("hint")
    expect(el("input").getAttribute("aria-hidden")).toBe("true")
    expect(el("input").getAttribute("tabindex")).toBe("-1")
    expect(el("input").readOnly).toBe(true)
    expect(el("input").type).toBe("password")
    expect(el("eye").hidden).toBe(true)
  })

  it("reveals on group click: type=text, input editable and focused, mask demoted", async () => {
    await mount()

    click("group")
    await nextFrame()

    expect(el("root").getAttribute("data-state")).toBe("revealed")
    expect(el("input").type).toBe("text")
    expect(el("input").readOnly).toBe(false)
    expect(el("mask").hasAttribute("role")).toBe(false)
    expect(document.activeElement).toBe(el("input"))
    expect(el("eye").hidden).toBe(false)
  })

  it("reveals on Enter and Space from the mask button", async () => {
    await mount()

    el("mask").dispatchEvent(new KeyboardEvent("keydown", { key: "Enter", bubbles: true }))
    await nextFrame()

    expect(el("root").getAttribute("data-state")).toBe("revealed")
  })

  it("ignores clicks bubbling from the addon cell", async () => {
    await mount()

    click("copy")
    await nextFrame()

    expect(el("root").getAttribute("data-state")).toBe("masked")
  })

  it("ignores synthetic label clicks (no gesture coordinates)", async () => {
    await mount()

    click("group", { clientX: 0, clientY: 0, detail: 0 })
    await nextFrame()

    expect(el("root").getAttribute("data-state")).toBe("masked")
  })

  it("Escape re-masks, is consumed, and hands focus back to the mask", async () => {
    await mount()
    click("group")
    await nextFrame()

    const escape = new KeyboardEvent("keydown", { key: "Escape", bubbles: true, cancelable: true })
    el("input").dispatchEvent(escape)
    await nextFrame()

    expect(escape.defaultPrevented).toBe(true)
    expect(el("root").getAttribute("data-state")).toBe("masked")
    expect(document.activeElement).toBe(el("mask"))
    expect(el("input").type).toBe("password")
  })

  it("re-masks when focus leaves the component, but not when it moves inside", async () => {
    await mount()
    click("group")
    await nextFrame()

    el("input").dispatchEvent(new FocusEvent("focusout", { bubbles: true, relatedTarget: el("eye") }))
    await nextFrame()

    expect(el("root").getAttribute("data-state")).toBe("revealed")

    el("input").dispatchEvent(new FocusEvent("focusout", { bubbles: true, relatedTarget: el("outside") }))
    await nextFrame()

    expect(el("root").getAttribute("data-state")).toBe("masked")
  })

  it("the eye re-masks and hands focus to the mask", async () => {
    await mount()
    click("group")
    await nextFrame()

    click("eye")
    await nextFrame()

    expect(el("root").getAttribute("data-state")).toBe("masked")
    expect(document.activeElement).toBe(el("mask"))
    expect(el("eye").hidden).toBe(true)
  })

  it("typing into an empty field auto-reveals; clearing goes back to empty", async () => {
    await mount({ value: "", state: "empty" })

    expect(el("mask").hasAttribute("role")).toBe(false)
    expect(el("input").readOnly).toBe(false)

    el("input").value = "a"
    el("input").dispatchEvent(new Event("input", { bubbles: true }))
    await nextFrame()

    expect(el("root").getAttribute("data-state")).toBe("revealed")
    expect(el("input").type).toBe("text")

    el("input").value = ""
    el("input").dispatchEvent(new Event("input", { bubbles: true }))
    await nextFrame()

    expect(el("root").getAttribute("data-state")).toBe("empty")
    expect(el("input").type).toBe("password")
  })

  it("disabled: the mask button is not a tab stop and clicks do nothing", async () => {
    await mount({ disabled: "data-disabled" })

    expect(el("mask").getAttribute("tabindex")).toBe("-1")

    click("group")
    await nextFrame()

    expect(el("root").getAttribute("data-state")).toBe("masked")
  })

  it("dispatches reveal and mask", async () => {
    await mount()
    const events = []
    el("root").addEventListener("poetry:sensitive-input:reveal", () => events.push("reveal"))
    el("root").addEventListener("poetry:sensitive-input:mask", () => events.push("mask"))

    click("group")
    await nextFrame()
    click("eye")
    await nextFrame()

    expect(events).toEqual(["reveal", "mask"])
  })
})
