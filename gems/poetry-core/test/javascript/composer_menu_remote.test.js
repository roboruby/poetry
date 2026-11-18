import { afterEach, beforeEach, describe, expect, it, vi } from "vitest"
import { Application } from "@hotwired/stimulus"
import { registerPoetryControllers } from "@poetry/controllers"

// The Composer's server-fed menus: a menu with data-src asks the server
// about the word being typed once typing has paused, by pointing its
// listbox (a Turbo frame) at the address; the answer is shown as it
// came; a longer word narrows it here until the server answers again;
// a word the answer cannot cover shows nothing; and an answer that
// fails never reaches Turbo. Turbo is not loaded here: the tests read
// the address the frame is pointed at and play the server's part.

const nextFrame = () => new Promise((resolve) => setTimeout(resolve, 0))

const COMPOSER = "poetry--core--composer"
const MENU = "poetry--core--composer-menu"
const DEBOUNCE = 150

const el = (id) => document.getElementById(id)

const option = (index, { value, label, keywords = "" }) => `
  <div role="option" id="composer-menu-0-option-${index}" aria-selected="false" data-value="${value}"
       data-label="${label}" data-filter-value="${label}" data-keywords="${value} ${keywords}"><span>${label}</span></div>`

const options = (people) => people.map((person, index) => option(index, person)).join("")

const ROSA = { value: "rosa", label: "Rosa Park" }
const ROB = { value: "rob", label: "Rob Lin" }
const ROBIN = { value: "robin", label: "Robin Vale" }
// Matched by the server on something the page never sees (an email).
const SAM = { value: "sam", label: "Sam Diaz" }

const markup = ({ src = "/people", param = "q", initial = null } = {}) => `
  <div id="composer" data-controller="${MENU} ${COMPOSER}" data-empty
       data-${MENU}-messages-value='{"one":"1 suggestion","other":"{count} suggestions"}'
       data-action="poetry:composer:sent->${MENU}#sent turbo:morph-element->${MENU}#restore">
    <div id="menu-0" hidden data-closed data-${MENU}-target="menu" data-trigger="@" data-inserts="text" data-at="word"
         data-src="${src}" data-param="${param}"
         data-action="pointerdown->${MENU}#hold click->${MENU}#pick pointermove->${MENU}#point turbo:frame-load->${MENU}#loaded turbo:before-fetch-response->${MENU}#answered turbo:frame-missing->${MENU}#failed turbo:fetch-request-error->${MENU}#failed">
      <turbo-frame role="listbox" id="composer-menu-0" aria-label="People" ${initial ? `data-query=""` : ""}>${initial ? options(initial) : ""}</turbo-frame>
    </div>
    <form id="form" action="/messages" method="post" data-${COMPOSER}-target="form"
          data-action="submit->${COMPOSER}#guard turbo:submit-end->${COMPOSER}#settle">
      <textarea id="input" name="content" aria-autocomplete="list" aria-controls="composer-menu-0"
                data-${MENU}-target="input" data-${COMPOSER}-target="input"
                data-action="keydown->${MENU}#keydown input->${MENU}#track keyup->${MENU}#track click->${MENU}#track focus->${MENU}#track blur->${MENU}#blurred keydown->${COMPOSER}#keydown input->${COMPOSER}#changed"></textarea>
      <button id="send" type="submit" data-${COMPOSER}-target="send">Send</button>
    </form>
  </div>`

const type = (text, caret = text.length) => {
  const field = el("input")

  field.value = text
  field.setSelectionRange(caret, caret)
  field.dispatchEvent(new Event("input", { bubbles: true }))
}

const press = (key) => {
  const event = new KeyboardEvent("keydown", { key, bubbles: true, cancelable: true })

  el("input").dispatchEvent(event)
  return event
}

const frame = () => el("composer-menu-0")
const pause = () => vi.advanceTimersByTime(DEBOUNCE)

// The address the frame is pointed at, as a path and a query.
const asked = () => {
  const src = frame().getAttribute("src")

  if (!src) return null

  const url = new URL(src)

  return `${url.pathname}${url.search}`
}

// The server's part: the frame's content is replaced and Turbo reports the load.
const answer = (people) => {
  frame().innerHTML = options(people)
  frame().dispatchEvent(new CustomEvent("turbo:frame-load", { bubbles: true }))
}

const shown = () => Array.from(frame().querySelectorAll("[role=option]"))
  .filter((entry) => !entry.hidden).map((entry) => entry.dataset.value)

const highlighted = () => frame().querySelector("[data-highlighted]")?.dataset.value ?? null

const open = () => !el("menu-0").hidden

