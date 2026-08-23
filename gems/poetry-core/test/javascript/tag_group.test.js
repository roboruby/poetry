import { beforeEach, describe, expect, it } from "vitest"
import { Application } from "@hotwired/stimulus"
import { registerPoetryControllers } from "@poetry/controllers"

// The TagGroup removal engine: Delete/
// Backspace removes the focused tag (row-origin keys only), the remove
// button removes exactly its own tag, focus recovers forward-then-backward
// skipping disabled tags, the last removal hands focus to the container
// (role flips grid->group), removal is cancelable, and the live region is
// polite only while focus is within.

const nextFrame = () => new Promise((resolve) => setTimeout(resolve, 0))

const IDENTIFIER = "poetry--core--tag-group"

const el = (id) => document.getElementById(id)

const tag = (id, { disabled = false, value = id } = {}) => `
  <div id="${id}" role="row" data-slot="tag-group-tag" data-value="${value}"
       tabindex="-1" ${disabled ? 'data-disabled=""' : ""}>
    <span role="gridcell">${id}
      <button id="${id}-remove" tabindex="0" aria-label="Remove"
              data-action="click->${IDENTIFIER}#remove">×</button>
      <input type="hidden" name="tags[]" value="${value}">
    </span>
  </div>`

const groupMarkup = (tags) => `
  <div id="group" role="grid" aria-label="Tags" aria-live="off"
       aria-atomic="false" aria-relevant="additions"
       data-controller="${IDENTIFIER}"
       data-action="keydown->${IDENTIFIER}#keydown">
    ${tags.join("\n")}
  </div>`

const pressOn = (element, key) =>
  element.dispatchEvent(new KeyboardEvent("keydown", { key, bubbles: true, cancelable: true }))

describe("poetry--core--tag-group", () => {
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

  async function mount(tags = [tag("alpha"), tag("beta"), tag("gamma")]) {
    el("host").innerHTML = groupMarkup(tags)
    await nextFrame()
  }

  it("Delete on a focused tag removes it (and its hidden input) and focuses the NEXT tag", async () => {
    await mount()

    el("beta").focus()
    pressOn(el("beta"), "Delete")

    expect(el("beta")).toBeNull()
    expect(document.querySelectorAll("input[name='tags[]']").length).toBe(2)
    expect(document.activeElement).toBe(el("gamma"))
  })

  it("removing the LAST tag focuses the previous; a disabled neighbor is skipped", async () => {
    await mount([tag("alpha"), tag("beta", { disabled: true }), tag("gamma")])

    el("gamma").focus()
    pressOn(el("gamma"), "Backspace")

    expect(el("gamma")).toBeNull()
    expect(document.activeElement).toBe(el("alpha")) // beta is disabled: skipped
  })

  it("keys from the tag's inner remove button never drive removal", async () => {
    await mount()

    el("beta-remove").focus()
    pressOn(el("beta-remove"), "Delete")

    expect(el("beta")).not.toBeNull()
  })

  it("a disabled tag ignores Delete", async () => {
    await mount([tag("alpha", { disabled: true }), tag("beta")])

    el("alpha").focus()
    pressOn(el("alpha"), "Delete")

    expect(el("alpha")).not.toBeNull()
  })

  it("the remove button removes exactly its own tag", async () => {
    await mount()

    el("alpha-remove").dispatchEvent(new MouseEvent("click", { bubbles: true, cancelable: true }))

    expect(el("alpha")).toBeNull()
    expect(el("beta")).not.toBeNull()
    expect(el("gamma")).not.toBeNull()
  })

  it("removal is CANCELABLE - a Turbo host preventDefault()s and owns the render", async () => {
    await mount()

    el("group").addEventListener("poetry:tag-group:remove", (event) => {
      expect(event.detail.value).toBe("beta")
      event.preventDefault()
    })

    el("beta").focus()
    pressOn(el("beta"), "Delete")

    expect(el("beta")).not.toBeNull()
  })

  it("removing the last tag hands focus to the container and flips role grid->group", async () => {
    await mount([tag("alpha")])

    el("alpha").focus()
    pressOn(el("alpha"), "Delete")

    expect(el("group").getAttribute("role")).toBe("group")
    expect(el("group").hasAttribute("data-empty")).toBe(true)
    expect(el("group").getAttribute("tabindex")).toBe("0")
    expect(document.activeElement).toBe(el("group"))
  })

  it("the live region is polite only while focus is within", async () => {
    await mount()

    expect(el("group").getAttribute("aria-live")).toBe("off")

    el("alpha").focus()
    expect(el("group").getAttribute("aria-live")).toBe("polite")

    el("alpha").blur()
    expect(el("group").getAttribute("aria-live")).toBe("off")
  })
})
