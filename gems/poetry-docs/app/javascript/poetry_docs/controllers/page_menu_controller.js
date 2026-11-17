import { Controller } from "@hotwired/stimulus"

// Docs-only (not part of poetry): "Copy page" puts the page's Markdown
// twin on the clipboard. The Markdown is fetched on the press, once, from
// the address the page already advertises.
//
// A browser lets a page write to the clipboard only inside the press that
// asked for it, and Safari counts a fetch as the end of that press. A
// ClipboardItem takes the text as a promise, so the write starts inside
// the press and finishes when the fetch does; writeText after the fetch is
// the path for a browser without ClipboardItem.
export default class extends Controller {
  static targets = ["label", "status"]
  static values = {
    url: String,
    copied: { type: String, default: "Copied" },
    failed: { type: String, default: "Could not copy" },
  }

  disconnect() {
    clearTimeout(this.timer)
  }

  async copy() {
    try {
      await this.write(this.markdown())
      this.say(this.copiedValue)
    } catch {
      this.fetched = null
      this.say(this.failedValue)
    }
  }

  // The page's Markdown as a promise, fetched once.
  markdown() {
    this.fetched ||= fetch(this.urlValue, { headers: { Accept: "text/markdown" } }).then((response) => {
      if (!response.ok) throw new Error(`HTTP ${response.status}`)
      return response.text()
    })
    return this.fetched
  }

  write(text) {
    if (window.ClipboardItem && navigator.clipboard?.write) {
      const blob = text.then((value) => new Blob([value], { type: "text/plain" }))
      return navigator.clipboard.write([new ClipboardItem({ "text/plain": blob })])
    }
    return text.then((value) => navigator.clipboard.writeText(value))
  }

  // Shows the outcome on the button and announces it, then puts the
  // button's own words back.
  say(message) {
    this.words ||= this.labelTarget.textContent
    this.labelTarget.textContent = message
    this.statusTarget.textContent = message
    clearTimeout(this.timer)
    this.timer = setTimeout(() => {
      this.labelTarget.textContent = this.words
      this.statusTarget.textContent = ""
    }, 2000)
  }
}
