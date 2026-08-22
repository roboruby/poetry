import { Controller } from "@hotwired/stimulus"

// The operator-register demo loader (opt-in, nothing ambient): activates
// the vendored page-agent build (?autoInit=false - no demo agent, no demo
// LLM) and constructs window.PageAgent with poetry's operator register.
// The key lives in sessionStorage only and is sent ONLY to the baseURL the
// visitor configured. Activation survives Turbo visits via a session flag:
// Turbo replaces <body> (taking the agent panel with it), so we re-mount
// on every turbo:load while the flag is set.
const SCRIPT_URL = "/vendor/page-agent/page-agent-1.12.2.js?autoInit=false"
const FLAG = "poetry-docs-agent"

let registerPromise = null

async function operatorRegister() {
  registerPromise ||= fetch("/operator-register.json").then((response) => response.json())
  return registerPromise
}

function pageInstructions(register, url) {
  const path = new URL(url, window.location.origin).pathname
  const hit = Object.entries(register.pages)
    .filter(([prefix]) => path === prefix || path.startsWith(`${prefix}/`))
    .sort((a, b) => b[0].length - a[0].length)[0]
  return `${hit ? hit[1] : ""}\n${register.default}`.trim()
}

async function mountAgent() {
  // Turbo body swaps and hard loads can leave a live instance with a dead
  // panel (the panel element rides <body>); rebuild rather than limp - but
  // ONLY when idle: a running task survives the body swap headless and
  // completes (URL-state components like DataTable navigate mid-task), and
  // disposing it here aborts the task out from under the agent.
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
      system: register.system,
      getPageInstructions: (url) => pageInstructions(register, url),
    },
  })
  window.pageAgent.panel.show()
}

document.addEventListener("turbo:load", mountAgent)
// Hard loads race module evaluation against the first turbo:load - catch up
// once at module init (modules are deferred, so the DOM is parsed by now).
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
      this.note("Agent mounted - give it a task from the list below.")
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
