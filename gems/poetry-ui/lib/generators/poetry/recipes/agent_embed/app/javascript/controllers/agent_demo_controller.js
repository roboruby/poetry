import { Controller } from "@hotwired/stimulus"

// installed by the poetry `agent-embed` recipe - this file is yours: edit
// freely. An OPT-IN in-page GUI agent (page-agent, MIT, loaded from the
// pinned CDN build with ?autoInit=false - no auto agent, no demo LLM)
// configured for a poetry app. Wire a small form with this controller
// (targets: model, baseUrl, apiKey, status; actions: agent-demo#activate,
// agent-demo#deactivate) - see the reference demo at the poetry docs
// /agent page, whose loader this file mirrors.
//
// The three Turbo rules this encodes (learned the hard way):
// 1. Turbo replaces <body> on navigation and the agent panel lives there -
//    remount on turbo:load.
// 2. Remount ONLY when idle: a running task survives the body swap
//    headless and completes (URL-state components navigate mid-task);
//    disposing mid-task aborts it out from under the agent.
// 3. On a hard load, the first turbo:load can fire before this module
//    evaluates - catch up once at module init.
const SCRIPT_URL =
  "https://cdn.jsdelivr.net/npm/page-agent@1.12.2/dist/iife/page-agent.demo.js?autoInit=false"
const FLAG = "poetry-agent-embed"

// Host-agnostic operator instructions for any poetry app. If your app
// serves its own operator register (a JSON of per-page instructions),
// point REGISTER_URL at it; absent, the agent still gets the poetry
// ground rules below plus the part contract via includeAttributes.
const REGISTER_URL = "/operator-register.json"
const POETRY_SYSTEM = `This site is built from poetry components. Every component stamps
data-component (its family) and data-slot (its parts) - trust those over guessing
from classes. Interactive components follow WAI-ARIA patterns; open surfaces are
portaled to the end of <body>, one at a time - never click through an overlay
scrim, dismiss first (Escape or outside click). Prefer clicking labels and options
over coordinates. Keyboard-first components (sliders, date/time segments, OTP
inputs): TYPE values into segments - typed input works where clicking alone never
sets them; sliders need arrow keys and track clicks are only coarse.`

let registerPromise = null

async function operatorRegister() {
  registerPromise ||= fetch(REGISTER_URL)
    .then((response) => (response.ok ? response.json() : null))
    .catch(() => null)
  return registerPromise
}

function pageInstructions(register, url) {
  if (!register) return null
  const path = new URL(url, window.location.origin).pathname
  const hit = Object.entries(register.pages || {})
    .filter(([prefix]) => path === prefix || path.startsWith(`${prefix}/`))
    .sort((a, b) => b[0].length - a[0].length)[0]
  return `${hit ? hit[1] : ""}\n${register.default || ""}`.trim() || null
}

async function mountAgent() {
  if (window.pageAgent && !document.getElementById("page-agent-runtime_agent-panel") &&
      window.pageAgent.status !== "running") {
    try { window.pageAgent.dispose?.() } catch { /* replaced below */ }
    window.pageAgent = undefined
  }
  if (window.pageAgent) return
  const config = JSON.parse(sessionStorage.getItem(FLAG) || "null")
  if (!config) return

  if (!window.PageAgent) {
    await new Promise((resolve, reject) => {
      const script = document.createElement("script")
      script.src = SCRIPT_URL
      script.crossOrigin = "anonymous"
      script.onload = resolve
      script.onerror = reject
      document.head.appendChild(script)
    })
  }

  const register = await operatorRegister()
  window.pageAgent = new window.PageAgent({
    model: config.model,
    baseURL: config.baseURL,
    apiKey: config.apiKey,
    language: "en-US",
    includeAttributes: ["data-component", "data-slot"],
    instructions: {
      system: register?.system || POETRY_SYSTEM,
      getPageInstructions: (url) => pageInstructions(register, url),
    },
  })
  window.pageAgent.panel.show()
}

document.addEventListener("turbo:load", mountAgent)
mountAgent()

export default class extends Controller {
  static targets = ["model", "baseUrl", "apiKey", "status"]

  connect() {
    if (sessionStorage.getItem(FLAG)) this.note("Agent is active - the panel follows you across pages.")
  }

  async activate(event) {
    event.preventDefault()
    const config = {
      model: this.modelTarget.value.trim(),
      baseURL: this.baseUrlTarget.value.trim(),
      apiKey: this.apiKeyTarget.value.trim(),
    }
    if (!config.apiKey) return this.note("An API key is required (it stays in this browser session).")

    sessionStorage.setItem(FLAG, JSON.stringify(config))
    try {
      await mountAgent()
      this.note("Agent mounted.")
    } catch (error) {
      sessionStorage.removeItem(FLAG)
      this.note(`Could not mount the agent: ${error.message || error}`)
    }
  }

  deactivate(event) {
    event.preventDefault()
    sessionStorage.removeItem(FLAG)
    window.pageAgent?.dispose?.()
    window.pageAgent = undefined
    this.note("Agent deactivated and its key cleared.")
  }

  note(text) {
    this.statusTarget.textContent = text
  }
}
