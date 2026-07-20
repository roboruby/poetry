import { Controller } from "@hotwired/stimulus"

// Optimistic UI for Turbo forms (the hotwire_club-toolbox port).
// The optimistic update is AUTHORED AS A TURBO STREAM inside a <template>
// target - the same vocabulary the server answers in, so prediction and
// truth share one mental model and there is no bespoke DOM patching. On
// turbo:submit-start the template contents are cloned into the document
// and Turbo paints the predicted state immediately; on turbo:submit-end
// the controller reconciles ONLY when the submission failed, by
// appending <turbo-stream action="refresh"> - which must morph (the
// helper documents the turbo-refresh-method=morph meta) so the
// correction is seamless.
//
// THE SERVER CONTRACT (enforced nowhere, so stated everywhere): success
// answers 204 (or a targeted stream for authoritative correction under
// contention) - NEVER a redirect, because a redirect under morph
// refreshes is itself a full reload and defeats the optimism. Failure
// answers 4xx so event.detail.success is false and the refresh restores
// authoritative truth. See poetry-ui docs/optimistic-form.md.
export default class OptimisticFormController extends Controller {
  static targets = ["template"]

  // Applies every template's stream(s). Rapid resubmits inside the window
  // cannot stack duplicate clones; the first paint is still immediate.
  apply() {
    const now = Date.now()
    if (this.lastAppliedAt && now - this.lastAppliedAt < 200) return
    this.lastAppliedAt = now

    this.templateTargets.forEach((template) => {
      document.body.appendChild(template.content.cloneNode(true))
    })
  }

  reconcile(event) {
    // On success the optimistic paint already reflects the new state (or
    // the server's targeted stream corrected it); only a rejection needs
    // the authoritative refresh.
    if (event.detail?.success) return

    document.body.insertAdjacentHTML(
      "beforeend",
      '<turbo-stream action="refresh"></turbo-stream>'
    )
  }
}
