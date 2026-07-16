import { Controller } from "@hotwired/stimulus"
import { announce } from "@poetry/controllers/helpers/announce"
import { isImeKeydown } from "@poetry/controllers/helpers/escape"

// The SensitiveInput machine (the kumo contract): a secret field in
// three states - masked | revealed | empty - where data-state on the root
// carries the truth and CSS renders it. Masked-with-value turns the
// bordered GROUP into the reveal affordance (role=button + label +
// sr-hint; a div because copy/eye buttons live inside) while the real
// input stays rendered for layout but goes inert (aria-hidden,
// tabindex -1, readonly, transparent). Reveal: click/Enter/Space on the
// group, focus moves into the input. Re-mask: Escape (focus returns to
// the group - the input just lost its tab stop), leaving the component,
// or the eye. Typing into an empty field auto-reveals so composition
// happens in type=text. The no-JS story is a plain password input.
const EVENT_PREFIX = "poetry:sensitive-input"

export default class SensitiveInputController extends Controller {
  // The events this controller dispatches (manifest surface;
  // events_declaration.test.js enforces the list stays honest).
  static events = ["poetry:sensitive-input:reveal", "poetry:sensitive-input:mask"]

  static targets = ["group", "input", "toggle", "hint"]

  static values = {
    // "{label}, masked." - built server-side so i18n stays in Rails.
    maskedLabel: String,
    // The re-mask announcement ("Value hidden").
    hiddenMessage: String,
    // The host-declared readonly (the controller borrows the input's
    // readOnly while masked, so the option needs its own home).
    readOnly: Boolean
  }

  connect() {
    this.#visible = this.element.getAttribute("data-state") === "revealed"
    this.#reflect()
  }

  // click on the group - the masked container is the reveal affordance.
  reveal(event) {
    if (this.#disabled || this.#state !== "masked") return
    // The addon cell holds its own actions (copy/eye) - their clicks
    // bubble here and must never reveal.
    if (event.target instanceof Element && event.target.closest("[data-slot=input-group-addon]")) return
    // Synthetic label-click guard (kumo's coordinate check): a <label for=>
    // click re-dispatches on the input with no gesture behind it.
    if (event.detail === 0 && event.clientX === 0 && event.clientY === 0) return

    this.#reveal()
  }

  groupKeydown(event) {
    if (this.#disabled || this.#state !== "masked") return
    if (event.target !== this.groupTarget) return
    if (event.key !== "Enter" && event.key !== " ") return

    event.preventDefault()
    this.#reveal()
  }

  inputKeydown(event) {
    if (event.key !== "Escape" || isImeKeydown(event)) return
    if (this.#state !== "revealed") return

    // Consumed: this press masks; the NEXT one reaches the dismissal layer.
    event.preventDefault()
    event.stopPropagation()
    this.#mask({ focusGroup: true })
  }

  // focusout on the root: leaving the component with a value re-masks.
  blurred(event) {
    if (event.relatedTarget instanceof Node && this.element.contains(event.relatedTarget)) return
    if (this.#state !== "revealed") return

    this.#mask()
  }

  // input event: emptiness drives the state; the first character typed
  // into an empty field reveals (composition belongs in type=text).
  changed() {
    if (this.#state === "empty" && this.inputTarget.value !== "") this.#visible = true

    this.#reflect()
  }

  // the eye: re-mask, and hand focus to the group - the eye is about to
  // hide (it only exists while revealed).
  toggle(event) {
    event.stopPropagation()
    if (this.#state !== "revealed") return

    this.#mask({ focusGroup: true })
  }

  #visible = false

  get #state() {
    return this.element.getAttribute("data-state")
  }

  get #disabled() {
    return this.element.hasAttribute("data-disabled")
  }

  #reveal() {
    this.#visible = true
    this.#reflect()
    if (!this.readOnlyValue) this.inputTarget.focus()
    this.dispatch("reveal", { prefix: EVENT_PREFIX })
  }

  #mask({ focusGroup = false } = {}) {
    this.#visible = false
    this.#reflect()
    if (this.hiddenMessageValue !== "") announce(this.hiddenMessageValue)
    if (focusGroup) this.groupTarget.focus()
    this.dispatch("mask", { prefix: EVENT_PREFIX })
  }

  #reflect() {
    const empty = this.inputTarget.value === ""
    const state = empty ? "empty" : this.#visible ? "revealed" : "masked"
    this.element.setAttribute("data-state", state)

    const masked = state === "masked"

    if (masked) {
      this.groupTarget.setAttribute("role", "button")
      this.groupTarget.setAttribute("tabindex", this.#disabled ? "-1" : "0")
      this.groupTarget.setAttribute("aria-label", this.maskedLabelValue)
      if (this.hasHintTarget) this.groupTarget.setAttribute("aria-describedby", this.hintTarget.id)
    } else {
      this.groupTarget.removeAttribute("role")
      this.groupTarget.removeAttribute("tabindex")
      this.groupTarget.removeAttribute("aria-label")
      this.groupTarget.removeAttribute("aria-describedby")
    }

    // The real input: rendered for layout, inert while masked; native
    // password whenever the value is not shown.
    this.inputTarget.type = state === "revealed" ? "text" : "password"
    this.inputTarget.readOnly = masked || this.readOnlyValue
    if (masked) {
      this.inputTarget.setAttribute("aria-hidden", "true")
      this.inputTarget.setAttribute("tabindex", "-1")
    } else {
      this.inputTarget.removeAttribute("aria-hidden")
      this.inputTarget.removeAttribute("tabindex")
    }

    if (this.hasToggleTarget) this.toggleTarget.hidden = state !== "revealed"
  }
}
