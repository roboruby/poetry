import { describe, it, expect, beforeEach, afterEach, vi } from "vitest"
import { Application } from "@hotwired/stimulus"
import { registerPoetryAgent } from "@poetry/agent"

// The host frame's display modes: the page's offer in the host context,
// the app's declaration as the ceiling, the page's veto on the event,
// fullscreen and pip as styles on the element with the frame staying put,
// and the way back. The endpoint is a stub answering the app's resource.
const flush = () => new Promise((resolve) => setTimeout(resolve, 0))
const RESOURCE = { contents: [{ uri: "ui://shop/plans", mimeType: "text/html;profile=mcp-app", text: "<html><body>app</body></html>", _meta: { ui: {} } }] }

let application

const mount = async (attributes = "") => {
  document.body.innerHTML = `
    <div id="row">
      <div id="holder" class="rounded-xl border" data-mcp-app-host data-controller="poetry--agent--mcp-app-host"
           data-poetry--agent--mcp-app-host-server-value="shop" data-poetry--agent--mcp-app-host-tool-value="show_plans"
           data-poetry--agent--mcp-app-host-resource-value="ui://shop/plans" data-poetry--agent--mcp-app-host-rpc-url-value="/mcp-apps/rpc"
           data-poetry--agent--mcp-app-host-sandbox-page-value="<html></html>" ${attributes}>
        <p data-poetry--agent--mcp-app-host-target="status"></p>
      </div>
    </div>`
  application = Application.start()
  registerPoetryAgent(application)
  await flush()
  await flush()
  const holder = document.getElementById("holder")
  const controller = application.getControllerForElementAndIdentifier(holder, "poetry--agent--mcp-app-host")
  const posted = []
  controller.post = (message) => posted.push(message)
  expect(holder.querySelectorAll("iframe")).toHaveLength(1)
  return { holder, controller, posted, frame: holder.querySelector("iframe") }
}

