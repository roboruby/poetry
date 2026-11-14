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

// Files as part of the message: the composer's root carries the file-drop
// and file-input controllers beside its own, and the native file input is
// the composer's attachments target.
const FILES = "poetry--core--file-input"

const attachMarkup = ({ value = "" } = {}) => `
  <div id="composer" data-controller="poetry--core--file-drop ${FILES} ${IDENTIFIER}"
       ${value.trim() === "" ? "data-empty" : ""}
       data-poetry--core--file-drop-multiple-value="true"
       data-${FILES}-multiple-value="true"
       data-action="poetry:file-drop:files->${FILES}#files poetry:composer:sent->${FILES}#discard
                    turbo:morph-element->${IDENTIFIER}#changed">
    <form id="form" action="/messages" method="post" data-${IDENTIFIER}-target="form"
          data-action="submit->${IDENTIFIER}#guard turbo:submit-end->${IDENTIFIER}#settle">
      <div id="items" data-${FILES}-target="items"></div>
      <textarea id="input" name="content" data-${IDENTIFIER}-target="input"
                data-action="keydown->${IDENTIFIER}#keydown input->${IDENTIFIER}#changed">${value}</textarea>
      <input id="files" type="file" name="files[]" multiple hidden
             data-poetry--core--file-drop-target="input" data-${FILES}-target="input"
             data-${IDENTIFIER}-target="attachments" data-action="change->${IDENTIFIER}#changed">
      <span id="composer-action">${SEND}</span>
    </form>
    <template data-${FILES}-target="template">
      <div data-slot="attachment"><span data-slot="attachment-title"></span>
        <button type="button" data-upload-action="remove" data-action="click->${FILES}#remove">remove</button></div>
    </template>
  </div>`

const file = (name) => new File([new Uint8Array(4)], name, { type: "text/plain", lastModified: 0 })

describe("poetry--core--composer with attachments", () => {
  let application
  let sent

  const turbo = (event) => {
    if (event.defaultPrevented) return
    event.preventDefault()
    sent.push({ text: el("input").value, files: Array.from(el("files").files).map((held) => held.name) })
  }

  const names = () => Array.from(el("items").querySelectorAll("[data-slot=attachment-title]")).map((title) => title.textContent)

  beforeEach(async () => {
    sent = []
    document.body.innerHTML = `<div id="host"></div>`
    document.addEventListener("submit", turbo)
    application = Application.start()
    registerPoetryControllers(application)
    await nextFrame()
  })

  // The composer leaves the document before the application stops, so
  // the file-drop controller's document listeners go with it.
  afterEach(async () => {
    document.removeEventListener("submit", turbo)
    el("host")?.replaceChildren()
    await nextFrame()
    application.stop()
  })

  async function mount(options = {}) {
    el("host").innerHTML = attachMarkup(options)
    await nextFrame()
    // jsdom's input.files is not assignable with a plain array.
    Object.defineProperty(el("files"), "files", { writable: true, configurable: true, value: [] })
  }

  const pick = async (...files) => {
    el("files").files = [...Array.from(el("files").files), ...files]
    el("files").dispatchEvent(new Event("change", { bubbles: true }))
    await nextFrame()
  }

  it("a message of files alone is not blank: the emptiness lifts and Enter sends it", async () => {
    await mount()

    expect(el("composer").hasAttribute("data-empty")).toBe(true)

    await pick(file("a.txt"))

    expect(el("composer").hasAttribute("data-empty")).toBe(false)
    expect(names()).toEqual(["a.txt"])

    press()

    expect(sent).toEqual([{ text: "", files: ["a.txt"] }])
  })

  it("removing the last file of a wordless message makes it blank again", async () => {
    await mount()
    await pick(file("a.txt"))

    el("items").querySelector("[data-upload-action=remove]").click()
    await nextFrame()

    expect(el("composer").hasAttribute("data-empty")).toBe(true)

    press()

    expect(sent).toEqual([])
  })

  it("an accepted message takes its files with it and keeps a file added since", async () => {
    await mount({ value: "see attached" })
    await pick(file("a.txt"), file("b.txt"))
    const heard = []

    document.addEventListener("poetry:composer:sent", (event) => heard.push(event.detail.files.map((held) => held.name)), { once: true })
    press()
    await pick(file("late.txt"))
    settle(true)
    await nextFrame()

    expect(heard).toEqual([["a.txt", "b.txt"]])
    expect(Array.from(el("files").files).map((held) => held.name)).toEqual(["late.txt"])
    expect(names()).toEqual(["late.txt"])
    expect(el("input").value).toBe("")
    expect(el("composer").hasAttribute("data-empty")).toBe(false)
  })

  it("a refused message keeps its files and reports nothing", async () => {
    await mount({ value: "see attached" })
    await pick(file("a.txt"))
    const heard = []
    const listen = (event) => heard.push(event.type)

    document.addEventListener("poetry:composer:sent", listen)
    press()
    settle(false)
    await nextFrame()
    document.removeEventListener("poetry:composer:sent", listen)

    expect(heard).toEqual([])
    expect(names()).toEqual(["a.txt"])
    expect(el("input").value).toBe("see attached")
  })

  it("a submit already held back is not a send: nothing is cleared when it settles", async () => {
    await mount({ value: "uploads still running" })
    await pick(file("a.txt"))
    // The upload queue's place: a capture listener that holds the submit.
    const hold = (event) => event.preventDefault()

    el("form").addEventListener("submit", hold, { capture: true })
    press()
    el("form").removeEventListener("submit", hold, { capture: true })
    settle(true)
    await nextFrame()

    expect(sent).toEqual([])
    expect(el("input").value).toBe("uploads still running")
    expect(names()).toEqual(["a.txt"])
  })
})

