// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"

// Keep the sidebar's scroll position across Turbo visits. The active item is
// server-rendered (current_page?), so the sidebar must re-render on navigation
// - data-turbo-permanent would freeze the highlight. Instead we carry the
// scroll offset over via sessionStorage: save when leaving a page, restore
// when the next one renders (before paint, so there is no jump).
(() => {
  const KEY = "poetry-docs:sidebar-scroll"
  const SEL = '[data-slot="sidebar-content"]'

  const save = () => {
    const el = document.querySelector(SEL)
    if (el) { try { sessionStorage.setItem(KEY, String(el.scrollTop)) } catch {} }
  }
  const restore = () => {
    const el = document.querySelector(SEL)
    if (!el) return
    let v
    try { v = sessionStorage.getItem(KEY) } catch {}
    if (v != null) el.scrollTop = parseInt(v, 10) || 0
  }

  document.addEventListener("turbo:before-cache", save) // leaving a page
  document.addEventListener("turbo:render", restore)    // next page swapped in (pre-paint)
  document.addEventListener("turbo:load", restore)      // initial load + fallback

  // Keep it fresh as the user scrolls the sidebar (throttled to one write/frame).
  let ticking = false
  document.addEventListener("scroll", (e) => {
    const t = e.target
    if (!(t instanceof Element) || !t.matches?.(SEL) || ticking) return
    ticking = true
    requestAnimationFrame(() => { save(); ticking = false })
  }, true)
})()

// The chat-replay versioned replace (rig): streaming re-morphs the
// SAME message row from a server stream, which inherits an out-of-order
// delivery race - so every payload carries data-version and this action
// applies only strictly-newer frames (Radan Skoric's versioned-replace
// pattern). Older or duplicate frames are dropped silently.
window.Turbo.StreamActions.vreplace = function () {
  this.targetElements.forEach((el) => {
    const incoming = this.templateContent.firstElementChild
    const version = Number(incoming?.dataset?.version || 0)
    const current = Number(el.dataset.version || -1)
    if (version > current) el.replaceWith(this.templateContent.cloneNode(true))
  })
}
