import { Controller } from "@hotwired/stimulus"

// The Questionnaire machine (shadcn's @shadcn/react questionnaire
// primitive, ported): a native <form> of fieldset items shown ONE at a
// time. The server renders the complete initial state (active item,
// statuses, shortcuts, button visibility); this controller owns the
// runtime transitions - navigation (validate-gated Next, Skip for
// optional items, submit validates every item and jumps to the first
// invalid), answer tracking (choice change / text input -> status), the
// keyboard map (Cmd/Ctrl+Enter confirm, ArrowUp/Down answer focus,
// ArrowLeft/Right item navigation, Enter-on-filled-answer confirm,
// letter/number shortcuts), and the data-attribute stamps the styling
// contract reads. Answers are native radio/checkbox/text inputs - the
// form serializes with zero JS.
const ITEM = '[data-slot="questionnaire-item"]'
const CHOICE = '[data-slot="questionnaire-choice"]'
const CHOICE_INPUT = '[data-slot="questionnaire-choice-input"]'
const TEXT_INPUT = '[data-slot="questionnaire-input"]'
const ERROR = '[data-slot="questionnaire-error"]'
const DESCRIPTION = '[data-slot="questionnaire-description"]'

export default class QuestionnaireController extends Controller {
  // The events this controller dispatches (manifest surface).
  static events = [
    "poetry:questionnaire:item-change",
    "poetry:questionnaire:status-change",
  ]

  static targets = ["progress", "previous", "skip", "next", "submit"]

  static values = {
    // "letters" | "numbers" | "" - gates the shortcut KEY HANDLING; the
    // key labels themselves are server-rendered (data-shortcut).
    shortcuts: { type: String, default: "" },
  }

  connect() {
    this.#sync()
  }

  // --- navigation actions -------------------------------------------------

  previous() {
    const items = this.#enabledItems()
    const index = this.#currentIndex(items)
    if (index <= 0) return

    this.#setItem(items[index - 1])
  }

  next() {
    const items = this.#enabledItems()
    const index = this.#currentIndex(items)
    const active = items[index]
    if (!active || index >= items.length - 1) return

    if (!this.#validate(active)) return this.#focusInvalid(active)

    this.#setItem(items[index + 1])
  }

  skip() {
    const items = this.#enabledItems()
    const index = this.#currentIndex(items)
    const active = items[index]
    if (!active || this.#required(active)) return

    active.dataset.skipped = ""
    this.#setStatus(active)
    if (index >= items.length - 1) return this.element.requestSubmit()

    this.#setItem(items[index + 1])
  }

  // Form submit: every enabled item must validate; the first invalid one
  // becomes active with its error focused.
  submit(event) {
    const invalid = this.#enabledItems().find((item) => !this.#validate(item))
    if (!invalid) return

    event.preventDefault()
    this.#setItem(invalid)
    this.#focusInvalid(invalid)
  }

  // Native reset restores the inputs; re-derive every stamp from the
  // restored DOM and return to the first item.
  reset() {
    requestAnimationFrame(() => {
      this.#items().forEach((item) => {
        delete item.dataset.skipped
        delete item.dataset.validated
        item.querySelectorAll(TEXT_INPUT).forEach((input) => this.#stampFilled(input))
        this.#setStatus(item)
        this.#syncInvalid(item)
      })
      const first = this.#enabledItems()[0]
      if (first) this.#setItem(first)
    })
  }

  // --- answer tracking ----------------------------------------------------

  change(event) {
    const input = event.target.closest(CHOICE_INPUT)
    if (!input) return
    const item = input.closest(ITEM)
    if (!item) return

    delete item.dataset.skipped
    item.querySelectorAll(CHOICE).forEach((choice) => {
      const choiceInput = choice.querySelector(CHOICE_INPUT)
      this.#stampChecked(choice, choiceInput)
    })
    this.#setStatus(item)
    this.#syncInvalid(item)
  }

  input(event) {
    const input = event.target.closest(TEXT_INPUT)
    if (!input) return
    const item = input.closest(ITEM)
    if (!item) return

    delete item.dataset.skipped
    this.#stampFilled(input)
    this.#setStatus(item)
    this.#syncInvalid(item)
  }

  // --- keyboard (the primitive's full map) --------------------------------

  keydown(event) {
    if (event.defaultPrevented || event.isComposing || event.keyCode === 229) return
    const active = this.#activeItem()
    if (!active || !(event.target instanceof Element)) return

    const meta = event.metaKey || event.ctrlKey
    if (event.key === "Enter" && meta && !event.altKey && !event.shiftKey) {
      event.preventDefault()
      if (!event.repeat) this.#confirm()
      return
    }
    if (meta || event.altKey) return

    if (event.key === "ArrowUp" || event.key === "ArrowDown") {
      if (this.#moveAnswerFocus(active, event.target, event.key === "ArrowDown" ? 1 : -1)) {
        event.preventDefault()
      }
      return
    }

    if (
      (event.key === "ArrowLeft" || event.key === "ArrowRight") &&
      !this.#textEntryTarget(event.target) &&
      !this.#radioTarget(event.target)
    ) {
      event.preventDefault()
      if (event.repeat) return
      if (event.key === "ArrowLeft") this.previous()
      else if (this.#status(active) !== "unanswered") this.next()
      return
    }

    if (event.key === "Enter") {
      const answer = event.target.closest(`${CHOICE_INPUT}, ${TEXT_INPUT}`)
      if (!answer) return
      event.preventDefault()
      if (!event.repeat && this.#answerFilled(answer)) this.#confirm()
      return
    }

    if (!this.shortcutsValue || this.#textEntryTarget(event.target)) return

    const key = event.key.length === 1 ? event.key.toUpperCase() : event.key
    const choice = [...active.querySelectorAll(CHOICE)].find(
      (candidate) => candidate.dataset.shortcut === key && !this.#choiceDisabled(candidate)
    )
    if (!choice) return

    event.preventDefault()
    if (event.repeat) return
    const input = choice.querySelector(CHOICE_INPUT)
    input?.focus()
    input?.click()
  }

  // --- internals ----------------------------------------------------------

  // Cmd/Ctrl+Enter and Enter-on-a-filled-answer: validate, then submit on
  // the last item or advance.
  #confirm() {
    const items = this.#enabledItems()
    const index = this.#currentIndex(items)
    const active = items[index]
    if (!active) return

    if (!this.#validate(active)) return this.#focusInvalid(active)
    if (index >= items.length - 1) return this.element.requestSubmit()

    this.#setItem(items[index + 1])
  }

  #items() {
    return [...this.element.querySelectorAll(ITEM)]
  }

  #enabledItems() {
    return this.#items().filter((item) => !item.disabled)
  }

  #activeItem() {
    return this.#enabledItems().find((item) => item.hasAttribute("data-active"))
  }

  #currentIndex(items) {
    return items.findIndex((item) => item.hasAttribute("data-active"))
  }

