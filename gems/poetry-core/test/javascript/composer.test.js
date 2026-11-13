import { afterEach, beforeEach, describe, expect, it } from "vitest"
import { Application } from "@hotwired/stimulus"
import { registerPoetryControllers } from "@poetry/controllers"

// The Composer seams: Enter sends and Shift+Enter does not; an Enter that
// belongs to an input-method composition never sends; the form's submit
// event is the one gate for the key and the button (blank, running, and
// already-sending are refused); an accepted message leaves the field and
// what was typed after it stays; a Stop button on the page is the whole
// fact that a reply is running.

const nextFrame = () => new Promise((resolve) => setTimeout(resolve, 0))

const IDENTIFIER = "poetry--core--composer"

const el = (id) => document.getElementById(id)

const SEND = `<button id="send" type="submit" data-${IDENTIFIER}-target="send"
                      data-action="pointerdown->${IDENTIFIER}#holdFocus">Send</button>`
const STOP = `<button id="stop" type="submit" form="composer-stop" data-${IDENTIFIER}-target="stop"
                      data-action="pointerdown->${IDENTIFIER}#holdFocus click->${IDENTIFIER}#returnFocus">Stop</button>`

const markup = ({ value = "", action = SEND, enter = null, disabled = "" } = {}) => `
  <div id="composer" data-controller="${IDENTIFIER}" ${value.trim() === "" ? "data-empty" : ""}
       ${enter === null ? "" : `data-${IDENTIFIER}-submit-on-enter-value="${enter}"`}
       data-action="turbo:morph-element->${IDENTIFIER}#changed">
    <form id="form" action="/messages" method="post" data-${IDENTIFIER}-target="form"
          data-action="submit->${IDENTIFIER}#guard turbo:submit-end->${IDENTIFIER}#settle">
      <textarea id="input" name="content" ${disabled} data-${IDENTIFIER}-target="input"
                data-action="keydown->${IDENTIFIER}#keydown input->${IDENTIFIER}#changed">${value}</textarea>
      <span id="composer-action">${action}</span>
    </form>
    <form id="composer-stop" action="/stop" method="post" hidden></form>
  </div>
  <button id="elsewhere" type="button">Elsewhere</button>`

const press = (options = {}) => {
  const event = new KeyboardEvent("keydown", { key: "Enter", bubbles: true, cancelable: true, ...options })

  el("input").dispatchEvent(event)
  return event
}

const type = (text) => {
  el("input").value = text
  el("input").dispatchEvent(new Event("input", { bubbles: true }))
}

const settle = (success) => {
  el("form").dispatchEvent(new CustomEvent("turbo:submit-end", { bubbles: true, detail: { success } }))
}

