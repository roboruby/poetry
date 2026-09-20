import BaseFormController from "./base_form_controller"

export default class extends BaseFormController {
  static targets = ["total"]
  static values = { url: { type: String, default: "/invoices" }, currency: String }

  recalculate() {
    this.totalTarget.textContent = "0"
  }
}
