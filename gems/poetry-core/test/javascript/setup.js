// jsdom does not implement HTMLDialogElement's methods (a known gap). This
// is a MINIMAL test shim so poetry's controller logic (state sync, backdrop
// discrimination, scroll lock) is unit-testable; the platform's real
// behavior - top-layer, focus trap, focus return - is covered by the
// browser-verification loop, never asserted through jsdom.
if (typeof HTMLDialogElement !== "undefined" && !HTMLDialogElement.prototype.showModal) {
  HTMLDialogElement.prototype.show = function () {
    this.setAttribute("open", "")
  }
  HTMLDialogElement.prototype.showModal = function () {
    this.setAttribute("open", "")
  }
  HTMLDialogElement.prototype.close = function (returnValue) {
    if (returnValue !== undefined) this.returnValue = returnValue
    this.removeAttribute("open")
    this.dispatchEvent(new Event("close"))
  }
}
