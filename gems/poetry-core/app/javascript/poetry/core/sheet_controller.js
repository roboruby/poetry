import DialogController from "@poetry/controllers/dialog_controller"
import { enterPresence, exitPresence } from "@poetry/controllers/helpers/presence"
import { showModalPreservingScroll } from "@poetry/controllers/helpers/scroll_lock"

// The Sheet (N9 W5b commit 1): the dialog machinery + the presence-hold
// close its dictionary was waiting on since W3b - the Drawer's animated
// path minus the swipe. Everything hard about the overlay is inherited
// (native <dialog> platform trap, backdrop-click discrimination, scroll
// lock, hotkey); this subclass makes the close ANIMATED: exit flips the
// pair to data-closed and HOLDS the dialog through the slide-out
// (data-closed:animate-out in the Sheet dictionary) before the native
// close(). Enter rides enterPresence so the data-starting-style hook
// fires like every other presence consumer.
export default class SheetController extends DialogController {
  #closing = false

  open() {
    showModalPreservingScroll(this.dialogTarget)
    enterPresence(this.dialogTarget)
    this.lockScroll()
  }

  close(event) {
    if (event?.type === "cancel") event.preventDefault() // route Esc through the animated path
    if (this.#closing) return

    this.#closing = true
    exitPresence(this.dialogTarget, {
      onRemove: () => {
        this.#closing = false
        this.dialogTarget.close()
        this.unlockScroll()
      }
    })
  }
}
