import { afterEach, beforeEach, describe, expect, it } from "vitest"
import { Application } from "@hotwired/stimulus"
import { registerPoetryControllers } from "@poetry/controllers"
import { isEditingTarget, matchesHotkey } from "@poetry/controllers/helpers/hotkey"

const nextFrame = () => new Promise((resolve) => setTimeout(resolve, 0))

function key(props) {
  return new KeyboardEvent("keydown", { bubbles: true, cancelable: true, ...props })
}

describe("hotkey helper", () => {
  it("meta descriptor matches metaKey OR ctrlKey (the command-palette convention)", () => {
    expect(matchesHotkey(key({ key: "k", metaKey: true }), "meta+k")).toBe(true)
    expect(matchesHotkey(key({ key: "k", ctrlKey: true }), "meta+k")).toBe(true)
    expect(matchesHotkey(key({ key: "k" }), "meta+k")).toBe(false)
  })

  it("unlisted modifiers must be up - plain typing never triggers", () => {
    expect(matchesHotkey(key({ key: "k" }), "k")).toBe(true)
    expect(matchesHotkey(key({ key: "k", metaKey: true }), "k")).toBe(false)
    expect(matchesHotkey(key({ key: "k", shiftKey: true }), "k")).toBe(false)
    expect(matchesHotkey(key({ key: "p", ctrlKey: true, shiftKey: true }), "ctrl+shift+p")).toBe(true)
    expect(matchesHotkey(key({ key: "p", ctrlKey: true }), "ctrl+shift+p")).toBe(false)
  })

  it("isEditingTarget flags inputs, textareas, selects, and contentEditable", () => {
    const input = document.createElement("input")
    document.body.appendChild(input)
    const event = key({ key: "/" })
    Object.defineProperty(event, "target", { value: input })

    expect(isEditingTarget(event)).toBe(true)

    const div = document.createElement("div")
    Object.defineProperty(div, "isContentEditable", { value: true })
    const editable = key({ key: "/" })
    Object.defineProperty(editable, "target", { value: div })

    expect(isEditingTarget(editable)).toBe(true)

    const plain = key({ key: "/" })
    Object.defineProperty(plain, "target", { value: document.body })

    expect(isEditingTarget(plain)).toBe(false)
    input.remove()
  })
})

describe("poetry--core--hotkey", () => {
  let application

  beforeEach(async () => {
    application = Application.start()
    registerPoetryControllers(application)
    await nextFrame()
  })

  // application.stop() does not DISCONNECT live controllers - clear the
  // body while the application still observes so each test's window
  // listener is actually removed (a leaked listener claims the key first
  // and the defaultPrevented gate makes the fresh one defer to it).
  afterEach(async () => {
    document.body.innerHTML = ""
    await nextFrame()
    application.stop()
  })

  it("clicks the host, prevents default, and honors a pressed-event veto", async () => {
    document.body.innerHTML = `
      <button id="palette" data-controller="poetry--core--hotkey"
              data-poetry--core--hotkey-keys-value="meta+k">Palette</button>`
    await nextFrame()

    const palette = document.getElementById("palette")
    let clicks = 0
    palette.addEventListener("click", () => { clicks += 1 })

    const event = key({ key: "k", metaKey: true })
    window.dispatchEvent(event)

    expect(clicks).toBe(1)
    expect(event.defaultPrevented).toBe(true)

    palette.addEventListener("poetry--core--hotkey:pressed", (pressed) => pressed.preventDefault())
    window.dispatchEvent(key({ key: "k", metaKey: true }))

    expect(clicks).toBe(1)
  })

  it("leaves a key another consumer already claimed (defaultPrevented) alone", async () => {
    document.body.innerHTML = `
      <button id="palette" data-controller="poetry--core--hotkey"
              data-poetry--core--hotkey-keys-value="meta+k">Palette</button>`
    await nextFrame()

    let clicks = 0
    document.getElementById("palette").addEventListener("click", () => { clicks += 1 })

    const claimed = key({ key: "k", metaKey: true })
    claimed.preventDefault()
    window.dispatchEvent(claimed)

    expect(clicks).toBe(0)
  })

  it("single-key descriptors stay inert while typing; combos fire everywhere", async () => {
    document.body.innerHTML = `
      <button id="slash" data-controller="poetry--core--hotkey"
              data-poetry--core--hotkey-keys-value="/">Search</button>
      <button id="combo" data-controller="poetry--core--hotkey"
              data-poetry--core--hotkey-keys-value="meta+k">Palette</button>
      <input id="field" type="text">`
    await nextFrame()

    let slashClicks = 0
    let comboClicks = 0
    document.getElementById("slash").addEventListener("click", () => { slashClicks += 1 })
    document.getElementById("combo").addEventListener("click", () => { comboClicks += 1 })
    const field = document.getElementById("field")

    // Dispatch FROM the input - the event bubbles to the window listener
    // with a real editing composedPath, exactly like typing does.
    field.dispatchEvent(key({ key: "/" }))

    expect(slashClicks).toBe(0)

    field.dispatchEvent(key({ key: "k", metaKey: true }))

    expect(comboClicks).toBe(1)

    window.dispatchEvent(key({ key: "/" }))

    expect(slashClicks).toBe(1)
  })
})