  #required(item) {
    return item.hasAttribute("data-required")
  }

  #answerControls(item) {
    return [...item.querySelectorAll(`${CHOICE_INPUT}, ${TEXT_INPUT}`)].filter(
      (control) => !control.disabled
    )
  }

  #answerFilled(control) {
    if (control.matches(CHOICE_INPUT)) return control.checked

    return control.value.trim() !== ""
  }

  #answered(item) {
    return this.#answerControls(item).some((control) => this.#answerFilled(control))
  }

  #status(item) {
    if ("skipped" in item.dataset && !this.#answered(item)) return "skipped"

    return this.#answered(item) ? "answered" : "unanswered"
  }

  #setStatus(item) {
    const status = this.#status(item)
    if (item.dataset.status === status) return

    item.dataset.status = status
    this.dispatch("status-change", {
      prefix: "poetry:questionnaire",
      detail: { item: item.dataset.name, status },
    })
    if (item.hasAttribute("data-active")) this.#syncButtons()
  }

  // validate() marks the attempt; invalid derives from it (the error
  // stays hidden until a navigation actually requires the answer).
  #validate(item) {
    item.dataset.validated = ""
    const valid =
      item.disabled ||
      (this.#status(item) === "skipped" && !this.#required(item)) ||
      this.#answered(item)
    this.#syncInvalid(item)
    return valid
  }

  #invalid(item) {
    if (item.disabled) return false
    if (!("validated" in item.dataset)) return false
    if (this.#status(item) === "skipped" && !this.#required(item)) return false

    return !this.#answered(item)
  }

  #syncInvalid(item) {
    const invalid = this.#invalid(item)
    const error = item.querySelector(ERROR)
    item.toggleAttribute("data-invalid", invalid)
    if (error) {
      error.hidden = !invalid
      if (invalid) error.setAttribute("role", "alert")
      else error.removeAttribute("role")
    }
    const description = item.querySelector(DESCRIPTION)
    const describedby = [description?.id, invalid ? error?.id : null]
      .filter(Boolean)
      .join(" ")
    if (describedby) item.setAttribute("aria-describedby", describedby)
    else item.removeAttribute("aria-describedby")
    this.#answerControls(item).forEach((control) => {
      if (invalid) control.setAttribute("aria-invalid", "true")
      else control.removeAttribute("aria-invalid")
    })
  }

  #stampChecked(choice, input) {
    if (!choice || !input) return
    choice.toggleAttribute("data-checked", input.checked)
    choice.toggleAttribute("data-unchecked", !input.checked)
    input.toggleAttribute("data-checked", input.checked)
    input.toggleAttribute("data-unchecked", !input.checked)
  }

  #stampFilled(input) {
    const filled = input.value.trim() !== ""
    input.toggleAttribute("data-filled", filled)
    input.toggleAttribute("data-empty", !filled)
  }

  #setItem(item, { focus = true } = {}) {
    const previous = this.#activeItem()
    if (previous === item) {
      if (focus) this.#focusFirstAnswer(item)
      return
    }

    this.#items().forEach((candidate) => {
      const active = candidate === item
      candidate.toggleAttribute("data-active", active)
      candidate.hidden = !active
      candidate.inert = !active
    })
    this.#syncProgress()
    this.#syncButtons()
    this.dispatch("item-change", {
      prefix: "poetry:questionnaire",
      detail: { item: item.dataset.name },
    })
    if (focus) this.#focusFirstAnswer(item)
  }

  #focusFirstAnswer(item) {
    this.#answerControls(item)[0]?.focus()
  }

  #focusInvalid(item) {
    this.#focusFirstAnswer(item)
  }

  #moveAnswerFocus(item, from, direction) {
    const controls = this.#answerControls(item)
    if (controls.length === 0) return false

    const target = from.closest(`${CHOICE_INPUT}, ${TEXT_INPUT}`)
    const index = controls.indexOf(target)
    const nextIndex = index === -1 ? (direction > 0 ? 0 : controls.length - 1) : index + direction
    const next = controls[nextIndex]
    if (!next) return false

    next.focus()
    return true
  }

  #textEntryTarget(target) {
    return target.matches?.("input[type=text], input[type=email], input[type=number], " +
      "input[type=search], input[type=tel], input[type=url], textarea")
  }

  #radioTarget(target) {
    return target.matches?.("input[type=radio]")
  }

  #choiceDisabled(choice) {
    const input = choice.querySelector(CHOICE_INPUT)
    return !input || input.disabled
  }

  #sync() {
    this.#items().forEach((item) => {
      item.querySelectorAll(CHOICE).forEach((choice) => {
        this.#stampChecked(choice, choice.querySelector(CHOICE_INPUT))
      })
      item.querySelectorAll(TEXT_INPUT).forEach((input) => this.#stampFilled(input))
      this.#setStatus(item)
    })
    this.#syncProgress()
    this.#syncButtons()
  }

  #syncProgress() {
    if (!this.hasProgressTarget) return
    const items = this.#enabledItems()
    const total = items.length
    const current = Math.max(this.#currentIndex(items) + 1, 1)
    const label = total ? `Question ${current} of ${total}` : ""

    if (!("custom" in this.progressTarget.dataset)) this.progressTarget.textContent = label
    if (total) {
      this.progressTarget.setAttribute("aria-valuemax", String(total))
      this.progressTarget.setAttribute("aria-valuemin", "1")
      this.progressTarget.setAttribute("aria-valuenow", String(current))
      this.progressTarget.setAttribute("aria-valuetext", label)
    }
  }

  #syncButtons() {
    const items = this.#enabledItems()
    const index = this.#currentIndex(items)
    const active = items[index]
    const first = index <= 0
    const last = index >= items.length - 1

    this.#stampButton(this.hasPreviousTarget && this.previousTarget, items.length > 1 && !first)
    this.#stampButton(this.hasSkipTarget && this.skipTarget, !!active && !this.#required(active))
    this.#stampButton(this.hasNextTarget && this.nextTarget, items.length > 1 && !last)
    this.#stampButton(this.hasSubmitTarget && this.submitTarget, items.length > 0 && last)
  }

  #stampButton(button, visible) {
    if (!button) return
    button.hidden = !visible
    button.inert = !visible
    button.tabIndex = visible ? 0 : -1
    button.toggleAttribute("data-visible", visible)
    button.toggleAttribute("data-hidden", !visible)
    if (visible) button.removeAttribute("aria-hidden")
    else button.setAttribute("aria-hidden", "true")
  }
}
