import { beforeEach, describe, expect, it } from "vitest"
import { tabbableWithin } from "@poetry/controllers/helpers/tabbable"

// The tabbable walk's radio-group rule: a
// radio GROUP is one tab stop - the checked radio represents it; an
// all-unchecked group is represented by its first radio. Everything else
// about the walk is pinned by the focus-scope suite that consumes it.

const ids = (elements) => elements.map((element) => element.id)

describe("helpers/tabbable radio groups", () => {
  beforeEach(() => {
    document.body.innerHTML = ""
  })

  it("the checked radio represents its group; unchecked siblings are not stops", () => {
    document.body.innerHTML = `
      <button id="before">b</button>
      <input type="radio" name="plan" id="a">
      <input type="radio" name="plan" id="b" checked>
      <input type="radio" name="plan" id="c">
      <button id="after">a</button>`

    expect(ids(tabbableWithin(document.body))).toEqual(["before", "b", "after"])
  })

  it("an all-unchecked group collapses to its FIRST radio", () => {
    document.body.innerHTML = `
      <input type="radio" name="plan" id="a">
      <input type="radio" name="plan" id="b">
      <input type="radio" name="plan" id="c">`

    expect(ids(tabbableWithin(document.body))).toEqual(["a"])
  })

  it("different names are different groups; nameless radios are individual stops", () => {
    document.body.innerHTML = `
      <input type="radio" name="plan" id="plan-a">
      <input type="radio" name="seat" id="seat-a" checked>
      <input type="radio" name="seat" id="seat-b">
      <input type="radio" id="bare">`

    expect(ids(tabbableWithin(document.body))).toEqual(["plan-a", "seat-a", "bare"])
  })

  it("same-name radios in DIFFERENT forms are separate groups (the namedItem quirk)", () => {
    document.body.innerHTML = `
      <form><input type="radio" name="plan" id="f1-a"><input type="radio" name="plan" id="f1-b" checked></form>
      <form><input type="radio" name="plan" id="f2-a"></form>`

    expect(ids(tabbableWithin(document.body))).toEqual(["f1-b", "f2-a"])
  })

  it("checkboxes and text inputs are untouched by the radio rule", () => {
    document.body.innerHTML = `
      <input type="checkbox" name="opts" id="check-a">
      <input type="checkbox" name="opts" id="check-b">
      <input type="text" name="plan" id="text-a">`

    expect(ids(tabbableWithin(document.body))).toEqual(["check-a", "check-b", "text-a"])
  })
})
