# poetry overlays components

Contracts generated from the registry. `RULE` lines are constraints,
not suggestions. Options are keywords; content is the block.

## alert_dialog (`poetry_alert_dialog`)

Class: Poetry::Ui::AlertDialog::Component - BEM block `poetry-ui-alert_dialog`.
Slot REQUIRED: with_title (the accessible name) - a call without it raises.
Slot REQUIRED: with_description (the alertdialog must explain itself) - a call without it raises.
Slot REQUIRED: with_action (the confirming choice) - a call without it raises.
Slot REQUIRED: with_cancel (the safe way out) - a call without it raises.
- `size:` (symbol) - one of default|sm, default "default", required
Slots: trigger (takes poetry_button props, not a block; with_trigger yields NOTHING to the block - no |param|, write content directly), title, description, media, action (takes poetry_button props, not a block; with_action yields NOTHING to the block - no |param|, write content directly), cancel (takes poetry_button props, not a block; with_cancel yields NOTHING to the block - no |param|, write content directly).
- PART `alert-dialog` - Root wrapper around the trigger and the <dialog> element
- PART `alert-dialog-content` - The role=alertdialog <dialog> panel - sizing, animation, and the open state ride here | states: data-open (panel is open (the shared dialog controller flips the pair at runtime)); data-closed (panel is closed (the server-rendered state)); data-size=default|sm (always - the resolved size)
- PART `alert-dialog-header` - Title block - holds the optional media well, the title, and the description
- PART `alert-dialog-title` - The heading - the alertdialog's accessible name (required slot)
- PART `alert-dialog-description` - The explanation, wired to aria-describedby (required slot)
- PART `alert-dialog-footer` - The choice row - cancel then action
- WIRING `poetry--core--dialog`: targets dialog; values dismissible, hotkey; actions backdropClose, close, lockScroll, open, toggle, unlockScroll
- RULE: Destructive confirmations use AlertDialog with with_action(variant: :destructive) - never a bare Dialog, never data-turbo-confirm.
- RULE: with_title AND with_description are REQUIRED (both raise).
- RULE: The action must be an explicit user activation - agents NEVER auto-submit the action.
- RULE: No extra form fields inside an AlertDialog - if input is needed, use a Dialog.
- RULE: Cancel keeps variant: :outline; do not make cancel visually primary.

## command (`poetry_command`)

Class: Poetry::Ui::Command::Component - BEM block `poetry-ui-command`.
REQUIRED - one of id: / aria-label: / aria-labelledby: / aria: (the input's accessible name); a call satisfying none raises.
- `disabled:` (boolean) - default false
- `filter:` (boolean) - default true
- `id:` (string)
- `list_label:` (string) - default "dynamic"
- `loop:` (boolean) - default false
- `placeholder:` (string)
- `value:` (string)
Slots: empty, loading, items (many; types item|group|separator - one with_<type> setter each, options as keywords).
- PART `command` - Root of the palette - the input row over the listbox, carrying the engine controller
- PART `command-input-wrapper` - The input row - search icon + filter input above the list
- PART `command-search-icon` - Decorative search glyph beside the input
- PART `command-input` - The role=combobox filter input - real focus stays pinned here for the whole session; the highlight rides aria-activedescendant
- PART `command-list` - The role=listbox holding empty/loading/items - the input's aria-controls target
- PART `command-empty` - Zero-matches message - rendered hidden; the controller unhides it when the filter pass leaves no visible items
- PART `command-loading` - Pending affordance (role=status) - rendered hidden; the HOST toggles it (Turbo frame events), Command never does
- PART `command-group` - role=group labelled by its heading - hidden by the controller when every member item is filtered out | states: data-always-render (always_render: is set - the group survives every filter pass)
- PART `command-group-heading` - The group heading - styled, no ARIA role (the group points at it via aria-labelledby)
- PART `command-item` - One role=option action row - highlight, filtering, and disablement ride here (never aria-selected in a bare Command) | states: data-value (always - the item's unique value (its server-stable id follows registration order)); data-highlighted (the item holds the highlight (bare; the controller twin-writes it with the input's aria-activedescendant)); data-disabled (disabled: is set (aria-disabled rides along)); data-keywords (keywords: given - extra filter terms beyond the label); data-always-render (always_render: is set - the item survives every filter pass); data-hidden (the filter scored the item zero (the controller pairs it with hidden; never rendered server-side))
- PART `command-item-text` - The item's label span - the filter/typematch text source (shortcuts and icons excluded)
- PART `command-shortcut` - Presentational keyboard hint - excluded from the filter text; Command never binds the hinted key
- PART `command-separator` - Decorative divider (aria-hidden) - hidden by the controller whenever the query is non-empty
- PART `command-status` - The sr-only polite result-count live region - the controller writes the debounced count from the localized templates | states: data-zero (always - the localized zero-results template); data-one (always - the localized one-result template); data-other (always - the localized many-results template (a literal count placeholder the controller interpolates))
- WIRING `poetry--core--command`: values debounce, filter, loop; actions activate, filterInput, highlightItem, keydown, pointerHighlight, reset; events poetry:command:filter, poetry:command:highlight, poetry:command:select
- RULE: Use poetry_command - never hand-roll a filterable listbox with an input + a list and ad-hoc JS.
- RULE: Command items DO things; they carry no form value. Picking a value for a form is Combobox (which wraps this) - never bind a hidden input to a bare Command.
- RULE: Every item needs a unique value: (ArgumentError) and gets a server id - never strip item ids (aria-activedescendant depends on them).
- RULE: Never put tabindex or focus on options; never write aria-selected in a bare Command - highlight is data-highlighted + activedescendant only.
- RULE: Filtering is hide-only: never reorder, remove, or re-append items to 'sort' results - DOM order is the contract.
- RULE: The poetry:command:select event is the ONLY activation surface - act in a listener (or item data-action); don't patch the controller to navigate.
- RULE: Long/async data: filter: false + a Turbo frame (the recipe) - don't render 5,000 items and hope.
- RULE: Icon-rich labels: set filter_value:/keywords: rather than stuffing hidden text into items.

