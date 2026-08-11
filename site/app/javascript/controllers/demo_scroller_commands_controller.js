import { Controller } from "@hotwired/stimulus"

// Docs demo harness - NOT part of poetry. Buttons outside the scroller
// drive it through the message-scroller controller's programmatic
// command surface (scrollToStart / scrollToEnd / scrollToMessage - the
// same methods outlet callers use); this controller only forwards the
// clicks.
export default class extends Controller {
  static targets = ["scroller"]

  // Menu items own their data-action (the menu's activate wiring), so
  // jump targets carry data-demo-jump-id and one delegated listener
  // forwards them.
  connect() {
    this.onClick = (event) => {
      const item = event.target.closest("[data-demo-jump-id]")
      if (item) this.scroller?.scrollToMessage(item.dataset.demoJumpId, { behavior: "smooth" })
    }
    this.element.addEventListener("click", this.onClick)
  }

  disconnect() {
    this.element.removeEventListener("click", this.onClick)
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