describe("poetry--core--composer", () => {
  let application
  let sent

  // Turbo's place in the page: a document-level listener that takes every
  // submission no one refused. Here it records the form and the text.
  const turbo = (event) => {
    if (event.defaultPrevented) return
    event.preventDefault()
    sent.push({ form: event.target.id, text: el("input")?.value })
  }

  beforeEach(async () => {
    sent = []
    document.body.innerHTML = `<div id="host"></div>`
    document.addEventListener("submit", turbo)
    application = Application.start()
    registerPoetryControllers(application)
    await nextFrame()
  })

  afterEach(async () => {
    document.removeEventListener("submit", turbo)
    el("host")?.replaceChildren()
    await nextFrame()
    application.stop()
  })

  async function mount(options = {}) {
    el("host").innerHTML = markup(options)
    await nextFrame()
  }

  it("Enter sends the message once and takes the line break", async () => {
    await mount({ value: "hello" })

    const event = press()

    expect(event.defaultPrevented).toBe(true)
    expect(sent).toEqual([{ form: "form", text: "hello" }])
  })

  it("Shift+Enter is the browser's line break and sends nothing", async () => {
    await mount({ value: "hello" })

    const event = press({ shiftKey: true })

    expect(event.defaultPrevented).toBe(false)
    expect(sent).toEqual([])
  })

  it("an Enter that belongs to a composition never sends", async () => {
    await mount({ value: "こんにちは" })

    expect(press({ isComposing: true }).defaultPrevented).toBe(false)
    // Safari reports the confirming Enter with isComposing already false
    // and only the legacy key code to tell it apart.
    expect(press({ keyCode: 229 }).defaultPrevented).toBe(false)
    expect(sent).toEqual([])
  })

  it("a held Enter sends once", async () => {
    await mount({ value: "hello" })

    press()
    await nextFrame()
    press({ repeat: true })

    expect(sent.length).toBe(1)
  })

  it("a blank or whitespace-only field sends nothing, by key or by button", async () => {
    await mount({ value: "  \n " })

    expect(press().defaultPrevented).toBe(true)
    el("send").click()

    expect(sent).toEqual([])
  })

  it("the Send button passes the same gate as the key", async () => {
    await mount({ value: "hello" })

    el("send").click()

    expect(sent).toEqual([{ form: "form", text: "hello" }])
  })

  it("two sends in one task become one", async () => {
    await mount({ value: "hello" })

    press()
    press()
    el("send").click()

    expect(sent.length).toBe(1)
  })

  it("the bridge lasts one task: a submission that never started leaves nothing stuck", async () => {
    await mount({ value: "hello" })

    press()
    await nextFrame()
    press()

    expect(sent.length).toBe(2)
  })

  it("nothing is sent while Turbo holds the form busy", async () => {
    await mount({ value: "hello" })
    el("form").setAttribute("aria-busy", "true")

    press()
    el("send").click()

    expect(sent).toEqual([])

    el("form").removeAttribute("aria-busy")
    press()

    expect(sent.length).toBe(1)
  })

  it("a Stop button on the page is the running state: the draft stays and nothing is sent", async () => {
    await mount({ value: "next question", action: STOP })

    expect(press().defaultPrevented).toBe(true)

    expect(sent).toEqual([])
    expect(el("input").value).toBe("next question")
  })

  it("the Stop button submits its own form, never the message", async () => {
    await mount({ value: "a draft", action: STOP })

    el("stop").click()

    expect(sent).toEqual([{ form: "composer-stop", text: "a draft" }])
  })

  it("a press on Send or Stop does not take focus", async () => {
    await mount({ value: "a draft", action: SEND + STOP })

    for (const id of ["send", "stop"]) {
      const press = new Event("pointerdown", { bubbles: true, cancelable: true })

      el(id).dispatchEvent(press)

      expect(press.defaultPrevented, id).toBe(true)
    }
  })

  it("Stop pressed from the keyboard hands its focus to the field before it is replaced", async () => {
    await mount({ value: "a draft", action: STOP })

    el("stop").focus()
    el("stop").click()

    expect(document.activeElement).toBe(el("input"))
  })

  it("Stop pressed with a pointer leaves focus where the reader had it", async () => {
    await mount({ value: "a draft", action: STOP })

    el("elsewhere").focus()
    el("stop").click()

    expect(document.activeElement).toBe(el("elsewhere"))

    el("elsewhere").blur()
    el("stop").click()

    expect(document.activeElement).toBe(document.body)
  })

  it("the server's redraw of the slot is all it takes to send again", async () => {
    await mount({ value: "next question", action: STOP })

    el("composer-action").innerHTML = SEND
    await nextFrame()
    press()

    expect(sent).toEqual([{ form: "form", text: "next question" }])
  })

  it("a disabled field sends nothing", async () => {
    await mount({ value: "hello", disabled: "disabled" })

    el("send").click()

    expect(sent).toEqual([])
  })

  it("with submit-on-enter off, Enter is a line break and Cmd/Ctrl+Enter sends", async () => {
    await mount({ value: "hello", enter: "false" })

    expect(press().defaultPrevented).toBe(false)
    expect(sent).toEqual([])

    expect(press({ ctrlKey: true }).defaultPrevented).toBe(true)
    await nextFrame()
    press({ metaKey: true })

    expect(sent.length).toBe(2)
  })

  it("an accepted message leaves the field with a real input event", async () => {
    await mount({ value: "hello" })

    const inputs = []

    el("input").addEventListener("input", () => inputs.push(el("input").value))
    press()
    settle(true)

    expect(el("input").value).toBe("")
    expect(inputs).toEqual([""])
    expect(el("composer").hasAttribute("data-empty")).toBe(true)
  })

  it("text typed after the send stays when the message is accepted", async () => {
    await mount({ value: "hello" })

    press()
    type("hello and one more thing")
    settle(true)

    expect(el("input").value).toBe(" and one more thing")
    expect(el("composer").hasAttribute("data-empty")).toBe(false)
  })

  it("a refused message stays whole", async () => {
    await mount({ value: "hello" })

    press()
    settle(false)

    expect(el("input").value).toBe("hello")

    await nextFrame()
    press()

    expect(sent.length).toBe(2)
  })

  it("a submission the composer did not send clears nothing", async () => {
    await mount({ value: "a draft" })

    settle(true)

    expect(el("input").value).toBe("a draft")
  })

  it("data-empty follows the field, from connect on", async () => {
    await mount({ value: "" })

    expect(el("composer").hasAttribute("data-empty")).toBe(true)

    type("h")

    expect(el("composer").hasAttribute("data-empty")).toBe(false)

    type("   ")

    expect(el("composer").hasAttribute("data-empty")).toBe(true)
  })

  it("a restored draft the server never rendered is reflected on connect", async () => {
    el("host").innerHTML = markup({ value: "" })
    el("input").value = "restored by the browser"
    await nextFrame()

    expect(el("composer").hasAttribute("data-empty")).toBe(false)
  })

  it("a morph that puts the server's emptiness back is corrected from the field", async () => {
    await mount({ value: "" })
    type("a draft the morph keeps")

    // The morph syncs the root to what the server rendered (an empty
    // composer), leaves the dirty field alone, then reports each node.
    el("composer").setAttribute("data-empty", "")
    el("input").dispatchEvent(new CustomEvent("turbo:morph-element", { bubbles: true }))

    expect(el("composer").hasAttribute("data-empty")).toBe(false)
  })

  it("a send made from inside the composer ends with focus in the field", async () => {
    await mount({ value: "hello" })

    // The keyboard reached the Send button; Turbo disables it for the request.
    el("send").focus()
    el("send").click()
    settle(true)

    expect(document.activeElement).toBe(el("input"))
  })

  it("focus the reader moved during the request stays where they put it", async () => {
    await mount({ value: "hello" })

    el("input").focus()
    press()
    el("elsewhere").focus()
    settle(true)

    expect(document.activeElement).toBe(el("elsewhere"))
  })

  it("a send made with nothing focused does not pull focus into the field", async () => {
    await mount({ value: "hello" })

    // A reader who put the on-screen keyboard away and tapped Send.
    el("send").click()
    settle(true)

    expect(document.activeElement).toBe(document.body)
  })
})
