import { Controller } from "@hotwired/stimulus"
import { isImeKeydown } from "@poetry/controllers/helpers/escape"
import { teardown } from "@poetry/controllers/helpers/scope"
import { useTimeout } from "@poetry/controllers/behaviors/interval"

/**
 * The Composer seams: a chat message form whose state the SERVER holds.
 * The form is never replaced; the server redraws one slot inside it with
 * a Send button or a Stop button, and a Stop button on the page is the
 * whole fact that a reply is running - the controller keeps no copy.
 *
 * Enter sends and Shift+Enter breaks the line (Cmd/Ctrl+Enter always
 * sends; with submit-on-enter off a bare Enter is a line break). An Enter
 * that confirms an input-method composition never sends. The form's own
 * submit event is the one gate, so the key and the button obey the same
 * rules: nothing is sent while the field is blank, while a reply runs, or
 * while a send is already on its way. Turbo marks the form aria-busy for
 * the length of a request; the one moment before that mark lands is
 * bridged by a flag that lasts a single task.
 *
 * When the server accepts a message the sent text leaves the field, and
 * whatever was typed after it stays. A refused message stays whole.
 *
 * Focus is never taken by a pointer: a press on Send or Stop leaves it
 * where it was, so a field being typed in keeps its on-screen keyboard
 * and a reader who put the keyboard away is not handed it back. A button
 * pressed from the keyboard does hold focus, and the server is about to
 * disable or replace it, so focus goes to the field instead of the page.
 */
export default class ComposerController extends Controller {
  static targets = ["form", "input", "send", "stop"]

  static values = {
    // Whether a bare Enter sends. Off, Enter is a line break and only
    // Cmd/Ctrl+Enter sends.
    submitOnEnter: { type: Boolean, default: true }
  }

  #sending = false
  #sent = ""
  #within = false

  /** Reflects the field's emptiness (a browser may restore a draft the server never rendered). */
  connect() {
    this.#reflect()
  }

  /** Undoes the per-connect scope (the pending flag's timer). */
  disconnect() {
    teardown(this)
  }

  /**
   * The field's keydown action: Enter sends, Shift+Enter is left to the
   * browser, and an Enter that belongs to an input-method composition is
   * never read as a send.
   *
   * @param {KeyboardEvent} event
   */
  keydown(event) {
    if (event.key !== "Enter" || event.shiftKey || event.altKey || isImeKeydown(event)) return
    if (!(event.metaKey || event.ctrlKey) && !this.submitOnEnterValue) return

    event.preventDefault()
    if (!event.repeat) this.submit()
  }

  /**
   * The field's input action, and the root's turbo:morph-element action:
   * keeps data-empty on the root honest. A morph puts the server's
   * attributes back on the root while the field keeps its draft, so the
   * emptiness is read again from the field once the morph has passed.
   */
  changed() {
    this.#reflect()
  }

  /**
   * Sends the message through the form, as a press of the Send button
   * would. The form's submit action decides whether anything goes.
   */
  submit() {
    this.formTarget.requestSubmit(this.hasSendTarget ? this.sendTarget : undefined)
  }

  /**
   * The form's submit action, the one gate for the key and the button:
   * refuses a blank message, a send while a reply runs (a Stop button is
   * on the page), and a second send while the first is on its way.
   *
   * @param {SubmitEvent} event
   */
  guard(event) {
    if (this.#sending || this.#busy() || this.hasStopTarget || this.#blank() || this.inputTarget.disabled) {
      event.preventDefault()
      return
    }

    this.#sent = this.inputTarget.value
    this.#within = this.element.contains(document.activeElement)
    // Turbo marks the form busy a moment after the submit, once the
    // request has been offered for interception; the flag covers that
    // moment and no longer, so a submission that never starts (a declined
    // confirmation, a listener's veto) leaves nothing stuck.
    this.#sending = true
    useTimeout(this, () => { this.#sending = false }, 0)
  }

  /**
   * The form's turbo:submit-end action: an accepted message leaves the
   * field (text typed since the send stays), a refused one stays whole,
   * and a send made from inside the composer ends with focus in the field
   * unless the reader took it elsewhere meanwhile.
   *
   * @param {CustomEvent} event - detail.success decides
   */
  settle(event) {
    this.#sending = false

    const field = this.inputTarget

    if (event.detail?.success && this.#sent !== "" && field.value.startsWith(this.#sent)) {
      field.value = field.value.slice(this.#sent.length)
      // A REAL input event: the emptiness reflection and a host's own
      // listeners react to the clearing exactly like typing.
      field.dispatchEvent(new Event("input", { bubbles: true }))
    }
    this.#sent = ""
    if (this.#within) this.#refocus()
    this.#within = false
  }

  /**
   * The Send and Stop buttons' pointerdown action: a press does not take
   * focus. A field being typed in keeps it, and with it the on-screen
   * keyboard.
   *
   * @param {PointerEvent} event
   */
  holdFocus(event) {
    event.preventDefault()
  }

  /**
   * The Stop button's click action: when the button itself holds focus (a
   * press from the keyboard), focus moves to the field, because the server
   * is about to replace the button and a replaced element drops focus to
   * the page.
   *
   * @param {MouseEvent} event
   */
  returnFocus(event) {
    if (document.activeElement === event.currentTarget) this.inputTarget.focus()
  }

  /**
   * Turbo's mark for a form with a request in flight.
   *
   * @returns {boolean}
   */
  #busy() {
    return this.formTarget.getAttribute("aria-busy") === "true"
  }

  /**
   * Whether the field holds nothing but whitespace.
   *
   * @returns {boolean}
   */
  #blank() {
    return this.inputTarget.value.trim() === ""
  }

  /** Writes the field's emptiness onto the root as data-empty. */
  #reflect() {
    this.element.toggleAttribute("data-empty", this.#blank())
  }

  /**
   * Returns focus to the field when it is still inside the composer or was
   * lost with a disabled button - never away from where the reader
   * deliberately put it.
   */
  #refocus() {
    const active = document.activeElement

    if (!active || active === document.body || this.element.contains(active)) this.inputTarget.focus()
  }
}
