import { Controller } from "@hotwired/stimulus"
import { collectionItems } from "@poetry/controllers/helpers/collection"
import { directionOf } from "@poetry/controllers/helpers/direction"
import { enterPresence, exitPresence } from "@poetry/controllers/helpers/presence"
import { setState, stateOf } from "@poetry/controllers/helpers/state"
import { createTypeahead } from "@poetry/controllers/helpers/typeahead"

// The menus-family controller (the DropdownMenu contract's ANCHOR - Radix's
// one @radix-ui/react-menu behind DropdownMenu / ContextMenu / Menubar).
// This owns ONLY what is menu-specific: open/close with the data-open-reason
// initial-focus contract, item activation (the cancelable poetry:menu:select),
// checkbox/radio state (poetry:menu:change), the APG typeahead buffer,
// submenu open/close with hover intent + sibling exclusivity, and the
// cancelable poetry:menu:edge-navigate seam a Menubar coordinator consumes.
// Everything else is composed BY REFERENCE: focus-scope (trap + focus return
// to the trigger), dismissable (topmost-only Esc + outside press, arriving
// here as its "dismiss" event), roving-focus (arrows/Home/End per menu
// level), popper (positioning - markup-owned, untouched here), presence
// (data-open/data-closed flip -> animationend -> hidden).
//
// STRUCTURAL RESOLUTION, no targets: the content is found via the trigger's
// aria-controls id (portal-safe - a Stimulus target cannot cross a portal
// move), items via the collection helper over the family's data-slot suffix
// selectors ([data-slot$=menu-item] etc., so dropdown-menu-*, context-menu-*
// and menubar-* anatomies all resolve), subs via their own aria-controls
// pairs. Content-level listeners are wired programmatically in connect for
// the same portal-safety reason.
//
// The layer stack is ACTIVATED on open: the focus-scope / dismissable /
// roving-focus identifiers are appended to the content's data-controller (a
// statically-connected trap or dismiss layer on a hidden menu would steal
// focus at page load and swallow topmost-Esc). Close reverses: presence exit
// -> hidden -> tokens removed -> focus-scope's disconnect restores focus to
// the trigger. Each open sub level adds its own dismissable layer (the
// close-one-level-at-a-time Esc chain for free) + its own roving group; subs
// join the ROOT focus scope (no nested traps - Radix-exact).
// Both family spellings resolve: dropdown-menu-* / context-menu-* share the
// "menu-" suffix; menubar-* is its own word (menubar-item does NOT end with
// "menu-item"), so every part selector carries the pair.
const menuSlot = (suffix) => `[data-slot$="menu-${suffix}"], [data-slot$="menubar-${suffix}"]`
const MENU_SELECTOR = '[role="menu"]'
const TRIGGER_SELECTOR = menuSlot("trigger")
const SUB_SELECTOR = menuSlot("sub")
const SUB_TRIGGER_SELECTOR = menuSlot("sub-trigger")
const SUB_CONTENT_SELECTOR = menuSlot("sub-content")
const CHECKBOX_ITEM_SELECTOR = menuSlot("checkbox-item")
const RADIO_ITEM_SELECTOR = menuSlot("radio-item")
const RADIO_GROUP_SELECTOR = menuSlot("radio-group")
const ITEM_SELECTOR = [
  menuSlot("item"),
  CHECKBOX_ITEM_SELECTOR,
  RADIO_ITEM_SELECTOR,
  SUB_TRIGGER_SELECTOR
].join(", ")

// The family event namespace (poetry:menu:open|closed|select|change|edge-navigate).
const EVENT_PREFIX = "poetry:menu"

const ROVING = "poetry--core--roving-focus"
const ROVING_ACTION = `keydown->${ROVING}#keydown`
const CONTENT_LAYER_CONTROLLERS = ["poetry--core--focus-scope", "poetry--core--dismissable", ROVING]
const SUB_LAYER_CONTROLLERS = ["poetry--core--dismissable", ROVING]

// Hover intent (the contract's spec): open after 100ms of rest on a
// sub-trigger; close 300ms after the pointer leaves the sub pair - entering
// the sub-content (or the trigger again) within the window cancels it, which
// is the simple-closeDelay answer to the grace-area open question.
const SUB_OPEN_DELAY = 100
const SUB_CLOSE_DELAY = 300

