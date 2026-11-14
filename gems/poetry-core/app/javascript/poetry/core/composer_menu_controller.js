import { Controller } from "@hotwired/stimulus"
import { useAnnounce } from "@poetry/controllers/behaviors/announce"
import { useTimeout } from "@poetry/controllers/behaviors/interval"
import { isImeKeydown } from "@poetry/controllers/helpers/escape"
import { scoreItem, SCORE_HIDDEN } from "@poetry/controllers/helpers/filter_rank"
import { teardown } from "@poetry/controllers/helpers/scope"

const EVENT_PREFIX = "poetry:composer-menu"
const OPTION = "[role=option]"
const SPACE = /\s/
// The count is said once a burst of keystrokes has settled, not per key.
const STATUS_DEBOUNCE = 100

// VoiceOver does not speak the option aria-activedescendant names while
// focus stays in a text field, so there the option is announced as well.
const speaksOptions = () => !/Mac|iP(hone|ad|od)/.test(navigator.userAgentData?.platform ?? navigator.platform ?? "")

/**
 * The Composer's menus: lists the server rendered that open over the
 * composer while the word at the caret starts with a menu's trigger
 * ("@", "/"), filter as the word grows, and put the chosen option into
 * the message. The field stays a plain textarea and keeps focus
 * throughout: the open list is named by aria-controls, the highlighted
 * option by aria-activedescendant, and a live region says how many
 * suggestions there are, because a textarea takes no expanded state.
 *
 * What a choice does is the menu's to say. A text menu replaces the
 * typed word with the option's text ("@ana "). A chip menu takes the
 * typed word out and adds a chip beside the field with a hidden field
 * for the server, so the reference is context for the whole message
 * and never syntax inside it. An option marked to run takes the typed
 * word out and only reports the choice. Every choice is reported with
 * the choose event.
 *
 * Arrow keys move the highlight, Enter and Tab choose, and Escape
 * closes the list for the word being typed: it stays closed until the
 * caret leaves that word. A key this controller takes is claimed
 * (preventDefault), which is how the composer controller beside it
 * knows an Enter was a choice and not a send.
 */
export default class ComposerMenuController extends Controller {
  // The events this controller dispatches (manifest surface;
  // events_declaration.test.js enforces the list stays honest).
  static events = ["poetry:composer-menu:choose"]

  static targets = ["input", "menu", "chips", "template"]

  static values = {
    // What the live region says: one and other with a {count} token for
    // the suggestions, added and removed with a {label} token for a chip.
    messages: { type: Object, default: {} }
  }

  #active = null
  #dismissed = null
  #announce = null
  #count = -1
  #pending = null
  #marked = null

  /** Takes the announcement surface for this connect. */
  connect() {
    this.#announce = useAnnounce(this)
  }

  /** Closes an open list so its state never outlives the controller. */
  disconnect() {
    this.#close()
    teardown(this)
    this.#announce = null
  }

