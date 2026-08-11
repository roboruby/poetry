import { Controller } from "@hotwired/stimulus"

// Docs demo harness - NOT part of poetry. Buttons outside the scroller
// drive it through the message-scroller controller's programmatic
// command surface (scrollToStart / scrollToEnd / scrollToMessage - the
// same methods outlet callers use); this controller only forwards the
// clicks.
export default class extends Controller {
  static targets = ["scroller"]

  // Menu items own their data-action (the menu's activate wiring), so
  // jump targets carry data-demo-jump-id instead. The menu activates on
  // pointerup and tears down before a click can bubble, so listen for
  // pointerup at the document (click kept for keyboard activation; a
  // double fire just re-scrolls to the same row).
  connect() {
    this.onActivate = (event) => {
      const item = event.target.closest?.("[data-demo-jump-id]")
      if (item) this.scroller?.scrollToMessage(item.dataset.demoJumpId, { behavior: "smooth" })
    }
    document.addEventListener("pointerup", this.onActivate)
    document.addEventListener("click", this.onActivate)
  }

  disconnect() {
    document.removeEventListener("pointerup", this.onActivate)
    document.removeEventListener("click", this.onActivate)
  }

  get scroller() {
    return this.application.getControllerForElementAndIdentifier(
      this.scrollerTarget,
      "poetry--core--message-scroller"
    )
  }

  toStart() {
    this.scroller?.scrollToStart({ behavior: "smooth" })
  }

  toEnd() {
    this.scroller?.scrollToEnd({ behavior: "smooth" })
  }
}
