import { Controller } from "@hotwired/stimulus"

// The hero background video. Under prefers-reduced-motion the loop
// never plays: the video is removed so the poster image (the same
// artwork, still) carries the hero instead.
export default class extends Controller {
  static targets = ["video"]

  connect() {
    if (matchMedia("(prefers-reduced-motion: reduce)").matches) {
      this.videoTarget.remove()
    }
  }
}
