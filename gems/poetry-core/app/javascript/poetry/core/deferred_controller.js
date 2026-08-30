import { Controller } from "@hotwired/stimulus"
import { onBeforeCache } from "@poetry/controllers/helpers/turbo_cache"

// Error isolation for deferred turbo-frames. Turbo owns the
// loading physics (loading="lazy" fetches on visibility, "eager" after
// paint) but leaves failure INVISIBLE: a missing frame logs "Content
// missing" or - Turbo 8 - promotes the error response to a full-page
// visit, and a network error leaves the placeholder spinning forever.
// This controller makes failure a state: data-error reflected on the
// frame (a bespoke boolean, deliberately not the shared open/closed
// vocabulary), the placeholder hidden, and the slotted <template> error
// content stamped so the region shows a real, retryable message.
//
// THE BOOT CONTRACT: the frame renders with NO src - the URL rides
// srcValue and connect() arms it. A visible lazy frame with src in
// markup can complete its fetch before the controllers module graph
// finishes loading (caught live: a local 404 beat Stimulus and Turbo 8
// navigated the whole page to the error response); with src armed at
// connect, no fetch - and so no failure - can predate the instance.
//
// retry() prefers Turbo's FrameElement#reload(); environments without
// the Turbo runtime (jsdom, dommy) fall back to re-setting src, the same
// signal Turbo reacts to.
export default class DeferredController extends Controller {
  static targets = ["placeholder", "error"]
  static values = { src: String }

  /**
   * Wires the three failure listeners, subscribes the before-cache reset,
   * and arms src LAST (the boot contract above: no fetch can predate the
   * instance).
   */
  connect() {
    // Three failure paths, one state. turbo:before-fetch-response is the
    // load-bearing one: for 4xx/5xx frame responses Turbo 8 fires NO
    // frame-missing - it promotes the error response straight to a
    // full-page visit (caught live: the docs page navigated to a bare
    // 404). Cancelling the response event here stops that promotion cold.
    // frame-missing still covers 2xx-without-a-matching-frame, and
    // fetch-request-error covers the network layer.
    this.element.addEventListener("turbo:before-fetch-response", this.#onResponse)
    this.element.addEventListener("turbo:frame-missing", this.#failed)
    this.element.addEventListener("turbo:fetch-request-error", this.#failed)

    // Reset before Turbo snapshots: a stamped error message serialized
    // into the cache restores as a permanent failure - the placeholder
    // posture retries the (transient) fetch on the restoration visit.
    this.#unsubscribeBeforeCache = onBeforeCache(() => this.#reset())

    if (!this.element.getAttribute("src")) this.element.setAttribute("src", this.srcValue)
  }

  /** Unwires the listeners and the before-cache subscription. */
  disconnect() {
    this.element.removeEventListener("turbo:before-fetch-response", this.#onResponse)
    this.element.removeEventListener("turbo:frame-missing", this.#failed)
    this.element.removeEventListener("turbo:fetch-request-error", this.#failed)
    this.#unsubscribeBeforeCache?.()
    this.#unsubscribeBeforeCache = null
  }

  /**
   * The retry action: back to the placeholder posture, then reload -
   * Turbo's FrameElement#reload when the runtime is present, else the
   * re-set-src fallback (the same signal Turbo reacts to).
   */
  retry() {
    this.#reset()

    if (typeof this.element.reload === "function") {
      this.element.reload()
    } else {
      const src = this.element.getAttribute("src") || this.srcValue
      this.element.removeAttribute("src")
      this.element.setAttribute("src", src)
    }
  }

  #onResponse = (event) => {
    if (event.detail?.fetchResponse?.succeeded !== false) return

    event.preventDefault()
    this.#failed(event)
  }

  #failed = (event) => {
    // Keep Turbo from acting on the failure itself (frame-missing default
    // = promote the response to a page visit) - the error template below
    // is the user-visible state.
    if (event.type === "turbo:frame-missing") event.preventDefault()

    this.element.setAttribute("data-error", "")
    if (this.hasPlaceholderTarget) this.placeholderTarget.hidden = true
    if (this.hasErrorTarget && !this.#stamped) {
      this.#stamped = this.errorTarget.content.firstElementChild?.cloneNode(true)
      if (this.#stamped) this.element.appendChild(this.#stamped)
    }
  }

  // Back to the placeholder posture (shared by retry and the
  // before-cache teardown).
  #reset() {
    this.#stamped?.remove()
    this.#stamped = null
    this.element.removeAttribute("data-error")
    if (this.hasPlaceholderTarget) this.placeholderTarget.hidden = false
  }

  #stamped = null
  #unsubscribeBeforeCache = null
}
