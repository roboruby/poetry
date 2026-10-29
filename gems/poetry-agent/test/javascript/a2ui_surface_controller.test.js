import { describe, it, expect, beforeEach, afterEach } from "vitest"
import { Application } from "@hotwired/stimulus"
import { registerPoetryAgent, installVersionedReplace, preservesLocalState } from "@poetry/agent"

// The client side of a surface's checks: buttons disable while their own
// checks fail, inputs turn invalid and their error slot carries the
// message, all re-evaluated as the user types. Unknown functions pass here
// (the server decides). What the user sees waits for them: an input's
// message once its path is edited, a button's reason once any input is;
// until then the server's rendering stands.
const PROGRAM = {
  checks: {
    email: { kind: "input", path: "/email", rules: [{ condition: { "@call": "email", args: { value: { "@path": "/email" } } }, message: "Enter a valid email" }] },
    submit: { kind: "button", rules: [{
      condition: { "@call": "and", args: { values: [
        { "@call": "required", args: { value: { "@path": "/terms" } } },
        { "@call": "or", args: { values: [
          { "@call": "required", args: { value: { "@path": "/email" } } },
          { "@call": "required", args: { value: { "@path": "/phone" } } } ] } } ] } },
      message: "Accept the terms and give an email or phone" }] },
    size: { kind: "input", path: "/size", rules: [{ condition: { "@call": "required", args: { value: { "@path": "/size" } } }, message: "Pick a size" }] },
    seats: { kind: "input", path: "/seats", rules: [{ condition: { "@call": "numeric", args: { value: { "@path": "/seats" }, min: 1, max: 5 } }, message: "1 to 5 seats" }] },
    exotic: { kind: "button", rules: [{ condition: { "@call": "customValidator", args: { value: { "@path": "/email" } } }, message: "never shown" }] },
    phone: { kind: "input", path: "/phone", rules: [{ condition: { "@call": "phoneNumber", args: { value: { "@path": "/phone" } } }, message: "never shown" }] }
  },
  inputs: { "/email": "string", "/phone": "string", "/terms": "boolean", "/size": "string_list", "/seats": "number" },
  model: { email: "", phone: "", terms: false, size: [], seats: 3, plan: "Team" }
}

const flush = () => new Promise((resolve) => setTimeout(resolve, 0))

// The surface as the server renders it; `server` is what a rejected action
// left in the phone's slot (a failure of a rule the browser cannot judge).
const mount = ({ server = false } = {}) => {
  document.body.innerHTML = `
    <form id="s" data-a2ui-surface="s" data-controller="poetry--agent--a2ui-surface"
          data-poetry--agent--a2ui-surface-program-value='${JSON.stringify(PROGRAM)}'
          data-action="input->poetry--agent--a2ui-surface#touch change->poetry--agent--a2ui-surface#touch turbo:morph-element->poetry--agent--a2ui-surface#morphed">
      <input id="email" type="email" name="a2ui[values][/email]" value="" data-a2ui-key="email">
      <p data-a2ui-error-for="email" hidden></p>
      <input id="phone" type="text" name="a2ui[values][/phone]" value="" data-a2ui-key="phone"${server ? ' aria-invalid="true"' : ""}>
      <p data-a2ui-error-for="phone"${server ? ">Not a phone number we can reach" : " hidden>"}</p>
      <input type="hidden" name="a2ui[values][/terms]" value="false">
      <input id="terms" type="checkbox" name="a2ui[values][/terms]" value="true">
      <input type="radio" name="a2ui[values][/size]" value="s" id="size-s">
      <input type="radio" name="a2ui[values][/size]" value="m" id="size-m">
      <p data-a2ui-error-for="size" hidden></p>
      <input id="seats" type="number" name="a2ui[values][/seats]" value="3" data-a2ui-key="seats">
      <p data-a2ui-error-for="seats" hidden></p>
      <button id="submit" type="submit" name="a2ui[action]" value="submit" data-a2ui-key="submit">Go</button>
      <p data-a2ui-error-for="submit" hidden></p>
      <button id="exotic" type="submit" name="a2ui[action]" value="exotic" data-a2ui-key="exotic">Other</button>
    </form>`
}

const fire = (element, type) => element.dispatchEvent(new Event(type, { bubbles: true }))