export default class MenuController extends Controller {
  static values = {
    open: { type: Boolean, default: false },
    modal: { type: Boolean, default: true },
    loop: { type: Boolean, default: false },
    typeaheadTimeout: { type: Number, default: 1000 },
    closeOnSelect: { type: Boolean, default: true }
  }

  #connected = false
  #wired = []
  #claimed = new WeakSet() // events already handled once (data-action + delegation both firing)
  #suppressRestore = false
  #cancelExit = null
  #typeahead = createTypeahead()
  #subOpenTimers = new Map()
  #subCloseTimers = new Map()

  connect() {
    const content = this.#content()

    if (content) this.#wireContent(content)

    this.#connected = true

    // Reconcile-on-connect: the server may own the open state (Turbo Stream
    // re-render). DOM attributes win; the layer stack catches up.
    if (this.#isOpen()) {
      if (content) this.#activateLayers(content)
      this.openValue = true
    } else if (this.openValue) {
      this.#show("trigger-press", { focus: false })
    }
  }

  disconnect() {
    this.#connected = false

    for (const [target, type, listener] of this.#wired) target.removeEventListener(type, listener)

    this.#wired = []

    for (const timer of this.#subOpenTimers.values()) window.clearTimeout(timer)
    for (const timer of this.#subCloseTimers.values()) window.clearTimeout(timer)

    this.#subOpenTimers.clear()
    this.#subCloseTimers.clear()
    this.#typeahead.reset()
    this.#cancelExit?.()
    this.#cancelExit = null
  }

  // Controllable state: a host (outlet / Turbo Stream / URL param) may own
  // the open value; flipping the attribute drives the same machine.
  openValueChanged(value) {
    if (!this.#connected) return

    if (value && !this.#isOpen()) this.#show("trigger-press")
    else if (!value && this.#isOpen()) this.#hide("none")
  }

  // --- trigger actions ---

  toggle() {
    if (this.#isOpen()) this.#hide("trigger-press")
    else this.#show("trigger-press")
  }

  // Enter / Space / ArrowDown: open + focus FIRST enabled item; ArrowUp:
  // open + focus LAST (the APG menu-button map). preventDefault also
  // suppresses the button's synthetic click, so toggle cannot double-fire.
  triggerKeydown(event) {
    if (this.#isOpen()) return

    if (event.key === "Enter" || event.key === " " || event.key === "ArrowDown") {
      event.preventDefault()
      this.#show("list-navigation", { seed: "first" })
    } else if (event.key === "ArrowUp") {
      event.preventDefault()
      this.#show("list-navigation", { seed: "last" })
    }
  }

  // --- programmatic API (the family surface Menubar's coordinator calls) ---

  // focus: false is the coordinator's pointer-toggle contract (a menubar
  // pointer-open leaves focus on the trigger; keyboard-open focuses an item).
  open(reason = "trigger-press", { focus = true, seed = null } = {}) {
    if (reason instanceof Event) this.#show("trigger-press")
    else this.#show(reason, { focus, seed })
  }

  // restoreFocus: false is the hover-slide/edge-navigate contract (the
  // outgoing menu must not yank focus back mid-swap).
  close(reason = "none", { restoreFocus = true } = {}) {
    if (reason instanceof Event) this.#hide("none")
    else this.#hide(reason, { restoreFocus })
  }

  // --- item activation ---

  // click/Enter/Space unified. Kept as a public action for markup-declared
  // data-action; the delegated content listener claims the event first, so
  // both paths never double-activate.
  activate(event) {
    if (this.#claim(event)) return

    const origin = event.currentTarget instanceof Element ? event.currentTarget : event.target
    const item = origin instanceof Element ? origin.closest(ITEM_SELECTOR) : null

    if (!item || this.#isDisabled(item)) return

    if (item.matches(SUB_TRIGGER_SELECTOR)) this.#showSub(item, { focusFirst: false })
    else this.#activate(item)
  }

  // --- content keydown (Enter/Space, submenu arrows, edges, Tab, typeahead) ---

  keydown(event) {
    if (this.#claim(event)) return
    if (!this.#isOpen()) return

    const content = this.#content()

    if (!content) return

    const target = event.target instanceof Element ? event.target : content
    const menu = target.closest(MENU_SELECTOR) ?? content
    const item = target.closest(ITEM_SELECTOR)

    switch (event.key) {
      case "Tab":
        // Menus are at most ONE Tab stop: close and let focus move on
        // naturally. The still-attached focus trap must not see this Tab.
        event.stopImmediatePropagation()
        this.#hide("none", { restoreFocus: false })
        return
      case "Enter":
      case " ":
        if (event.key === " " && this.#typeahead.pending()) break // space extends a live search

        event.preventDefault()

        if (!item || this.#isDisabled(item)) return
        if (item.matches(SUB_TRIGGER_SELECTOR)) this.#showSub(item, { focusFirst: true })
        else this.#activate(item)

        return
      case "ArrowRight":
      case "ArrowLeft":
        this.#horizontalKeydown(event, { content, menu, item })
        return
      default:
        break
    }

    if (event.key.length === 1 && !event.ctrlKey && !event.altKey && !event.metaKey) {
      event.preventDefault()
      this.#search(event.key, menu)
    }
  }

  // --- submenu actions (pointer + markup-declared) ---

  subEnter(event) {
    const subTrigger = this.#subTriggerFrom(event)

    if (subTrigger) this.#subPointerEnter(subTrigger)
  }

  subLeave(event) {
    const subTrigger = this.#subTriggerFrom(event)
    const related = event.relatedTarget instanceof Element ? event.relatedTarget : null

    if (subTrigger) this.#subPointerLeave(subTrigger, related)
  }

  openSub(event) {
    if (this.#claim(event)) return

    const subTrigger = this.#subTriggerFrom(event)

    if (subTrigger && !this.#isDisabled(subTrigger)) this.#showSub(subTrigger, { focusFirst: false })
  }

  closeSub(event) {
    const subTrigger = this.#subTriggerFrom(event)

    if (subTrigger) this.#closeSubTree(subTrigger, { focusTrigger: false })
  }

  // --- open / close ---

  #show(reason, { focus = true, seed = null } = {}) {
    const content = this.#content()

    if (!content || this.#isOpen()) return

    this.#cancelExit?.()
    this.#cancelExit = null
    this.#suppressRestore = false

    const trigger = this.#trigger()

    content.hidden = false
    content.setAttribute("data-open-reason", reason)
    if (seed) content.setAttribute("data-open-seed", seed)
    else content.removeAttribute("data-open-seed")
    // ContextMenu's trigger SURFACE is not a widget: aria-expanded is only
    // flipped where the server declared it (DropdownMenu button, Menubar
    // menuitem) - never introduced onto a role-less span.
    if (trigger?.hasAttribute("aria-expanded")) trigger.setAttribute("aria-expanded", "true")
    if (trigger) setState(trigger, "popup-open")
    enterPresence(content)
    this.#activateLayers(content)
    this.openValue = true

    // The layer controllers connect on the attribute-mutation microtask;
    // initial focus must land AFTER focus-scope snapshots the trigger (its
    // focus-return target), so it rides one microtask behind.
    queueMicrotask(() => {
      if (!this.#isOpen()) return
      if (focus) this.#applyInitialFocus(content, seed)

      this.dispatch("open", { prefix: EVENT_PREFIX, detail: seed ? { reason, seed } : { reason } })
    })
  }

  #hide(reason, { restoreFocus = true } = {}) {
    const content = this.#content()

    if (!content || !this.#isOpen()) return

    // The whole chain closes: subs first (no focus juggling on the way down).
    for (const subTrigger of this.#openSubTriggersIn(content)) {
      this.#closeSubTree(subTrigger, { focusTrigger: false })
    }

    this.#typeahead.reset()
    // Focus return to the trigger is focus-scope's disconnect job - vetoed
    // for Tab-out and for outside interaction on a non-modal menu (Radix's
    // non-modal semantics: focus follows the click).
    this.#suppressRestore = !restoreFocus || (reason === "outside-press" && !this.modalValue)

    const trigger = this.#trigger()

    if (trigger?.hasAttribute("aria-expanded")) trigger.setAttribute("aria-expanded", "false")
    if (trigger) setState(trigger, "popup-closed")
    content.removeAttribute("data-open-reason")
    content.removeAttribute("data-open-seed")
    this.openValue = false

    this.#cancelExit = exitPresence(content, {
      onRemove: () => {
        this.#cancelExit = null
        content.hidden = true
        this.#removeControllers(content, CONTENT_LAYER_CONTROLLERS)
        this.dispatch("closed", { prefix: EVENT_PREFIX, detail: { reason } })
      }
    })
  }

  // Initial focus per the family data-open-reason contract: trigger-press ->
  // the content itself (roving arms on the first arrow - Radix parity);
  // list-navigation seeds via data-open-seed: "first" / "last" -> first /
  // last enabled item.
  #applyInitialFocus(content, seed) {
    if (seed === "first") this.#enabledItems(content)[0]?.focus()
    else if (seed === "last") this.#enabledItems(content).at(-1)?.focus()
    else content.focus()
  }

  // --- activation ---

  #activate(item) {
    const kind = item.matches(CHECKBOX_ITEM_SELECTOR)
      ? "checkbox"
      : item.matches(RADIO_ITEM_SELECTOR) ? "radio" : "item"
    const value = item.dataset.value ?? null

    // Checkbox/radio state commits BEFORE the select event, so a canceled
    // close still keeps the new state (the contract's activation semantics).
    if (kind === "checkbox") {
      const checked = item.getAttribute("aria-checked") !== "true"

      this.#writeChecked(item, checked)
      this.dispatch("change", {
        prefix: EVENT_PREFIX, target: item, detail: { kind, value, checked, group_value: null }
      })
    } else if (kind === "radio") {
      const group = item.closest(RADIO_GROUP_SELECTOR)
      const radios = group ? Array.from(group.querySelectorAll(RADIO_ITEM_SELECTOR)) : [item]

      for (const radio of radios) this.#writeChecked(radio, radio === item)

      group?.setAttribute("data-value", value ?? "")
      this.dispatch("change", {
        prefix: EVENT_PREFIX, target: item, detail: { kind, value, checked: true, group_value: value }
      })
    }

    // The cancelable select (Radix's onSelect + preventDefault as an event):
    // a canceled select keeps the menu open.
    const select = this.dispatch("select", {
      prefix: EVENT_PREFIX,
      target: item,
      cancelable: true,
      detail: { item, value, variant: item.dataset.variant ?? "default", kind }
    })

    if (select.defaultPrevented) return
    if (!this.#closeOnSelectFor(item)) return

    this.#hide("item-press")
  }

  // aria-checked and data-checked/data-unchecked are written TOGETHER, never separately.
  #writeChecked(item, checked) {
    item.setAttribute("aria-checked", String(checked))
    setState(item, checked ? "checked" : "unchecked")
  }

  // Per-item close_on_select overrides the menu-level default (checkbox /
  // radio preference toggles commonly declare data-close-on-select="false").
  #closeOnSelectFor(item) {
    const override = item.dataset.closeOnSelect

    if (override !== undefined) return override !== "false"

    return this.closeOnSelectValue
  }

  // --- horizontal arrows: submenus + the Menubar edge seam ---

  #horizontalKeydown(event, { content, menu, item }) {
    const rtl = directionOf(menu) === "rtl"
    const openKey = rtl ? "ArrowLeft" : "ArrowRight"

    if (event.key === openKey) {
      if (item?.matches(SUB_TRIGGER_SELECTOR) && !this.#isDisabled(item)) {
        event.preventDefault()
        this.#showSub(item, { focusFirst: true })
        return
      }

      // No submenu meaning at the ROOT level only -> the Menubar seam.
      if (menu === content) this.#edgeNavigate(event)
      return
    }

    // The close arrow: inside a sub it closes one level back to its
    // sub-trigger; at the root there is nothing to close -> the edge seam.
    // NEVER fired from inside a sub (ArrowLeft there means close-sub).
    if (menu !== content) {
      event.preventDefault()

      const subTrigger = this.#subTriggerFor(menu)

      if (subTrigger) this.#closeSubTree(subTrigger, { focusTrigger: true })
    } else {
      this.#edgeNavigate(event)
    }
  }

  // Cancelable, bubbling, from the ROOT content only. direction is the
  // PHYSICAL key; the consumer (the Menubar coordinator) applies RTL
  // mapping. Unconsumed (standalone DropdownMenu) -> no-op.
  #edgeNavigate(event) {
    const direction = event.key === "ArrowRight" ? "right" : "left"
    const dispatched = this.dispatch("edge-navigate", {
      prefix: EVENT_PREFIX,
      target: this.#content(),
      cancelable: true,
      detail: { direction }
    })

    if (dispatched.defaultPrevented) event.preventDefault()
  }

  // --- typeahead (APG: 1s buffer, wrap, same-letter cycling, per level) ---
  // The algorithm lives in helpers/typeahead.js (shared with Select); the
  // menu keeps only its own wiring: enabled items per level, the focused
  // item as the search anchor, and focus as the match action.

  #search(key, menu) {
    const items = this.#enabledItems(menu)
    const active = document.activeElement instanceof Element
      ? document.activeElement.closest(ITEM_SELECTOR)
      : null
    const match = this.#typeahead.search(key, items, { active, timeout: this.typeaheadTimeoutValue })

    match?.focus()
  }

  // --- submenus ---

  #showSub(subTrigger, { focusFirst = false } = {}) {
    if (this.#isDisabled(subTrigger)) return

    const subContent = this.#subContentFor(subTrigger)

    if (!subContent) return

    if (!subTrigger.hasAttribute("data-popup-open")) {
      // Sibling exclusivity: at most ONE open sub per level - the open-sub
      // chain is a path.
      const menu = subTrigger.closest(MENU_SELECTOR)

      for (const sibling of this.#openSubTriggersIn(menu ?? this.#content(), { level: menu })) {
        if (sibling !== subTrigger) this.#closeSubTree(sibling, { focusTrigger: false })
      }

      subContent.hidden = false
      subTrigger.setAttribute("aria-expanded", "true")
      setState(subTrigger, "popup-open")
      enterPresence(subContent)

      // Each sub level = its own dismissable layer (topmost-only Esc closes
      // just the deepest level) + its own roving group; NO focus-scope (subs
      // join the root trap) and the sub's popper root is markup-owned.
      subContent.setAttribute("data-poetry--core--dismissable-disable-outside-pointer-events-value", "false")
      this.#wireRoving(subContent)
      this.#addControllers(subContent, SUB_LAYER_CONTROLLERS)
    }

    if (focusFirst) this.#enabledItems(subContent)[0]?.focus()
  }

  #closeSubTree(subTrigger, { focusTrigger = false } = {}) {
    this.#cancelSubOpen(subTrigger)
    this.#cancelSubClose(subTrigger)

    if (!subTrigger.hasAttribute("data-popup-open")) return

    const subContent = this.#subContentFor(subTrigger)

    if (subContent) {
      for (const nested of this.#openSubTriggersIn(subContent)) {
        this.#closeSubTree(nested, { focusTrigger: false })
      }
    }

    subTrigger.setAttribute("aria-expanded", "false")
    setState(subTrigger, "popup-closed")

    if (subContent) {
      exitPresence(subContent, {
        onRemove: () => {
          subContent.hidden = true
          this.#removeControllers(subContent, SUB_LAYER_CONTROLLERS)
        }
      })
    }

    if (focusTrigger) subTrigger.focus()
  }

  // --- submenu hover intent ---

  #subPointerEnter(subTrigger) {
    this.#cancelSubClose(subTrigger)

    for (const ancestor of this.#ancestorSubTriggers(subTrigger)) this.#cancelSubClose(ancestor)

    if (this.#isDisabled(subTrigger) || subTrigger.hasAttribute("data-popup-open")) return
    if (this.#subOpenTimers.has(subTrigger)) return

    this.#subOpenTimers.set(subTrigger, window.setTimeout(() => {
      this.#subOpenTimers.delete(subTrigger)
      this.#showSub(subTrigger, { focusFirst: false }) // hover-open never moves focus
    }, SUB_OPEN_DELAY))
  }

  #subPointerLeave(subTrigger, related) {
    this.#cancelSubOpen(subTrigger)

    const subContent = this.#subContentFor(subTrigger)

    if (related && (subTrigger.contains(related) || subContent?.contains(related))) return
    if (subTrigger.hasAttribute("data-popup-open")) this.#scheduleSubClose(subTrigger)
  }

  #scheduleSubClose(subTrigger) {
    this.#cancelSubClose(subTrigger)
    this.#subCloseTimers.set(subTrigger, window.setTimeout(() => {
      this.#subCloseTimers.delete(subTrigger)
      this.#closeSubTree(subTrigger, { focusTrigger: false })
    }, SUB_CLOSE_DELAY))
  }

  #cancelSubOpen(subTrigger) {
    const timer = this.#subOpenTimers.get(subTrigger)

    if (timer === undefined) return

    window.clearTimeout(timer)
    this.#subOpenTimers.delete(subTrigger)
  }

  #cancelSubClose(subTrigger) {
    const timer = this.#subCloseTimers.get(subTrigger)

    if (timer === undefined) return

    window.clearTimeout(timer)
    this.#subCloseTimers.delete(subTrigger)
  }

