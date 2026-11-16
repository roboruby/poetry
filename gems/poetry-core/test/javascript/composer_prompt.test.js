import { afterEach, beforeEach, describe, expect, it } from "vitest"
import { Application } from "@hotwired/stimulus"
import { registerPoetryControllers } from "@poetry/controllers"

// A suggested prompt: a button elsewhere on the page names a composer by
// id; pressed, the composer writes the prompt's text and sends it through
// its own gate. A prompt that could not go leaves the draft alone, and a
// prompt that only writes puts the caret after its text.

const nextFrame = () => new Promise((resolve) => setTimeout(resolve, 0))

const COMPOSER = "poetry--core--composer"
const PROMPT = "poetry--core--composer-prompt"

const el = (id) => document.getElementById(id)

const SEND = `<button id="send" type="submit" data-${COMPOSER}-target="send">Send</button>`
const STOP = `<button id="stop" type="submit" form="composer-stop" data-${COMPOSER}-target="stop">Stop</button>`

const composer = (id, { action = SEND, disabled = "", value = "" } = {}) => `
  <div id="${id}" data-controller="${COMPOSER}">
    <form id="${id}-form" action="/messages" method="post" data-${COMPOSER}-target="form"
          data-action="submit->${COMPOSER}#guard turbo:submit-end->${COMPOSER}#settle">
      <textarea id="${id}-input" name="content" ${disabled} data-${COMPOSER}-target="input"
                data-action="keydown->${COMPOSER}#keydown input->${COMPOSER}#changed">${value}</textarea>
      <span id="${id}-action">${action}</span>
    </form>
  </div>`

const prompt = (id, { composer: target, text, send = null }) => `
  <button id="${id}" type="button" data-controller="${PROMPT}" data-${PROMPT}-composer-value="${target}"
          data-${PROMPT}-text-value="${text}" ${send === null ? "" : `data-${PROMPT}-send-value="${send}"`}
          data-action="click->${PROMPT}#write">${text}</button>`

describe("poetry--core--composer-prompt", () => {
  let application
  let sent

  // Turbo's place in the page: every submission no one refused, with the text it carried.
  const turbo = (event) => {
    if (event.defaultPrevented) return
    event.preventDefault()
    sent.push([event.target.id, event.target.querySelector("textarea").value])
  }

  const mount = async (html) => {
    document.body.innerHTML = `<div id="host"></div>`
    application = Application.start()
    registerPoetryControllers(application)
    await nextFrame()
    el("host").innerHTML = html
    await nextFrame()
  }

  beforeEach(() => {
    sent = []
    document.addEventListener("submit", turbo)
  })

  afterEach(async () => {
    document.removeEventListener("submit", turbo)
    el("host")?.replaceChildren()
    await nextFrame()
    application.stop()
  })

  it("writes its text into the composer it names and sends it", async () => {
    await mount(composer("chat") + prompt("chip", { composer: "chat", text: "Show me the riskiest loans" }))

    el("chip").click()

    expect(sent).toEqual([["chat-form", "Show me the riskiest loans"]])
    expect(el("chat").hasAttribute("data-empty")).toBe(false)
  })

  it("replaces a draft when it sends", async () => {
    await mount(composer("chat", { value: "half a thought" }) + prompt("chip", { composer: "chat", text: "Overview" }))

    el("chip").click()

    expect(sent).toEqual([["chat-form", "Overview"]])
  })

  it("leaves the draft alone while a reply is running", async () => {
    await mount(composer("chat", { action: STOP, value: "my draft" }) + prompt("chip", { composer: "chat", text: "Overview" }))

    el("chip").click()

    expect(sent).toEqual([])
    expect(el("chat-input").value).toBe("my draft")
  })

  it("leaves a disabled composer alone", async () => {
    await mount(composer("chat", { disabled: "disabled" }) + prompt("chip", { composer: "chat", text: "Overview" }))

    el("chip").click()

    expect(sent).toEqual([])
    expect(el("chat-input").value).toBe("")
  })

  it("only writes when told not to send, and puts the caret after the text", async () => {
    await mount(composer("chat") + prompt("chip", { composer: "chat", text: "Compare ", send: false }))

    el("chip").click()

    const field = el("chat-input")

    expect(sent).toEqual([])
    expect(field.value).toBe("Compare ")
    expect(document.activeElement).toBe(field)
    expect([field.selectionStart, field.selectionEnd]).toEqual([8, 8])
    expect(el("chat").hasAttribute("data-empty")).toBe(false)
  })

  it("a prompt that only writes still writes while a reply is running", async () => {
    await mount(composer("chat", { action: STOP }) + prompt("chip", { composer: "chat", text: "Next: ", send: false }))

    el("chip").click()

    expect(el("chat-input").value).toBe("Next: ")
    expect(sent).toEqual([])
  })

  it("reaches only the composer it names", async () => {
    await mount(composer("one") + composer("two") + prompt("chip", { composer: "two", text: "For two" }))

    el("chip").click()

    expect(sent).toEqual([["two-form", "For two"]])
    expect(el("one-input").value).toBe("")
  })

  it("a prompt for a composer that is not on the page does nothing", async () => {
    await mount(composer("chat") + prompt("chip", { composer: "elsewhere", text: "Lost" }))

    el("chip").click()

    expect(sent).toEqual([])
    expect(el("chat-input").value).toBe("")
  })

  it("a composer taken off the page stops hearing prompts", async () => {
    await mount(composer("chat") + prompt("chip", { composer: "chat", text: "Overview" }))

    const form = el("chat-form")

    el("chat").remove()
    await nextFrame()
    document.body.append(form)
    el("chip").click()

    expect(sent).toEqual([])
    form.remove()
  })
})
