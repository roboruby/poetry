import { afterEach, beforeEach, describe, expect, it, vi } from "vitest"
import { Application } from "@hotwired/stimulus"
import { registerPoetryControllers } from "@poetry/controllers"

// The Composer's menus: the word at the caret opens the list whose
// trigger it starts with; the list filters and ranks as the word grows;
// arrows move the highlight, Enter and Tab choose, Escape dismisses for
// that word; a text menu writes the option's text, a chip menu adds a
// chip with a hidden field, a run option only reports; and an Enter the
// menu takes is never a send.

const nextFrame = () => new Promise((resolve) => setTimeout(resolve, 0))

const COMPOSER = "poetry--core--composer"
const MENU = "poetry--core--composer-menu"

const el = (id) => document.getElementById(id)

const option = (menu, index, { value, label, keywords = "", insert = null, run = false, icon = false }) => `
  <div role="option" id="composer-menu-${menu}-option-${index}" aria-selected="false" data-value="${value}"
       data-label="${label}" data-filter-value="${label}" data-keywords="${value} ${keywords}"
       ${insert === null ? "" : `data-insert="${insert}"`} ${run ? "data-run" : ""}>${icon ? "<svg></svg>" : ""}<span>${label}</span></div>`

const menu = (index, { trigger, inserts = "text", name = "", at = "word" }, options) => `
  <div id="menu-${index}" hidden data-closed data-${MENU}-target="menu" data-trigger="${trigger}"
       data-inserts="${inserts}" data-name="${name}" data-at="${at}"
       data-action="pointerdown->${MENU}#hold click->${MENU}#pick pointermove->${MENU}#point">
    <div role="listbox" id="composer-menu-${index}" aria-label="Menu ${index}">
      ${options.map((entry, at) => option(index, at, entry)).join("")}
    </div>
  </div>`

const PEOPLE = [
  { value: "jordan", label: "Jordan Lee" },
  { value: "ana", label: "Ana Diaz", keywords: "design" },
  { value: "dan", label: "Dan Abe" }
]
const COMMANDS = [
  { value: "summarize", label: "summarize", insert: "/summarize " },
  { value: "clear", label: "clear", run: true }
]
const FILES = [
  { value: "doc_1", label: "Q3 plan.pdf", icon: true },
  { value: "doc_2", label: "Roadmap.md" }
]

const markup = () => `
  <div id="composer" data-controller="${MENU} ${COMPOSER}" data-empty
       data-${MENU}-messages-value='{"one":"1 suggestion","other":"{count} suggestions","added":"{label} added","removed":"{label} removed"}'
       data-action="poetry:composer:sent->${MENU}#sent turbo:morph-element->${MENU}#restore">
    ${menu(0, { trigger: "@" }, PEOPLE)}
    ${menu(1, { trigger: "/", at: "start" }, COMMANDS)}
    ${menu(2, { trigger: "#", inserts: "chip", name: "context[]" }, FILES)}
    <form id="form" action="/messages" method="post" data-${COMPOSER}-target="form"
          data-action="submit->${COMPOSER}#guard turbo:submit-end->${COMPOSER}#settle">
      <div id="chips" data-${MENU}-target="chips" data-action="turbo:before-morph-element->${MENU}#keep"></div>
      <textarea id="input" name="content" aria-autocomplete="list" aria-controls="composer-menu-0 composer-menu-1 composer-menu-2"
                data-${MENU}-target="input" data-${COMPOSER}-target="input"
                data-action="keydown->${MENU}#keydown input->${MENU}#track keyup->${MENU}#track click->${MENU}#track focus->${MENU}#track blur->${MENU}#blurred keydown->${COMPOSER}#keydown input->${COMPOSER}#changed"></textarea>
      <button id="send" type="submit" data-${COMPOSER}-target="send">Send</button>
    </form>
    <template data-${MENU}-target="template">
      <div data-slot="attachment"><div data-slot="attachment-media">F</div><span data-slot="attachment-title"></span>
        <button type="button" data-action="click->${MENU}#remove">remove</button></div>
    </template>
  </div>`

// Typing: the text lands with the caret at its end (or where asked) and
// a real input event follows, as a keystroke's would.
const type = (text, caret = text.length) => {
  const field = el("input")

  field.value = text
  field.setSelectionRange(caret, caret)
  field.dispatchEvent(new Event("input", { bubbles: true }))
}

