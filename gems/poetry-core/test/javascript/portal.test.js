import { beforeEach, describe, expect, it } from "vitest"
// Side effect: index.js registers the union of every controller's declared
// events as the bridge list (docs/portal-on-open.md D5).
import "@poetry/controllers"
import {
  isPortaled, portalContent, resolvePortalContainer, restoreContent
} from "@poetry/controllers/helpers/portal"

// The portal-on-open mechanism (S0): move/restore round-trip against the
// placeholder, the container override attribute, the event bridge
// (React-portal semantics for poetry CustomEvents: one path above the
// content - the HOME one - with cancellation transferring back), the
// native-events-are-never-bridged boundary, the placeholder-gone drop
// guard, and the turbo:before-cache force-restore net.

const el = (id) => document.getElementById(id)

const dispatchFrom = (element, type, { detail = null, cancelable = false } = {}) => {
  const event = new CustomEvent(type, { detail, bubbles: true, cancelable })

  element.dispatchEvent(event)
  return event
}

beforeEach(() => {
  document.body.innerHTML = `
    <div id="app">
      <div id="root">
        <button id="trigger">open</button>
        <div id="content"><button id="inner">pick</button></div>
        <span id="after">after</span>
      </div>
      <div id="scope"></div>
    </div>`
})

describe("helpers/portal", () => {
  it("round-trips: portal to body leaves a placeholder, restore puts the content back in exact position", () => {
    const content = el("content")

    expect(portalContent(content)).toBe(true)
    expect(isPortaled(content)).toBe(true)
    expect(content.parentNode).toBe(document.body)
    expect(el("root").contains(content)).toBe(false)

    expect(restoreContent(content)).toBe(true)
    expect(isPortaled(content)).toBe(false)
    expect(content.previousElementSibling).toBe(el("trigger"))
    expect(content.nextElementSibling).toBe(el("after"))
    // the placeholder comment is gone (replaceWith swapped it out)
    expect([...el("root").childNodes].some((node) => node.nodeType === Node.COMMENT_NODE)).toBe(false)
  })

  it("is idempotent in both directions", () => {
    const content = el("content")

    expect(portalContent(content)).toBe(true)
    expect(portalContent(content)).toBe(false)

    expect(restoreContent(content)).toBe(true)
    expect(restoreContent(content)).toBe(false)
  })

  it("resolvePortalContainer honors data-poetry-portal-container, defaulting to body", () => {
    expect(resolvePortalContainer(el("root"))).toBe(document.body)

    el("root").setAttribute("data-poetry-portal-container", "scope")

    expect(resolvePortalContainer(el("root"))).toBe(el("scope"))

    el("root").setAttribute("data-poetry-portal-container", "missing")

    expect(resolvePortalContainer(el("root"))).toBe(document.body)

    const content = el("content")

    portalContent(content, { container: el("scope") })

    expect(content.parentNode).toBe(el("scope"))
    restoreContent(content)
  })

  it("bridges poetry CustomEvents to the home path - same detail, portalTarget, exactly ONE path above the content", () => {
    const content = el("content")
    const seenAtRoot = []
    let documentCount = 0

    el("root").addEventListener("poetry:command:select", (event) => {
      seenAtRoot.push({ detail: event.detail, portalTarget: event.portalTarget, target: event.target })
    })
    document.addEventListener("poetry:command:select", () => { documentCount += 1 }, { once: false })

    portalContent(content)
    dispatchFrom(el("inner"), "poetry:command:select", { detail: { value: "x" } })

    expect(seenAtRoot).toHaveLength(1)
    expect(seenAtRoot[0].detail).toEqual({ value: "x" })
    expect(seenAtRoot[0].portalTarget).toBe(el("inner"))
    expect(seenAtRoot[0].target).toBe(el("root"), "the clone dispatches from the home parent")
    expect(documentCount).toBe(1) // the home path only - the portal path was cut at the content

    restoreContent(content)
  })

  it("transfers cancellation from the home-path clone back to the original dispatch", () => {
    const content = el("content")

    el("root").addEventListener("poetry:combobox:select", (event) => event.preventDefault(), { once: true })

    portalContent(content)
    const original = dispatchFrom(el("inner"), "poetry:combobox:select", { cancelable: true })

    expect(original.defaultPrevented).toBe(true)

    restoreContent(content)
  })

  it("bridges poetry:state-change (the setState helper's event) too", () => {
    const content = el("content")
    let seen = 0

    el("root").addEventListener("poetry:state-change", () => { seen += 1 })

    portalContent(content)
    dispatchFrom(el("inner"), "poetry:state-change", { detail: { state: "open" } })

    expect(seen).toBe(1)
    restoreContent(content)
  })

  it("NEVER bridges native events - they stay on the real DOM path for the document-level layers", () => {
    const content = el("content")
    let rootClicks = 0
    let documentClicks = 0

    el("root").addEventListener("click", () => { rootClicks += 1 })
    document.addEventListener("click", () => { documentClicks += 1 }, { once: true })

    portalContent(content)
    el("inner").dispatchEvent(new MouseEvent("click", { bubbles: true }))

    expect(rootClicks).toBe(0) // the root is no longer an ancestor - and we do not fake it
    expect(documentClicks).toBe(1) // the real path (body -> document) still fires once

    restoreContent(content)
  })

  it("stamps the home-effective dir across the move and un-stamps on restore", () => {
    el("root").setAttribute("dir", "rtl")
    const content = el("content")

    portalContent(content)

    expect(content.getAttribute("dir")).toBe("rtl") // closest([dir]) still resolves at body

    restoreContent(content)

    expect(content.hasAttribute("dir")).toBe(false) // the stamp never outlives the portal

    // a content declaring its OWN dir is never touched
    content.setAttribute("dir", "ltr")
    portalContent(content)
    restoreContent(content)

    expect(content.getAttribute("dir")).toBe("ltr")
  })

  it("drops the content instead of stranding it when the origin vanished (morph guard)", () => {
    const content = el("content")

    portalContent(content)
    el("root").remove() // a morph replaced the origin subtree, placeholder included

    expect(restoreContent(content)).toBe(false)
    expect(content.isConnected).toBe(false)
    expect(isPortaled(content)).toBe(false)
  })

  it("turbo:before-cache force-restores everything still portaled (the net)",  => {
    const content = el("content")

    portalContent(content)
    expect(content.parentNode).toBe(document.body)

    document.dispatchEvent(new Event("turbo:before-cache"))

    expect(isPortaled(content)).toBe(false)
    expect(content.previousElementSibling).toBe(el("trigger"))
    expect(content.parentNode).toBe(el("root"))
  })
})
