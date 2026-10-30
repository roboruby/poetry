import { Controller } from "@hotwired/stimulus"

// The MCP App demo's panels around the host's frame: the messages the app
// sends to the chat, the bridge's traffic (the host controller's trace
// events), and the host theme flip the app follows.
export default class extends Controller {
  static targets = ["messages", "log", "status"]

  connected(event) {
    this.log("app", `connected: ${event.detail.app?.name || "app"} ${event.detail.app?.version || ""}`)
  }

  message(event) {
    const text = (event.detail.params?.content || []).filter((part) => part.type === "text").map((part) => part.text).join(" ")
    const item = document.createElement("li")
    item.className = "rounded-md border px-3 py-2"
    item.textContent = `${event.detail.params?.role || "user"}: ${text}`
    this.messagesTarget.append(item)
  }

  context(event) {
    this.log("app", `model context: ${JSON.stringify(event.detail.params).slice(0, 120)}`)
  }

  displayMode(event) {
    this.log("app", `display mode requested: ${event.detail.requested}, granted: ${event.detail.mode}`)
  }

  trace(event) {
    const { direction, message } = event.detail
    this.log(direction, message.method ? `${message.method}${message.id !== undefined ? ` #${message.id}` : ""}` : `reply #${message.id}`)
  }

  toggleTheme() {
    document.documentElement.classList.toggle("dark")
    document.dispatchEvent(new CustomEvent("poetry:theme-change"))
    this.log("host", `theme ${document.documentElement.classList.contains("dark") ? "dark" : "light"}`)
  }

  log(side, text) {
    const item = document.createElement("li")
    item.textContent = `${side === "host" ? "host" : "app "} ${text}`
    this.logTarget.append(item)
    this.logTarget.scrollTop = this.logTarget.scrollHeight
  }
}
