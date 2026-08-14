import { Controller } from "@hotwired/stimulus"

// The client-side toast delivery trigger (poetry's no-round-trip path -
// what sonner does with a toast() JS factory, done with server-rendered
// markup): press -> dispatch poetry:toaster:stamp, and the toaster clones
// the addressed <template>'s toast into its region. The toast inside the
// template is byte-for-byte what a Turbo Stream would deliver.
export default class ToastTriggerController extends Controller {
  static events = ["poetry:toaster:stamp"]
  static values = {
    // The <template> element id holding the rendered toast.
    template: String,
    // Optional toaster region id - omit for the page's toaster.
    toaster: String
  }

  fire() {
    window.dispatchEvent(new CustomEvent("poetry:toaster:stamp", {
      detail: { template: this.templateValue, toaster: this.toasterValue || null }
    }))
  }
}