  /**
   * The field's input, keyup, click and focus action: reads the word at
   * the caret and opens, filters or closes the list it calls for. A
   * word whose list was dismissed stays without one.
   *
   * @param {Event} [event]
   */
  track(event) {
    // A composition's partial text is not a query yet; compositionend's
    // input event follows with the finished text.
    if (event?.isComposing) return

    const context = this.#context()

    if (!context) {
      this.#dismissed = null
      this.#close()
      return
    }
    if (this.#dismissed === context.start) {
      this.#close()
      return
    }
    this.#dismissed = null
    if (this.#same(context)) return

    const shown = this.#filter(context.menu, context.query)

    if (shown.length === 0) {
      this.#close()
      return
    }
    this.#open(context, shown)
  }

  /**
   * The field's keydown action, ahead of the composer's own: while a
   * list is open the arrows move its highlight, Enter and Tab choose
   * the highlighted option and Escape dismisses the list. Each of those
   * keys is claimed. Keys held with a modifier, and keys that belong to
   * an input-method composition, are left alone.
   *
   * @param {KeyboardEvent} event
   */
  keydown(event) {
    if (!this.#active || isImeKeydown(event)) return
    if (event.shiftKey || event.altKey || event.metaKey || event.ctrlKey) return

    switch (event.key) {
      case "ArrowDown":
      case "ArrowUp":
        event.preventDefault()
        this.#move(event.key === "ArrowDown" ? 1 : -1)
        break
      case "Enter":
      case "Tab": {
        const option = this.#highlighted()

        if (!option) return
        event.preventDefault()
        this.#choose(option)
        break
      }
      case "Escape":
        event.preventDefault()
        // Consumed: this press closes the list; the next reaches the layer above.
        event.stopPropagation()
        this.#dismissed = this.#active.start
        this.#close()
        break
    }
  }

  /**
   * A list's pointerdown action: a press never takes focus from the
   * field, so the list stays open under it and the on-screen keyboard
   * stays up.
   *
   * @param {PointerEvent} event
   */
  hold(event) {
    event.preventDefault()
  }

  /**
   * A list's click action: chooses the option under it. A click and not
   * a press, so a finger that scrolls the list chooses nothing.
   *
   * @param {MouseEvent} event
   */
  pick(event) {
    const option = event.target.closest?.(OPTION)

    if (option && this.#active?.menu.contains(option)) this.#choose(option)
  }

  /**
   * A list's pointermove action: the highlight follows the pointer.
   *
   * @param {PointerEvent} event
   */
  point(event) {
    const option = event.target.closest?.(OPTION)

    if (option && option !== this.#highlighted() && this.#active?.menu.contains(option)) this.#highlight(option, false)
  }

  /** The field's blur action: a list is open only while the field has focus. */
  blurred() {
    this.#close()
  }

  /**
   * The chips' row's turbo:before-morph-element action: the chips and
   * their hidden fields are the client's, and the server renders the
   * row empty. A morph that reached it would drop what the reader chose,
   * so the row is left as it is.
   *
   * @param {CustomEvent} event - cancelled when the row itself is about to be morphed
   */
  keep(event) {
    if (event.target === event.currentTarget) event.preventDefault()
  }

  /**
   * The root's turbo:morph-element action: a morph puts the server's
   * render back on the options and the field, which highlights nothing
   * and names no option, while the reader is still on the same word.
   * Once the whole composer has been morphed the open list is filtered
   * again and the highlight returns to the option it was on.
   *
   * @param {CustomEvent} event - acted on when it is the root's own
   */
  restore(event) {
    const context = this.#active

    if (event.target !== this.element || !context) return

    const shown = this.#filter(context.menu, context.query)

    if (shown.length === 0) {
      this.#close()
      return
    }
    this.#show(context.menu)
    this.#highlight(shown.find((option) => option.id === this.#marked) ?? shown[0], false)
  }

  /**
   * A chip's remove action: the reference and its hidden field leave
   * the message, and focus goes to the field.
   *
   * @param {MouseEvent} event
   */
  remove(event) {
    const chip = event.currentTarget.closest("[data-composer-chip]")

    if (!chip) return
    this.#say("removed", { label: chip.getAttribute("data-label") ?? "" })
    chip.remove()
    this.inputTarget.focus()
  }

  /**
   * The composer's sent action: the chips that went with an accepted
   * message leave, and a chip added since stays.
   *
   * @param {CustomEvent} event - detail.fields holds the per-message fields that were sent
   */
  sent(event) {
    const fields = event.detail?.fields ?? []

    for (const chip of this.#chips()) {
      if (fields.some((field) => chip.contains(field))) chip.remove()
    }
  }

  /**
   * The word at the caret, when it starts with a menu's trigger: the
   * menu, where the word starts and what follows the trigger. A range
   * selection has no such word.
   *
   * @returns {{ menu: Element, start: number, query: string } | null}
   */
  #context() {
    const field = this.inputTarget

    if (field.selectionStart !== field.selectionEnd) return null

    const before = field.value.slice(0, field.selectionStart)
    let start = before.length

    while (start > 0 && !SPACE.test(before[start - 1])) start -= 1

    const word = before.slice(start)

    for (const menu of this.menuTargets) {
      const trigger = menu.getAttribute("data-trigger") ?? ""

      if (trigger === "" || !word.startsWith(trigger)) continue
      // A menu that opens only on the message's first word (commands).
      if (menu.getAttribute("data-at") === "start" && before.slice(0, start).trim() !== "") continue

      return { menu, start, query: word.slice(trigger.length) }
    }

    return null
  }

  /**
   * Whether the open list already answers this word.
   *
   * @param {{ menu: Element, start: number, query: string }} context
   * @returns {boolean}
   */
  #same(context) {
    const active = this.#active

    return Boolean(active) && active.menu === context.menu && active.start === context.start &&
      active.query === context.query
  }

  /**
   * Shows the options that match the query, best first, and hides the
   * rest.
   *
   * @param {Element} menu
   * @param {string} query
   * @returns {Element[]} the options shown, in order
   */
  #filter(menu, query) {
    const list = menu.querySelector("[role=listbox]") ?? menu
    const scored = Array.from(menu.querySelectorAll(OPTION)).map((option, index) => ({
      option, index, score: scoreItem(option, query)
    }))
    const shown = scored.filter((entry) => entry.score !== SCORE_HIDDEN)
      .sort((a, b) => b.score - a.score || a.index - b.index)

    for (const entry of scored) entry.option.hidden = entry.score === SCORE_HIDDEN
    // Best first: the option Enter would choose is the closest match.
    for (const entry of shown) list.append(entry.option)
    list.scrollTop = 0

    return shown.map((entry) => entry.option)
  }

  /**
   * Opens the context's list on its first option and says how many
   * suggestions it holds when that number changed.
   *
   * @param {{ menu: Element, start: number, query: string }} context
   * @param {Element[]} shown
   */
  #open(context, shown) {
    for (const menu of this.menuTargets) {
      if (menu !== context.menu) this.#hide(menu)
    }
    this.#active = context
    this.#show(context.menu)
    this.#highlight(shown[0], false)
    this.#tell(shown.length)
  }

