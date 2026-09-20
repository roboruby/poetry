import { afterEach, describe, expect, it, vi } from "vitest"
import { installPoetryIdIntegrityCheck, scanForDuplicateIds } from "@poetry/controllers/helpers/id_integrity"

// The composed-DOM duplicate-id tripwire: the scan
// finds duplicates the static lints structurally cannot (composition), the
// installer reports through the injectable channel, and clean documents
// stay silent.
describe("id integrity", () => {
  afterEach(() => {
    document.body.innerHTML = ""
  })

  it("finds duplicate ids and ignores empty ones", () => {
    document.body.innerHTML = `
      <div id="a"></div><div id="b"></div><div id="a"></div>
      <div id=""></div><div id=""></div>
    `

    expect(scanForDuplicateIds()).toEqual(["a"])
  })

  it("stays silent on a clean document", () => {
    document.body.innerHTML = `<div id="a"></div><div id="b"></div>`
    const report = vi.fn()

    const scan = installPoetryIdIntegrityCheck({ report })
    const dups = scan()

    expect(dups).toEqual([])
    expect(report).not.toHaveBeenCalled()
  })

  it("reports through the injectable channel and rescans on turbo events", async () => {
    document.body.innerHTML = `<div id="x"></div>`
    const report = vi.fn()
    installPoetryIdIntegrityCheck({ report })

    document.body.insertAdjacentHTML("beforeend", `<div id="x"></div>`)
    document.dispatchEvent(new Event("turbo:frame-load"))
    await new Promise((resolve) => requestAnimationFrame(() => requestAnimationFrame(resolve)))

    expect(report).toHaveBeenCalledWith(["x"])
  })
})