describe("poetry--agent--a2ui-surface", () => {
  let application

  beforeEach(async () => {
    mount()
    application = Application.start()
    registerPoetryAgent(application)
    await flush()
  })

  afterEach(() => application.stop())

  it("evaluates at mount: the button's own checks disable it, but nothing is told until the user touches an input", () => {
    expect(document.getElementById("submit").disabled).toBe(true)
    expect(document.querySelector('[data-a2ui-error-for="submit"]').hidden).toBe(true)
    expect(document.getElementById("email").getAttribute("aria-invalid")).toBeNull()
    expect(document.querySelector('[data-a2ui-error-for="email"]').hidden).toBe(true)
    expect(document.querySelector('[data-a2ui-error-for="size"]').hidden).toBe(true)
    expect(document.getElementById("exotic").disabled).toBe(false)
  })

  it("re-evaluates as the user types and toggles, telling each input once it is touched", () => {
    // required() follows the spec: null, undefined, "", and [] are absent; a boolean
    // false is present, so the unchecked terms box alone does not fail the button.
    const email = document.getElementById("email")
    email.value = "ada"
    fire(email, "input")
    expect(email.getAttribute("aria-invalid")).toBe("true")
    expect(document.querySelector('[data-a2ui-error-for="email"]').textContent).toBe("Please enter a valid email address (e.g. user@example.com).")
    expect(document.querySelector('[data-a2ui-error-for="size"]').hidden).toBe(true) // untouched: still nothing
    expect(document.getElementById("submit").disabled).toBe(false) // something in email or phone is all it asks

    email.value = "ada@example.com"
    fire(email, "input")
    expect(email.getAttribute("aria-invalid")).toBe("false")
    expect(document.querySelector('[data-a2ui-error-for="email"]').hidden).toBe(true)
    expect(document.querySelector('[data-a2ui-error-for="submit"]').hidden).toBe(true)

    email.value = ""
    fire(email, "input")
    expect(document.getElementById("submit").disabled).toBe(true)
    expect(document.querySelector('[data-a2ui-error-for="submit"]').hidden).toBe(false) // the button explains itself now
    expect(document.querySelector('[data-a2ui-error-for="submit"]').textContent).toBe("Accept the terms and give an email or phone")
    const phone = document.getElementById("phone")
    phone.value = "555"
    fire(phone, "input")
    expect(document.getElementById("submit").disabled).toBe(false)

    document.getElementById("size-m").checked = true
    fire(document.getElementById("size-m"), "change")
    expect(document.querySelector('[data-a2ui-error-for="size"]').hidden).toBe(true)

    const seats = document.getElementById("seats")
    seats.value = "9"
    fire(seats, "input")
    expect(seats.getAttribute("aria-invalid")).toBe("true")
    expect(document.querySelector('[data-a2ui-error-for="seats"]').textContent).toBe("1 to 5 seats")
  })

  it("keeps a failure the server rendered until the browser can judge it, and re-judges after a morph", async () => {
    application.stop()
    mount({ server: true })
    application = Application.start()
    registerPoetryAgent(application)
    await flush()
    const phone = document.getElementById("phone")
    const slot = document.querySelector('[data-a2ui-error-for="phone"]')
    expect(slot.hidden).toBe(false)
    expect(phone.getAttribute("aria-invalid")).toBe("true")

    phone.value = "555"
    fire(phone, "input")
    expect(slot.textContent).toBe("Not a phone number we can reach") // phoneNumber is the server's to judge
    expect(phone.getAttribute("aria-invalid")).toBe("true")

    // A morph puts the server's rendering back; the touched email is judged again once it is over.
    const email = document.getElementById("email")
    email.value = "ada"
    fire(email, "input")
    expect(document.querySelector('[data-a2ui-error-for="email"]').hidden).toBe(false)
    document.querySelector('[data-a2ui-error-for="email"]').hidden = true
    document.querySelector('[data-a2ui-error-for="email"]').textContent = ""
    delete document.querySelector('[data-a2ui-error-for="email"]').dataset.a2uiVerdict
    email.dispatchEvent(new CustomEvent("turbo:morph-element", { bubbles: true }))
    email.dispatchEvent(new CustomEvent("turbo:morph-element", { bubbles: true }))
    await flush()
    expect(document.querySelector('[data-a2ui-error-for="email"]').hidden).toBe(false)
    expect(document.querySelector('[data-a2ui-error-for="email"]').textContent).toBe("Please enter a valid email address (e.g. user@example.com).")
  })

  it("re-evaluates when a server render changes the program", async () => {
    const form = document.getElementById("s")
    const seats = document.getElementById("seats")
    seats.value = "9"
    fire(seats, "input")
    expect(document.querySelector('[data-a2ui-error-for="seats"]').textContent).toBe("1 to 5 seats")

    const widened = { ...PROGRAM, checks: { ...PROGRAM.checks, seats: { ...PROGRAM.checks.seats, rules: [{ condition: { "@call": "numeric", args: { value: { "@path": "/seats" }, min: 1, max: 10 } }, message: "1 to 10 seats" }] } } }
    form.setAttribute("data-poetry--agent--a2ui-surface-program-value", JSON.stringify(widened))
    await flush()
    expect(document.querySelector('[data-a2ui-error-for="seats"]').hidden).toBe(true)
    expect(seats.getAttribute("aria-invalid")).toBe("false")
  })

  it("reads paths no control carries from the model", () => {
    const controller = application.getControllerForElementAndIdentifier(document.getElementById("s"), "poetry--agent--a2ui-surface")
    expect(controller.read("/plan")).toBe("Team")
    expect(controller.read("/seats")).toBe(3)
    expect(controller.read("/terms")).toBe(false)
    expect(controller.read("/size")).toEqual([])
    expect(controller.resolve({ "@call": "not", args: { value: { "@call": "regex", args: { value: "x@example.com", pattern: "@example\\.com$" } } } })).toBe(false)
  })
})