describe("poetry--core--composer-menu, fed by the server", () => {
  let application

  const mount = async (config) => {
    document.body.innerHTML = `<div id="host"></div>`
    application = Application.start()
    registerPoetryControllers(application)
    await nextFrame()
    el("host").innerHTML = markup(config)
    await nextFrame()
    el("input").focus()
    // Faked once Stimulus has booted: its start rides real timers.
    vi.useFakeTimers()
  }

  beforeEach(() => mount())

  afterEach(async () => {
    vi.useRealTimers()
    el("host")?.replaceChildren()
    await nextFrame()
    application.stop()
  })

  it("asks about the word once typing has paused, and shows nothing until the server answers", () => {
    type("@")
    vi.advanceTimersByTime(DEBOUNCE - 1)

    expect(asked()).toBeNull()
    expect(open()).toBe(false)

    vi.advanceTimersByTime(1)

    expect(asked()).toBe("/people?q=")
    expect(open()).toBe(false)
  })

  it("the menu is marked loading from the first key to the answer, across a newer word", () => {
    const loading = () => el("menu-0").hasAttribute("data-loading")

    expect(loading()).toBe(false)

    type("@r")

    expect(loading()).toBe(true)

    pause()
    type("@ro")
    answer([ROSA, ROB])

    expect(loading()).toBe(true)

    pause()
    answer([ROSA, ROB])

    expect(loading()).toBe(false)
  })

  it("the mark goes when the word goes, when the list is dismissed and when the server fails", () => {
    const loading = () => el("menu-0").hasAttribute("data-loading")

    type("@r")
    type("@r ")

    expect(loading()).toBe(false)

    type("@ro")
    pause()
    frame().dispatchEvent(new CustomEvent("turbo:fetch-request-error", { bubbles: true }))

    expect(loading()).toBe(false)

    type("@rob")
    el("input").blur()

    expect(loading()).toBe(false)
  })

  it("asks once for a burst of keys, about the word the burst ended on", () => {
    const pointed = vi.spyOn(frame(), "setAttribute")

    type("@r")
    vi.advanceTimersByTime(60)
    type("@ro")
    vi.advanceTimersByTime(60)
    type("@ros")
    pause()

    expect(pointed.mock.calls.filter(([name]) => name === "src")).toHaveLength(1)
    expect(asked()).toBe("/people?q=ros")
  })

  it("shows the answer as it came: the server's matches, in the server's order", () => {
    type("@ro")
    pause()
    answer([SAM, ROB, ROSA])

    expect(open()).toBe(true)
    expect(shown()).toEqual(["sam", "rob", "rosa"])
    expect(highlighted()).toBe("sam")
    expect(frame().getAttribute("data-query")).toBe("ro")
    expect(el("input").getAttribute("aria-activedescendant")).toBe("composer-menu-0-option-0")
  })

  it("narrows the answer here for a longer word, in the server's order, and asks again", () => {
    type("@r")
    pause()
    answer([ROSA, SAM, ROBIN, ROB])
    type("@rob")

    expect(shown()).toEqual(["robin", "rob"])
    expect(highlighted()).toBe("robin")
    expect(asked()).toBe("/people?q=r")

    pause()

    expect(asked()).toBe("/people?q=rob")

    answer([ROB, ROBIN])

    expect(shown()).toEqual(["rob", "robin"])
    expect(frame().getAttribute("data-query")).toBe("rob")
  })

  it("has nothing to show for a word the answer cannot cover, until the server answers it", () => {
    type("@ro")
    pause()
    answer([ROSA, ROB])
    type("@r")

    expect(open()).toBe(false)

    pause()
    answer([ROSA, ROB, SAM])

    expect(open()).toBe(true)
    expect(shown()).toEqual(["rosa", "rob", "sam"])
  })

  it("an answer with no options closes the list", () => {
    type("@ro")
    pause()
    answer([ROSA])

    expect(open()).toBe(true)

    type("@rosz")
    pause()
    answer([])

    expect(open()).toBe(false)
    expect(el("input").hasAttribute("aria-activedescendant")).toBe(false)
  })

  it("the word a list is stamped with is answered from the page, with no request", () => {
    const reload = vi.fn()

    type("@ro")
    pause()
    answer([ROSA, ROB])
    frame().reload = reload
    type("hello")
    type("hello @ro")
    pause()

    expect(open()).toBe(true)
    expect(shown()).toEqual(["rosa", "rob"])
    expect(asked()).toBe("/people?q=ro")
    expect(reload).not.toHaveBeenCalled()
  })

  it("an answer for a word the reader has left opens nothing, and is kept", () => {
    type("@ro")
    pause()
    type("@ro and more")
    answer([ROSA, ROB])

    expect(open()).toBe(false)
    expect(frame().getAttribute("data-query")).toBe("ro")
  })

  it("an answer that lands after the field lost focus opens nothing", () => {
    type("@ro")
    pause()
    el("input").blur()
    answer([ROSA])

    expect(open()).toBe(false)
  })

  it("a word that goes away before the pause is never asked about", () => {
    type("@ro")
    vi.advanceTimersByTime(60)
    type("@ro ")
    pause()

    expect(asked()).toBeNull()
  })

  it("Escape drops the request that was waiting, and the list stays closed for the word", () => {
    type("@r")
    pause()
    answer([ROSA, ROB])
    type("@ro")
    press("Escape")
    pause()

    expect(asked()).toBe("/people?q=r")
    expect(open()).toBe(false)
  })

  it("Enter chooses from the server's answer", () => {
    type("ask @ro")
    pause()
    answer([ROSA, ROB])
    press("ArrowDown")

    const enter = press("Enter")

    expect(enter.defaultPrevented).toBe(true)
    expect(el("input").value).toBe("ask @rob ")
    expect(open()).toBe(false)
  })

  it("a new answer keeps the highlight on the person it was on", () => {
    type("@r")
    pause()
    answer([ROSA, ROB, SAM])
    type("@ro")
    press("ArrowDown")

    expect(highlighted()).toBe("rob")

    pause()
    answer([ROBIN, ROSA, ROB])

    expect(shown()).toEqual(["robin", "rosa", "rob"])
    expect(highlighted()).toBe("rob")
    expect(el("input").getAttribute("aria-activedescendant")).toBe("composer-menu-0-option-2")
  })

  it("a new answer without that person starts again at the top", () => {
    type("@r")
    pause()
    answer([ROSA, ROB])
    type("@ro")
    press("ArrowDown")
    pause()
    answer([ROBIN, ROSA])

    expect(highlighted()).toBe("robin")
  })

  it("an error answer is kept from Turbo, and the word is not asked about again until it changes", () => {
    const reload = vi.fn()
    const response = (succeeded) => {
      const event = new CustomEvent("turbo:before-fetch-response", {
        bubbles: true, cancelable: true, detail: { fetchResponse: { succeeded } }
      })

      frame().dispatchEvent(event)
      return event.defaultPrevented
    }

    frame().reload = reload
    type("@ro")
    pause()

    expect(response(true)).toBe(false)
    expect(response(false)).toBe(true)

    el("input").dispatchEvent(new Event("keyup", { bubbles: true }))
    pause()

    expect(reload).not.toHaveBeenCalled()

    type("@rob")
    pause()

    expect(asked()).toBe("/people?q=rob")

    type("@ro")
    pause()

    expect(asked()).toBe("/people?q=ro")
  })

  it("an answer without the list's frame, or no answer, is kept from Turbo too", () => {
    const report = (name) => {
      const event = new CustomEvent(name, { bubbles: true, cancelable: true })

      frame().dispatchEvent(event)
      return event.defaultPrevented
    }

    type("@ro")
    pause()

    expect(report("turbo:frame-missing")).toBe(true)
    expect(report("turbo:fetch-request-error")).toBe(false)
    expect(open()).toBe(false)
  })

  it("a failure reported by a frame that is not the list is left alone", () => {
    type("@ro")
    pause()
    answer([ROSA])

    const inner = document.createElement("turbo-frame")
    const event = new CustomEvent("turbo:frame-missing", { bubbles: true, cancelable: true })

    frame().firstElementChild.append(inner)
    inner.dispatchEvent(event)

    expect(event.defaultPrevented).toBe(false)
  })

  it("a morph puts the server's render back, and the word is asked about again", () => {
    const reload = vi.fn()

    type("@ro")
    pause()
    answer([ROSA, ROB])
    frame().reload = reload

    // What a morph does: the server's content and attributes, which
    // carry no stamp, and a closed list.
    frame().replaceChildren()
    frame().removeAttribute("data-query")
    el("menu-0").hidden = true
    el("composer").dispatchEvent(new CustomEvent("turbo:morph-element", { bubbles: true }))

    expect(open()).toBe(false)

    pause()

    expect(reload).toHaveBeenCalledTimes(1)

    answer([ROSA, ROB])

    expect(open()).toBe(true)
    expect(shown()).toEqual(["rosa", "rob"])
  })

  it("leaving the page drops a request that was waiting", async () => {
    type("@ro")

    const list = frame()

    vi.useRealTimers()
    el("composer").remove()
    await new Promise((resolve) => setTimeout(resolve, DEBOUNCE + 30))

    expect(list.hasAttribute("src")).toBe(false)
  })

  describe("with options rendered in the page", () => {
    beforeEach(async () => {
      vi.useRealTimers()
      el("host").replaceChildren()
      await nextFrame()
      application.stop()
      await mount({ initial: [ROSA, SAM] })
    })

    it("the bare trigger shows them at once and asks nothing", () => {
      type("@")
      pause()

      expect(open()).toBe(true)
      expect(shown()).toEqual(["rosa", "sam"])
      expect(asked()).toBeNull()
    })

    it("a word narrows them at once and asks the server", () => {
      type("@ro")

      expect(shown()).toEqual(["rosa"])

      pause()

      expect(asked()).toBe("/people?q=ro")
    })
  })

  describe("with an address that has a query of its own and another param", () => {
    beforeEach(async () => {
      vi.useRealTimers()
      el("host").replaceChildren()
      await nextFrame()
      application.stop()
      await mount({ src: "/people?team=7", param: "term" })
    })

    it("keeps the address's query and adds the word under the param", () => {
      type("@ro")
      pause()

      expect(asked()).toBe("/people?team=7&term=ro")
    })
  })
})
