import { Controller } from "@hotwired/stimulus"
import { announce } from "@poetry/controllers/helpers/announce"
import { isImeKeydown } from "@poetry/controllers/helpers/escape"

// The SensitiveInput machine (the kumo contract): a secret field in
// three states - masked | revealed | empty - where data-state on the root
// carries the truth and CSS renders it. Masked-with-value turns the MASK
// OVERLAY into the reveal affordance (role=button + label + sr-hint; only
// text spans inside - a role on the surrounding group would trip axe
// nested-interactive around the inert input, the bug kumo ships unseen)
// while the real input stays rendered for layout but goes inert
// (aria-hidden, tabindex -1, readonly, transparent). Reveal: click
// anywhere on the group (mask clicks bubble) or Enter/Space on the mask,
// focus moves into the input. Re-mask: Escape (focus returns to the mask
// - the input just lost its tab stop), leaving the component, or the eye.
// Typing into an empty field auto-reveals so composition happens in
// type=text. The no-JS story is a plain password input.
const EVENT_PREFIX = "poetry:sensitive-input"

export default class SensitiveInputController extends Controller {
  // The events this controller dispatches (manifest surface;
  // events_declaration.test.js enforces the list stays honest).
  static events = ["poetry:sensitive-input:reveal", "poetry:sensitive-input:mask"]

  static targets = ["mask", "input", "toggle", "hint"]

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

  // click anywhere on the bordered group (the mask button's own clicks
  // bubble here too).
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

  maskKeydown(event) {
    if (this.#disabled || this.#state !== "masked") return
    if (event.target !== this.maskTarget) return
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
    this.#mask({ focusMask: true })
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

  // the eye: re-mask, and hand focus to the mask button - the eye is about
  // to hide (it only exists while revealed).
  toggle(event) {
    event.stopPropagation()
    if (this.#state !== "revealed") return

    this.#mask({ focusMask: true })
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
    // Move focus off the mask BEFORE #reflect hides it: hiding the
    // focused element drops focus to body, blurred() reads that as
    // leaving the field, and the re-mask beats the reveal (the
    // takes-two-clicks bug). The input accepts .focus() even while
    // masked (tabindex=-1 only skips Tab); read-only hands focus on
    // to the eye once #reflect has shown it.
    this.inputTarget.focus()
    this.#reflect()
    if (this.readOnlyValue && this.hasToggleTarget) this.toggleTarget.focus()
    this.dispatch("reveal", { prefix: EVENT_PREFIX })
  }

  #mask({ focusMask = false } = {}) {
    this.#visible = false
    this.#reflect()
    if (this.hiddenMessageValue !== "") announce(this.hiddenMessageValue)
    if (focusMask) this.maskTarget.focus()
    this.dispatch("mask", { prefix: EVENT_PREFIX })
  }

  #reflect() {
    const empty = this.inputTarget.value === ""
    const state = empty ? "empty" : this.#visible ? "revealed" : "masked"
    this.element.setAttribute("data-state", state)

    const masked = state === "masked"

    if (masked) {
      this.maskTarget.setAttribute("role", "button")
      this.maskTarget.setAttribute("tabindex", this.#disabled ? "-1" : "0")
      this.maskTarget.setAttribute("aria-label", this.maskedLabelValue)
      if (this.hasHintTarget) this.maskTarget.setAttribute("aria-describedby", this.hintTarget.id)
    } else {
      this.maskTarget.removeAttribute("role")
      this.maskTarget.removeAttribute("tabindex")
      this.maskTarget.removeAttribute("aria-label")
      this.maskTarget.removeAttribute("aria-describedby")
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
