import { Controller } from "@hotwired/stimulus"

// The InputOTP projection (the single-input architecture, poetry's own
// build - no npm dependency): ONE real native <input> holds the whole
// value, stretched invisibly over the slot row, so paste, SMS autofill,
// IME, constraint validation and form serialization are all native and AT
// sees ONE text field. The n slot cells are an aria-hidden MIRROR painted
// here - this controller contains ZERO editing logic:
//
// - #sync filters input.value per-character through the pattern + truncates
//   to length (writing back only when filtering changed it - that one line
//   IS paste splitting: "123-456" under digits becomes "123456"), paints
//   slot[i] with value[i], and projects the caret: the active cell is
//   min(selectionStart, length - 1) while focused (data-active), with the
//   fake blinking caret element visible only on the active EMPTY cell.
// - Auto-advance and backspace-retreat are not features: typing moves the
//   native caret forward, Backspace moves it back - the active cell is a
//   PROJECTION of selectionStart. Arrows/Home/End/IME: native, re-projected
//   via the document-level selectionchange listener (bound on focus,
//   unbound on blur - n OTP fields must not all re-project on every caret
//   move anywhere).
// - poetry:otp:change fires per accepted mutation; poetry:otp:complete
//   fires once when the value reaches length and re-arms below it (the
//   enable-the-submit-button hook - it never submits).
export default class OtpController extends Controller {
  // The events this controller dispatches (manifest surface;
  // events_declaration.test.js enforces the list stays honest).
  static events = ["poetry:otp:change", "poetry:otp:complete"]

  static values = {
    length: { type: Number, default: 6 },
    pattern: { type: String, default: "\\d" }
  }

  static targets = ["input", "slot"]

  #regex = null
  #lastValue = null
  #completed = false
  #selectionListener = null

  /**
   * Compiles the pattern, adopts the input's value, and paints the
   * initial projection (no events dispatched).
   */
  connect() {
    this.#regex = this.#compile()
    this.#lastValue = this.inputTarget.value
    this.#completed = this.inputTarget.value.length >= this.lengthValue
    this.#sync({ dispatch: false })
  }

  /** Unbinds the document-level selectionchange listener. */
  disconnect() {
    this.#unbindSelection()
  }

  /**
   * The native input's input / focus / blur action (one handler - the
   * projection is idempotent; blur clears the active cell; focus binds
   * the selectionchange re-projection).
   *
   * @param {Event} [event]
   */
  sync(event) {
    if (event?.type === "focus") this.#bindSelection()
    if (event?.type === "blur") this.#unbindSelection()

    this.#sync()
  }

  /**
   * The paste action. Paste is the one native path maxlength breaks: the
   * browser truncates the RAW clipboard text to maxlength before any
   * input event, so "123-456" loses its tail before the sync pass could
   * filter the dashes (real Chrome; jsdom doesn't enforce maxlength,
   * which is why the unit tier never saw it). Intercept, filter FIRST,
   * splice at the selection.
   *
   * @param {ClipboardEvent} event
   */
  paste(event) {
    const text = event.clipboardData?.getData("text") ?? ""

    event.preventDefault()

    const input = this.inputTarget
    const accepted = Array.from(text).filter((char) => this.#regex.test(char)).join("")
    const start = input.selectionStart ?? input.value.length
    const end = input.selectionEnd ?? start
    const next = (input.value.slice(0, start) + accepted + input.value.slice(end))
      .slice(0, this.lengthValue)

    input.value = next

    const caret = Math.min(start + accepted.length, this.lengthValue)

    input.setSelectionRange?.(caret, caret)
    this.#sync()
  }

  /**
   * The container's click action (gaps, separators - the input already
   * covers the cells at z-20): focuses the real control.
   */
  focusInput() {
    if (this.inputTarget.disabled) return

    this.inputTarget.focus()
  }

  // --- the projection ---

  #sync({ dispatch = true } = {}) {
    const input = this.inputTarget
    const raw = input.value
    const filtered = Array.from(raw)
      .filter((char) => this.#regex.test(char))
      .join("")
      .slice(0, this.lengthValue)

    // Write back only when filtering changed it (paste splitting +
    // pattern rejection); the caret lands after the accepted text.
    if (filtered !== raw) {
      input.value = filtered

      const caret = Math.min(input.selectionStart ?? filtered.length, filtered.length)

      input.setSelectionRange?.(caret, caret)
    }

    this.#paint(filtered)
    this.#projectCaret(filtered)

    if (!dispatch) return

    if (filtered !== this.#lastValue) {
      this.#lastValue = filtered

      const complete = filtered.length >= this.lengthValue

      this.dispatch("change", { prefix: "poetry:otp", detail: { value: filtered, complete } })

      // complete fires ONCE per rise to full length; editing below re-arms.
      if (complete && !this.#completed) {
        this.#completed = true
        this.dispatch("complete", { prefix: "poetry:otp", detail: { value: filtered } })
      } else if (!complete) {
        this.#completed = false
      }
    }
  }

  // slot[i] shows value[i] - painted as the slot's leading text node so the
  // caret element child survives (textContent would wipe it).
  #paint(value) {
    this.slotTargets.forEach((slot, index) => {
      const char = value[index] ?? ""
      let node = slot.firstChild

      if (!node || node.nodeType !== Node.TEXT_NODE) {
        node = document.createTextNode("")
        slot.prepend(node)
      }

      node.data = char
    })
  }

  // Exactly one data-active cell while focused: the caret's cell, clamped
  // to the last slot when the value is complete. The fake caret is visible
  // only when the active cell is EMPTY (a filled active cell shows the
  // ring alone).
  #projectCaret(value) {
    const focused = document.activeElement === this.inputTarget
    const active = focused
      ? Math.min(this.inputTarget.selectionStart ?? value.length, this.lengthValue - 1)
      : -1

    this.slotTargets.forEach((slot, index) => {
      const isActive = index === active

      slot.setAttribute("data-active", String(isActive))

      const caret = slot.querySelector("[data-slot=input-otp-caret]")

      if (caret) caret.hidden = !(isActive && (value[index] ?? "") === "")
    })
  }

  // selectionchange is DOCUMENT-level: bind on focus, unbind on blur (the
  // leak guard) - arrows/Home/End re-project without any input event.
  #bindSelection() {
    if (this.#selectionListener) return

    this.#selectionListener = () => {
      if (document.activeElement === this.inputTarget) this.#sync()
    }
    document.addEventListener("selectionchange", this.#selectionListener)
  }

  #unbindSelection() {
    if (!this.#selectionListener) return

    document.removeEventListener("selectionchange", this.#selectionListener)
    this.#selectionListener = null
  }

  // The per-character filter: the pattern value is a regex SOURCE tested
  // one char at a time (anchored so multi-char patterns can't smuggle).
  #compile() {
    try {
      return new RegExp(`^(?:${this.patternValue})$`)
    } catch {
      console.warn(`poetry--core--otp: invalid pattern ${this.patternValue}; falling back to digits`)
      return /^\d$/
    }
  }
}
