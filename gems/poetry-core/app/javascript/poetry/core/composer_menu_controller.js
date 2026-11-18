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
// A server-fed menu asks about a word once typing has paused.
const FETCH_DEBOUNCE = 150

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
 * A menu with data-src is fed by the server. Its listbox is a Turbo
 * frame, and the word being typed is asked about at that address
 * (?q=word, under the menu's data-param) once typing has paused. What
 * the server answers is shown as it came: the server decides what
 * matches and in what order. The frame is stamped with the word its
 * options answer (data-query), so a longer word narrows them here at
 * once while the server is asked again, and a word they cannot answer
 * shows no list until the server has. The menu carries data-loading
 * from the moment a word is to be asked about until its answer lands.
 * An answer that is an error, or that holds no such frame, leaves the
 * list as it was: Turbo is kept from writing its own message into the
 * list, and from making a page visit of an error page that asks for
 * one, as Rails' own does in development.
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
  #markedValue = null
  #remote = new Map()

  /** Takes the announcement surface for this connect. */
  connect() {
    this.#announce = useAnnounce(this)
  }

  /** Closes an open list so its state never outlives the controller. */
  disconnect() {
    this.#rest()
    this.#close()
    teardown(this)
    this.#remote.clear()
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
      this.#rest()
      this.#close()
      return
    }
    if (this.#dismissed === context.start) {
      this.#rest()
      this.#close()
      return
    }
    this.#dismissed = null
    if (this.#same(context)) return

    this.#present(context)
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
        this.#rest()
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
    this.#rest()
    this.#close()
  }

  /**
   * A server-fed list's turbo:frame-load action: the server's options
   * for the word last asked about are in the list. The list is stamped
   * with that word, and when the reader is still on a word it answers
   * the list opens on the new options, with the highlight on the option
   * it was on when that option is still among them.
   *
   * @param {CustomEvent} event - dispatched by the menu's own listbox frame
   */
  loaded(event) {
    const menu = this.#fed(event.target)

    if (!menu) return

    const state = this.#state(menu)

    event.target.setAttribute("data-query", state.sent ?? "")
    if (state.wanted === state.sent) state.wanted = null
    // A newer word may be waiting its turn: the menu is loading until that one lands.
    if (state.wanted === null) menu.removeAttribute("data-loading")
    this.#refresh(menu)
  }

  /**
   * A server-fed list's turbo:before-fetch-response action: an answer
   * that is an error is not handed to Turbo. Rails' exception page in
   * development asks Turbo for a full page visit, which would take the
   * draft along; any other error page would be written over the
   * options. The list stays as it was.
   *
   * @param {CustomEvent} event - detail.fetchResponse is the answer
   */
  answered(event) {
    if (event.detail?.fetchResponse?.succeeded !== false) return

    const menu = this.#fed(event.target)

    if (!menu) return
    event.preventDefault()
    this.#fail(menu)
  }

  /**
   * A server-fed list's turbo:frame-missing and turbo:fetch-request-error
   * action: an answer without the list's frame, or no answer at all. A
   * missing frame is not handed to Turbo either, which would write
   * "Content missing" where the options go. The list stays as it was,
   * and the same word is not asked about again until the word changes.
   *
   * @param {CustomEvent} event
   */
  failed(event) {
    const menu = this.#fed(event.target)

    if (!menu) return
    if (event.type === "turbo:frame-missing") event.preventDefault()
    this.#fail(menu)
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
    if (event.target !== this.element) return

    // The server's render is back on every list, with its own stamp: a
    // request made for the render before it answers nothing here.
    for (const [menu, state] of this.#remote) {
      state.cancel?.()
      Object.assign(state, { cancel: null, wanted: null, sent: null, failed: null })
      menu.removeAttribute("data-loading")
    }

    const context = this.#active

    if (!context) {
      // A word still waiting on the server is asked about again.
      if (document.activeElement === this.inputTarget) this.track()
      return
    }

    const shown = this.#options(context)

    if (shown.length === 0) {
      this.#close()
      return
    }
    this.#show(context.menu)
    this.#highlight(this.#again(context.menu, shown) ?? shown[0], false)
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
   * Opens the context's list on the options that answer its word, or
   * closes whichever list is open when there are none.
   *
   * @param {{ menu: Element, start: number, query: string }} context
   */
  #present(context) {
    const shown = this.#options(context)

    if (shown.length === 0) {
      this.#close()
      return
    }
    this.#open(context, shown)
  }

  /**
   * The options that answer the context's word, shown and in order. A
   * menu the server rendered whole is filtered and ranked here. A
   * server-fed menu shows what the server answered for this word as it
   * came, narrows what it answered for a shorter word until it answers
   * again, and has nothing to show for a word its options cannot
   * answer. Any word but the one the list is stamped with is asked
   * about.
   *
   * @param {{ menu: Element, query: string }} context
   * @returns {Element[]}
   */
  #options({ menu, query }) {
    const frame = this.#frame(menu)

    if (!frame) return this.#filter(menu, query, true)

    const loaded = frame.getAttribute("data-query")

    if (loaded !== query) this.#request(menu, frame, query)
    if (loaded === null || !query.startsWith(loaded)) return []

    return this.#filter(menu, loaded === query ? "" : query, false)
  }

  /**
   * Shows the options that match the query and hides the rest. Ranked,
   * the shown options are moved best first; unranked, they keep the
   * order the server gave them.
   *
   * @param {Element} menu
   * @param {string} query
   * @param {boolean} ranked
   * @returns {Element[]} the options shown, in order
   */
  #filter(menu, query, ranked) {
    const list = menu.querySelector("[role=listbox]") ?? menu
    const scored = Array.from(menu.querySelectorAll(OPTION)).map((option, index) => ({
      option, index, score: scoreItem(option, query)
    }))
    const shown = scored.filter((entry) => entry.score !== SCORE_HIDDEN)

    if (ranked) shown.sort((a, b) => b.score - a.score || a.index - b.index)
    for (const entry of scored) entry.option.hidden = entry.score === SCORE_HIDDEN
    // Best first: the option Enter would choose is the closest match.
    if (ranked) for (const entry of shown) list.append(entry.option)
    list.scrollTop = 0

    return shown.map((entry) => entry.option)
  }

  /**
   * A server-fed menu's listbox frame; null for a menu the server
   * rendered whole.
   *
   * @param {Element} menu
   * @returns {Element | null}
   */
  #frame(menu) {
    return menu.hasAttribute("data-src") ? menu.querySelector("[role=listbox]") : null
  }

  /**
   * The server-fed menu whose listbox frame this is; null for any other
   * element, so a frame an option happens to hold is never taken for it.
   *
   * @param {EventTarget} frame
   * @returns {Element | null}
   */
  #fed(frame) {
    return this.menuTargets.find((menu) => this.#frame(menu) === frame) ?? null
  }

  /**
   * What is known of a server-fed menu's requests: the word waiting to
   * be asked about or on its way (wanted), the word last sent (sent),
   * the word the server failed to answer (failed), and the wait before
   * the next request (cancel).
   *
   * @param {Element} menu
   * @returns {{ wanted: string | null, sent: string | null, failed: string | null, cancel: Function | null }}
   */
  #state(menu) {
    if (!this.#remote.has(menu)) this.#remote.set(menu, { wanted: null, sent: null, failed: null, cancel: null })

    return this.#remote.get(menu)
  }

  /**
   * Asks the server about a word once typing has paused. A word already
   * asked about, or one the server just failed to answer, is not asked
   * about again.
   *
   * @param {Element} menu
   * @param {Element} frame
   * @param {string} query
   */
  #request(menu, frame, query) {
    const state = this.#state(menu)

    if (state.wanted === query || state.failed === query) return

    state.wanted = query
    state.failed = null
    menu.setAttribute("data-loading", "")
    state.cancel?.()
    state.cancel = useTimeout(this, () => {
      state.cancel = null
      this.#fetch(menu, frame, query)
    }, FETCH_DEBOUNCE)
  }

  /**
   * Points the frame at the menu's address with the word in its query.
   * Turbo makes the request, and drops one still on its way. An address
   * the frame already holds is loaded again.
   *
   * @param {Element} menu
   * @param {Element} frame
   * @param {string} query
   */
  #fetch(menu, frame, query) {
    const url = new URL(menu.getAttribute("data-src"), document.baseURI)

    url.searchParams.set(menu.getAttribute("data-param") || "q", query)
    this.#state(menu).sent = query
    if (frame.getAttribute("src") === url.href && typeof frame.reload === "function") frame.reload()
    else frame.setAttribute("src", url.href)
  }

  /**
   * Records that the server did not answer the word last sent.
   *
   * @param {Element} menu
   */
  #fail(menu) {
    const state = this.#state(menu)

    state.failed = state.sent
    state.wanted = null
    menu.removeAttribute("data-loading")
  }

  /** Drops every request still waiting to be sent: the word it was for is gone. */
  #rest() {
    for (const [menu, state] of this.#remote) {
      state.cancel?.()
      state.cancel = null
      state.wanted = null
      menu.removeAttribute("data-loading")
    }
  }

  /**
   * Shows a server-fed menu's new options when the reader is still in
   * the field, on a word that opens this menu.
   *
   * @param {Element} menu
   */
  #refresh(menu) {
    const context = this.#context()

    if (!context || context.menu !== menu || this.#dismissed === context.start) return
    if (document.activeElement !== this.inputTarget) return

    // Read before the list opens again, which moves the highlight to the top.
    const marked = this.#active?.menu === menu ? { id: this.#marked, value: this.#markedValue } : null

    this.#present(context)
    if (!marked || !this.#active) return

    const again = this.#again(menu, this.#shown(), marked)

    if (again) this.#highlight(again, false)
  }

  /**
   * The option the highlight was last on, among those shown: by its id
   * in a menu the server rendered whole, by its value in a server-fed
   * one, whose ids count positions in an answer.
   *
   * @param {Element} menu
   * @param {Element[]} shown
   * @param {{ id: string | null, value: string | null }} [marked] - the highlight as it was; as it is now by default
   * @returns {Element | null}
   */
  #again(menu, shown, marked = { id: this.#marked, value: this.#markedValue }) {
    if (!this.#frame(menu)) return shown.find((option) => option.id === marked.id) ?? null
    if (marked.value === null) return null

    return shown.find((option) => option.getAttribute("data-value") === marked.value) ?? null
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
    this.#markedValue = null
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
    this.#markedValue = option.getAttribute("data-value")
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
    this.#rest()
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