  // --- content wiring (programmatic: portal-safe, no data-action required) ---

  #wireContent(content) {
    this.#listen(content, "keydown", (event) => this.keydown(event))
    this.#listen(content, "click", this.#onClick)
    this.#listen(content, "pointerover", this.#onPointerover)
    this.#listen(content, "pointerout", this.#onPointerout)
    this.#listen(content, "poetry--core--dismissable:dismiss", this.#onDismiss)
    this.#listen(content, "poetry--core--focus-scope:mount-auto-focus", this.#onMountAutoFocus)
    this.#listen(content, "poetry--core--focus-scope:unmount-auto-focus", this.#onUnmountAutoFocus)
  }

  #listen(target, type, listener) {
    target.addEventListener(type, listener)
    this.#wired.push([target, type, listener])
  }

  #onClick = (event) => {
    if (this.#claim(event)) return

    const item = event.target instanceof Element ? event.target.closest(ITEM_SELECTOR) : null

    if (!item || this.#isDisabled(item)) return

    if (item.matches(SUB_TRIGGER_SELECTOR)) this.#showSub(item, { focusFirst: false })
    else this.#activate(item)
  }

  // Esc / outside-press arrive as the dismissable layer's dismiss event: the
  // root content's layer closes the menu; a sub-content's layer (the topmost
  // while a sub is open) closes just that level - Esc focuses ITS sub-trigger.
  #onDismiss = (event) => {
    const target = event.target instanceof Element ? event.target : null

    if (!target) return

    const escaped = event.detail?.originalEvent?.type === "keydown"

    if (target === this.#content()) {
      this.#hide(escaped ? "escape-key" : "outside-press")
      return
    }

    const subContent = target.closest(SUB_CONTENT_SELECTOR)
    const subTrigger = subContent && this.#subTriggerFor(subContent)

    if (subTrigger) this.#closeSubTree(subTrigger, { focusTrigger: escaped })
  }

  // The menu owns initial focus (per data-open-reason), not focus-scope.
  #onMountAutoFocus = (event) => {
    if (event.target === this.#content()) event.preventDefault()
  }

  #onUnmountAutoFocus = (event) => {
    if (event.target === this.#content() && this.#suppressRestore) event.preventDefault()
  }

  #onPointerover = (event) => {
    const target = event.target instanceof Element ? event.target : null

    if (!target) return

    // Travel into an open sub keeps its whole chain alive (the grace window).
    for (const subTrigger of this.#ancestorSubTriggers(target)) this.#cancelSubClose(subTrigger)

    const related = event.relatedTarget instanceof Element ? event.relatedTarget : null
    const subTrigger = target.closest(SUB_TRIGGER_SELECTOR)

    if (subTrigger) {
      if (!related || !subTrigger.contains(related)) this.#subPointerEnter(subTrigger)

      return
    }

    // Hovering a plain sibling item schedules the open sub at that level to close.
    const item = target.closest(ITEM_SELECTOR)

    if (!item) return

    const menu = item.closest(MENU_SELECTOR)

    if (!menu) return

    for (const open of this.#openSubTriggersIn(menu, { level: menu })) this.#scheduleSubClose(open)
  }

  #onPointerout = (event) => {
    const target = event.target instanceof Element ? event.target : null

    if (!target) return

    const related = event.relatedTarget instanceof Element ? event.relatedTarget : null
    const subTrigger = target.closest(SUB_TRIGGER_SELECTOR)

    if (subTrigger && (!related || !subTrigger.contains(related))) {
      this.#subPointerLeave(subTrigger, related)
    }

    const subContent = target.closest(SUB_CONTENT_SELECTOR)

    if (subContent && (!related || !subContent.contains(related))) {
      const owner = this.#subTriggerFor(subContent)

      if (owner && !(related && owner.contains(related)) && owner.hasAttribute("data-popup-open")) {
        this.#scheduleSubClose(owner)
      }
    }
  }

  // --- the layer stack ---

  #activateLayers(content) {
    content.setAttribute("data-poetry--core--focus-scope-trapped-value", String(this.modalValue))
    content.setAttribute(
      "data-poetry--core--dismissable-disable-outside-pointer-events-value", String(this.modalValue)
    )
    this.#wireRoving(content)
    this.#addControllers(content, CONTENT_LAYER_CONTROLLERS)
  }

  // Menus are roving-focus's DEFAULT mode: vertical, manageTabindex TRUE
  // (items tabindex=-1, real focus roves - the mode Accordion's
  // focus-nav-only flag contrasted against). loop forwards the menu value
  // (Radix Menu default false).
  #wireRoving(element) {
    element.setAttribute(`data-${ROVING}-orientation-value`, "vertical")
    element.setAttribute(`data-${ROVING}-manage-tabindex-value`, "true")
    element.setAttribute(`data-${ROVING}-loop-value`, String(this.loopValue))

    const action = element.getAttribute("data-action") ?? ""

    if (!action.includes(ROVING_ACTION)) {
      element.setAttribute("data-action", `${action} ${ROVING_ACTION}`.trim())
    }
  }

  #addControllers(element, identifiers) {
    const tokens = (element.getAttribute("data-controller") ?? "").split(/\s+/).filter(Boolean)

    for (const identifier of identifiers) {
      if (!tokens.includes(identifier)) tokens.push(identifier)
    }

    element.setAttribute("data-controller", tokens.join(" "))
  }

  #removeControllers(element, identifiers) {
    const tokens = (element.getAttribute("data-controller") ?? "")
      .split(/\s+/)
      .filter((token) => token && !identifiers.includes(token))

    element.setAttribute("data-controller", tokens.join(" "))
  }

  // --- structural resolution (the DOM is the registry; ids are the seams) ---

  #trigger() {
    for (const candidate of this.element.querySelectorAll(TRIGGER_SELECTOR)) {
      if (!candidate.closest(MENU_SELECTOR)) return candidate
    }

    return null
  }

  #content() {
    const id = this.#trigger()?.getAttribute("aria-controls")

    return id ? document.getElementById(id) : null
  }

  #isOpen() {
    const content = this.#content()

    return Boolean(content) && stateOf(content) === "open"
  }

  #subContentFor(subTrigger) {
    const id = subTrigger.getAttribute("aria-controls")
    const byId = id ? document.getElementById(id) : null

    return byId ?? subTrigger.closest(SUB_SELECTOR)?.querySelector(SUB_CONTENT_SELECTOR) ?? null
  }

  #subTriggerFor(subContent) {
    if (subContent.id) {
      for (const candidate of document.querySelectorAll(SUB_TRIGGER_SELECTOR)) {
        if (candidate.getAttribute("aria-controls") === subContent.id) return candidate
      }
    }

    return subContent.closest(SUB_SELECTOR)?.querySelector(SUB_TRIGGER_SELECTOR) ?? null
  }

  #subTriggerFrom(event) {
    const origin = event?.currentTarget instanceof Element ? event.currentTarget : event?.target

    return origin instanceof Element ? origin.closest(SUB_TRIGGER_SELECTOR) : null
  }

  // Open sub-triggers within a scope; level restricts to one menu level.
  #openSubTriggersIn(scope, { level = null } = {}) {
    if (!scope) return []

    return Array.from(scope.querySelectorAll(SUB_TRIGGER_SELECTOR)).filter((subTrigger) =>
      subTrigger.hasAttribute("data-popup-open") && (!level || subTrigger.closest(MENU_SELECTOR) === level))
  }

  #ancestorSubTriggers(node) {
    const ancestors = []
    let subContent = node.closest(SUB_CONTENT_SELECTOR)

    while (subContent) {
      const subTrigger = this.#subTriggerFor(subContent)

      if (!subTrigger) break

      ancestors.push(subTrigger)
      subContent = subTrigger.closest(SUB_CONTENT_SELECTOR)
    }

    return ancestors
  }

  // Items of ONE menu level, in DOM order, disabled filtered at query time.
  #itemsOf(menu) {
    return collectionItems(menu, ITEM_SELECTOR).filter((item) => item.closest(MENU_SELECTOR) === menu)
  }

  #enabledItems(menu) {
    return this.#itemsOf(menu).filter((item) => !this.#isDisabled(item))
  }

  #isDisabled(item) {
    return item.hasAttribute("data-disabled") || item.getAttribute("aria-disabled") === "true"
  }

  #claim(event) {
    if (this.#claimed.has(event)) return true

    this.#claimed.add(event)

    return false
  }
}