## command_dialog (`poetry_command_dialog`)

Class: Poetry::Ui::Command::DialogComponent - BEM block `poetry-ui-command-dialog`.
- `description:` (string) - default "dynamic"
- `dismissible:` (boolean) - default true
- `filter:` (boolean) - default true
- `hotkey:` (string)
- `id:` (string)
- `list_label:` (string)
- `loop:` (boolean) - default false
- `placeholder:` (string)
- `show_close_button:` (boolean) - default true
- `title:` (string) - default "dynamic"
- `value:` (string)
Slots: trigger (with_trigger yields NOTHING to the block - no |param|, write content directly).
- PART `command-dialog` - Root wrapper around the trigger and the <dialog> - the palette's own chrome; the embedded Command inside carries its own part contract
- PART `dialog-content` - The <dialog> panel (Dialog's chrome retuned to overflow-hidden p-0) - positioning, animation, and the open state ride here | states: data-open (panel is open (the dialog controller flips the pair at runtime)); data-closed (panel is closed or animating out (the server-rendered state))
- PART `dialog-header` - Dialog's title block, sr-only here - the palette owns the visible surface
- PART `dialog-title` - The sr-only heading - the dialog's accessible name (defaults to the source string)
- PART `dialog-description` - The sr-only description wired to aria-describedby
- WIRING `poetry--core--command`: values debounce, filter, loop; actions activate, filterInput, highlightItem, keydown, pointerHighlight, reset; events poetry:command:filter, poetry:command:highlight, poetry:command:select
- WIRING `poetry--core--dialog`: targets dialog; values dismissible, hotkey; actions backdropClose, close, lockScroll, open, toggle, unlockScroll
- RULE: App-wide palettes use poetry_command_dialog with hotkey: ('meta+k') - never a hand-wired window keydown listener around poetry_dialog.
- RULE: Open it with with_trigger(...) too - the hotkey is an accelerator, not the only way in.
- RULE: The sr-only title/description default to the source strings - override title:/description: rather than removing them (they are the dialog's accessible name).
- RULE: Item wiring is Command's: act on poetry:command:select; close the dialog in the listener if the action should dismiss the palette.

## context_menu (`poetry_context_menu`)

Class: Poetry::Ui::ContextMenu::Component - BEM block `poetry-ui-context_menu`.
Slot REQUIRED: with_trigger (the right-click surface) - a call without it raises.
Slot REQUIRED: with_item (at least one item) - a call without it raises.
- `dir:` (symbol) - one of ltr|rtl
- `disabled:` (boolean) - default false
- `focusable_surface:` (boolean) - default false
- `label:` (string)
- `long_press_delay:` (integer) - default 700
- `modal:` (boolean) - default true
- `open:` (boolean) - default false
Slots: items (many; types item|checkbox_item|radio_group|label|separator|group|sub - one with_<type> setter each, options as keywords; with_item/with_checkbox_item/with_label yield NOTHING to the block - no |param|, write content directly; each with_radio_group REQUIRES with_radio_item inside its block (at least one radio item); each with_group REQUIRES with_item inside its block (at least one item); each with_sub REQUIRES with_trigger inside its block (the sub-menu item); each with_sub REQUIRES with_item inside its block (at least one item)), trigger (with_trigger yields NOTHING to the block - no |param|, write content directly).
- PART `context-menu` - Root wrapper hosting the context-menu + menu + popper controllers around the surface and content
- PART `context-menu-trigger` - The right-click/long-press SURFACE wrapping the logical object - not a widget: no role, no aria-haspopup | states: data-popup-open (the menu is open (absence is the closed state - no aria-expanded on a role-less surface)); data-disabled (the surface is inert (disabled: true))
- PART `context-menu-content` - The role=menu popup panel - anchored at the pointer via popper's virtual-anchor mode; open state and animation ride here | states: data-open (menu is open (presence flips the pair at runtime)); data-closed (menu is closed or animating out (the server-rendered state)); data-side=top|right|bottom|left (the placement side (forced right initially; popper re-writes it after collision flips)); data-align=start|center|end (the alignment (forced start initially; popper re-resolves it)) | vars: --transform-origin (popper's anchor-facing animation origin); --available-width (popper: viewport space left for the panel (post-flip)); --available-height (popper: viewport space left for the panel (post-flip)); --anchor-width (popper: the anchor rect's measured width); --anchor-height (popper: the anchor rect's measured height)
- PART `context-menu-label` - Non-interactive heading for a run of items
- PART `context-menu-item` - One role=menuitem action row | states: data-variant (default or destructive (the danger treatment)); data-inset (indented to align with checkbox/radio item text (inset: true)); data-disabled (item is disabled (always written together with aria-disabled))
- PART `context-menu-checkbox-item` - A role=menuitemcheckbox toggle row | states: data-checked (checked (the controller re-writes the pair with aria-checked on activation)); data-unchecked (unchecked); data-close-on-select (per-item override of the menu's close-on-select default ("false" keeps the menu open))
- PART `context-menu-radio-group` - role=group scoping one single-select value | states: data-value (the selected radio value (the controller re-writes it on change))
- PART `context-menu-radio-item` - A role=menuitemradio row inside a radio group | states: data-checked (the selected radio (the controller re-writes the pair with aria-checked)); data-unchecked (not selected); data-value (the radio's value)
- PART `context-menu-item-indicator` - The check/circle glyph slot inside checkbox and radio items - state rides the parent item; the glyph stays decorative
- PART `context-menu-separator` - role=separator rule between groups
- PART `context-menu-shortcut` - The trailing keybinding HINT - aria-hidden, never binds the key
- PART `context-menu-sub` - A submenu scope - hosts its own popper around the sub trigger/content pair
- PART `context-menu-sub-trigger` - The role=menuitem row opening its submenu | states: data-popup-open (its submenu is open (written with aria-expanded; absence is the closed state)); data-inset (indented to align with checkbox/radio item text (inset: true))
- PART `context-menu-sub-content` - The nested role=menu panel - its own popper content on the same presence machinery | states: data-open (submenu is open (presence flips the pair at runtime)); data-closed (submenu is closed (the server-rendered state)); data-side=top|right|bottom|left (the placement side (right/left by direction; popper resolves it at runtime)); data-align=start|center|end (the alignment against the sub-trigger (popper resolves it at runtime)) | vars: --transform-origin (popper's anchor-facing animation origin); --available-width (popper: viewport space left for the panel (post-flip)); --available-height (popper: viewport space left for the panel (post-flip)); --anchor-width (popper: the sub-trigger's measured width); --anchor-height (popper: the sub-trigger's measured height)
- WIRING `poetry--core--context-menu`: values disabled, longPressDelay; actions disabledValueChanged, open, pressCancel, pressStart; events poetry:context-menu:open
- WIRING `poetry--core--menu`: values closeOnSelect, loop, modal, open, typeaheadTimeout; actions activate, close, closeSub, keydown, open, openSub, openValueChanged, subEnter, subLeave, toggle, triggerKeydown; events poetry:menu:change, poetry:menu:closed, poetry:menu:edge-navigate, poetry:menu:open, poetry:menu:select
- WIRING `poetry--core--popper`: targets anchor, arrow, content; values align, alignOffset, anchor, anchorPoint, avoidCollisions, side, sideOffset, strategy; actions anchorPointValueChanged, reposition, setAnchor, setAnchorElement
- RULE: NEVER make a context menu the only path to an action - it is an invisible affordance; every item needs a visible equivalent (a '...' DropdownMenu button, a toolbar, a detail page).
- RULE: Choose ContextMenu only for right-click-on-an-object semantics; a visible button opening a menu is DropdownMenu.
- RULE: Do not add aria-haspopup or a role to the trigger surface; do not make it focusable except via focusable_surface: true.
- RULE: Do not try to set side/align/side_offset - context menus anchor at the pointer, always.
- RULE: Wrap the whole logical object (row/card) as the trigger surface, not a fragment.
- RULE: Destructive items use variant: :destructive AND still confirm irreversible actions via a dialog.
- RULE: shortcut: is a visual hint only - it does NOT bind the key.
- RULE: Do not nest a ContextMenu trigger surface inside another ContextMenu trigger surface.

## dialog (`poetry_dialog`)

Class: Poetry::Ui::Dialog::Component - BEM block `poetry-ui-dialog`.
Slot REQUIRED: with_title (the accessible name) - a call without it raises.
- `dismissible:` (boolean) - default true
Slots: trigger (takes poetry_button props, not a block; with_trigger yields NOTHING to the block - no |param|, write content directly), title, description, footer.
- PART `dialog` - Root wrapper around the trigger and the <dialog> element
- PART `dialog-content` - The <dialog> panel - positioning, animation, and the open state ride here | states: data-open (panel is open (the controller flips the pair at runtime)); data-closed (panel is closed or animating out (the server-rendered state))
- PART `dialog-header` - Title block at the top of the panel
- PART `dialog-title` - The heading - the dialog's accessible name (required slot)
- PART `dialog-description` - Muted copy under the title, wired to aria-describedby
- PART `dialog-footer` - Action row at the bottom of the panel
- WIRING `poetry--core--dialog`: targets dialog; values dismissible, hotkey; actions backdropClose, close, lockScroll, open, toggle, unlockScroll
- RULE: Open dialogs with with_trigger(...) - never a hand-wired button.
- RULE: with_title is REQUIRED (the accessible name); with_description when the purpose needs explaining.
- RULE: Confirmations that must not be lost use dismissible: false (backdrop clicks stop closing).
- RULE: Destructive confirmations pair a destructive Button in the footer - never auto-submit.

## drawer (`poetry_drawer`)

Class: Poetry::Ui::Drawer::Component - BEM block `poetry-ui-drawer`.
Slot REQUIRED: with_title (the accessible name) - a call without it raises.
- `direction:` (symbol) - one of down|up|left|right, default "down", required
- `dismissible:` (boolean) - default true
- `show_swipe_handle:` (boolean) - default false
Slots: trigger (takes poetry_button props, not a block; with_trigger yields NOTHING to the block - no |param|, write content directly), title, description, footer.
- PART `drawer` - Root wrapper around the trigger and the <dialog> element
- PART `drawer-content` - The <dialog> popup - the edge chrome, presence animation, and the swipe contract all ride here (::backdrop inherits the swipe vars, so the overlay fade rides along) | states: data-open (popup is open (the controller flips the pair at runtime)); data-closed (popup is closed or animating out (the server-rendered state)); data-swipe-direction=down|up|left|right (always - the dismiss direction); data-swiping (a pointer drag is tracking (transitions go duration-0 - the drawer follows the finger)); data-starting-style (the enter transition's first frame (the presence helper's two-frame trick)); data-ending-style (held through the exit transition before the native close()) | vars: --drawer-swipe-movement-x (px dragged toward a left/right dismissal (controller-written during swipes)); --drawer-swipe-movement-y (px dragged toward an up/down dismissal (controller-written during swipes)); --drawer-swipe-progress (0..1 fraction of the dismiss travel (the backdrop fade rides it)); --drawer-swipe-strength (remaining-travel factor set on release - scales the exit duration so a mostly-swiped drawer closes fast)
- PART `drawer-swipe-handle` - The grab pill (show_swipe_handle: true, aria-hidden) - a drag may always start on it
- PART `drawer-header` - Title block at the top of the popup
- PART `drawer-title` - The heading - the drawer's accessible name (required slot)
- PART `drawer-description` - Muted copy under the title, wired to aria-describedby
- PART `drawer-body` - The scrollable content region between header and footer
- PART `drawer-footer` - Action row pinned to the bottom of the popup
- WIRING `poetry--core--drawer`: targets dialog; values direction, dismissible, hotkey; actions backdropClose, close, lockScroll, open, swipeCancel, swipeEnd, swipeMove, swipeStart, toggle, unlockScroll
- RULE: Open drawers with with_trigger(...) - never a hand-wired button.
- RULE: with_title is REQUIRED (the accessible name) - the inherited Dialog rule.
- RULE: direction: is the DISMISS direction: :down is the mobile bottom sheet (the default); left/right make an edge panel - prefer Sheet on desktop.
- RULE: show_swipe_handle: true renders the grab pill - use it on bottom sheets so the gesture is discoverable.
- RULE: Esc and the backdrop still dismiss (the platform trap) - the swipe is an addition, never the only way out.

## dropdown_menu (`poetry_dropdown_menu`)

Class: Poetry::Ui::DropdownMenu::Component - BEM block `poetry-ui-dropdown_menu`.
Slot REQUIRED: with_trigger (the menu button) - a call without it raises.
Slot REQUIRED: with_item (at least one item) - a call without it raises.
- `align:` (symbol) - one of start|center|end, default "center"
- `align_offset:` (integer) - default 0
- `avoid_collisions:` (boolean) - default true
- `dir:` (symbol) - one of ltr|rtl
- `disabled:` (boolean) - default false
- `loop:` (boolean) - default false
- `modal:` (boolean) - default true
- `open:` (boolean) - default false
- `side:` (symbol) - one of top|right|bottom|left, default "bottom"
- `side_offset:` (integer) - default 4
Slots: items (many; types item|checkbox_item|radio_group|label|separator|group|sub - one with_<type> setter each, options as keywords; with_item/with_checkbox_item/with_label yield NOTHING to the block - no |param|, write content directly; each with_radio_group REQUIRES with_radio_item inside its block (at least one radio item); each with_group REQUIRES with_item inside its block (at least one item); each with_sub REQUIRES with_trigger inside its block (the sub-menu item); each with_sub REQUIRES with_item inside its block (at least one item)), trigger (takes poetry_button props, not a block; with_trigger yields NOTHING to the block - no |param|, write content directly).
- PART `dropdown-menu` - Root wrapper hosting the menu + popper controllers around the trigger and content
- PART `dropdown-menu-content` - The role=menu popup panel - positioning, animation, and the open state ride here | states: data-open (menu is open (presence flips the pair at runtime)); data-closed (menu is closed or animating out (the server-rendered state)); data-side=top|right|bottom|left (the placement side (popper re-writes it after collision flips)); data-align=start|center|end (the alignment against the trigger (popper re-resolves it)) | vars: --transform-origin (popper's anchor-facing animation origin); --available-width (popper: viewport space left for the panel (post-flip)); --available-height (popper: viewport space left for the panel (post-flip)); --anchor-width (popper: the trigger's measured width); --anchor-height (popper: the trigger's measured height)
- PART `dropdown-menu-group` - role=group semantic grouping between separators
- PART `dropdown-menu-label` - Non-interactive heading for a run of items | states: data-inset (indented to align with checkbox/radio item text (inset: true))
- PART `dropdown-menu-item` - One role=menuitem action row | states: data-variant (default or destructive (the danger treatment)); data-inset (indented to align with checkbox/radio item text (inset: true)); data-disabled (item is disabled (always written together with aria-disabled))
- PART `dropdown-menu-checkbox-item` - A role=menuitemcheckbox toggle row | states: data-checked (checked (the controller re-writes the pair with aria-checked on activation)); data-unchecked (unchecked); data-disabled (item is disabled (always written together with aria-disabled)); data-close-on-select (per-item override of the menu's close-on-select default ("false" keeps the menu open))
- PART `dropdown-menu-radio-group` - role=group scoping one single-select value | states: data-value (the selected radio value (the controller re-writes it on change))
- PART `dropdown-menu-radio-item` - A role=menuitemradio row inside a radio group | states: data-checked (the selected radio (the controller re-writes the pair with aria-checked)); data-unchecked (not selected); data-value (the radio's value)
- PART `dropdown-menu-item-indicator` - The check/circle glyph slot inside checkbox and radio items - state rides the parent item; the glyph stays decorative
- PART `dropdown-menu-separator` - role=separator rule between groups
- PART `dropdown-menu-shortcut` - The trailing keybinding HINT - aria-hidden, never binds the key
- PART `dropdown-menu-sub` - A submenu scope - hosts its own popper around the sub trigger/content pair
- PART `dropdown-menu-sub-trigger` - The role=menuitem row opening its submenu | states: data-popup-open (its submenu is open (written with aria-expanded; absence is the closed state))
- PART `dropdown-menu-sub-content` - The nested role=menu panel - its own popper content on the same presence machinery | states: data-open (submenu is open (presence flips the pair at runtime)); data-closed (submenu is closed (the server-rendered state)); data-side=top|right|bottom|left (the placement side (right/left by direction; popper resolves it at runtime)); data-align=start|center|end (the alignment against the sub-trigger (popper resolves it at runtime)) | vars: --transform-origin (popper's anchor-facing animation origin); --available-width (popper: viewport space left for the panel (post-flip)); --available-height (popper: viewport space left for the panel (post-flip)); --anchor-width (popper: the sub-trigger's measured width); --anchor-height (popper: the sub-trigger's measured height)
- WIRING `poetry--core--menu`: values closeOnSelect, loop, modal, open, typeaheadTimeout; actions activate, close, closeSub, keydown, open, openSub, openValueChanged, subEnter, subLeave, toggle, triggerKeydown; events poetry:menu:change, poetry:menu:closed, poetry:menu:edge-navigate, poetry:menu:open, poetry:menu:select
- WIRING `poetry--core--popper`: targets anchor, arrow, content; values align, alignOffset, anchor, anchorPoint, avoidCollisions, side, sideOffset, strategy; actions anchorPointValueChanged, reposition, setAnchor, setAnchorElement
- RULE: Use poetry_dropdown_menu - never hand-roll role=menu popups with Tailwind.
- RULE: Items are ACTIONS. Choosing a form VALUE is a Select/Combobox - do not fake it with radio items.
- RULE: Icon-only triggers MUST have an accessible name (the composed Button's label: rule).
- RULE: Never write the state attributes (data-popup-open / data-checked / data-unchecked) without their aria twin (aria-expanded / aria-checked) - the controller writes both; agents patching DOM must too.
- RULE: Destructive items use variant: :destructive AND still confirm irreversible actions via a dialog.
- RULE: shortcut: is a visual hint only - it does NOT bind the key; wire a real hotkey separately or omit it.
- RULE: Do not nest interactive elements inside items (a menuitem IS the interactive unit).
- RULE: Keep submenus <= 2 levels; prefer grouping + separators over deep nesting.
- RULE: Critical actions must exist somewhere reachable without JS (menus are JS-required interaction).

## hover_card (`poetry_hover_card`)

Class: Poetry::Ui::HoverCard::Component - BEM block `poetry-ui-hover_card`.
Slot REQUIRED: with_trigger (the enriched link) - a call without it raises.
- `align:` (symbol) - one of start|center|end, default "center"
- `align_offset:` (integer) - default 0
- `avoid_collisions:` (boolean) - default true
- `close_delay:` (integer) - default 300
- `content_class:` (string)
- `defer:` (string)
- `open:` (boolean) - default false
- `open_delay:` (integer) - default 700
- `side:` (symbol) - one of top|right|bottom|left, default "bottom"
- `side_offset:` (integer) - default 4
Slots: trigger.
- PART `hover-card` - Root wrapper around the trigger link and the panel
- PART `hover-card-trigger` - The enriched link itself - simultaneously the no-JS fallback, the touch path, and the keyboard path | states: data-popup-open (bare while the card is open; absent while closed (Base UI absence-is-the-state))
- PART `hover-card-content` - The role-less preview panel (invisible to AT on purpose) - positioning, animation, and the open state ride here | states: data-open (card is open (the controller flips the pair at runtime)); data-closed (card is closed (the server-rendered state; hidden rides along)); data-side=top|right|bottom|left (always - the side (initial placement, re-resolved live by popper after flip)); data-align=start|center|end (always - the alignment (re-resolved live by popper)) | vars: --transform-origin (the anchor-facing origin popper writes for scale-in animation); --available-width (viewport space left for the panel (popper, post-flip)); --available-height (viewport space left for the panel (popper, post-flip)); --anchor-width (the anchor's measured width (popper)); --anchor-height (the anchor's measured height (popper))
- WIRING `poetry--core--hover-card`: values closeDelay, open, openDelay; actions blurClose, focusOpen, openValueChanged, pointerEnter, pointerLeave, touchGuard; events poetry:hover-card:closed, poetry:hover-card:open
- WIRING `poetry--core--popper`: targets anchor, arrow, content; values align, alignOffset, anchor, anchorPoint, avoidCollisions, side, sideOffset, strategy; actions anchorPointValueChanged, reposition, setAnchor, setAnchorElement
- RULE: Use poetry_hover_card - never hand-roll hover-div previews.
- RULE: THE REACHABLE-ELSEWHERE RULE (non-negotiable): every piece of information in a hover card MUST exist at the trigger link's destination (or another keyboard/touch-reachable surface). The card is pointer-only enrichment - keyboard and touch users never see inside it.
- RULE: The trigger must be a REAL link with a real href - it is the fallback, the touch path, and the keyboard path all at once.
- RULE: NO interactive elements inside the card - they get tabindex=-1 stripped and become pointer-only traps. Actions belong in a Popover or at the destination.
- RULE: Don't add aria-expanded/haspopup to the trigger - advertising an unreachable surface is worse than silence (Radix-aligned).
- RULE: Never use HoverCard for hints (Tooltip) or for content users act on (Popover).
- RULE: Prefer defer: for expensive previews - a lazy turbo-frame that fetches on first open.

## menubar (`poetry_menubar`)

Class: Poetry::Ui::Menubar::Component - BEM block `poetry-ui-menubar`.
Slot REQUIRED: with_menu (at least one menu) - a call without it raises.
- `dir:` (symbol) - one of ltr|rtl
- `label:` (string) - required
- `loop:` (boolean) - default false
- `value:` (string)
Slots: menus (many; each with_menu REQUIRES with_trigger inside its block (the top-level menu button); each with_menu REQUIRES with_item inside its block (at least one item)).
- PART `menubar` - The role=menubar bar - one horizontal roving tab stop across the triggers | states: data-open (some menu is open (value present; the coordinator flips the pair)); data-closed (no menu is open)
- PART `menubar-menu` - One logical menu - a display:contents wrapper hosting the trigger + content pair's menu and popper controllers
- PART `menubar-trigger` - The top-level menu button - a role=menuitem INSIDE the bar | states: data-value (the menu's value - the coordinator's open/close key); data-popup-open (its menu is open (written with aria-expanded; absence is the closed state)); data-disabled (trigger is disabled (written together with the disabled property))
- PART `menubar-content` - The role=menu popup panel - positioning, animation, and the open state ride here | states: data-open (menu is open (presence flips the pair at runtime)); data-closed (menu is closed or animating out (the server-rendered state)); data-side=top|right|bottom|left (the placement side (bottom initially; popper re-writes it after collision flips)); data-align=start|center|end (the alignment against the trigger (start initially; popper re-resolves it)) | vars: --transform-origin (popper's anchor-facing animation origin); --available-width (popper: viewport space left for the panel (post-flip)); --available-height (popper: viewport space left for the panel (post-flip)); --anchor-width (popper: the trigger's measured width); --anchor-height (popper: the trigger's measured height)
- PART `menubar-item` - One role=menuitem action row | states: data-variant (default or destructive (the danger treatment)); data-inset (indented to align with checkbox/radio item text (inset: true)); data-disabled (item is disabled (always written together with aria-disabled))
- PART `menubar-checkbox-item` - A role=menuitemcheckbox toggle row | states: data-checked (checked (the controller re-writes the pair with aria-checked on activation)); data-unchecked (unchecked); data-close-on-select (per-item override of the menu's close-on-select default ("false" keeps the menu open))
- PART `menubar-radio-group` - role=group scoping one single-select value | states: data-value (the selected radio value (the controller re-writes it on change))
- PART `menubar-radio-item` - A role=menuitemradio row inside a radio group | states: data-checked (the selected radio (the controller re-writes the pair with aria-checked)); data-unchecked (not selected); data-value (the radio's value)
- PART `menubar-item-indicator` - The check/circle glyph slot inside checkbox and radio items - state rides the parent item; the glyph stays decorative
- PART `menubar-separator` - role=separator rule between groups
- PART `menubar-shortcut` - The trailing keybinding HINT - aria-hidden, never binds the key
- PART `menubar-sub` - A submenu scope - hosts its own popper around the sub trigger/content pair
- PART `menubar-sub-trigger` - The role=menuitem row opening its submenu | states: data-popup-open (its submenu is open (written with aria-expanded; absence is the closed state))
- PART `menubar-sub-content` - The nested role=menu panel - its own popper content on the same presence machinery | states: data-open (submenu is open (presence flips the pair at runtime)); data-closed (submenu is closed (the server-rendered state)); data-side=top|right|bottom|left (the placement side (right/left by direction; popper resolves it at runtime)); data-align=start|center|end (the alignment against the sub-trigger (popper resolves it at runtime)) | vars: --transform-origin (popper's anchor-facing animation origin); --available-width (popper: viewport space left for the panel (post-flip)); --available-height (popper: viewport space left for the panel (post-flip)); --anchor-width (popper: the sub-trigger's measured width); --anchor-height (popper: the sub-trigger's measured height)
- WIRING `poetry--core--menu`: values closeOnSelect, loop, modal, open, typeaheadTimeout; actions activate, close, closeSub, keydown, open, openSub, openValueChanged, subEnter, subLeave, toggle, triggerKeydown; events poetry:menu:change, poetry:menu:closed, poetry:menu:edge-navigate, poetry:menu:open, poetry:menu:select
- WIRING `poetry--core--menubar`: values loop, value; actions hoverSlide, onMenuClosed, slideAdjacent, toggle, triggerKeydown, valueValueChanged; events poetry:menubar:value-changed
- WIRING `poetry--core--popper`: targets anchor, arrow, content; values align, alignOffset, anchor, anchorPoint, avoidCollisions, side, sideOffset, strategy; actions anchorPointValueChanged, reposition, setAnchor, setAnchorElement
- WIRING `poetry--core--roving-focus`: values loop, manageTabindex, orientation; actions keydown; events poetry--core--roving-focus:entry
- RULE: Use poetry_menubar for app-chrome command menus ONLY - site navigation is NavigationMenu (untrapped), a single actions menu is DropdownMenu.
- RULE: label: is REQUIRED (the bar's accessible name).
- RULE: Never put non-menuitem interactive elements directly in the bar (breaks roving focus + APG roles) - a Toolbar is the component for mixed controls.
- RULE: shortcut: is a visual hint ONLY - it does not register a keybinding; wire real shortcuts separately.
- RULE: Do not hand-wire hover-open-from-cold; hover only slides between menus once one is open (the gated-hover rule).
- RULE: In-menu item rules (destructive variant, inset, checkbox/radio) follow the DropdownMenu family contract.

## popover (`poetry_popover`)

Class: Poetry::Ui::Popover::Component - BEM block `poetry-ui-popover`.
Slot REQUIRED: with_trigger (the panel's control) - a call without it raises.
- `align:` (symbol) - one of start|center|end, default "center"
- `align_offset:` (integer) - default 0
- `avoid_collisions:` (boolean) - default true
- `content_class:` (string)
- `label:` (string)
- `modal:` (boolean) - default false
- `open:` (boolean) - default false
- `side:` (symbol) - one of top|right|bottom|left, default "bottom"
- `side_offset:` (integer) - default 4
Slots: trigger (takes poetry_button props, not a block; with_trigger yields NOTHING to the block - no |param|, write content directly), anchor (with_anchor yields NOTHING to the block - no |param|, write content directly), title, description.
- PART `popover` - Root wrapper around the trigger, the optional anchor, and the panel
- PART `popover-anchor` - Optional alternate popper anchor (Radix PopoverAnchor) - when present the panel positions against it instead of the trigger
- PART `popover-content` - The role=dialog panel - positioning, animation, and the open state ride here | states: data-open (panel is open (the controller flips the pair at runtime)); data-closed (panel is closed (the server-rendered state; hidden rides along)); data-side=top|right|bottom|left (always - the side (initial placement, re-resolved live by popper after flip)); data-align=start|center|end (always - the alignment (re-resolved live by popper)) | vars: --transform-origin (the anchor-facing origin popper writes for scale-in animation); --available-width (viewport space left for the panel (popper, post-flip)); --available-height (viewport space left for the panel (popper, post-flip)); --anchor-width (the anchor's measured width (popper)); --anchor-height (the anchor's measured height (popper))
- PART `popover-header` - Title block wrapping the title and description (renders only when either is present)
- PART `popover-title` - The heading - the panel's accessible name via aria-labelledby
- PART `popover-description` - Muted copy under the title, wired to aria-describedby
- WIRING `poetry--core--popover`: values modal, open; actions close, open, openValueChanged, toggle; events poetry:popover:closed, poetry:popover:open
- WIRING `poetry--core--popper`: targets anchor, arrow, content; values align, alignOffset, anchor, anchorPoint, avoidCollisions, side, sideOffset, strategy; actions anchorPointValueChanged, reposition, setAnchor, setAnchorElement
- RULE: Use poetry_popover - never hand-roll an anchored role=dialog panel with Tailwind.
- RULE: Popover content is INTERACTIVE - for text-only hover hints use Tooltip; for pointer-only previews use HoverCard.
- RULE: Give the panel a name: use with_title (preferred) or label: - a role=dialog without a name fails the audit.
- RULE: Icon-only triggers MUST have an accessible name (the composed Button's label: rule).
- RULE: Default is NON-modal (modal: false) - reach for modal: true only when stray outside interaction would corrupt the task; reach for Dialog when the task deserves full modality.
- RULE: Critical-path panels must also be reachable without JS (full page or server-rendered open: true) - popovers are JS-required interaction.
- RULE: Do not nest a Popover inside a Popover - restructure (the layer stack allows it; comprehension does not).

## sheet (`poetry_sheet`)

Class: Poetry::Ui::Sheet::Component - BEM block `poetry-ui-sheet`.
Slot REQUIRED: with_title (the accessible name) - a call without it raises.
- `side:` (symbol) - one of top|right|bottom|left, default "right", required
- `dismissible:` (boolean) - default true
- `show_close_button:` (boolean) - default true
Slots: trigger (takes poetry_button props, not a block; with_trigger yields NOTHING to the block - no |param|, write content directly), title, description, footer.
- PART `sheet` - Root wrapper around the trigger and the <dialog> element
- PART `sheet-content` - The <dialog> panel, anchored to a screen edge - the slide animation and the open state ride here | states: data-open (panel is open (the controller flips the pair at runtime)); data-closed (panel is closed or animating out (the server-rendered state; the presence-hold close rides the closed slide-out)); data-side=top|right|bottom|left (always - the edge the sheet slides in from)
- PART `sheet-header` - Title block at the top of the panel
- PART `sheet-title` - The heading - the sheet's accessible name (required slot)
- PART `sheet-description` - Muted copy under the title, wired to aria-describedby
- PART `sheet-footer` - Action row pinned to the bottom of the panel
- WIRING `poetry--core--sheet`: targets dialog; values dismissible, hotkey; actions backdropClose, close, lockScroll, open, toggle, unlockScroll
- RULE: Open sheets with with_trigger(...) - never a hand-wired button.
- RULE: with_title is REQUIRED (the accessible name) - the inherited Dialog rule.
- RULE: Pick side by content: navigation left, detail/edit right, pickers bottom.
- RULE: Do not put must-not-lose confirmations in a Sheet - that is AlertDialog.
- RULE: Do not rebuild a centered Dialog with a Sheet; use Dialog.

## tooltip (`poetry_tooltip`)

Class: Poetry::Ui::Tooltip::Component - BEM block `poetry-ui-tooltip`.
Slot REQUIRED: with_trigger (the described control) - a call without it raises.
- `align:` (symbol) - one of start|center|end, default "center"
- `content_class:` (string)
- `delay_duration:` (integer)
- `disable_hoverable_content:` (boolean)
- `label:` (string)
- `open:` (boolean) - default false
- `side:` (symbol) - one of top|right|bottom|left, default "top"
- `side_offset:` (integer) - default 0
Slots: trigger (takes poetry_button props, not a block; with_trigger yields NOTHING to the block - no |param|, write content directly).
- PART `tooltip` - Root wrapper around the trigger and the bubble
- PART `tooltip-content` - The role=tooltip bubble - positioning, animation, and the open state ride here | states: data-open (bubble is open (the controller flips the pair at runtime)); data-closed (bubble is closed (the server-rendered state; hidden rides along)); data-instant=delay|focus (the open skipped the delay - warm-grace/programmatic or keyboard focus (runtime-only; absent on a delayed open)); data-side=top|right|bottom|left (always - the side (initial placement, re-resolved live by popper after flip)); data-align=start|center|end (always - the alignment (re-resolved live by popper)) | vars: --transform-origin (the anchor-facing origin popper writes for scale-in animation); --available-width (viewport space left for the bubble (popper, post-flip)); --available-height (viewport space left for the bubble (popper, post-flip)); --anchor-width (the anchor's measured width (popper)); --anchor-height (the anchor's measured height (popper))
- PART `tooltip-arrow` - The arrow wrapper (aria-hidden) - popper pins it to the bubble's anchor-facing edge and rotates it toward the anchor | states: data-side=top|right|bottom|left (written by popper alongside the content's - the resolved side, for per-side restyling)
- WIRING `poetry--core--popper`: targets anchor, arrow, content; values align, alignOffset, anchor, anchorPoint, avoidCollisions, side, sideOffset, strategy; actions anchorPointValueChanged, reposition, setAnchor, setAnchorElement
- WIRING `poetry--core--tooltip`: values delayDuration, disableHoverableContent, open; actions blurClose, clickClose, focusOpen, openValueChanged, pointerDown, pointerLeave, pointerMove; events poetry:tooltip:closed, poetry:tooltip:open
- RULE: Use poetry_tooltip - never hand-roll title-attribute replacements or hover divs.
- RULE: Tooltip content is TEXT and never interactive/focusable - links, buttons, or inputs inside are a contract violation (use Popover).
- RULE: Never put essential information only in a tooltip - touch users NEVER see it (no long-press path, by design).
- RULE: The tooltip DESCRIBES; it never names. Icon-only triggers still require label: on the composed Button.
- RULE: Wrap toolbar/button rows in ONE poetry_tooltip_provider so the warm grace makes the row feel continuous.
- RULE: Rich visual content needs label: (the plain-text announcement).
- RULE: Do not pin tooltips open as onboarding callouts - that is a Popover.