describe("poetry--core--composer beside other listeners", () => {
  let application
  let sent

  const turbo = (event) => {
    if (event.defaultPrevented) return
    event.preventDefault()
    sent.push(el("input").value)
  }

  beforeEach(async () => {
    sent = []
    document.body.innerHTML = `<div id="host"></div>`
    document.addEventListener("submit", turbo)
    application = Application.start()
    registerPoetryControllers(application)
    await nextFrame()
    el("host").innerHTML = markup({ value: "hello" })
    await nextFrame()
  })

  afterEach(async () => {
    document.removeEventListener("submit", turbo)
    el("host")?.replaceChildren()
    await nextFrame()
    application.stop()
  })

  it("an Enter an earlier listener claimed is not a send", async () => {
    // An open menu's place: it takes the key before the composer sees it.
    const claim = (event) => event.preventDefault()

    el("form").addEventListener("keydown", claim, { capture: true })
    press()
    el("form").removeEventListener("keydown", claim, { capture: true })

    expect(sent).toEqual([])

    press()

    expect(sent).toEqual(["hello"])
  })

  const controller = () => application.getControllerForElementAndIdentifier(el("composer"), IDENTIFIER)

  it("setText replaces the draft with a real input event and answers with the field's state", () => {
    const heard = []

    el("input").addEventListener("input", () => heard.push(el("input").value))

    expect(controller().setText("a new draft")).toEqual({ text: "a new draft", empty: false, changed: true })
    expect(heard).toEqual(["a new draft"])
    expect(controller().setText("a new draft")).toEqual({ text: "a new draft", empty: false, changed: false })
    expect(controller().setText("")).toEqual({ text: "", empty: true, changed: true })
    expect(el("composer").hasAttribute("data-empty")).toBe(true)
    expect(sent).toEqual([])
  })

  it("setText leaves a disabled field alone", () => {
    el("input").disabled = true

    expect(controller().setText("nope")).toEqual({ text: "hello", empty: false, changed: false })
  })

  it("send goes through the same gate as the button and says why a message did not go", async () => {
    expect(controller().send()).toEqual({ sent: true })
    expect(sent).toEqual(["hello"])
    expect(controller().send()).toEqual({ sent: false, reason: "sending" })

    await nextFrame()
    controller().setText("   ")

    expect(controller().send()).toEqual({ sent: false, reason: "blank" })

    controller().setText("again")
    el("composer-action").innerHTML = STOP
    await nextFrame()

    expect(controller().send()).toEqual({ sent: false, reason: "running" })

    el("input").disabled = true

    expect(controller().send()).toEqual({ sent: false, reason: "disabled" })
    expect(sent).toEqual(["hello"])
  })

  it("stop presses the Stop button when a reply runs, and says when there was nothing to stop", async () => {
    expect(controller().stop()).toEqual({ stopped: false })

    el("composer-action").innerHTML = STOP
    await nextFrame()
    const stops = []

    el("composer-stop").addEventListener("submit", (event) => {
      event.preventDefault()
      stops.push(event.target.id)
    })

    expect(controller().stop()).toEqual({ stopped: true })
    expect(stops).toEqual(["composer-stop"])

    el("stop").disabled = true

    expect(controller().stop()).toEqual({ stopped: false })
  })

  it("an accepted message is reported even without a file input, with no files", async () => {
    const heard = []

    document.addEventListener("poetry:composer:sent", (event) => heard.push(event.detail.files), { once: true })
    press()
    settle(true)

    expect(heard).toEqual([[]])
  })
})
