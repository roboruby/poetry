import { Controller } from "@hotwired/stimulus"

// Docs demo harness - NOT part of poetry. Replays a scripted
// conversation into a MessageScroller the way a real app's Turbo
// Streams would: every turn's markup is server-rendered ERB kept in
// <template> rows; Send moves the next pair in, and the assistant reply
// then streams by UPDATING its row's text (the scroller's
// stream-by-morphing posture - never append-per-token). The scroller
// itself does the rest: anchoring, follow-bottom, the jump button.
export default class extends Controller {
  static targets = ["empty", "chat", "turn", "send", "queue"]

  connect() {
    this.index = 0
    this.streaming = false
    this.content = this.element.querySelector("[data-slot=message-scroller-content]")
    this.pristine = this.content.innerHTML
    this.#syncQueue()
  }

  disconnect() {
    this.#stopStream()
  }

  send() {
    if (this.streaming) return
    const template = this.turnTargets[this.index]
    if (!template) return

    this.index += 1
    this.emptyTarget.hidden = true
    this.chatTarget.hidden = false

    const turn = template.content.cloneNode(true)
    const rows = [...turn.children]
    this.#append(rows)
    const streamed = rows.find((row) => row.querySelector("[data-demo-text]"))
    if (streamed) this.#stream(streamed)
    this.#syncQueue()
  }

  reset() {
    this.#stopStream()
    this.index = 0
    this.content.innerHTML = this.pristine
    this.chatTarget.hidden = true
    this.emptyTarget.hidden = false
    this.#syncQueue()
  }

  #append(rows) {
    const spacer = this.content.querySelector("[data-slot=message-scroller-spacer]")
    rows.forEach((row) => this.content.insertBefore(row, spacer))
  }

  #stream(row) {
    const slot = row.querySelector("[data-demo-text]")
    const words = slot.dataset.demoText.split(" ")
    let shown = 0
    this.streaming = true
    this.content.setAttribute("aria-busy", "true")
    if (this.hasSendTarget) this.sendTarget.disabled = true
    this.timer = setInterval(() => {
      shown += 1
      slot.textContent = words.slice(0, shown).join(" ")
      if (shown >= words.length) this.#stopStream()
    }, 45)
  }

  #stopStream() {
    if (this.timer) clearInterval(this.timer)
    this.timer = null
    this.streaming = false
    this.content?.removeAttribute("aria-busy")
    this.#syncQueue()
  }

  #syncQueue() {
    if (!this.hasQueueTarget) return
    const next = this.turnTargets[this.index]
    if (next) {
      this.queueTarget.textContent = next.dataset.demoPreview
      this.queueTarget.classList.remove("text-muted-foreground")
    } else {
      this.queueTarget.textContent = "No messages queued. Reset the conversation."
      this.queueTarget.classList.add("text-muted-foreground")
    }
    if (this.hasSendTarget) this.sendTarget.disabled = this.streaming || !next
  }
}