const press = (key, options = {}) => {
  const event = new KeyboardEvent("keydown", { key, bubbles: true, cancelable: true, ...options })

  el("input").dispatchEvent(event)
  return event
}

const shown = (index) => Array.from(el(`composer-menu-${index}`).querySelectorAll("[role=option]"))
  .filter((entry) => !entry.hidden).map((entry) => entry.dataset.value)

const highlighted = (index) => el(`composer-menu-${index}`).querySelector("[data-highlighted]")?.dataset.value ?? null

const live = () => Array.from(document.querySelectorAll("[aria-live]")).map((region) => region.textContent).join("|")

// The shared live region warms up, then writes a frame later and spaces
// its messages, so an announcement is waited for, not read at once.
const heard = (text) => vi.waitFor(() => expect(live()).toContain(text))

describe("poetry--core--composer-menu", () => {
  let application
  let sent
  let chosen

  const turbo = (event) => {
    if (event.defaultPrevented) return
    event.preventDefault()
    sent.push(el("input").value)
  }
  const choose = (event) => chosen.push(event.detail)

  beforeEach(async () => {
    sent = []
    chosen = []
    document.body.innerHTML = `<div id="host"></div>`
    document.addEventListener("submit", turbo)
    document.addEventListener("poetry:composer-menu:choose", choose)
    application = Application.start()
    registerPoetryControllers(application)
    await nextFrame()
    el("host").innerHTML = markup()
    await nextFrame()
    el("input").focus()
  })

  afterEach(async () => {
    document.removeEventListener("submit", turbo)
    document.removeEventListener("poetry:composer-menu:choose", choose)
    el("host")?.replaceChildren()
    await nextFrame()
    application.stop()
    vi.unstubAllGlobals()
  })

  it("a word that starts with a trigger opens that menu on its first option", () => {
    type("hello @")

    expect(el("menu-0").hidden).toBe(false)
    expect(el("menu-0").hasAttribute("data-open")).toBe(true)
    expect(el("menu-1").hidden).toBe(true)
    expect(shown(0)).toEqual(["jordan", "ana", "dan"])
    expect(highlighted(0)).toBe("jordan")
    expect(el("input").getAttribute("aria-activedescendant")).toBe("composer-menu-0-option-0")
    expect(el("composer-menu-0-option-0").getAttribute("aria-selected")).toBe("true")
  })

  it("the field never takes an expanded state or a role", () => {
    type("@")

    expect(el("input").hasAttribute("aria-expanded")).toBe(false)
    expect(el("input").hasAttribute("role")).toBe(false)
    expect(el("input").getAttribute("aria-controls")).toBe("composer-menu-0 composer-menu-1 composer-menu-2")
  })

  it("a trigger inside a word opens nothing", () => {
    type("mail ana@example")

    expect(el("menu-0").hidden).toBe(true)
    expect(el("input").hasAttribute("aria-activedescendant")).toBe(false)
  })

  it("the list filters as the word grows and ranks the closest match first", () => {
    type("@an")

    // "Ana" starts with the query; "Jordan" only holds it; "Dan" too.
    expect(shown(0)).toEqual(["ana", "jordan", "dan"])
    expect(highlighted(0)).toBe("ana")

    type("@ana")

    expect(shown(0)).toEqual(["ana"])
  })

  it("an option matches by its value and its keywords as well as its label", () => {
    type("@design")

    expect(shown(0)).toEqual(["ana"])
  })

  it("a word nothing matches closes the list, and Enter sends as usual", () => {
    type("@zz")

    expect(el("menu-0").hidden).toBe(true)

    press("Enter")

    expect(sent).toEqual(["@zz"])
  })

  it("the arrows move the highlight and wrap, and are taken from the field", () => {
    type("@")

    const down = press("ArrowDown")

    expect(down.defaultPrevented).toBe(true)
    expect(highlighted(0)).toBe("ana")
    expect(el("input").getAttribute("aria-activedescendant")).toBe("composer-menu-0-option-1")
    expect(el("composer-menu-0-option-0").getAttribute("aria-selected")).toBe("false")

    press("ArrowUp")
    press("ArrowUp")

    expect(highlighted(0)).toBe("dan")
  })

  it("the keyup that follows a key the menu took does not reset the highlight", () => {
    type("@")
    press("ArrowDown")
    el("input").dispatchEvent(new KeyboardEvent("keyup", { key: "ArrowDown", bubbles: true }))

    expect(highlighted(0)).toBe("ana")
  })

  it("Enter chooses the highlighted option and is not a send", () => {
    type("ask @an")

    const enter = press("Enter")

    expect(enter.defaultPrevented).toBe(true)
    expect(sent).toEqual([])
    expect(el("input").value).toBe("ask @ana ")
    expect(el("input").selectionStart).toBe(9)
    expect(el("menu-0").hidden).toBe(true)
    expect(el("input").hasAttribute("aria-activedescendant")).toBe(false)
    expect(chosen).toEqual([{ kind: "text", trigger: "@", value: "ana", label: "Ana Diaz" }])
  })

  it("Tab chooses too, and the next Enter sends the message", () => {
    type("@jo")

    const tab = press("Tab")

    expect(tab.defaultPrevented).toBe(true)
    expect(el("input").value).toBe("@jordan ")

    press("Enter")

    expect(sent).toEqual(["@jordan "])
  })

  it("a choice in the middle of the text replaces only the typed word", () => {
    type("ask @an about it", 7)
    press("Enter")

    expect(el("input").value).toBe("ask @ana  about it")
    expect(el("input").selectionStart).toBe(9)
  })

  it("a choice is followed by a real input event, so the composer's emptiness follows", () => {
    type("@")

    expect(el("composer").hasAttribute("data-empty")).toBe(false)

    const heard = []

    el("input").addEventListener("input", () => heard.push(el("input").value), { once: true })
    press("Enter")

    expect(heard).toEqual(["@jordan "])
  })

  it("Shift+Enter and Cmd+Enter are not the menu's: the line breaks or the message goes", () => {
    type("@an")

    const shifted = press("Enter", { shiftKey: true })

    expect(shifted.defaultPrevented).toBe(false)
    expect(el("input").value).toBe("@an")

    press("Enter", { metaKey: true })

    expect(sent).toEqual(["@an"])
  })

  it("an Enter that belongs to a composition chooses nothing", () => {
    type("@an")

    const composing = press("Enter", { isComposing: true })

    expect(composing.defaultPrevented).toBe(false)
    expect(el("input").value).toBe("@an")
    expect(sent).toEqual([])
  })

  it("Escape dismisses the list for that word, is consumed, and typing on keeps it closed", () => {
    const above = []
    const listen = (event) => above.push(event.key)

    document.addEventListener("keydown", listen)
    type("@a")

    const escape = press("Escape")

    document.removeEventListener("keydown", listen)

    expect(escape.defaultPrevented).toBe(true)
    expect(above).toEqual([])
    expect(el("menu-0").hidden).toBe(true)

    type("@an")

    expect(el("menu-0").hidden).toBe(true)

    press("Enter")

    expect(sent).toEqual(["@an"])
  })

  it("a dismissed list comes back for a new word", () => {
    type("@a")
    press("Escape")
    type("@a and @")

    expect(el("menu-0").hidden).toBe(false)
  })

  it("Escape with no list open is left for the layer above", () => {
    type("plain text")

    const escape = press("Escape")

    expect(escape.defaultPrevented).toBe(false)
  })

  it("the caret leaving the word closes the list, and coming back opens it", () => {
    type("@an and more")

    expect(el("menu-0").hidden).toBe(true)

    el("input").setSelectionRange(3, 3)
    el("input").dispatchEvent(new MouseEvent("click", { bubbles: true }))

    expect(el("menu-0").hidden).toBe(false)
    expect(shown(0)).toEqual(["ana", "jordan", "dan"])
  })

  it("a selected range has no word, so no list", () => {
    type("@an")
    el("input").setSelectionRange(0, 3)
    el("input").dispatchEvent(new KeyboardEvent("keyup", { key: "a", bubbles: true }))

    expect(el("menu-0").hidden).toBe(true)
  })

  it("a list is open only while the field has focus", () => {
    type("@")
    el("input").dispatchEvent(new FocusEvent("blur"))

    expect(el("menu-0").hidden).toBe(true)
    expect(el("input").hasAttribute("aria-activedescendant")).toBe(false)
  })

  it("a press on the list does not take focus, and a click on an option chooses it", () => {
    type("@")

    const down = new Event("pointerdown", { bubbles: true, cancelable: true })

    el("composer-menu-0-option-2").dispatchEvent(down)

    expect(down.defaultPrevented).toBe(true)
    expect(el("input").value).toBe("@")

    el("composer-menu-0-option-2").querySelector("span").click()

    expect(el("input").value).toBe("@dan ")
    expect(document.activeElement).toBe(el("input"))
  })

  it("the highlight follows the pointer", () => {
    type("@")
    el("composer-menu-0-option-1").dispatchEvent(new Event("pointermove", { bubbles: true }))

    expect(highlighted(0)).toBe("ana")
    expect(el("input").getAttribute("aria-activedescendant")).toBe("composer-menu-0-option-1")
  })

  it("a menu that opens at the start answers only the message's first word", () => {
    type("/")

    expect(el("menu-1").hidden).toBe(false)

    type("see /")

    expect(el("menu-1").hidden).toBe(true)

    type("  /su")

    expect(shown(1)).toEqual(["summarize"])
  })

  it("an option's own text is what a text menu writes", () => {
    type("/su")
    press("Enter")

    expect(el("input").value).toBe("/summarize ")
    expect(chosen).toEqual([{ kind: "text", trigger: "/", value: "summarize", label: "summarize" }])
  })

  it("an option marked to run takes the typed word out and only reports", () => {
    type("/cl")
    press("Enter")

    expect(el("input").value).toBe("")
    expect(el("composer").hasAttribute("data-empty")).toBe(true)
    expect(chosen).toEqual([{ kind: "run", trigger: "/", value: "clear", label: "clear" }])
    expect(sent).toEqual([])
  })

  it("a chip menu takes the word out and adds a chip with the hidden field the server reads", () => {
    type("compare #q with last year", 10)
    press("Enter")

    expect(el("input").value).toBe("compare with last year")
    expect(el("input").selectionStart).toBe(8)
    const chip = el("chips").querySelector("[data-composer-chip]")
    const field = chip.querySelector("input[type=hidden]")

    expect(chip.querySelector("[data-slot=attachment-title]").textContent).toBe("Q3 plan.pdf")
    expect(chip.querySelector("[data-slot=attachment-media] svg")).not.toBeNull()
    expect([field.name, field.value]).toEqual(["context[]", "doc_1"])
    expect(field.form).toBe(el("form"))
    expect(chosen).toEqual([{ kind: "chip", trigger: "#", value: "doc_1", label: "Q3 plan.pdf" }])
  })

  it("a reference chosen twice is one chip", () => {
    type("#q")
    press("Enter")
    type("#q")
    press("Enter")

    expect(el("chips").querySelectorAll("[data-composer-chip]").length).toBe(1)
  })

  it("a chip's remove button takes the reference and its field out and returns focus to the field", async () => {
    type("#ro")
    press("Enter")
    // The cloned chip's action binds once Stimulus has seen the new node.
    await nextFrame()
    el("send").focus()
    el("chips").querySelector("button").click()

    expect(el("chips").children.length).toBe(0)
    expect(el("form").querySelector("input[type=hidden]")).toBeNull()
    expect(document.activeElement).toBe(el("input"))
  })

  it("chips alone are not a message", () => {
    type("#q")
    press("Enter")

    expect(el("composer").hasAttribute("data-empty")).toBe(true)

    press("Enter")

    expect(sent).toEqual([])
  })

  it("an accepted message takes its chips with it and keeps a chip added since", async () => {
    type("#q")
    press("Enter")
    type("compare these")
    press("Enter")

    expect(sent).toEqual(["compare these"])

    type("compare these #ro")
    press("Enter")
    el("form").dispatchEvent(new CustomEvent("turbo:submit-end", { bubbles: true, detail: { success: true } }))
    await nextFrame()

    expect(Array.from(el("chips").querySelectorAll("[data-composer-chip]")).map((chip) => chip.dataset.value)).toEqual(["doc_2"])
  })

  it("a refused message keeps its chips", async () => {
    type("#q")
    press("Enter")
    type("compare these")
    press("Enter")
    el("form").dispatchEvent(new CustomEvent("turbo:submit-end", { bubbles: true, detail: { success: false } }))
    await nextFrame()

    expect(el("chips").querySelectorAll("[data-composer-chip]").length).toBe(1)
  })

  it("the live region says how many suggestions there are when the number changes", async () => {
    type("@")

    await heard("3 suggestions")

    type("@ana")

    await heard("1 suggestion")
  })

  it("a burst of keystrokes is one announcement, and a list that closes first says nothing", async () => {
    const said = []
    const observer = new MutationObserver(() => {
      const text = live().replaceAll("|", "")

      if (text !== "" && said.at(-1) !== text) said.push(text)
    })

    observer.observe(document.body, { childList: true, characterData: true, subtree: true })
    type("@")
    type("@a")
    type("@ana")
    await heard("1 suggestion")
    type("#")
    press("Escape")
    await new Promise((resolve) => setTimeout(resolve, 400))
    observer.disconnect()

    expect(said).toEqual(["1 suggestion"])
  })

  it("the same number of suggestions is not said twice", async () => {
    type("@")
    await heard("3 suggestions")
    const region = Array.from(document.querySelectorAll("[aria-live]")).find((entry) => entry.textContent !== "")
    const writes = []
    const observer = new MutationObserver((records) => writes.push(...records))

    observer.observe(region, { childList: true, characterData: true, subtree: true })
    press("ArrowDown")
    el("input").dispatchEvent(new KeyboardEvent("keyup", { key: "ArrowDown", bubbles: true }))
    await new Promise((resolve) => setTimeout(resolve, 250))
    observer.disconnect()

    expect(writes).toEqual([])
  })

  it("a chip added and a chip removed are announced", async () => {
    type("#q")
    press("Enter")

    await heard("Q3 plan.pdf added")

    el("chips").querySelector("button").click()

    await heard("Q3 plan.pdf removed")
  })

  it("where the reader does not speak the active option, an arrow announces it", async () => {
    vi.stubGlobal("navigator", { platform: "MacIntel" })
    type("@")
    press("ArrowDown")

    await heard("Ana Diaz")
  })

  it("a morph leaves the chips' row alone, and morphs everything else", () => {
    const morphing = (target) => {
      const event = new CustomEvent("turbo:before-morph-element", { bubbles: true, cancelable: true })

      target.dispatchEvent(event)
      return event.defaultPrevented
    }

    type("#q")
    press("Enter")

    expect(morphing(el("chips"))).toBe(true)
    expect(morphing(el("chips").firstElementChild)).toBe(false)
    expect(morphing(el("input"))).toBe(false)
  })

  it("a morph that puts the server's render back is answered: the list, its filter and its highlight return", () => {
    // What a morph does to an open list: the server's attributes, which
    // show every option, highlight none and name none on the field.
    const morph = () => {
      el("menu-0").hidden = true
      for (const option of el("composer-menu-0").children) {
        option.hidden = false
        option.removeAttribute("data-highlighted")
        option.setAttribute("aria-selected", "false")
      }
      el("input").removeAttribute("aria-activedescendant")
      // Every morphed element reports, and the root reports last.
      el("input").dispatchEvent(new CustomEvent("turbo:morph-element", { bubbles: true }))
      el("composer").dispatchEvent(new CustomEvent("turbo:morph-element", { bubbles: true }))
    }

    type("@an")
    press("ArrowDown")

    expect(highlighted(0)).toBe("jordan")

    morph()

    expect(el("menu-0").hidden).toBe(false)
    expect(shown(0)).toEqual(["ana", "jordan", "dan"])
    expect(highlighted(0)).toBe("jordan")
    expect(el("input").getAttribute("aria-activedescendant")).toBe(el("composer-menu-0").querySelector("[data-highlighted]").id)

    press("Escape")
    morph()

    expect(el("menu-0").hidden).toBe(true)
    expect(el("input").hasAttribute("aria-activedescendant")).toBe(false)
  })

  it("leaving the page closes an open list", async () => {
    type("@")
    const input = el("input")
    const menu = el("menu-0")

    el("composer").remove()
    await nextFrame()

    expect(menu.hidden).toBe(true)
    expect(input.hasAttribute("aria-activedescendant")).toBe(false)
  })
})