describe("versioned replace with morph", () => {
  it("delegates newer frames to Turbo's replace when method is morph", () => {
    const calls = []
    const turbo = { StreamActions: { replace() { calls.push({ method: this.getAttribute("method"), targets: this.targetElements.map((e) => e.id) }) } } }
    expect(installVersionedReplace(turbo)).toBe(true)
    document.body.innerHTML = '<div id="row" data-version="2">old</div>'
    const template = document.createElement("template")
    template.innerHTML = '<div id="row" data-version="3">new</div>'
    const stream = { targetElements: [document.getElementById("row")], templateContent: template.content, getAttribute: (name) => (name === "method" ? "morph" : null) }
    turbo.StreamActions.vreplace.call(stream)
    expect(calls).toEqual([{ method: "morph", targets: ["row"] }])
    expect(document.getElementById("row").textContent).toBe("old") // the fake replace did not morph

    const stale = document.createElement("template")
    stale.innerHTML = '<div id="row" data-version="1">stale</div>'
    turbo.StreamActions.vreplace.call({ ...stream, templateContent: stale.content })
    expect(calls.length).toBe(1)
  })

  it("swaps without a method, as before", () => {
    const turbo = { StreamActions: {} }
    installVersionedReplace(turbo)
    document.body.innerHTML = '<div id="row" data-version="2">old</div>'
    const template = document.createElement("template")
    template.innerHTML = '<div id="row" data-version="3">new</div>'
    turbo.StreamActions.vreplace.call({ targetElements: [document.getElementById("row")], templateContent: template.content })
    expect(document.getElementById("row").textContent).toBe("new")
  })
})

describe("the morph state guard", () => {
  beforeEach(() => {
    document.body.innerHTML = `
      <form data-a2ui-surface="s">
        <button data-slot="tabs-trigger" aria-selected="true" id="tab"></button>
        <div data-slot="tabs-content" hidden id="panel"></div>
        <dialog data-slot="dialog-content" open id="dialog"></dialog>
        <input id="typed" value="server"><input id="untouched" value="server">
        <input id="box" type="checkbox"><textarea id="area">server</textarea>
        <span id="popup" aria-expanded="true"></span>
      </form>
      <input id="outside" value="server">`
    document.getElementById("typed").value = "mine"
    document.getElementById("box").checked = true
    document.getElementById("area").value = "mine"
    document.getElementById("outside").value = "mine"
  })

  it("keeps tab selection, dialog state, expanded popups, and dirty controls inside a surface", () => {
    expect(preservesLocalState(document.getElementById("tab"), "aria-selected")).toBe(true)
    expect(preservesLocalState(document.getElementById("tab"), "class")).toBe(false)
    expect(preservesLocalState(document.getElementById("panel"), "hidden")).toBe(true)
    expect(preservesLocalState(document.getElementById("dialog"), "open")).toBe(true)
    expect(preservesLocalState(document.getElementById("popup"), "aria-expanded")).toBe(true)
    expect(preservesLocalState(document.getElementById("typed"), "value")).toBe(true)
    expect(preservesLocalState(document.getElementById("untouched"), "value")).toBe(false)
    expect(preservesLocalState(document.getElementById("box"), "checked")).toBe(true)
    expect(preservesLocalState(document.getElementById("area"), "value")).toBe(true)
    expect(preservesLocalState(document.getElementById("outside"), "value")).toBe(false)
  })
})
