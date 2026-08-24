import { beforeEach, describe, expect, it } from "vitest"
import { Application } from "@hotwired/stimulus"
import { registerPoetryControllers } from "@poetry/controllers"

// poetry--core--tabs JS-unit: the activation machine. What this file
// proves: reconcile-on-connect (server data-active is the truth; aria/
// tabindex/hidden derive from it), click + automatic focus activation
// writing the Base UI vocabulary (data-active + aria-selected + hidden/
// data-hidden), the roving tab-stop stamp, disabled triggers ignored,
// nested-root scoping, and the setValue programmatic surface.

const nextFrame = () => new Promise((resolve) => setTimeout(resolve, 0))
const el = (id) => document.getElementById(id)

const click = (element) =>
  element.dispatchEvent(new MouseEvent("click", { bubbles: true, cancelable: true }))

const trigger = (value, { active = false, disabled = false } = {}) => `
  <button type="button" id="tab-${value}" role="tab" data-slot="tabs-trigger" data-value="${value}"
          data-poetry-collection-item aria-controls="panel-${value}"
          ${active ? 'data-active aria-selected="true" tabindex="0"' : 'aria-selected="false" tabindex="-1"'}
          ${disabled ? "disabled data-disabled" : ""}
          data-action="click->poetry--core--tabs#activate">${value}</button>`

const panel = (value, { active = false } = {}) => `
  <div id="panel-${value}" role="tabpanel" data-slot="tabs-content" data-value="${value}"
       aria-labelledby="tab-${value}" tabindex="0" ${active ? "" : "hidden data-hidden"}>${value} panel</div>`

const markup = ({ inner = "" } = {}) => `
  <div id="root" data-controller="poetry--core--tabs" data-slot="tabs" data-orientation="horizontal">
    <div id="list" role="tablist" data-slot="tabs-list"
         data-action="poetry--core--roving-focus:entry->poetry--core--tabs#focusActivate focusin->poetry--core--tabs#focusActivate">
      ${trigger("account", { active: true })}
      ${trigger("password")}
      ${trigger("billing", { disabled: true })}
    </div>
    ${panel("account", { active: true })}
    ${panel("password")}
    ${panel("billing")}
    ${inner}
  </div>`

async function mount(html) {
  document.body.innerHTML = html
  const application = Application.start()
  registerPoetryControllers(application)
  await nextFrame()
  return application
}

const stateOfTab = (value) => ({
  active: el(`tab-${value}`).hasAttribute("data-active"),
  selected: el(`tab-${value}`).getAttribute("aria-selected"),
  tabindex: el(`tab-${value}`).getAttribute("tabindex"),
  panelHidden: el(`panel-${value}`).hidden,
})

describe("poetry--core--tabs", () => {
  let application

  beforeEach(async () => {
    application = await mount(markup())
    return async () => {
      application.stop()
      document.body.replaceChildren()
      await nextFrame()
    }
  })

  it("reconciles the server-rendered active tab on connect", () => {
    expect(stateOfTab("account")).toEqual({ active: true, selected: "true", tabindex: "0", panelHidden: false })
    expect(stateOfTab("password")).toEqual({ active: false, selected: "false", tabindex: "-1", panelHidden: true })
  })

  it("click activates: vocabulary, aria, tab stop, and panels flip together", () => {
    click(el("tab-password"))

    expect(stateOfTab("password")).toEqual({ active: true, selected: "true", tabindex: "0", panelHidden: false })
    expect(stateOfTab("account")).toEqual({ active: false, selected: "false", tabindex: "-1", panelHidden: true })
    expect(el("panel-account").hasAttribute("data-hidden")).toBe(true)
    expect(el("panel-password").hasAttribute("data-hidden")).toBe(false)
  })

  it("automatic activation follows the roving entry event", () => {
    el("tab-password").dispatchEvent(
      new CustomEvent("poetry--core--roving-focus:entry", { bubbles: true, detail: { item: el("tab-password") } }),
    )

    expect(stateOfTab("password").active).toBe(true)
    expect(stateOfTab("account").active).toBe(false)
  })

  it("a raw focusin activates too (the hand-wired fallback)", () => {
    el("tab-password").dispatchEvent(new FocusEvent("focusin", { bubbles: true }))

    expect(stateOfTab("password").active).toBe(true)
  })

  it("a disabled trigger activates nothing", () => {
    click(el("tab-billing"))
    el("tab-billing").dispatchEvent(new FocusEvent("focusin", { bubbles: true }))

    expect(stateOfTab("billing").active).toBe(false)
    expect(stateOfTab("account").active).toBe(true)
  })

  it("setValue is the programmatic surface and unknown values are ignored", () => {
    const controller = application.getControllerForElementAndIdentifier(el("root"), "poetry--core--tabs")

    controller.setValue("password")
    expect(stateOfTab("password").active).toBe(true)

    controller.setValue("nope")
    expect(stateOfTab("password").active).toBe(true) // unchanged
  })

  it("dispatches a change event with the activated value", () => {
    let detail = null
    el("root").addEventListener("poetry:tabs:change", (event) => { detail = event.detail })

    click(el("tab-password"))

    expect(detail).toEqual({ value: "password" })
  })

  it("a nested tabs root owns its own triggers and panels", async () => {
    application.stop()
    const inner = `
      <div id="inner-root" data-controller="poetry--core--tabs" data-slot="tabs">
        <div role="tablist" data-slot="tabs-list">
          ${trigger("inner-a", { active: true })}
          ${trigger("inner-b")}
        </div>
        ${panel("inner-a", { active: true })}
        ${panel("inner-b")}
      </div>`
    application = await mount(markup({ inner }))

    click(el("tab-inner-b"))

    expect(stateOfTab("inner-b").active).toBe(true)
    expect(stateOfTab("account").active).toBe(true, "the OUTER tabs must not react to the inner click")
  })
})
