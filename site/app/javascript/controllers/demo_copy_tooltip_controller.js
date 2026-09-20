import { Controller } from "@hotwired/stimulus"

// Docs-only harness (NOT part of poetry): copies the sensitive input's
// value and shows "Copied!" in the copy button's tooltip. Two tooltip
// mechanics shape it: the content PORTALS to <body> on first open (so
// the label is found document-wide, not as a scoped target), and the
// tooltip closes on trigger press by design (Radix/Base UI) - after
// copying we reopen it through its own focus path, which opens
// instantly and only reaches this trigger's Stimulus action. The
// component's built-in copy: affordance confirms with a glyph swap +
// live-region announcement instead.
export default class extends Controller {
  static targets = ["trigger"]

  async copy() {
    const value = this.element.querySelector("[data-slot=input-group-control]").value

    try {
      await navigator.clipboard.writeText(value)
    } catch {
      const scratch = document.createElement("textarea")
      scratch.value = value
      scratch.setAttribute("readonly", "")
      scratch.style.position = "absolute"
      scratch.style.left = "-9999px"
      document.body.append(scratch)
      scratch.select()
      document.execCommand("copy")
      scratch.remove()
    }

    const label = document.querySelector("[data-demo-copy-label]")
    if (label) label.textContent = "Copied!"
    this.triggerTarget.dispatchEvent(new FocusEvent("focus"))
    clearTimeout(this.timer)
    this.timer = setTimeout(() => {
      if (label) label.textContent = "Copy to clipboard"
    }, 1500)
  }

  disconnect() {
    clearTimeout(this.timer)
  }
}
