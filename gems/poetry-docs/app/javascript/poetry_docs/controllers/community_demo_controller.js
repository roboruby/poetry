import { Controller } from "@hotwired/stimulus"

// How tall the box may grow. A demo that would pass this is one whose
// height never settles, and the page must not grow with it.
const CEILING = 6000

// A community item's demo, running. The page renders the demo's
// screenshot with an empty frame laid over it, out of sight. This loads
// the saved demo into the frame from the demos' address, and once the
// demo reports its height it shows the frame in the screenshot's place,
// keeps the box as tall as the demo says it is, and hands the demo the
// page's scheme whenever that changes. The screenshot stays where the
// demo never answers, and where no script runs.
//
// The demos' address is another origin than the page's (the server frames
// nothing else), so the demo's scripts cannot reach the page; a message
// is believed only from this frame, at that origin.
export default class extends Controller {
  static targets = ["box", "frame", "shot", "still", "live"]
  static values = { url: String }

  connect() {
    this.demos = new URL(this.urlValue).origin
    this.height = null
    this.receive = this.receive.bind(this)
    this.reset = this.reset.bind(this)
    window.addEventListener("message", this.receive)
    // Turbo's cache keeps the page as the server rendered it, so a visit
    // back loads the demo again instead of showing a dead frame.
    document.addEventListener("turbo:before-cache", this.reset)
    // The scheme is a class on <html> (the theme controller toggles it).
    this.watcher = new MutationObserver(() => this.sendScheme())
    this.watcher.observe(document.documentElement, { attributes: true, attributeFilter: ["class"] })
    this.sent = this.scheme()
    this.frameTarget.src = `${this.urlValue}#scheme=${this.sent}`
  }

  disconnect() {
    window.removeEventListener("message", this.receive)
    document.removeEventListener("turbo:before-cache", this.reset)
    this.watcher.disconnect()
  }

  receive(event) {
    if (event.origin !== this.demos || event.source !== this.frameTarget.contentWindow) return
    const height = event.data && event.data.height
    if (typeof height !== "number" || !(height > 0)) return
    const first = this.height === null
    this.height = Math.min(Math.ceil(height), CEILING)
    this.show()
    // The scheme may have changed while the demo was loading.
    if (first) this.sendScheme()
  }

  // The frame in the screenshot's place. The screenshot stays in the
  // box, unseen, because its width is the box's width. The box's border
  // counts in its height, so it is added: a frame shorter than its demo
  // by the border would cut the demo, and a demo that fills its frame
  // would then ask for less each time.
  show() {
    const border = this.boxTarget.offsetHeight - this.boxTarget.clientHeight
    this.boxTarget.style.height = `${this.height + border}px`
    this.shotTarget.classList.add("invisible")
    this.frameTarget.classList.remove("invisible")
    this.stillTarget.hidden = true
    this.liveTarget.hidden = false
  }

  reset() {
    this.height = null
    this.frameTarget.removeAttribute("src")
    this.boxTarget.style.height = ""
    this.shotTarget.classList.remove("invisible")
    this.frameTarget.classList.add("invisible")
    this.stillTarget.hidden = false
    this.liveTarget.hidden = true
  }

  // A page refresh morphs the server's markup back over the figure, which
  // would put the screenshot back and leave the running frame unseen.
  keep(event) {
    event.preventDefault()
  }

  scheme() {
    return document.documentElement.classList.contains("dark") ? "dark" : "light"
  }

  sendScheme() {
    const mode = this.scheme()
    if (this.height === null || mode === this.sent) return
    this.sent = mode
    this.frameTarget.contentWindow.postMessage({ poetryDemoScheme: mode }, this.demos)
  }
}
