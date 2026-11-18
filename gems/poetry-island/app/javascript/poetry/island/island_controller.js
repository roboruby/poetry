import { Controller } from "@hotwired/stimulus"

/**
 * Island: a bounded client mount inside server-rendered HTML. The server
 * renders the shell, the element's content before and without the module;
 * on connect the controller imports the island's module through the
 * importmap and mounts it in a root beside the shell, which steps aside
 * while the island is up. A morph refresh leaves the island alone and
 * hands it the server's new props; a cached snapshot's dead root is
 * cleared on connect; a preview shows the shell; a failed import or mount
 * leaves the shell in place and says so.
 *
 * A module exports mount(element, props) and returns { unmount, update? }.
 * The props are the island's JSON script, plus input (the hidden input
 * rendered with name:, or null) and focus (true when the shell had focus).
 */
export default class IslandController extends Controller {
  static targets = ["shell", "input"]
  static values = {
    // The importmap specifier of the module.
    import: String,
    // fill paints the shell's box; flow takes the shell's place.
    mode: { type: String, default: "fill" }
  }
  static events = ["mount", "error"]

  /**
   * How a module loads: a dynamic import by specifier, resolved by the
   * importmap. A test replaces it.
   * @param {string} specifier the importmap specifier
   * @returns {Promise<Object>} the module
   */
  static load = (specifier) => import(/* @vite-ignore */ specifier)

  /** Clears what a cached snapshot kept, guards against a morph and mounts. */
  connect() {
    this.#clear()
    this.guard = (event) => this.#morph(event)
    this.element.addEventListener("turbo:before-morph-element", this.guard)
    this.mount()
  }

  /** Unmounts the island and drops the morph guard. */
  disconnect() {
    this.element.removeEventListener("turbo:before-morph-element", this.guard)
    this.unmount()
  }

  /**
   * Imports the module and mounts it beside the shell. A Turbo preview, a
   * failed import and a failed mount all leave the shell.
   * @returns {Promise<void>} settles once the island is up or the shell stays
   */
  async mount() {
    if (document.documentElement.hasAttribute("data-turbo-preview")) return
    const token = (this.token = {})
    let module
    try {
      module = await this.constructor.load(this.importValue)
      if (typeof module?.mount !== "function") throw new TypeError(`${this.importValue} exports no mount(element, props)`)
    } catch (error) {
      this.#fail("load", error)
      return
    }
    if (this.token !== token || !this.element.isConnected) return
    const focus = this.hasShellTarget && this.shellTarget.contains(document.activeElement)
    const root = document.createElement("div")
    root.dataset.islandRoot = ""
    if (this.modeValue !== "flow") root.style.cssText = "position:absolute;inset:0"
    this.element.append(root)
    try {
      this.island = module.mount(root, this.#props({ focus }))
    } catch (error) {
      root.remove()
      this.#fail("mount", error)
      return
    }
    this.root = root
    this.element.dataset.islandMounted = ""
    this.dispatch("mount", { detail: { import: this.importValue } })
  }

  /** Unmounts the island, removes its root and shows the shell again. */
  unmount() {
    this.token = null
    if (!this.island) return
    const island = this.island
    this.island = null
    try {
      island.unmount?.()
    } catch (error) {
      console.error(`poetry island ${this.importValue} failed to unmount`, error)
    }
    this.root?.remove()
    this.root = null
    delete this.element.dataset.islandMounted
  }

  /**
   * The props a module receives: the island's JSON script, the hidden
   * input (or null) and whatever the caller adds.
   * @param {Object} extra props added for this call
   * @param {Element} element the island element to read the JSON script from
   * @returns {Object} the props
   */
  #props(extra = {}, element = this.element) {
    const script = element.querySelector(':scope > script[type="application/json"]')
    let parsed = {}
    try {
      parsed = JSON.parse(script?.textContent || "{}")
    } catch {
      parsed = {}
    }
    return { ...parsed, input: this.hasInputTarget ? this.inputTarget : null, ...extra }
  }

  /**
   * A morph refresh keeps the island: the element is left as it is and the
   * module receives the server's new props through update.
   * @param {CustomEvent} event turbo:before-morph-element
   */
  #morph(event) {
    if (event.target !== this.element) return
    event.preventDefault()
    this.island?.update?.(this.#props({}, event.detail.newElement))
  }

  /** Removes what a cached snapshot kept: a dead root and the mounted mark. */
  #clear() {
    this.element.querySelectorAll(":scope > [data-island-root]").forEach((stale) => stale.remove())
    delete this.element.dataset.islandMounted
  }

  /**
   * Reports a failed load or mount: the shell stays, the console and an
   * event say why.
   * @param {string} stage "load" or "mount"
   * @param {Error} error what went wrong
   */
  #fail(stage, error) {
    console.error(`poetry island ${this.importValue} failed to ${stage}; the shell stays`, error)
    this.dispatch("error", { detail: { import: this.importValue, stage, error } })
  }
}
