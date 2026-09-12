import DialogController from "@poetry/controllers/dialog_controller"

export default class extends DialogController {
  static targets = ["confetti"]

  celebrate() {
    this.confettiTarget.hidden = false
  }
}
