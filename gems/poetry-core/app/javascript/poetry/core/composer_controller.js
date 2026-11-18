import { Controller } from "@hotwired/stimulus"
import { isImeKeydown } from "@poetry/controllers/helpers/escape"
import { teardown } from "@poetry/controllers/helpers/scope"
import { useListen } from "@poetry/controllers/behaviors/listen"
import { useTimeout } from "@poetry/controllers/behaviors/interval"

const EVENT_PREFIX = "poetry:composer"

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
 * Files are part of the message when the composer has a file input (the
 * attachments target): a message of files alone is not blank, and once
 * the server accepts it the sent event names the files that went, so the
 * file-input controller beside this one drops their chips and keeps any
 * file added since. The event names the per-message fields that went as
 * well (elements marked data-composer-field, a chosen reference's hidden
 * input), for whoever added them to take back out.
 *
 * Focus is never taken by a pointer: a press on Send or Stop leaves it
 * where it was, so a field being typed in keeps its on-screen keyboard
 * and a reader who put the keyboard away is not handed it back. A button
 * pressed from the keyboard does hold focus, and the server is about to
 * disable or replace it, so focus goes to the field instead of the page.
 *
 * A suggested prompt reaches the composer as a poetry:composer:prompt
 * event on the window that names it by id (the composer-prompt
 * controller's press). The composer writes the text and, asked to, sends
 * it through the same gate. A prompt that could not go writes nothing,
 * so a draft is never traded for a prompt the gate refused.
 */
export default class ComposerController extends Controller {
  // The events this controller dispatches (manifest surface;
  // events_declaration.test.js enforces the list stays honest).
  static events = ["poetry:composer:sent"]

  static targets = ["form", "input", "send", "stop", "attachments"]

  static values = {
    // Whether a bare Enter sends. Off, Enter is a line break and only
    // Cmd/Ctrl+Enter sends.
    submitOnEnter: { type: Boolean, default: true }
  }

  #sending = false
  #sent = ""
  #files = []
  #fields = []
  #within = false

  /**
   * Reflects the field's emptiness (a browser may restore a draft the
   * server never rendered) and starts hearing prompts meant for this
   * composer.
   */
  connect() {
    this.#reflect()
    useListen(this, window, "poetry:composer:prompt", (event) => this.#prompted(event))
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
    // A key an earlier action claimed (an open menu choosing its option)
    // is not a send.
    if (event.defaultPrevented) return
    if (event.key !== "Enter" || event.shiftKey || event.altKey || isImeKeydown(event)) return
    if (!(event.metaKey || event.ctrlKey) && !this.submitOnEnterValue) return

    event.preventDefault()
    if (!event.repeat) this.submit()
  }

  /**
   * The field's input action, the file input's change action and the
   * root's turbo:morph-element action: keeps data-empty on the root
   * honest. A morph puts the server's attributes back on the root while
   * the field keeps its draft, so the emptiness is read again from the
   * field once the morph has passed.
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
    // A submit something else already held back (uploads still in
    // flight) is not a send.
    if (event.defaultPrevented) return
    if (this.#refusal()) {
      event.preventDefault()
      return
    }

    this.#sent = this.inputTarget.value
    this.#files = this.#attached()
    this.#fields = Array.from(this.formTarget.querySelectorAll("[data-composer-field]"))
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
   * field (text typed since the send stays) and is reported with the
   * files and the per-message fields that went with it, a refused one
   * stays whole, and a send made
   * from inside the composer ends with focus in the field unless the
   * reader took it elsewhere meanwhile.
   *
   * @param {CustomEvent} event - detail.success decides
   */
  settle(event) {
    this.#sending = false

    const field = this.inputTarget
    const accepted = Boolean(event.detail?.success)

    if (accepted && this.#sent !== "" && field.value.startsWith(this.#sent)) {
      field.value = field.value.slice(this.#sent.length)
      // A REAL input event: the emptiness reflection and a host's own
      // listeners react to the clearing exactly like typing.
      field.dispatchEvent(new Event("input", { bubbles: true }))
    }
    if (accepted) {
      this.dispatch("sent", { prefix: EVENT_PREFIX, detail: { files: this.#files, fields: this.#fields } })
    }
    this.#sent = ""
    this.#files = []
    this.#fields = []
    if (this.#within) this.#refocus()
    this.#within = false
  }

  /**
   * The programmatic surface for the message's text: setText("Hello")
   * replaces the draft, with a real input event, and does not send. A
   * disabled field is left alone. Returns the resulting state - what an
   * agent tool reports back - so a refusal is visible as changed: false.
   *
   * @param {string} text - the message text (stringified)
   * @returns {{ text: string, empty: boolean, changed: boolean }} the field after the call
   */
  setText(text) {
    const field = this.inputTarget
    const next = String(text ?? "")
    const changed = !field.disabled && field.value !== next

    if (changed) {
      field.value = next
      field.dispatchEvent(new Event("input", { bubbles: true }))
    }

    return { text: field.value, empty: this.#blank(), changed }
  }

  /**
   * The programmatic surface for sending: send() does what a press of
   * Send would, through the same gate. Returns whether the message was
   * let go and, when it was not, why: blank, running (a reply is being
   * written), sending (a send is on its way) or disabled.
   *
   * @returns {{ sent: boolean, reason?: "blank" | "running" | "sending" | "disabled" }}
   */
  send() {
    const reason = this.#refusal()

    if (reason) return { sent: false, reason }

    this.submit()
    return { sent: true }
  }

  /**
   * The programmatic surface for stopping: stop() presses the Stop
   * button when a reply is running and the button can be pressed.
   * Returns whether it was.
   *
   * @returns {{ stopped: boolean }}
   */
  stop() {
    if (!this.hasStopTarget || this.stopTarget.disabled) return { stopped: false }

    this.stopTarget.click()
    return { stopped: true }
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
   * A prompt dispatched on the window: taken when it names this composer
   * by id. To be sent it must be able to go now, so the draft is left
   * alone while a reply runs, a send is on its way or the field is
   * disabled. Without a send the text is written and the caret put after
   * it.
   *
   * @param {CustomEvent} event - detail.composer is the composer's id, detail.text the prompt, detail.send whether to send it
   */
  #prompted(event) {
    const { composer, text, send = true } = event.detail ?? {}

    if (!this.element.id || composer !== this.element.id) return

    const field = this.inputTarget
    const next = String(text ?? "")

    if (field.disabled) return
    if (send && (this.#sending || this.#busy() || this.hasStopTarget)) return

    this.setText(next)
    if (send) {
      this.submit()
      return
    }
    field.focus()
    field.setSelectionRange(next.length, next.length)
  }

  /**
   * Why a message cannot go right now, or null when it can: the field
   * is disabled, a send is on its way, a reply is running (a Stop
   * button is on the page), or there is nothing to send.
   *
   * @returns {"disabled" | "sending" | "running" | "blank" | null}
   */
  #refusal() {
    if (this.inputTarget.disabled) return "disabled"
    if (this.#sending || this.#busy()) return "sending"
    if (this.hasStopTarget) return "running"
    if (this.#blank()) return "blank"

    return null
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
   * Whether there is nothing to send: the field holds nothing but
   * whitespace and no file is attached.
   *
   * @returns {boolean}
   */
  #blank() {
    return this.inputTarget.value.trim() === "" && this.#attached().length === 0
  }

  /**
   * The files the composer's file input holds; none without one.
   *
   * @returns {File[]}
   */
  #attached() {
    return this.hasAttachmentsTarget ? Array.from(this.attachmentsTarget.files ?? []) : []
  }

  /** Writes the message's emptiness onto the root as data-empty. */
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
