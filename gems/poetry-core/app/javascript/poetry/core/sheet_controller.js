import DialogController from "@poetry/controllers/dialog_controller"
import { enterPresence } from "@poetry/controllers/helpers/presence"

// The Sheet: the dialog machinery, animated end to end. Everything hard
// about the overlay is inherited (native <dialog> platform trap,
// backdrop-click discrimination, scroll lock, hotkey) - including the
// presence-hold close, which the base controller owns (exit flips the
// pair to data-closed and holds the dialog through the slide-out before
// the native close()). This subclass only upgrades the ENTER: open rides
// enterPresence so the data-starting-style hook fires like every other
// presence consumer.
export default class SheetController extends DialogController {
  open() {
    this.dialogTarget.showModal()
    enterPresence(this.dialogTarget)
    this.lockScroll()
  }
}
