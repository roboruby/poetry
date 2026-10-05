// The docs pages' own JavaScript graph. The docs layouts name this module
// as the importmap entry point, so a host's application.js never loads on
// a docs page and the docs' controllers never load on the host's.
import "@hotwired/turbo-rails"
import { Application } from "@hotwired/stimulus"
import { eagerLoadControllersFrom } from "@hotwired/stimulus-loading"
import { registerPoetryControllers } from "@poetry/controllers"
import { registerPoetryChartsControllers } from "@poetry/charts"
import { registerPoetryAgent } from "@poetry/agent"

const application = Application.start()
application.debug = false
window.Stimulus = application

// The docs' own controllers register under their bare names (theme,
// style, docs-search, the demo controllers), then the gems' controllers.
eagerLoadControllersFrom("poetry_docs/controllers", application)
registerPoetryControllers(application)
registerPoetryChartsControllers(application)
registerPoetryAgent(application)

// Keep the sidebar's scroll position across Turbo visits. The active item is
// server-rendered (current_page?), so the sidebar must re-render on navigation
// - data-turbo-permanent would freeze the highlight. Instead we carry the
// scroll offset over via sessionStorage: save when leaving a page, restore
// when the next one renders (before paint, so there is no jump). The
// leading semicolon keeps the IIFE from chaining onto the call above.
;(() => {
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

// The versioned replace stream action (vreplace) comes from @poetry/agent's
// registerPoetryAgent above: versioned, and morphing when the frame says
// method="morph".
