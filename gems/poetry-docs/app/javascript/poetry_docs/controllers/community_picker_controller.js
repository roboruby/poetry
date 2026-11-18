import { Controller } from "@hotwired/stimulus"

// The list a Community filter is picked from (the libraries, in the
// dialog the sidebar opens). The server renders every choice with a box
// to tick, the chosen ones first with a rule under them; this narrows
// the list as the search is typed (the rule goes while it is), keeps the count
// of ticked boxes, and on submit sends the ticked values as one field
// with spaces between them, so the address reads ?library=acme+beta.
// Where no script runs
// the form still works: it sends a field per ticked box, which the
// browser's state reads the same.
export default class extends Controller {
  static targets = ["search", "row", "box", "empty", "summary", "joined", "rule"]

  connect() {
    this.count()
  }

  // Shows the rows whose text holds every word typed.
  narrow() {
    const words = this.searchTarget.value.toLowerCase().split(/\s+/).filter(Boolean)
    let shown = 0
    for (const row of this.rowTargets) {
      const match = words.every((word) => row.dataset.text.includes(word))
      row.hidden = !match
      if (match) shown += 1
    }
    this.emptyTarget.hidden = shown > 0
    for (const rule of this.ruleTargets) rule.hidden = words.length > 0
  }

  count() {
    const ticked = this.boxTargets.filter((box) => box.checked).length
    this.summaryTarget.textContent = `${ticked} chosen`
  }

  clear() {
    for (const box of this.boxTargets) box.checked = false
    this.count()
  }

  // One field with the ticked values in place of a field per box, and no
  // field at all when none is ticked. The boxes are given back once the
  // form's fields are read, so a page kept for the Back button holds a
  // list that still works.
  join() {
    const values = this.boxTargets.filter((box) => box.checked).map((box) => box.value)
    for (const box of this.boxTargets) box.disabled = true
    this.joinedTarget.value = values.join(" ")
    this.joinedTarget.disabled = values.length === 0
    setTimeout(() => {
      for (const box of this.boxTargets) box.disabled = false
      this.joinedTarget.disabled = true
    }, 0)
  }
}
