import { Controller } from "@hotwired/stimulus"

// The MCP App demo's panels around the host's frame: the messages the app
// sends to the chat, the bridge's traffic (the host controller's trace
// events), the host theme flip the app follows, and the page's side of the
// display modes (the host controller moves the frame on the page's call).
export default class extends Controller {
  static targets = ["messages", "log", "status"]

  fullscreen() { this.setDisplayMode("fullscreen") }

  pip() { this.setDisplayMode("pip") }

  setDisplayMode(mode) {
    const holder = this.element.querySelector("[data-mcp-app-host]")
    const host = holder && this.application.getControllerForElementAndIdentifier(holder, "poetry--agent--mcp-app-host")
    const granted = host?.setDisplayMode(mode)
    this.log("host", `display mode ${mode} asked by the page, now ${granted || "unchanged"}`)
  }

  authorize(event) {
    this.log("host", `the server wants the person authorized first: ${event.detail.url}`)
  }

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
    this.log(event.detail.by === "app" ? "app" : "host", `display mode ${event.detail.requested} requested, granting ${event.detail.mode}`)
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