describe("the host frame's display modes", () => {
  let answer

  beforeEach(() => {
    answer = { result: RESOURCE }
    vi.stubGlobal("fetch", vi.fn(async () => ({ json: async () => answer })))
  })

  afterEach(async () => {
    application?.stop()
    application = null
    await flush()
    vi.unstubAllGlobals()
    document.body.innerHTML = ""
    document.body.style.overflow = ""
  })

  it("offers the page's modes, refuses one the app did not declare, and refuses a mode outside the offer", async () => {
    const { holder, controller } = await mount()
    expect(controller.hostContext().availableDisplayModes).toEqual(["inline", "fullscreen", "pip"])
    expect(controller.hostContext().displayMode).toBe("inline")
    controller.bridge.appCapabilities = { availableDisplayModes: ["inline"] }
    expect(controller.setDisplayMode("fullscreen", { by: "app" })).toBe("inline")
    expect(holder.dataset.displayMode).toBeUndefined()
    controller.bridge.appCapabilities = { availableDisplayModes: ["inline", "fullscreen", "pip"] }
    expect(controller.setDisplayMode("carousel")).toBe("inline")
  })

  it("a page may offer fewer modes", async () => {
    const { controller } = await mount(`data-poetry--agent--mcp-app-host-display-modes-value='["pip"]'`)
    expect(controller.hostContext().availableDisplayModes).toEqual(["inline", "pip"])
    controller.bridge.appCapabilities = { availableDisplayModes: ["inline", "fullscreen", "pip"] }
    expect(controller.setDisplayMode("fullscreen")).toBe("inline")
    expect(controller.setDisplayMode("pip")).toBe("pip")
  })

  it("fullscreen fixes the element over the page with a placeholder, a way back and the app told; Escape returns inline", async () => {
    const { holder, controller, posted, frame } = await mount()
    controller.bridge.appCapabilities = { availableDisplayModes: ["inline", "fullscreen"] }
    controller.bridge.initialized = true
    frame.style.height = "300px"
    const events = []
    document.addEventListener("poetry:mcp-app-host:display-mode", (event) => events.push({ ...event.detail }))

    expect(controller.setDisplayMode("fullscreen", { by: "app" })).toBe("fullscreen")
    expect(events).toEqual([{ requested: "fullscreen", mode: "fullscreen", by: "app" }])
    expect(holder.style.position).toBe("fixed")
    expect(holder.dataset.displayMode).toBe("fullscreen")
    expect(holder.previousElementSibling.hasAttribute("data-mcp-app-host-placeholder")).toBe(true)
    expect(holder.querySelector("[data-mcp-app-host-close]")).not.toBeNull()
    expect(holder.querySelector("iframe")).toBe(frame)
    expect(frame.style.height).toBe("100%")
    expect(document.body.style.overflow).toBe("hidden")
    const change = posted.find((m) => m.method === "ui/notifications/host-context-changed")
    expect(change.params.displayMode).toBe("fullscreen")
    expect(controller.hostContext().displayMode).toBe("fullscreen")
    controller.resize({ height: 50 })
    expect(frame.style.height).toBe("100%")

    document.dispatchEvent(new KeyboardEvent("keydown", { key: "Escape" }))
    expect(controller.mode).toBe("inline")
    expect(holder.getAttribute("style")).toBeNull()
    expect(holder.dataset.displayMode).toBeUndefined()
    expect(document.querySelector("[data-mcp-app-host-placeholder]")).toBeNull()
    expect(holder.querySelector("[data-mcp-app-host-close]")).toBeNull()
    expect(document.body.style.overflow).toBe("")
    expect(frame.style.height).toBe("300px")
    expect(posted.filter((m) => m.method === "ui/notifications/host-context-changed").at(-1).params.displayMode).toBe("inline")
  })

  it("pip caps the frame's height, the page may refuse a mode on the event, and the close button returns inline", async () => {
    const { holder, controller, frame } = await mount()
    controller.bridge.appCapabilities = { availableDisplayModes: ["inline", "pip"] }
    const refuse = (event) => { event.detail.mode = "inline" }
    document.addEventListener("poetry:mcp-app-host:display-mode", refuse)
    expect(controller.setDisplayMode("pip")).toBe("inline")
    document.removeEventListener("poetry:mcp-app-host:display-mode", refuse)

    expect(controller.setDisplayMode("pip")).toBe("pip")
    expect(holder.style.position).toBe("fixed")
    expect(holder.style.width).toBe("360px")
    controller.resize({ height: 900 })
    expect(frame.style.height).toBe("480px")
    expect(controller.containerDimensions().maxHeight).toBe(480)

    holder.querySelector("[data-mcp-app-host-close]").click()
    expect(controller.mode).toBe("inline")
    expect(holder.style.position).toBe("")
  })

  it("an app's request goes through the handler and answers the mode in effect", async () => {
    const { controller } = await mount()
    controller.bridge.appCapabilities = { availableDisplayModes: ["inline", "pip"] }
    expect(await controller.bridge.handlers.requestDisplayMode({ mode: "pip" })).toEqual({ mode: "pip" })
    expect(await controller.bridge.handlers.requestDisplayMode({ mode: "fullscreen" })).toEqual({ mode: "pip" })
    expect(await controller.bridge.handlers.requestDisplayMode({ mode: "inline" })).toEqual({ mode: "inline" })
  })

  it("an authorization answer from the endpoint is announced to the page", async () => {
    const { controller } = await mount()
    answer = { error: { code: -32001, message: "authorization required for shop", data: { authorizationUrl: "https://auth.example/start" } } }
    const events = []
    document.addEventListener("poetry:mcp-app-host:authorize", (event) => events.push(event.detail))
    await expect(controller.rpc("tools/call", { name: "choose_plan" })).rejects.toMatchObject({ code: -32001 })
    expect(events).toEqual([{ server: "shop", url: "https://auth.example/start", message: "authorization required for shop" }])
  })

  it("leaving the page while fullscreen puts everything back", async () => {
    const { holder, controller } = await mount()
    controller.bridge.appCapabilities = { availableDisplayModes: ["inline", "fullscreen"] }
    controller.setDisplayMode("fullscreen")
    holder.remove()
    await flush()
    expect(document.body.style.overflow).toBe("")
    expect(document.querySelector("[data-mcp-app-host-placeholder]")).toBeNull()
  })
})