  /**
   * Shows one list.
   *
   * @param {Element} menu
   */
  #show(menu) {
    menu.hidden = false
    menu.setAttribute("data-open", "")
    menu.removeAttribute("data-closed")
  }

  /**
   * Says how many suggestions there are, once typing has paused, and
   * only when the number is not the one last said for this list.
   *
   * @param {number} count
   */
  #tell(count) {
    if (count === this.#count) return

    this.#count = count
    this.#pending?.()
    this.#pending = useTimeout(this, () => {
      this.#pending = null
      this.#say(count === 1 ? "one" : "other", { count: String(count) })
    }, STATUS_DEBOUNCE)
  }

  /** Closes whichever list is open and clears the highlight. */
  #close() {
    if (this.hasInputTarget) this.inputTarget.removeAttribute("aria-activedescendant")
    for (const menu of this.menuTargets) this.#hide(menu)
    this.#active = null
    this.#marked = null
    this.#count = -1
    // A count still waiting to be said is for a list that is gone.
    this.#pending?.()
    this.#pending = null
  }

  /**
   * Hides one list and drops its highlight.
   *
   * @param {Element} menu
   */
  #hide(menu) {
    menu.hidden = true
    menu.removeAttribute("data-open")
    menu.setAttribute("data-closed", "")
    for (const option of menu.querySelectorAll(`${OPTION}[data-highlighted]`)) this.#dim(option)
  }

  /**
   * The open list's highlighted option.
   *
   * @returns {Element | null}
   */
  #highlighted() {
    return this.#active?.menu.querySelector(`${OPTION}[data-highlighted]`) ?? null
  }

  /**
   * The open list's shown options, in order.
   *
   * @returns {Element[]}
   */
  #shown() {
    return Array.from(this.#active?.menu.querySelectorAll(OPTION) ?? []).filter((option) => !option.hidden)
  }

  /**
   * Moves the highlight one option on, wrapping at either end.
   *
   * @param {number} step - 1 or -1
   */
  #move(step) {
    const shown = this.#shown()

    if (shown.length === 0) return

    const index = shown.indexOf(this.#highlighted())

    this.#highlight(shown[(index + step + shown.length) % shown.length], true)
  }

  /**
   * Highlights one option and names it on the field.
   *
   * @param {Element} option
   * @param {boolean} spoken - whether a reader that does not speak the active option is told
   */
  #highlight(option, spoken) {
    const current = this.#highlighted()

    if (current && current !== option) this.#dim(current)
    option.setAttribute("data-highlighted", "")
    option.setAttribute("aria-selected", "true")
    this.#marked = option.id
    this.inputTarget.setAttribute("aria-activedescendant", option.id)
    option.scrollIntoView?.({ block: "nearest" })
    if (spoken && !speaksOptions()) this.#announce?.(option.getAttribute("data-label") ?? option.textContent.trim())
  }

  /**
   * Takes the highlight off one option.
   *
   * @param {Element} option
   */
  #dim(option) {
    option.removeAttribute("data-highlighted")
    option.setAttribute("aria-selected", "false")
  }

  /**
   * Puts the option into the message the way its menu says, closes the
   * list and reports the choice.
   *
   * @param {Element} option
   */
  #choose(option) {
    const { menu, start } = this.#active
    const field = this.inputTarget
    const trigger = menu.getAttribute("data-trigger") ?? ""
    const value = option.getAttribute("data-value") ?? ""
    const label = option.getAttribute("data-label") ?? option.textContent.trim()
    const kind = option.hasAttribute("data-run") ? "run" : (menu.getAttribute("data-inserts") === "chip" ? "chip" : "text")
    const text = kind === "text" ? (option.getAttribute("data-insert") ?? `${trigger}${value} `) : ""
    let end = field.selectionStart

    // A word taken out from between two spaces takes one of them along.
    if (text === "" && SPACE.test(field.value[end] ?? "") && (start === 0 || SPACE.test(field.value[start - 1]))) end += 1
    this.#close()
    field.setRangeText(text, start, end, "end")
    // A REAL input event: the composer's emptiness and a host's own
    // listeners react to the change exactly like typing.
    field.dispatchEvent(new Event("input", { bubbles: true }))
    if (kind === "chip") this.#add(menu, option, value, label)
    this.dispatch("choose", { prefix: EVENT_PREFIX, detail: { kind, trigger, value, label } })
  }

  /**
   * Adds the chip for a chosen reference, with the hidden field the
   * server reads; a reference already there is not added twice.
   *
   * @param {Element} menu
   * @param {Element} option
   * @param {string} value
   * @param {string} label
   */
  #add(menu, option, value, label) {
    if (!this.hasChipsTarget || !this.hasTemplateTarget) return

    const name = menu.getAttribute("data-name") ?? ""

    if (this.#chips().some((chip) => chip.getAttribute("data-name") === name && chip.getAttribute("data-value") === value)) return

    const chip = this.templateTarget.content.firstElementChild?.cloneNode(true)

    if (!chip) return

    const title = chip.querySelector("[data-slot=attachment-title]")
    const media = chip.querySelector("[data-slot=attachment-media]")
    const icon = option.querySelector("svg")
    const field = document.createElement("input")

    chip.setAttribute("data-composer-chip", "")
    chip.setAttribute("data-name", name)
    chip.setAttribute("data-value", value)
    chip.setAttribute("data-label", label)
    // textContent, never innerHTML: the label is the host's data.
    if (title) title.textContent = label
    if (media && icon) media.replaceChildren(icon.cloneNode(true))
    field.type = "hidden"
    field.name = name
    field.value = value
    field.setAttribute("data-composer-field", "")
    chip.append(field)
    this.chipsTarget.append(chip)
    this.#say("added", { label })
  }

  /**
   * The reference chips in the message.
   *
   * @returns {Element[]}
   */
  #chips() {
    return this.hasChipsTarget ? Array.from(this.chipsTarget.querySelectorAll("[data-composer-chip]")) : []
  }

  /**
   * Announces one of the messages with its tokens filled.
   *
   * @param {string} key - one, other, added or removed
   * @param {Object<string, string>} tokens
   */
  #say(key, tokens) {
    const template = this.messagesValue[key]

    if (!template) return
    this.#announce?.(template.replace(/\{(\w+)\}/g, (match, token) => (token in tokens ? tokens[token] : match)))
  }
}
